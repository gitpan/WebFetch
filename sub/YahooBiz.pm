#
# YahooBiz.pm - get headlines from Yahoo Business News
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::YahooBiz;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $search_string $search_days $search_pagesize );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);

# set defaults
$search_string = "linux";
$search_days = 14;
$search_pagesize = 10;

@Options = (
	"search:s" => \$search_string,
	"days:i" => \$search_days,
	"pagesize:i" => \$search_pagesize);
$Usage = "[--search search-string] [--days search-days] ".
	"[--pagesize search-page-size]";

# configuration parameters
$WebFetch::YahooBiz::filename = "yahoo_biz.html";
$WebFetch::YahooBiz::num_links = 5;
$WebFetch::YahooBiz::url = "http://search.news.yahoo.com/search/news";

# the search portion of the URL needs to be saved to run after
# command-line processing
$WebFetch::YahooBiz::search = sub {
	"o=1&p=".$search_string."&t=1&g=".$search_days."&n=".$search_pagesize;
};

# no user-servicable parts beyond this point

# array indices
sub entry_link { 0; }
sub entry_text { 1; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::YahooBiz::url
		."?".&$WebFetch::YahooBiz::search();
	$self->{num_links} = $WebFetch::YahooBiz::num_links;
	$self->{table_sections} = $WebFetch::YahooBiz::table_sections;

	# process the links
	my $content = $self->get;
	my ( @content_links, @lines, $state );
	@lines = split ( /\n/, $$content );
	$state = 0;
	foreach ( @lines ) {
		if ( $state == 0 and /News Headline Matches/ ) {
			$state = 1;
			next;
		} elsif ( $state == 1 and /^<a href=\"([^"]+)\">(.*)<\/a>/i ) {
			push ( @content_links, [ $1, $2 ]);
		} elsif ( $state == 1 and ( /<table /i )) {
			last;
		}
	}
	$self->html_gen( $WebFetch::YahooBiz::filename,
		sub { return "<a href=\"".$_[&entry_link]."\">"
			.$_[&entry_text]."</a>"; },
		\@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "url", "title" ],
                        \@content_links,
                        "Exported from WebFetch::YahooBiz\n"
                                ."\"url\" is article URL\n"
                                ."\"title\" is article title" );
        }
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::YahooBiz - download and save YahooBiz headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::YahooBiz;>

From the command line:

C<perl C<-w> -MWebFetch::YahooBiz C<-e> "&fetch_main" -- --dir I<directory>
     --search I<search-string> --days I<search-days>
     --pagesize I<search-page-size>>

=head1 DESCRIPTION

This module gets the current headlines from Yahoo Business News.

After this runs, the file C<yahoo_biz.html> will be created or replaced.
If there already was an C<yahoo_biz.html> file, it will be moved to
C<Oyahoo_biz.html>.

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
