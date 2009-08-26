#
# WebFetch::Input::PerlStruct.pm
# push a Perl structure with pre-parsed news into WebFetch
#
# Copyright (c) 1998-2009 Ian Kluft. This program is free software; you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License Version 3. See  http://www.webfetch.org/GPLv3.txt

package WebFetch::Input::PerlStruct;

use strict;
use base "WebFetch";

use Carp;

our $format;
our @Options = ( "format:s" );
our $Usage = "";

# configuration parameters
our $num_links = 5;
our $default_format = "<a href=\"%url%\">%title%</a>";

# no user-servicable parts beyond this point

# register capabilities with WebFetch
__PACKAGE__->module_register( "input:perlstruct" );

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{num_links} = $WebFetch::Input::PerlStruct::num_links;
	if ( defined $format ) {
		$self->{"format"} = $format;
	} else {
		$self->{"format"} = $WebFetch::Input::PerlStruct::default_format;
	}

	# get the content from the provided perl structure
	if ( !defined $self->{content}) {
		croak "WebFetch::Input::PerlStruct: content struct does not exist\n";
	}
	if ( ref($self->{content}) != "ARRAY" ) {
		croak "WebFetch::Input::PerlStruct: content is not an ARRAY ref\n";
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

	# build data structure
	$self->{data} = {};
}


1;
__END__
# POD docs follow

=head1 NAME

WebFetch::Input::PerlStruct - accepts a Perl structure with pre-parsed news

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::Input::PerlStruct;>

C<$obj = new WebFetch::Input::PerlStruct (
	"content" => content_struct,
	"dir" => output_dir,
	"file" => output_file,
	[ "format" => format_string, ]
	[ "export" => wf_export_filename, ]
	[ "font_size" => font_size, ]
	[ "font_face" => font_face, ]
	[ "group" => file_group_id, ]
	[ "mode" => file_mode_perms, ]
	[ "quiet" => 1 ]);>

I<Note: WebFetch::Input::PerlStruct is a Perl interface only.
It does not support usage from the command-line.>

=head1 DESCRIPTION

This module accepts a perl structure with pre-parsed news
and pushes it into the WebFetch infrastructure.

The webmaster of a remote site only needs to arrange for a cron job to
update a WebFetch Export file, and let others know the URL to reach
that file.
(On the exporting site, it is most likely they'll use
WebFetch::SiteNews to export their own news.)
Then you can use the WebFetch::Input::PerlStruct module to read the
remote file and generate and HTML summary of the news.

After WebFetch::Input::PerlStruct runs,
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

WebFetch::Input::PerlStruct uses a format string identical to WebFetch::General.
The default format for retrieved data is

<a href="%url%">%title%</a>

See the WebFetch::General documentation for more details.

The names of the fields are chosen by the calling function.
Though for the convenience of the user,
the author of an exporting module should keep in mind the
default WebFetch::Input::PerlStruct format uses fields called "url" and "title".
If you use fields by different names, make sure your code provides those
fields in the $content_struct parameter.

=head1 AUTHOR

WebFetch was written by Ian Kluft
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
