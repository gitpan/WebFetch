#
# WebFetch::Input::SiteNews.pm - get headlines from a site-local file
#
# Copyright (c) 1998-2009 Ian Kluft. This program is free software; you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License Version 3. See  http://www.webfetch.org/GPLv3.txt

package WebFetch::Input::SiteNews;

use strict;
use base "WebFetch";

use Carp;
use Date::Calc qw(Today Delta_Days Month_to_Text);

# set defaults
our ( $cat_priorities, $now, $nowstamp );

our @Options = (
	"short=s",
	"long=s",
);
our $Usage = "--short short-output-file --long long-output-file";

# configuration parameters
our $num_links = 5;

# no user-servicable parts beyond this point

# register capabilities with WebFetch
__PACKAGE__->module_register( "cmdline", "input:sitenews" );

# constants for state names
sub initial_state { 0; }
sub attr_state { 1; }
sub text_state { 2; }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	if ( !defined $self->{num_links}) {
		$self->{num_links} = $WebFetch::Input::SiteNews::num_links;
	}
	if ( !defined $self->{style}) {
		$self->{style} = {};
		$self->{style}{para} = 1;
	}

	# set up Webfetch Embedding API data
	$self->{data} = {}; 
	$self->{actions} = {}; 
	$self->{data}{fields} = [ "date", "title", "priority", "expired",
		"position", "label", "url", "category", "text" ];
	# defined which fields match to which "well-known field names"
	$self->{data}{wk_names} = {
		"title" => "title",
		"url" => "url",
		"date" => "date",
		"summary" => "text",
		"category" => "category"
	};
	$self->{data}{records} = [];

	# process the links

	# get local time for various date comparisons
	$now = [ Today ];
	$nowstamp = sprintf "%04d%02d%02d", @$now;

	# parse data file
	my $source;
	if (( exists $self->{sources}) and ( ref $self->{sources} eq "ARRAY" )) {
		foreach $source ( @{$self->{sources}}) {
			$self->parse_input( $source );
		}
	}

	# set parameters for the short news format
	if ( defined $self->{short_path} ) {
		# create the HTML actions list
		$self->{actions}{html} = [];

		# create the HTML-generation parameters
		my $params = {};
		$params = {};
		$params->{sort_func} = sub {
			my ( $a, $b ) = @_;

			# sort/compare news entries for the short display
			# sorting priority:
			#	expiration status first (expired items last)
			#	priority second (category/age combo)
			#	label third (chronological order)

			# check expirations first
			my $exp_fnum = $self->fname2fnum("expired");
			( $a->[$exp_fnum] and !$b->[$exp_fnum]) and return 1;
			( !$a->[$exp_fnum] and $b->[$exp_fnum]) and return -1;

			# compare priority - posting category w/ age penalty
			my $pri_fnum = $self->fname2fnum("priority");
			if ( $a->[$pri_fnum] != $b->[$pri_fnum] ) {
				return $a->[$pri_fnum] <=> $b->[$pri_fnum];
			}

			# otherwise sort by label (chronological order)
			my $lbl_fnum = $self->fname2fnum("label");
			return $a->[$lbl_fnum] cmp $b->[$lbl_fnum];
		};
		$params->{filter_func} = sub {
			# filter: skip expired items
			my $exp_fnum = $self->fname2fnum("expired");
			return ! $_[$exp_fnum];
		};
		$params->{format_func} = sub {
			# generate HTML text
			my $txt_fnum = $self->fname2fnum("text");
			my $pri_fnum = $self->fname2fnum("priority");
			return $_[$txt_fnum]
				."\n<!--- priority ".$_[$pri_fnum]." --->";
		};

		# put parameters for fmt_handler_html() on the html list
		push @{$self->{actions}{html}}, [ $self->{short_path}, $params ];
	}

	# set parameters for the long news format
	if ( defined $self->{long_path} ) {
		# create the SiteNews-specific action list
		# It will use WebFetch::Input::SiteNews::fmt_handler_sitenews_long()
		# which is defined in this file
		$self->{actions}{sitenews_long} = [];

		# put parameters for fmt_handler_sitenews_long() on the list
		push @{$self->{actions}{sitenews_long}}, [ $self->{long_path} ];
	}
}

# parse input file
sub parse_input
{
	my ( $self, $input ) = @_;

	# parse data file
	if ( ! open ( news_data, $input )) {
		croak "$0: failed to open $input: $!\n";
	}
	my @news_items;
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
					push( @news_items, $current );
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

	# translate parsed news into the WebFetch Embedding API data table
	my ( $item, %label_hash, $pos );
	$pos = 0;
	foreach $item ( @news_items ) {

		# generate an intra-page link label
		my ( $label, $count );
		$count=0;
		while (( $label = $item->{posted}."-".sprintf("%03d",$count)),
			defined $label_hash{$label})
		{
			$count++;
		}
		$label_hash{$label} = 1;

		# save the data record
		my $title = ( defined $item->{title}) ? $item->{title} : "";
		my $posted = ( defined $item->{posted}) ? $item->{posted} : "";
		my $category = ( defined $item->{category})
			? $item->{category} : "";
		my $text = ( defined $item->{text}) ? $item->{text} : "";
		my $url_prefix = ( defined $self->{url_prefix})
			? $self->{url_prefix} : "";
		push @{$self->{data}{records}},
			[ printstamp($posted), $title, priority( $item ),
				expired( $item ), $pos, $label,
				$url_prefix."#".$label, $category, $text ];
		$pos++;
	}
}

# format handler function specific to this module's long-news output format
sub fmt_handler_sitenews_long
{
	my ( $self, $filename ) = @_;

	# sort events for long display
	my @long_news = sort {
		# sort news entries for long display
		# sorting priority:
		#	date first
		#	category/priority second
		#	reverse file order last	

		# sort by date
		my $lbl_fnum = $self->fname2fnum("label");
		my ( $a_date, $b_date) = ( $a->[$lbl_fnum], $b->[$lbl_fnum]);
		$a_date =~ s/-.*//;
		$b_date =~ s/-.*//;
		if ( $a_date ne $b_date ) {
			return $b_date cmp $a_date;
		}

		# sort by priority (within same date)
		my $pri_fnum = $self->fname2fnum("priority");
		if ( $a->[$pri_fnum] != $b->[$pri_fnum] ) {
			return $a->[$pri_fnum] <=> $b->[$pri_fnum];
		}

		# sort by chronological order (within same date and priority)
		return $a->[$lbl_fnum] cmp $b->[$lbl_fnum];
	} @{$self->{data}{records}};

	# process the links for the long list
	my ( @long_text, $prev, $url_prefix, $i );
	$url_prefix = ( defined $self->{url_prefix})
		? $self->{url_prefix}
		: "";
	$prev=undef;
	push @long_text, "<dl>";
	my $lbl_fnum = $self->fname2fnum("label");
	my $date_fnum = $self->fname2fnum("date");
	my $title_fnum = $self->fname2fnum("title");
	my $txt_fnum = $self->fname2fnum("text");
	my $exp_fnum = $self->fname2fnum("expired");
	my $pri_fnum = $self->fname2fnum("priority");
	for ( $i = 0; $i <= $#long_news; $i++ ) {
		my $news = $long_news[$i];
		if (( ! defined $prev->[$date_fnum]) or
			$prev->[$date_fnum] ne $news->[$date_fnum])
		{
			push @long_text, "<dt>".$news->[$date_fnum];
			push @long_text, "<dd>";
		}
		push @long_text, "<a name=\"".$news->[$lbl_fnum]."\">"
			.$news->[$txt_fnum]."</a>\n"
			."<!--- priority: ".$news->[$pri_fnum]
			.($news->[$exp_fnum] ? " expired" : "")
			." --->";
		push @long_text, "<p>";
		$prev = $news;
	}
	push @long_text, "</dl>";

	# store it for later save to disk
	$self->html_savable( $self->{long_path}, join("\n",@long_text)."\n" );
}

#---------------------------------------------------------------------------

#
# utility functions
#

# generate a printable version of the datestamp
sub printstamp
{
	my ( $stamp ) = @_;
	my ( $year, $mon, $day ) = ( $stamp =~ /^(....)(..)(..)/ );

	return Month_to_Text(int($mon))." ".int($day).", $year";
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
	my $age = Delta_Days( $year, $mon, $day, @$now );
	my $bonus = 0;

	if ( $age <= 2 ) {
		$bonus -= 2 - $age;
	}
	if (( defined $entry->{category}) and
		( defined $cat_priorities->{$entry->{category}}))
	{
		my $cat_pri = ( exists $cat_priorities->{$entry->{category}})
			? $cat_priorities->{$entry->{category}} : 0;
		return $cat_pri + $age * 0.025 + $bonus;
	} else {
		return $cat_priorities->{"default"} + $age * 0.025
			+ $bonus;
	}
}

#---------------------------------------------------------------------------

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::Input::SiteNews - download and save SiteNews headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::Input::SiteNews;>

From the command line:

C<perl -w -MWebFetch::Input::SiteNews -e "&fetch_main" -- --dir directory
     --source news-file --short short-form-output-file
     --long long-form-output-file>

=head1 DESCRIPTION

This module gets the current headlines from a site-local file.

The I<--source> parameter specifies a file name which contains news to be
posted.  See L<"FILE FORMAT"> below for details on contents to put in the
file.  I<--source> may be specified more than once, allowing a single news
output to come from more than one input.  For example, one file could be
manually maintained in CVS or RCS and another could be entered from a
web form.

After this runs, the file C<site_news.html> will be created or replaced.
If there already was a C<site_news.html> file, it will be moved to
C<Osite_news.html>.

=head1 FILE FORMAT

The WebFetch::Input::SiteNews data format is used to set up news for the
local web site and allow other sites to import it via WebFetch.
The file is plain text containing comments and the news items.

There are three forms of outputs generated from these news files.

The I<"short news" output> is a small number (5 by default)
of HTML text and links used for display in a small news window.
This list takes into account expiration dates and
priorities to pick which news entries are displayed and in what order.

The I<"long news" output> lists all the news entries chronologically.
It does not take expiration or priority into account.
It is intended for a comprehensive site news list.

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
Send patches, bug reports, suggestions and questions to
C<maint@webfetch.org>.

=head1 SEE ALSO

=for html
<a href="WebFetch.html">WebFetch</a>

=for text
WebFetch

=for man
WebFetch

=cut
