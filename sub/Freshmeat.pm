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
$WebFetch::Freshmeat::url = "http://freshmeat.net/files/freshmeat/recentnews.txt";

# no user-servicable parts beyond this point

# array indices
sub entry_text { 0; }
sub entry_time { 1; }
sub entry_link { 2; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::Freshmeat::url;
	$self->{num_links} = $WebFetch::Freshmeat::num_links;
	$self->{table_sections} = $WebFetch::Freshmeat::table_sections;

	# process the links
	my $content = $self->get;
	my ( @content_links, @lines, $i );
	@lines = split ( /\n/, $$content );
	while ( $#lines >= 0 and $lines[0] eq "" ) {
	        shift @lines; shift @lines; shift @lines;
	}
	for ( $i = 0; $i < $#lines/3; $i++ ) {
		push ( @content_links, [ @lines[($i*3)..($i*3+2)]]);
	}
	$self->html_gen( $WebFetch::Freshmeat::filename,
		sub { return "<a href=\"".$_[&entry_link]."\">"
			.$_[&entry_text]."</a>"; },
		\@content_links );

	# export content if --export was specified
	if ( defined $self->{export}) {
		$self->wf_export( $self->{export},
			[ "title", "time", "url" ],
			\@content_links,
			"Exported from WebFetch::Freshmeat\n"
				."\"title\" is article title\n"
				."\"time\" is timestamp\n"
				."\"url\" is article URL" );
	}
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

C<perl C<-w> -MWebFetch::Freshmeat C<-e> "&fetch_main" -- --dir I<directory>>

=head1 DESCRIPTION

This module gets the current headlines from Freshmeat.

After this runs, the file C<freshmeat.html> will be created or replaced.
If there already was an C<freshmeat.html> file, it will be moved to
C<Ofreshmeat.html>.

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
