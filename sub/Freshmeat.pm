#
# Freshmeat.pm - get headlines from Freshmeat
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::Freshmeat;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);
#@Options = ();   # No command-line options added by this module

# configuration parameters
$WebFetch::Freshmeat::filename = "freshmeat.html";
$WebFetch::Freshmeat::num_links = 10;
$WebFetch::Freshmeat::table_sections = 2;
$WebFetch::Freshmeat::url = "http://freshmeat.net/backend/recentnews.txt";

# no user-servicable parts beyond this point

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	if ( ! defined $self->{url}) {
		$self->{url} = $WebFetch::Freshmeat::url;
	}
	if ( ! defined $self->{num_links}) {
		$self->{num_links} = $WebFetch::Freshmeat::num_links;
	}
	if ( ! defined $self->{table_sections}) {
		$self->{table_sections} = $WebFetch::Freshmeat::table_sections;
	}
	if ( ! defined $self->{filename}) {
		$self->{filename} = $WebFetch::Freshmeat::filename;
	}

	# set up Webfetch Embedding API data
	$self->{data} = {}; 
	$self->{actions} = {}; 
	$self->{data}{fields} = [ "title", "date", "url" ];
	# defined which fields match to which "well-known field names"
	$self->{data}{wk_names} = {
		"title" => "title",
		"url" => "url",
		"date" => "date",
	};
	$self->{data}{records} = [];

	# process the links
	my $content = $self->get;
	my ( @lines, $i );
	@lines = split ( /\n/, $$content );
	while ( $#lines >= 0 and $lines[0] eq "" ) {
	        shift @lines; shift @lines; shift @lines;
	}
	for ( $i = 0; $i < $#lines/3; $i++ ) {
		push ( @{$self->{data}{records}}, [ @lines[($i*3)..($i*3+2)]]);
	}

	# set parameters for saving to HTML

	# create the HTML actions list
	$self->{actions}{html} = [];

	# create the HTML-generation parameters
	my $params = {};
	$params = {};
	$params->{format_func} = sub {
		# generate HTML text
		my $url_fnum = $self->fname2fnum("url");
		my $title_fnum = $self->fname2fnum("title");
		return "<a href=\"".$_[$url_fnum]."\">"
			.$_[$title_fnum]."</a>";
	};

	# put parameters for fmt_handler_html() on the html list
	push @{$self->{actions}{html}}, [ $self->{filename}, $params ];
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::Freshmeat - download and save Freshmeat headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::Freshmeat;>

From the command line:

C<perl -w -MWebFetch::Freshmeat -e "&fetch_main" -- --dir directory>

=head1 DESCRIPTION

This module gets the current headlines from Freshmeat.

After this runs, the file C<freshmeat.html> will be created or replaced.
If there already was an C<freshmeat.html> file, it will be moved to
C<Ofreshmeat.html>.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
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
