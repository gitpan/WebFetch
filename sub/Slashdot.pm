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
use vars qw(
	$VERSION @ISA @EXPORT @Options $filtered_authors 
	$segfault_mode $alt_url $alt_file $xml
);

use Exporter;
use WebFetch;

@ISA = qw(Exporter WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );

$filtered_authors = [];
$segfault_mode = 0;
$alt_url = undef;
$alt_file = undef;
@Options = (
	"filtered:s\@" => $filtered_authors,
	"segfault" => \$segfault_mode,
	"url:s" => \$alt_url,
	"file:s" => \$alt_file
);

# configuration parameters
$WebFetch::Slashdot::filename = "slashdot.html";
$WebFetch::Slashdot::num_links = 5;
$WebFetch::Slashdot::url = "http://slashdot.org/ultramode.txt";
$WebFetch::Slashdot::xml = 0;

# no user-servicable parts beyond this point

# XML
my @parts    = ();
my $in_story = 0;
my @story    = ();
my $parser   = '';

if (!$segfault_mode and eval 'require XML::Parser') {

	$parser = XML::Parser->new(
		Handlers => {
			Start => \&xml_handle_start,
			End   => \&xml_handle_end,
			Char  => \&xml_handle_char
		},
	);

	$WebFetch::Slashdot::url = "http://slashdot.org/slashdot.xml";
	$WebFetch::Slashdot::xml = 1;
}

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
	if ( $segfault_mode ) {
		# use segfault.org instead of slashdot.org
		if ( ! defined $alt_file ) {
			$alt_file = "segfault.html";
		}
		if ( ! defined $alt_url ) {
			$alt_url = "http://segfault.org/stories.txt";
		}
	}
	$self->{url} = ( defined $alt_url )
		? $alt_url
		: $WebFetch::Slashdot::url;
	$self->{filename} = ( defined $alt_file )
		? $alt_file
		: $WebFetch::Slashdot::filename;
	$self->{num_links} = $WebFetch::Slashdot::num_links;

	# process the links
	my $content = $self->get;

	if ($xml) {
		$parser->parse($$content);
	} else {
		@parts = split ( /%%\r{0,1}\n/, $$content );
		shift @parts;   # discard intro text
	}

	# stuff filtered-out authors into hash
	my ( $part, @content_links, %filtered_out );
	foreach ( @$filtered_authors ) {
		$filtered_out{$_} = 1;
	}

	# split up the response into each of its subjects
	foreach $part ( @parts ) {
		my @subparts;

		if ($xml) {
			@subparts = @$part;
		} else {
			@subparts = split ( /\n/, $part );
		}

		(defined $subparts[&entry_author])
			and (defined $filtered_out{$subparts[&entry_author]})
			and $filtered_out{$subparts[&entry_author]}
			and next;
		push ( @content_links, [ @subparts ]);
	}

	# generate HTML
	$self->html_gen( $self->{filename},
		sub { return "<a href=\"".$_[&entry_link]."\">"
			.$_[&entry_title]."</a>".
			(((defined $_[&entry_numcomments]) and
				length($_[&entry_numcomments]) > 0 )
			? " (".$_[&entry_numcomments].")"
			: ""); },
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

sub xml_handle_start {
	my ($p,$el) = @_;
	$in_story = 1 if $el eq 'story';
}

sub xml_handle_end {
	my ($p,$el) = @_;
	$in_story = 0 if $el eq 'story';

	if (!$in_story) {
		push @parts, [ @story ];
		@story = ();
	}
}

sub xml_handle_char {
	my ($p,$data) = @_;
	return if $p->current_element =~ /^(?:story|backslash)$/;
	push @story, $data;
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::Slashdot - download and save Slashdot (or any Slashdot-compatible) headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::Slashdot;>

From the command line:

C<perl C<-w> -MWebFetch::Slashdot C<-e> "&fetch_main" -- --dir I<directory> [--segfault] [--alt_url I<url>]  [--alt_file I<file>]>

Alternative command line to filter out specific authors:

C<perl C<-w> -MWebFetch::Slashdot C<-e> "&fetch_main" -- --dir I<directory> --filter I<author> [--segfault] [--alt_url I<url>]  [--alt_file I<file>]>

=head1 DESCRIPTION

This module gets the current headlines from Slashdot.org.
It can also be directed to other sites because Slashdot's
discussion forum software is Open Source and used elsewhere.

The optional C<--alt_url> parameter allows you to select a different
URL to get the headlines from.

An optional command-line argument of C<--filter> may be used to
filter out specific authors.
This is not necessarily recommended but it was in use at
SVLUG when this module was first developed.

After this runs,
by default the file C<sdot.html> will be created or replaced.
If there already was an C<sdot.html> file, it will be moved to
C<Osdot.html>.
These filenames can be overridden by the C<--alt_file> parameter.

The optional C<--segfault> parameter is a flag that directs WebFetch::Slashdot
to retreive headlines from Segfault.org and save them in a
C<segfault.html> file.
This parameter should not be used at the same time as
C<--alt_url> and C<--alt_file> because they will override it.

If WebFetch::Slashdot can find XML::Parser in your Perl libraries,
it will fetch Slashdot's XML version of its headlines.
Otherwise it will fetch the plain text version.

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
