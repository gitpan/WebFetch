#
# CNNsearch.pm - search for stories at CNN Interactive
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::CNNsearch;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $search_string
	$search_pagesize $use_keyword );

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
$search_pagesize = 20;

@Options = (
	"search:s" => \$search_string,
	"pagesize:i" => \$search_pagesize,
	"use_keyword" => \$use_keyword,
	);
$Usage = "[--search search-string] [--pagesize search-page-size] "
	."[--use_keyword]";

# configuration parameters
$WebFetch::CNNsearch::filename = "cnnsearch.html";
$WebFetch::CNNsearch::num_links = 5;
$WebFetch::CNNsearch::url = "http://search.cnn.com/query.html";

# the search portion of the URL needs to be saved to run after
# command-line processing
$WebFetch::CNNsearch::search = sub {
	"?col=cnni&op0=%2B&fl0="
		.((defined $use_keyword ) ? "keywords" : "" )
		."%3A&ty0=p&tx0=$search_string&dt=in&inthe=2592000&nh=$search_pagesize&rf=1&lk=1&qp=&qt=&qs=&qc=&pw=460&qm=0&st=1&rq=0&ql=a";
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
	$self->{url} = $WebFetch::CNNsearch::url
		."?".&$WebFetch::CNNsearch::search();
	$self->{num_links} = $WebFetch::CNNsearch::num_links;
	$self->{table_sections} = $WebFetch::CNNsearch::table_sections;

	# process the links
	my $content = $self->get;
	my ( @content_links, @lines, $state );
	@lines = split ( /\n/, $$content );
	$state = 0;
	foreach ( @lines ) {
		if ( $state == 0 and /<td width=\"95\%\">/ ) {
			$state = 1;
			next;
		} elsif ( $state == 1 and /^<b><a href=\"([^"]+)\">(.*)<\/a><\/b>/i ) {
			push ( @content_links, [ $1, $2 ]);
		} elsif ( $state == 1 and ( /<table width=\"100\%\">/i )) {
			last;
		}
	}
	$self->html_gen( $WebFetch::CNNsearch::filename,
		sub { return "<a href=\"".$_[&entry_link]."\">"
			.$_[&entry_text]."</a>"; },
		\@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "url", "title" ],
                        \@content_links,
                        "Exported from WebFetch::CNNsearch\n"
                                ."\"url\" is article URL\n"
                                ."\"title\" is article title" );
        }
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::CNNsearch - search for stories at CNN Interactive

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::CNNsearch;>

From the command line:

C<perl C<-w> -MWebFetch::CNNsearch C<-e> "&fetch_main" -- --dir I<directory>
     --search I<search-string> [--pagesize I<search-page-size>>]
     [--use_keyword]

=head1 DESCRIPTION

This module gets the stories by searching CNN Interactive.

The required I<--search> parameter specifies a string to search for
in CNN's news.
The optional I<--pagesize> parameter can be used to have the search engine
return more entries per page if not enough are obtained for your use.

The optional I<--use_keyword> parameter causes a search by keyword
instead of by just any occurrence in the text.
This parameter was added in WebFetch 0.07 because previous searches
by body text only for "Linux" began to fail when a Linux story became
listed in the "in other news" links on every page at CNN.
Using a keyword-only search gets around this problem, returning only
pages which have the string among their keywords.
But this only works if the writers at CNN used the keyword you're
interested in - do some searches either way to try it out first.

After this runs, the file C<cnnsearch.html> will be created or replaced.
If there already was an C<cnnsearch.html> file, it will be moved to
C<Ocnnsearch.html>.

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
