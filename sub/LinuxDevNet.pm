#
# LinuxDevNet.pm - get headlines from LinuxDevNet
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::LinuxDevNet;

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
$WebFetch::LinuxDevNet::filename = "linuxdevnet.html";
$WebFetch::LinuxDevNet::num_links = 5;
$WebFetch::LinuxDevNet::url = "http://linuxdev.net/archive/headlines.txt";

# no user-servicable parts beyond this point

# array indices
sub entry_category { 0; }
sub entry_title { 1; }
sub entry_link { 2; }
sub entry_time { 3; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::LinuxDevNet::url;
	$self->{num_links} = $WebFetch::LinuxDevNet::num_links;

	# process the links
	my $content = $self->get;
	my @lines = split ( /\n/, $$content );

	# split up the response into each of its subjects
	my ( $line, @content_links );
	for ( $line = 0; $line <= $#lines; $line += 4 ) {
		push ( @content_links, [ @lines[$line..$line+3]]);

	}
        $self->html_gen( $WebFetch::LinuxDevNet::filename,
                sub { return "<a href=\"".$_[&entry_link]."\">"
                        .$_[&entry_title]."</a>"; },
                \@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "category", "title", "url", "time" ],
                        \@content_links,
                        "Exported from WebFetch::LinuxDevNet\n"
                                ."\"category\" is article category keyword\n"
                                ."\"title\" is article title\n"
                                ."\"url\" is article URL\n"
                                ."\"time\" is timestamp" );
        }

}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::LinuxDevNet - download and save Linux Dev.Net headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::LinuxDevNet;>

From the command line:

C<perl -w -MWebFetch::LinuxDevNet -e "&fetch_main" -- --dir directory>

=head1 DESCRIPTION

This module gets the current headlines from Linux Dev.Net (linuxdev.net).

After this runs, the file C<linuxdevnet.html> will be created or replaced.
If there already was an C<linuxdevnet.html> file, it will be moved to
C<Olinuxdevnet.html>.

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
