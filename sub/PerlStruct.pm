#
# PerlStruct.pm - push a Perl structure with pre-parsed news into WebFetch
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::PerlStruct;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $format );

use Exporter;
use AutoLoader;
use Carp;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );
@Options = ( "format:s" => \$format );
$Usage = "";

# configuration parameters
$WebFetch::PerlStruct::num_links = 5;
$WebFetch::PerlStruct::default_format = "<a href=\"%url%\">%title%</a>";

# no user-servicable parts beyond this point

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{num_links} = $WebFetch::PerlStruct::num_links;
	if ( defined $format ) {
		$self->{"format"} = $format;
	} else {
		$self->{"format"} = $WebFetch::PerlStruct::default_format;
	}

	# get the content from the provided perl structure
	if ( !defined $self->{content}) {
		croak "WebFetch::PerlStruct: content struct does not exist\n";
	}
	if ( ref($self->{content}) != "ARRAY" ) {
		croak "WebFetch::PerlStruct: content is not an ARRAY ref\n";
	}

	# collate $self->{content} into @content_links by fields from format
	my ( @content_links, $part );
	my @fields = ( $self->{"format"} =~ /%([^%]*)%/go );
	foreach $part ( @{$self->{content}} ) {
		my ( $fname, $subparts );
		$subparts= [];
		foreach $fname ( @fields ) {
			push @$subparts, "".((defined $part->{$fname})
				? $part->{$fname} : "" );
		}
		push ( @content_links, $subparts );
	}
	
	# generate HTML
        $self->html_gen( $self->{file},
                sub { $self->wf_format(@_); },
                \@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ @fields ],
                        \@content_links,
                        "Exported from WebFetch::PerlStruct\n" );
        }

	# export content if --ns_export was specified
	if ( defined $self->{ns_export}) {
		my ( @ns_list, $rec );
		foreach $rec ( @{$self->{content}} ) {
			( defined $rec->{title}) or next;
			( defined $rec->{url}) or next;
			push @ns_list, [ $rec->{title}, $rec->{url} ];
		}
		$self->ns_export( $self->{ns_export}, \@ns_list,
			$self->{ns_site_title}, $self->{ns_site_link},
			$self->{ns_site_desc}, $self->{ns_image_title},
			$self->{ns_image_url} );
	}
}

sub wf_format
{
	my ( $self, @subparts ) = @_;
	my $text = $self->{"format"};

	while ( $text =~ /^([^%]*)%([^%]*)%(.*)/ ) {
		$text = $1.((defined $subparts[0]) ? $subparts[0] : "").$3;
		shift @subparts;
	}
	return $text;
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::PerlStruct - accepts a Perl structure with pre-parsed news

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::PerlStruct;>

C<$obj = new WebFetch::PerlStruct (
	"content" => content_struct,
	"dir" => output_dir,
	"file" => output_file,
	[ "format" => format_string, ]
	[ "export" => wf_export_filename, ]
	[ "ns_export" => ns_export_filename, ]
	[ "ns_export" => ns_export_filename, ]
	[ "ns_export" => ns_export_filename, ]
	[ "ns_site_title" => ns_export_site_title, ]
	[ "ns_site_link" => ns_export_site_link, ]
	[ "ns_site_desc" => ns_export_site_desc, ]
	[ "ns_image_title" => ns_export_image_title, ]
	[ "ns_image_url" => ns_export_image_url, ]
	[ "font_size" => font_size, ]
	[ "font_face" => font_face, ]
	[ "group" => file_group_id, ]
	[ "mode" => file_mode_perms, ]
	[ "quiet" => 1 ]);>

I<Note: WebFetch::PerlStruct is a Perl interface only.
It does not support usage from the command-line.>

=head1 DESCRIPTION

This module accepts a perl structure with pre-parsed news
and pushes it into the WebFetch infrastructure.

The webmaster of a remote site only needs to arrange for a cron job to
update a WebFetch Export file, and let others know the URL to reach
that file.
(On the exporting site, it is most likely they'll use
WebFetch::SiteNews to export their own news.)
Then you can use the WebFetch::PerlStruct module to read the
remote file and generate and HTML summary of the news.

After WebFetch::PerlStruct runs,
the file specified in the --file parameter will be created or replaced.
If there already was a file by that name, it will be moved to
a filename with "O" (for old) prepended to the file name.

Most of the parameters listed are inherited from WebFetch.
See the WebFetch module documentation for details.

=head1 THE CONTENT STRUCTURE

The $content_struct parameter must be a reference to an array of hashes.
Each of the hashes represents a separate news item,
in the order they should be displayed.
The fields of each has entry must provide enough information to
match field names in all the the output formats you're using.
Output formats include the following:

=over 4

=item HTML output file

All the fields used in the $format_string (see below) must be present
for generation of the HTML output.

=item WebFetch export

The $format_string also determines the fields that will be used
for WebFetch export.
Note that the WebFetch::General module expects by default to find
fields called "url" and "title".
So if you use something different from the default,
you must provide your format string in the instructions
for sites that fetch news from you.
(Otherwise their WebFetch::General won't be looking for the fields
you're providing.)

=item MyNetscape export

The MyNetscape export function expects to find fields called
"title" and "url", and will skip any hash entry which is
missing either of them.

=back

=head1 FORMAT STRINGS

WebFetch::PerlStruct uses a format string identical to WebFetch::General.
The default format for retrieved data is

<a href="%url%">%title%</a>

See the WebFetch::General documentation for more details.

The names of the fields are chosen by the calling function.
Though for the convenience of the user,
the author of an exporting module should keep in mind the
default WebFetch::PerlStruct format uses fields called "url" and "title".
If you use fields by different names, make sure your code provides those
fields in the $content_struct parameter.

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
