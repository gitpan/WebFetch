#
# LinuxTelephony.pm - get headlines from LinuxTelephony
# Based on LinuxToday.pm
#
# Modifications for LinuxTelephony by Greg Youngblood, greg@tcscs.com
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::LinuxTelephony;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );
#@Options = ();  # No command-line options added by this module1
#$Usage = "";    # No additions to the usage error message

# configuration parameters
$WebFetch::LinuxTelephony::filename = "linuxtelephony.html";
$WebFetch::LinuxTelephony::num_links = 5;
$WebFetch::LinuxTelephony::url = 
"http://www.linuxtelephony.org/backend/linuxtelnews.txt";

# no user-servicable parts beyond this point

# array indices
sub entry_text { 0; }
sub entry_link { 1; }
sub entry_time { 2; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::LinuxTelephony::url;
	$self->{num_links} = $WebFetch::LinuxTelephony::num_links;

	# process the links
	my $content = $self->get;
	my @parts = split ( /\&\&\r{0,1}\n/, $$content );
	shift @parts;	# discard intro text

	# split up the response into each of its subjects
	my ( $part, @content_links );
	foreach $part ( @parts ) {
		my @subparts = split ( /\n/, $part );
		push ( @content_links, [ @subparts ]);

	}
        $self->html_gen( $WebFetch::LinuxTelephony::filename,
                sub { return "<a href=\"".$_[&entry_link]."\">"
                        .$_[&entry_text]."</a>"; },
                \@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "title", "url", "time" ],
                        \@content_links,
                        "Exported from WebFetch::LinuxTelephony\n"
                                ."\"title\" is article title\n"
                                ."\"url\" is article URL\n"
                                ."\"time\" is timestamp" );
        }

}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::LinuxTelephony - download and save LinuxTelephony headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::LinuxTelephony;>

>From the command line:

C<perl C<-w> -MWebFetch::LinuxTelephony C<-e> "&fetch_main" -- --dir 
I<directory>>

=head1 DESCRIPTION

This module gets the current headlines from LinuxTelephony.

After this runs, the file C<linuxtelephony.html> will be created or replaced.
If there already was an C<linuxtelephony.html> file, it will be moved to
C<Olinuxtelephony.html>.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
Send patches, bug reports, suggestions and questions to
C<webfetch-maint@svlug.org>.

WebFetch::LinuxTelephony is based on WebFetch::LinuxToday.
Modifications made for WebFetch::LinuxTelephony by 
Gregory S. Youngblood, C<greg@tcscs.com>.

=head1 SEE ALSO

=for html
<a href="WebFetch.html">WebFetch</a>

=for text
WebFetch

=for man
WebFetch

=cut
