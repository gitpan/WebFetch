#
# Slashdot.pm - get headlines from Slashdot
#
# NOTE: Slashdot requests that headline requests should not be done
# any more often than 30 minute intervals.  Be a good net.citizen.
# (You're not the only one doing this!)
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::Slashdot;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $filtered_authors );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);
$filtered_authors = [];
@Options = (
	"filtered:s\@" => $filtered_authors
);

# configuration parameters
$WebFetch::Slashdot::filename = "slashdot.html";
$WebFetch::Slashdot::num_links = 5;
$WebFetch::Slashdot::url = "http://slashdot.org/ultramode.txt";

# no user-servicable parts beyond this point

# array indices
sub entry_title { 0; }
sub entry_link { 1; }
sub entry_time { 2; }
sub entry_author { 3; }
sub entry_dept { 4; }
sub entry_topic { 5; }
sub entry_numcomments { 6; }
sub entry_strytype { 7; }
sub entry_image { 8; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::Slashdot::url;
	$self->{num_links} = $WebFetch::Slashdot::num_links;

	# process the links
	my $content = $self->get;
	my @parts = split ( /%%\r{0,1}\n/, $$content );
	shift @parts;	# discard intro text

	# stuff filtered-out authors into hash
	my ( $part, @content_links, %filtered_out );
	foreach ( @$filtered_authors ) {
		$filtered_out{$_} = 1;
	}

	# split up the response into each of its subjects
	foreach $part ( @parts ) {
		my @subparts = split ( /\n/, $part );
		( $filtered_out{$subparts[entry_author]}) and next;
		push ( @content_links, [ @subparts ]);

	}

	# generate HTML
	$self->html_gen( $WebFetch::Slashdot::filename,
		sub { return "<a href=\"".$_[&entry_link]."\">"
			.$_[&entry_title]."</a> ("
			.$_[&entry_numcomments].")"; },
		\@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
			[ "title", "link", "time", "author", "dept", "topic",
				"numcomments", "storytype", "imagename" ],
                        \@content_links,
                        "Exported from WebFetch::Slashdot\n"
                                ."\"title\" is the article title\n"
                                ."\"link\" is the article URL\n"
                                ."\"time\" is the timestamp\n"
                                ."\"author\" is the article author\n"
                                ."\"dept\" is a department name\n"
                                ."\"topic\" is the topic area\n"
                                ."\"numcomments\" is the number of comments\n"
                                ."\"storytype\" is the story type\n"
                                ."\"imagename\" is the Slashdot image/icon" );
        }
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::Slashdot - download and save Slashdot headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::Slashdot;>

From the command line:

C<perl C<-w> -MWebFetch::Slashdot C<-e> "&fetch_main" -- --dir I<directory>>

Alternative command line to filter out specific authors:

C<perl C<-w> -MWebFetch::Slashdot C<-e> "&fetch_main" -- --dir I<directory> --filter I<author>>

=head1 DESCRIPTION

This module gets the current headlines from Slashdot.org.

An optional command-line argument of C<--filter> may be used to
filter out specific authors.
This is not necessarily recommended but it was in use at
SVLUG when this module was first developed.

After this runs, the file C<sdot.html> will be created or replaced.
If there already was an C<sdot.html> file, it will be moved to
C<Osdot.html>.

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
