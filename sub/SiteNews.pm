#
# SiteNews.pm - get headlines from a site-local file
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::SiteNews;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $input $short_path $long_path $cat_priorities @month_name $now $nowstamp $ns_exp_file );

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
$ns_exp_file = undef;

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
	$cat_priorities = {};                   # priorities for sorting
	while ( <news_data> ) {
		chop;
		/^\s*\#/ and next;	# skip comments
		/^\s*$/ and next;	# skip blank lines

		if ( /^[^\s]/ ) {
			# found attribute line
			if ( $state == initial_state ) {
				if ( /^categories:\s*(.*)/ ) {
					my @cats = split ( /\s+/, $1 );
					my ( $i );
					$cat_priorities->{"default"} = 999;
					for ( $i=0; $i<=$#cats; $i++ ) {
						$cat_priorities->{$cats[$i]}
							= $i + 1;
					}
					next;
				} elsif ( /^url-prefix:\s*(.*)/ ) {
					$self->{url_prefix} = $1;
				}
			}
			if ( $state == initial_state or $state == text_state )
			{
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
	for ( $i = 0; $i <= $#short_news; $i++ ) {
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
	my ( @long_text, $prev, @news_export, %label_hash, @label_list,
		$url_prefix );
	$url_prefix = ( defined $self->{url_prefix})
		? $self->{url_prefix}
		: "";
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
		my $label = gen_label( \%label_hash, \@label_list, $news );
		push @long_text, "<a name=\"$label\">".$news->{text}."</a>\n"
			."<!--- priority: ".priority($news)
			.(expired($news) ? " expired" : "")
			." --->";
		push @long_text, "<p>";
		if ( ! expired($news)) {
			push @news_export,
				[ printstamp($news->{posted}),
				( defined $news->{title})
					? $news->{title} : $news->{text},
				$url_prefix."#".$label,
				$news->{text}];
		}
		$prev = $news;
	}
	push @long_text, "</dl>";

	# store it for later save to disk
	$self->html_savable( $long_path, join("\n",@long_text)."\n" );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "date", "title", "url", "text" ],
                        \@news_export,
                        "Exported from WebFetch::SiteNews\n"
                                ."\"date\" is the date of the news\n"
                                ."\"title\" is a one-liner title\n"
                                ."\"url\" is url to the news source\n"
                                ."\"text\" is the news text" );
        }

        # export content if --ns_export was specified
        if ( defined $self->{ns_export}) {
		my ( @ns_list );
		foreach ( sort { $b cmp $a } @label_list ) {
			push @ns_list, [ $label_hash{$_},
				$url_prefix."#".$_ ];
		}
                $self->ns_export( $self->{ns_export}, \@ns_list,
			$self->{ns_site_title}, $self->{ns_site_link},
			$self->{ns_site_desc}, $self->{ns_image_title},
			$self->{ns_image_url} );
        }
}

#---------------------------------------------------------------------------

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

# generate a printable version of the datestamp
sub printstamp
{
	my ( $stamp ) = @_;
	my ( $year, $mon, $day ) = ( $stamp =~ /^(....)(..)(..)/ );

	return $month_name[$mon-1]." ".int($day).", $year";
}

# generate and save an intra-document label
sub gen_label
{
	my ( $label_hash, $label_list, $news ) = @_;

	if ( ref($label_hash) ne "HASH" ) {
		die "WebFetch::SiteNews: label_hash parameter to gen_label "
			."is not a hash reference\n";
	}
	if ( ref($label_list) ne "ARRAY" ) {
		die "WebFetch::SiteNews: label_list parameter to gen_label "
			."is not an array reference\n";
	}
	if ( ref($news) ne "HASH" ) {
		die "WebFetch::SiteNews: news parameter to gen_label "
			."is not a hash reference\n";
	}
	my ( $i, $label );
	$i = 0;
	while (( $label = $news->{posted}."-".sprintf("%03d",$i)),
		defined $label_hash->{$label})
	{
		$i++;
	}
	
	# do not export items which have expired
	$label_hash->{$label} = (defined $news->{title})
		? $news->{title}
		: $news->{text};
	if ( !expired($news) ) {
		push @$label_list, $label;
	}

	return $label;
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
		( defined $cat_priorities->{$entry->{category}}))
	{
		return $cat_priorities->{$entry->{category}} + $age * 0.025
			+ $bonus;
	} else {
		return $cat_priorities->{"default"} + $age * 0.025
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

=head1 FILE FORMAT

The WebFetch::SiteNews data format is used to set up news for the
local web site and allow other sites to import it via WebFetch.
The file is plain text containing comments and the news items.

There are three forms of outputs generated from these news files.

The I<"short news" output> is a small number (5 by default)
of HTML text and links used for display in a small news window.
And example of this can be seen in the "SVLUG News" box on SVLUG's
home page.  This list takes into account expiration dates and
priorities to pick which news entries are displayed and in what order.

The I<"long news" output> lists all the news entries chronologically.
It does not take expiration or priority into account.
It is intended for a comprehensive site news list.
An example can be found on SVLUG's news page.

The I<export modes> make news items available in formats other web sites
can retrieve to post news about your site.  They are chronological
listings that omit expired items.
They do not take priorities into account.

=over 4

=item global parameters

Lines coming before the first news item can set global parameters.

=over 4

=item categories

A line before the first news item beginning with "categories:" contains a 
whitespace-delimited list of news category names in order from highest
to lowest priority.
These priority names are used by the news item attributes and
then for sorting "short news" list items.

=item url-prefix

A global parameter line beginning with "url-prefix:" will override the
--url_prefix command line parameter with a
URL prefix to use when exporting news items via the WebFetch Export
format (see --export)
or by MyNetscape's RDF export format (via --ns_export).

=back

=item data lines

Non-blank non-indented non-comment lines are I<data lines>.
Each data line contains a I<name=value> pair.
Each group of consecutive data lines is followed by an arbitrary number
of indented lines which contain HTML text for the news entry.

The recognized attributes are as follows:

=over 4

=item category

used for prioritization, values are set by the categories global parameter
(required)

=item posted

date posted, format is a numerical date YYYYMMDD (required)

=item expires

expiration date, format is a numerical date YYYYMMDD (optional)

=item title

shorter title for use in news exports to other sites,
otherwise the whole news text will be used (optional)

=back

=item text lines

Intended lines are HTML text for the news item.

=item comments

Comments are lines beginning with "#".
They are ignored so they can be used for human-readable information.

=back

Note that the "short news" list has some modifications to
priorities based on the age of the news item,
so that the short list will favor newer items when
they're the same priority.
There is a sorting "priority bonus" for items less than a
day old, which increases their priority by two priority levels.
Day-old news items get a bonus of one priority level.
All news items also "decay" in priority slightly every day,
dropping a whole priority level every 40 days.

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
