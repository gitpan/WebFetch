#
# SiteNews.pm - get headlines from a site-local file
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::SiteNews;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $input $short_path $long_path %cat_priorities @month_name $now $nowstamp );

use Exporter;
use AutoLoader;
use WebFetch;;
use Date::Calc qw(Delta_Days);;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);

# set defaults
$short_path = undef;
$long_path = undef;

@Options = (
	"input=s" => \$input,
	"short=s" => \$short_path,
	"long=s" => \$long_path);
$Usage = "--input news-file --short short-output-file --long long-output-file";

# configuration parameters
$WebFetch::SiteNews::num_links = 5;

# no user-servicable parts beyond this point

# array indices
sub entry_text { 0; }
sub entry_priority { 1; }

# constants for state names
sub initial_state { 0; }
sub attr_state { 1; }
sub text_state { 2; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{num_links} = $WebFetch::SiteNews::num_links;

	# process the links

	# get local time for various date comparisons
	{
		$now = [ localtime ];
		$now->[4]++;       # month
		$now->[5] += 1900; # year (yes, this is Y2K safe)
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) 
			= @$now;
		$nowstamp = sprintf "%04d%02d%02d", $year, $mon, $mday;
	}

	# parse data file
	if ( ! open ( news_data, $input )) {
		die "$0: failed to open $input: $!\n";
	}
	my @news_items = ();
	my $position = 0;
	my $state = initial_state;		# before first entry
	my ( $current );
	while ( <news_data> ) {
		chop;
		/^\s*\#/ and next;	# skip comments
		/^\s*$/ and next;	# skip blank lines

		if ( /^[^\s]/ ) {
			# found attribute line
			if ( $state == initial_state or $state == text_state ) {
				# found first attribute of a new entry
				if ( /^([^=]+)=(.*)/ ) {
					$current = {};
					$current->{position} = $position++;
					$current->{$1} = $2;
					push ( @news_items, $current );
					$state = attr_state;
				}
			} elsif ( $state == attr_state ) {
				# found a followup attribute
				if ( /^([^=]+)=(.*)/ ) {
					$current->{$1} = $2;
				}
			}
		} else {
			# found text line
			if ( $state == initial_state ) {
				# cannot accept text before any attributes
				next;
			} elsif ( $state == attr_state or $state == text_state ) {
				if ( defined $current->{text}) {
					$current->{text} .= "\n$_";
				} else {
					$current->{text} = $_;
				}
				$state = text_state;
			}
		}
	}

	# save short/summary version of news
	my @short_news = sort for_short @news_items;
	my ( @short_links, $i );
	for ( $i = 0; $i < $#short_news; $i++ ) {
		# skip expired items (they were sorted to the end of the list)
		if ( expired( $short_news[$i])) {
			last;
		}
		push ( @short_links,
			[ $short_news[$i]{text}, priority($short_news[$i]) ]);
	}
	$self->html_gen( $short_path,
		sub { return $_[&entry_text]
			."\n<!--- priority ".$_[&entry_priority]." --->"; },
		\@short_links,
		{ "para" => 1 });

	# sort events for long display
	my @long_news = sort for_long @news_items;

	# process the links for the long list
	my ( @long_text, $prev, @news_export );
	$prev=undef;
	push @long_text, "<dl>";
	for ( $i = 0; $i <= $#long_news; $i++ ) {
		my $news = $long_news[$i];
		if (( ! defined $prev->{posted}) or
			$prev->{posted} ne $news->{posted})
		{
			push @long_text, "<dt>".printstamp($news->{posted});
			push @long_text, "<dd>";
		}
		push @long_text, $news->{text}."\n"
			."<!--- priority: ".priority($news)
			.(expired($news) ? " expired" : "")
			." --->";
		push @long_text, "<p>";
		push @news_export,
			[ printstamp($news->{posted}), $news->{text}];
		$prev = $news;
	}
	push @long_text, "</dl>";

	# store it for later save to disk
	$self->html_savable( $long_path, join("\n",@long_text)."\n" );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "date", "text" ],
                        \@news_export,
                        "Exported from WebFetch::SiteNews\n"
                                ."\"date\" is the date of the news\n"
                                ."\"text\" is the news text" );
        }
}

#---------------------------------------------------------------------------

# news category priorities
# numeric values may be changed - just make sure the numeric order is correct
%cat_priorities = (
	"svlug-meeting" => 1,
	"svlug" => 2,
	"linux" => 3,
	"other-group" => 4,
	"default" => 999
);

# function to print a timestamp in Human-readable form
@month_name = (
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December"
);

#
# utility functions
#

sub printstamp
{
	my ( $stamp ) = @_;
	my ( $year, $mon, $day ) = ( $stamp =~ /^(....)(..)(..)/ );

	return $month_name[$mon-1]." ".int($day).", $year";
}

# function to detect if a news entry is expired
sub expired
{
	my ( $entry ) = @_;
	return (( defined $entry->{expires}) and
		( $entry->{expires} lt $nowstamp ));
}

# function to get the priority value from 
sub priority
{
	my ( $entry ) = @_;

	( defined $entry->{posted}) or return 999;
	my ( $year, $mon, $day ) = ( $entry->{posted} =~ /^(....)(..)(..)/ );
	my $age = Delta_Days( $year, $mon, $day,
		$now->[5], $now->[4], $now->[3]);
	my $bonus = 0;

	if ( $age <= 2 ) {
		$bonus -= 2 - $age;
	}
	if (( defined $entry->{category}) and
		( defined $cat_priorities{$entry->{category}}))
	{
		return $cat_priorities{$entry->{category}} + $age * 0.025
			+ $bonus;
	} else {
		return $cat_priorities{"default"} + $age * 0.025
			+ $bonus;
	}
}

# function to sort news entries for short display
# (moves expired entries  to end instead of leaving them in place)
# sorting priority:
#	expiration status first (puts expired items at end of list)
#	category/priority second 
#	date third
#	file order last
sub for_short
{
	# check expirations first
	if ( expired($a) and !expired($b)) {
		return 1;
	}
	if ( !expired($a) and expired($b)) {
		return -1;
	}

	# compare posting category
	if ( priority($a) != priority($b)) {
		return priority($a) <=> priority($b)
	}

	# compare posting dates
	if (( defined $a->{posted}) and ( defined $b->{posted}) and
		( $a->{posted} ne $b->{posted} ))
	{
		return $b->{posted} cmp $a->{posted};
	}

	# otherwise resort to chronological order in the news data file
	return $b->{position} <=> $a->{position};
}

# function to sort news entries for long display
# sorting priority:
#	date first
#	category/priority second
#	reverse file order last
sub for_long
{
	# compare posting dates
	if (( defined $a->{posted}) and ( defined $b->{posted}) and
		( $a->{posted} ne $b->{posted} ))
	{
		return $b->{posted} cmp $a->{posted};
	}

	# compare posting category
	if ( priority($a) != priority($b)) {
		return priority($a) <=> priority($b)
	}

	# otherwise resort to chronological order in the news data file
	return $b->{position} <=> $a->{position};
}

#---------------------------------------------------------------------------

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::SiteNews - download and save SiteNews headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::SiteNews;>

From the command line:

C<perl C<-w> -MWebFetch::SiteNews C<-e> "&fetch_main" -- --dir I<directory>
     --input I<news-file> --short I<short-form-output-file>
     --long I<long-form-output-file>>

=head1 DESCRIPTION

This module gets the current headlines from a site-local file.

After this runs, the file C<site_news.html> will be created or replaced.
If there already was an C<site_news.html> file, it will be moved to
C<Osite_news.html>.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
Send patches, bug reports, suggestions and questions to
C<webfetch-maint@svlug.org>.

=head1 SEE ALSO

=for html
<a href="WebFetch.html">WebFetch</a>

=for text
WebFetch

=for man
WebFetch

=cut
