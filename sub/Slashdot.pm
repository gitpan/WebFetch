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
	$alt_url $alt_file $xml
	@parts $story $parser @tag_stack
);

use Exporter;
use XML::Parser;
use WebFetch;

@ISA = qw(Exporter WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );

$filtered_authors = [];
$alt_url = undef;
$alt_file = undef;
@Options = (
	"filtered:s\@" => $filtered_authors,
	"url:s" => \$alt_url,
	"file:s" => \$alt_file
);

# configuration parameters
$WebFetch::Slashdot::filename = "slashdot.html";
$WebFetch::Slashdot::num_links = 5;
$WebFetch::Slashdot::url = "http://www.slashdot.org/slashdot.xml";

# no user-servicable parts beyond this point

# XML
$parser = XML::Parser->new(
	Handlers => {
		Start => \&xml_handle_start,
		End   => \&xml_handle_end,
		Char  => \&xml_handle_char
	},
);

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	if ( ! defined $self->{url}) {
		$self->{url} = $WebFetch::Slashdot::url;
	}
	if ( ! defined $self->{filename}) {
		$self->{filename} = $WebFetch::Slashdot::filename;
	}
	if ( ! defined $self->{num_links}) {
		$self->{num_links} = $WebFetch::Slashdot::num_links;
	}

        # set up Webfetch Embedding API data
        $self->{data} = {}; 
        $self->{actions} = {}; 
        $self->{data}{fields} = [ "title", "url", "time", "author",
		"department", "topic", "comments", "section", "image" ];
        # defined which fields match to which "well-known field names"
        $self->{data}{wk_names} = {
                "title" => "title",
                "url" => "url",
                "date" => "time",
                "comments" => "comments",
                "author" => "author",
                "category" => "topic",
        };
        $self->{data}{records} = [];

	# stuff filtered-out authors into hash
	my ( $part, %filtered_out );
	foreach ( @$filtered_authors ) {
		$filtered_out{$_} = 1;
	}

	# process the links
	my $content = $self->get;
	$parser->parse($$content);

	# unravel the table of XML fields and make a WebFetch record table
	foreach $part ( @parts ) {
		my ( $field, @fields );

		# skip if this was posted by a filtered-out author
		(defined $part->{author})
			and (defined $filtered_out{$part->{author}})
			and $filtered_out{$part->{author}}
			and next;

		# put the retrieved field names into the proper table slots
		foreach $field ( @{$self->{data}{fields}}) {
			push @fields, ( defined $part->{$field})
				? $part->{$field}
				: "";
		}
		push ( @{$self->{data}{records}}, [ @fields ]);
	}

        # create the HTML actions list
        $self->{actions}{html} = [];
        my $params = {};
        $params->{format_func} = sub {
                # generate HTML text
                my $url_fnum = $self->fname2fnum("url");
                my $title_fnum = $self->fname2fnum("title");
                my $com_fnum = $self->fname2fnum("comments");
                return "<a href=\"".$_[$url_fnum]."\">"
                        .$_[$title_fnum]."</a>"
			.( length($_[$com_fnum])
				? " (".$_[$com_fnum].")" : "" );
        };
 
        # put parameters for fmt_handler_html() on the html list
        push @{$self->{actions}{html}}, [ $self->{filename}, $params ];
}

sub xml_handle_start {
	my ($p,$el) = @_;
	push @tag_stack, $el;
}

sub xml_handle_end {
	my ($p,$el) = @_;
	my $leaving = pop @tag_stack;

	if ( $leaving eq "story" ) {
		push @parts, $story;
		$story = {};
	}
}

sub xml_handle_char {
	my ($p,$data) = @_;
	if ( $tag_stack[$#tag_stack-1] eq "story" 
		and $tag_stack[$#tag_stack] ne "story" )
	{
		$story->{$tag_stack[$#tag_stack]} = $data;
	}
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

C<perl -w -MWebFetch::Slashdot -e "&fetch_main" -- --dir directory [--alt_url url  [--alt_file file]>

Alternative command line to filter out specific authors:

C<perl -w -MWebFetch::Slashdot -e "&fetch_main" -- --dir directory --filter author [--alt_url url]  [--alt_file file]>

=head1 DESCRIPTION

This module gets the current headlines from Slashdot.org
via their XML interface.

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
