#
# COLA.pm - download news from the comp.os.linux.announce ("cola")
# moderator's archive
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::COLA;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $no_shuffle );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);

@Options = ( "noshuffle" => \$no_shuffle );
$Usage = "[--noshuffle]";

# configuration parameters
$WebFetch::COLA::filename = "cola.html";
$WebFetch::COLA::num_links = 5;
$WebFetch::COLA::base = "http://www.cs.helsinki.fi/%7Emjrauhal/linux/cola.archive";
$WebFetch::COLA::url = $WebFetch::COLA::base."/cola-last-50.html";

# no user-servicable parts beyond this point

# initialization
srand;

# array indices
sub entry_link { 0; }
sub entry_text { 1; }
sub entry_author { 2; }
sub entry_date { 3; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::COLA::url;
	$self->{num_links} = $WebFetch::COLA::num_links;
	$self->{table_sections} = $WebFetch::COLA::table_sections;

	# process the links
	my $content = $self->get;
	my ( @content_links, @lines );
	@lines = split ( /\n/, $$content );
	foreach ( @lines ) {
		if ( /^\s*<strong>/ ) {
			my ( @tmp_links ) = split ( /<br>/ );
			my ( $link );
			foreach $link ( @tmp_links ) {
				#print "debug: link - $link\n";
				if ( $link =~ /<strong><a href=\"([^"]+)\">([^<]+)<\/a><\/strong>\s*<em>([^<]+)<\/em> \(([-0-9]+)\)/ ) {
					push ( @content_links, [ $1, $2, $3, $4 ]);
				}
			}
		}
	}
	# sort backwards by date, shuffle it within each date
	if (!( defined $no_shuffle ) or ! $no_shuffle ) {
		@content_links = sort
			{ ($a->[&entry_date] eq $b->[&entry_date]
				? ((rand(1) < 0.5) ? -1 : 1)
				: ($b->[&entry_date] cmp $a->[&entry_date])) }
			@content_links;
	}

	$self->html_gen( $WebFetch::COLA::filename,
		sub { return "<a href=\""
			.$WebFetch::COLA::base."/".$_[&entry_link]."\">"
			.$_[&entry_text]."</a>"; },
		\@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "url", "title", "author", "date" ],
                        \@content_links,
                        "Exported from WebFetch::COLA\n"
                                ."\"url\" is article URL\n"
                                ."\"title\" is article title\n"
                                ."\"author\" is article author\n"
                                ."\"date\" is article date" );
        }
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::COLA - ews from the comp.os.linux.announce ("cola") newsgroup

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::COLA;>

From the command line:

C<perl C<-w> -MWebFetch::COLA C<-e> "&fetch_main" -- --dir I<directory>
	[--noshuffle]>

=head1 DESCRIPTION

This module downloads news from the comp.os.linux.announce ("c.o.l.a")
moderator's archive.

After this runs, the file C<cola.html> will be created or replaced.
If there already was an C<cola.html> file, it will be moved to
C<Ocola.html>.

The c.o.l.a archive is bursty, with many news items showing up at once,
but only updated every few days.
In order to present many current items, WebFetch::COLA
sorts by date but shuffles items which are listed as being on the same date.
The webmaster is advised to include a link to the COLA archive
near the headline list so readers can peruse it if anything listed
gets their attention.

If the shuffle feature is not desired, use the "--noshuffle" command-line
option to disable it.

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
