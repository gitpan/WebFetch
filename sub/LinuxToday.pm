#
# LinuxToday.pm - get headlines from LinuxToday
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::LinuxToday;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage
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
#@Options = ();  # No command-line options added by this module1
#$Usage = "";    # No additions to the usage error message

# configuration parameters
$WebFetch::LinuxToday::filename = "linuxtoday.html";
$WebFetch::LinuxToday::num_links = 5;
$WebFetch::LinuxToday::url = "http://linuxtoday.com/backend/linuxtoday.xml";

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

	# set parameters for WebFetch routines
	if ( !defined $self->{url}) {
		$self->{url} = $WebFetch::LinuxToday::url;
	}
	if ( !defined $self->{num_links}) {
		$self->{num_links} = $WebFetch::LinuxToday::num_links;
	}
	if ( !defined $self->{filename}) {
		$self->{filename} = $WebFetch::LinuxToday::filename;
	}


# "title", "url", "time", "author", "topic", "comments"

        # set up Webfetch Embedding API data
        $self->{data} = {}; 
        $self->{actions} = {}; 
        $self->{data}{fields} = [ "title", "url", "time", "author", "topic", "comments" ];
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

	# process the links
	my $content = $self->get;
	$parser->parse($$content);

        # unravel the table of XML fields and make a WebFetch record table
	my ( $part );
        foreach $part ( @parts ) {
                my ( $field, @fields );
 
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

WebFetch::LinuxToday - download and save LinuxToday headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::LinuxToday;>

From the command line:

C<perl -w -MWebFetch::LinuxToday -e "&fetch_main" -- --dir directory>

=head1 DESCRIPTION

This module gets the current headlines from LinuxToday.

After this runs, the file C<linuxtoday.html> will be created or replaced.
If there already was an C<linuxtoday.html> file, it will be moved to
C<Olinuxtoday.html>.

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
