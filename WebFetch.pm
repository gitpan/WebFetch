#
# WebFetch - infrastructure for downloading ("fetching") information from
# various sources around the Internet or the local system in order to
# present them for display, or to export local information to other sites
# on the Internet
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#
# Revisions listed below are only for this file, not the WebFetch package.
#
# $Revision: 1.27 $
# $Log: WebFetch.pm,v $
# Revision 1.27  1999/09/09 08:08:30  ikluft
# fix problem in WebFetch export after API upgrade
#
# Revision 1.26  1999/09/07 09:31:40  ikluft
# Added WebFetch Embedding API
#
# Revision 1.25  1999/08/16 02:21:44  ikluft
# updated to use new webfetch.org addresses/URLs
#
# Revision 1.24  1999/08/15 11:03:56  ikluft
# added modules for 0.09
#
# Revision 1.23  1999/08/02 05:50:59  ikluft
# updated version to 0.08
# added reference to DebianNews module
# moves style parameter docs
#
# Revision 1.22  1999/07/13 08:38:24  ikluft
# added notable and bullet styles
# added docs
#
# Revision 1.21  1999/05/05 00:17:28  ikluft
# we have been informed that the RDF format used by MyNetscape is actually
# Resource Description Framework.  This is now documented.
#
# Revision 1.20  1999/05/05 00:09:30  ikluft
# bump version to 0.06, add references to WebFetch::PerlStruct
# ./
#
# Revision 1.19  1999/04/11 13:57:09  ikluft
# bump version to 0.05
#
# Revision 1.18  1999/04/09 01:58:20  ikluft
# added font_size/font_face, added references to WebFetch::CNNsearch
# and WebFetch::COLA.
#
# Revision 1.17  1999/03/28 08:17:11  ikluft
# add VERSION to WF export files, bump version to 0.04
#
# Revision 1.16  1999/03/22 06:26:15  ikluft
# added MyNetscape export
#
# Revision 1.15  1999/03/20 08:28:44  ikluft
# WebFetch 0.02 checkpoint
# added first pass at MyNetscape exporting, then they completely changed
# the format (grrrr...)
#
# Revision 1.14  1999/02/08 03:55:34  ikluft
# fixed typo in variable name, added RCS revision/log
#
#
package WebFetch;

=head1 NAME

WebFetch - Perl module to download and save information from the Web

=head1 SYNOPSIS

  use WebFetch;

=head1 DESCRIPTION

The WebFetch module is a general framework for downloading and saving
information from the web, and for display on the web.
It requires another module to inherit it and fill in the specifics of
what and how to download.
WebFetch provides a generalized interface for saving to a file
while keeping the previous version as a backup.
This is expected to be used for periodically-updated information
which is run as a cron job.

=head1 INSTALLATION

After unpacking and the module sources from the tar file, run

C<perl Makefile.PL>

C<make>

C<make install>

Or from a CPAN shell you can simply type "C<install WebFetch>"
and it will download, build and install it for you.

If you need help setting up a separate area to install the modules
(i.e. if you don't have write permission where perl keeps its modules)
then see the Perl FAQ.

To begin using the WebFetch modules, you will need to test your
fetch operations manually, put them into a crontab, and then
use server-side include (SSI) or a similar server configuration to 
include the files in a live web page.

=head2 MANUALLY TESTING A FETCH OPERATION

Select a directory which will be the storage area for files created
by WebFetch.  This is an important administrative decision -
keep the volatile automatically-generated files in their own directory
so they'll be separated from manually-maintained files.

Choose the specific WebFetch-derived modules that do the work you want.
See their particular manual/web pages for details on command-line arguments.
Test run them first before committing to a crontab.

=head2 SETTING UP CRONTAB ENTRIES

First of all, if you don't have crontab access or don't know what they are,
contact your site's system administrator(s).  Only local help will do any
good on local-configuration issues.  No one on the Internet can help.
(If you are the administrator for your system, see the crontab(1) and
crontab(5) manpages and nearly any book on Unix system administration.)

Since the WebFetch command lines are usually very long, you may prefer
to make one or more scripts as front-ends so your crontab entries aren't
so huge.

Do not run the crontab entries too often - be a good net.citizen and
do your updates no more often than necessary.
Popular sites need their users to refrain from making automated
requests too often because they add up on an enormous scale
on the Internet.
Some sites such as Freshmeat prefer no shorter than hourly intervals.
Slashdot prefers no shorter than half-hourly intervals.
When in doubt, ask the site maintainers what they prefer.

(Then again, there are a very few sites like Yahoo and CNN who don't
mind getting the extra hits if you're going to create links to them.
Even so, more often than every 20 minutes would still be  excessive
to the biggest web sites.)

=head2 SETTING UP SERVER-SIDE INCLUDES

See the manual for your web server to make sure you have server-side include
(SSI) enabled for the files that need it.
(It's wasteful to enable it for all your files so be careful.)

When using Apache HTTPD,
a line like this will include a WebFetch-generated file:

<!--#include file="fetch/slashdot.html"-->

=head1 WebFetch FUNCTIONS

The following function definitions assume B<C<$obj>> is a blessed
reference to a module that is derived from (inherits from) WebFetch.

=over 4

=cut

use strict;
use vars qw($VERSION @ISA @EXPORT );

use Exporter;
use AutoLoader;
use Carp;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( );
$VERSION = '0.10';
my $debug;

=item Do not use the new() function directly from WebFetch.

I<Use the C<new> function from a derived class>, not directly from WebFetch.
The WebFetch module itself is just infrastructure for the other modules,
and contains none of the details needed to complete any specific fetches.

=cut

# allocate a new object
sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;

	# initialize the object parameters
	$self->init(@_);

	# go fetch the data
	# this function must be provided by a derived module
	$self->fetch();

	# the object has been created
	return $self;
}

=item $obj->init( ... )

This is called from the C<new> function of all WebFetch modules.
It takes "name" => "value" pairs which are all placed verbatim as
attributes in C<$obj>.

=cut

# initialize attributes of new objects
sub init
{
	my $self = shift;
	if ( @_ ) {
		my %params = @_;
		@$self{keys %params} = values %params;
	}
}

=item $obj->run

This function is exported by standard WebFetch-derived modules as
C<fetch_main>.
This handles command-line processing for some standard options,
calling the module-specific fetch function and WebFetch's $obj->save
function to save the contents to one or more files.

The command-line processing for some standard options are as follows:

=over 4

=item --dir I<directory>

(required) the directory in which to write output files

=item --group I<group>

(optional) the group ID to set the output file(s) to

=item --mode I<mode>

(optional) the file mode (permissions) to set the output file(s) to

=item --export I<export-file>

(optional) save a portable WebFetch-export copy of the fetched info
in the file named by this parameter.
The contents of this file can be read by the WebFetch::General module.
You may use this to export your own news to other WebFetch users.
(Exports may be explicitly disabled by some WebFetch-derived modules
simply by omiting the export step from their fetch() functions.
Though it works with all the modules that come included with the
WebFetch package itself.)

=item --xml_export I<xml-export-file>

(optional) save a generic XML copy of the fetched info
into the file named by this parameter.
(A module to read this XML output will be included in a near-future
version of WebFetch.)

=for html
For more info on XML see
<a href="http://www.w3.org/XML/">http://www.w3.org/XML/</a>
or
<a href="http://www.perlxml.com/faq/perl-xml-faq.html">http://www.perlxml.com/faq/perl-xml-faq.html</a>

=for text
For more info on XML see
http://www.w3.org/XML/
and
http://www.perlxml.com/faq/perl-xml-faq.html

=for man
For more info on XML see
http://www.w3.org/XML/
and
http://www.perlxml.com/faq/perl-xml-faq.html

If you choose to generate and sustain XML content on your site
over the long term,
you may want to have your site listed on the XML Tree
at http://www.xmltree.com/

=item --ns_export I<ns-export-file>

(optional) save a MyNetscape export copy of the fetched info
into the file named by this parameter.
If this optional parameter is used, three additional parameters
become required: --ns_site_title, --ns_site_link, and --ns_site_desc.
If you want to include an icon in the channel display,
you should also use --ns_image_title and --ns_image_url.
A URL Prefix must also be set for this to work correctly,
which can be supplied via the
the --url_prefix parameter or in the I<url-prefix> line of the
WebFetch::SiteNews news input file.

=for html
For more info see
<a href="http://my.netscape.com/publish/">http://my.netscape.com/publish/</a>
and 
<a href="http://www.w3.org/RDF/">http://www.w3.org/RDF/</a>

=for text
For more info see http://my.netscape.com/publish/
and http://www.w3.org/RDF/

=for man
For more info see http://my.netscape.com/publish/
and http://www.w3.org/RDF/

I<Note that MyNetscape uses Resource Description Framework (RDF),
which is a form of XML, for its imports.
Though this command-line option uses some specific RDF parameters
for the MyNetscape portal,
this format should be readable by any other RDF-capable
and even some XML-capable sites.
You should use the ".rdf" suffix on file names that use this format.>

=item --ns_site_title I<site-title>

(required if --ns_export is used)
For exporting to MyNetscape, this sets the name of your site.
It cannot be more than 40 characters

=item --ns_site_link I<site-link>

(required if --ns_export is used)
For exporting to MyNetscape, this is the full URL MyNetscape will
use to link to your site.
It cannot be more than 500 characters.

=item --ns_site_desc I<site-description>

(required if --ns_export is used)
For exporting to MyNetscape, this is a short description of your site.
It cannot be more than 500 characters.

=item --ns_image_title I<image-title>

(optional)
For exporting to MyNetscape, this is the title (alt) text for the icon image.

=item --ns_image_url I<image-url>

(optional)
For exporting to MyNetscape, this is the URL MyNetscpae will use
for your icon image.
If this is present, the link on the image will be the same as your
--ns_site_link parameter.

=item --url_prefix I<url-prefix>

(optional) include a URL prefix to use on the saved URLs on --ns_export
output files.
(It could also be used in the future by other output formats that need
URL prefixes.)
This is considered optional by WebFetch though you will probably need
it for MyNetscape to properly link to your site.
This information can also be supplied via the
I<url-prefix> line of the WebFetch::SiteNews news input file.
If it is set in the WebFetch::SiteNews,
it will override the --url_prefix command line parameter.

=item --font_size I<number>

(optional) choose a font size for generated HTML text.
This will be used in a B<font> tag so it may be relative,
like "-1" or "+1".

=item --font_face I<string>

(optional) choose a font face for generated HTML text.
This will be used in a B<font> tag so it may be any standard font name
or a list.  For example, for a sans-serif font, use
"C<Helvetica,Arial,sans-serif>".

=item --style I<style-name-list>

(optional) select from one or more of various HTML output styles for the
generated HTML text.  If more than one style name is listed, they must
be separated by commas (no spaces.)

=over 4

=item para

use paragraph breaks between lines/links instead of unordered lists

=item notable

usually WebFetch modules generate HTML table-formatted output text but
this option will disable the e of tables

=item bullet

use explicit bullet characters (HTML entity #149) and line breaks (br)
to identify and separate each link

=item ul

(default) use an HTML unnumbered list (ul) block for the list of links

=back

The I<para>, I<bullet> and I<ul> styles are mutually exclusive.  Others
may be specified at the same time.

=item --quiet

(optional) suppress printed warnings for HTTP errors
I<(applies only to modules which use the WebFetch::get() function)>
in case they are not desired for cron outputs

=item --debug

(optional) print verbose debugging outputs,
only useful for developers adding new WebFetch-based modules
or finding/reporting a bug in an existing module

=back

Modules derived from WebFetch may add their own command-line options
that WebFetch::run() will use by defining a variable called
B<C<@Options>> in the calling module,
using the name/value pairs defined in Perl's Getopts::Long module.
Derived modules can also add to the command-line usage error message by
defining a variable called B<C<$Usage>> with a string of the additional
parameters, as they should appear in the usage message.

=cut

# command-line handling for WebFetch-derived classes
sub run
{
	my ( $caller_pkg, $caller_file, $caller_line ) = caller;
	my ( $obj, $dir, $group, $mode, $export, $xml_export,
		$ns_export, $quiet,
		$url_prefix, $ns_site_title, $ns_site_link, $ns_site_desc,
		$ns_image_title, $ns_image_url, $font_size, $font_face,
		$style, %style_hash );


	my $result = GetOptions (
		"dir=s" => \$dir,
		"group:s" => \$group,
		"mode:s" => \$mode, 
		"export:s" => \$export,
		"xml_export:s" => \$xml_export,
		"ns_export:s" => \$ns_export,
		"ns_site_title:s" => \$ns_site_title,
		"ns_site_link:s" => \$ns_site_link,
		"ns_site_desc:s" => \$ns_site_desc,
		"ns_image_title:s" => \$ns_image_title,
		"ns_image_url:s" => \$ns_image_url,
		"url_prefix:s" => \$url_prefix,
		"font_size:s" => \$font_size,
		"font_face:s" => \$font_face,
		"style:s" => \$style,
		"quiet" => \$quiet,
		"debug" => \$debug,
		( eval "defined \@".$caller_pkg."::Options" )
			? eval  "\@".$caller_pkg."::Options"
			: ());
	if ( ! $result ) {
		print STDERR "usage: $0 --dir dirpath "
			."[--group group] [--mode mode] [--export file]\n";
		print STDERR "   [--xml_export file] [--ns_export file] "
			."[--ns_site_title title] [--ns_site_link url]\n";
		print STDERR "   [--ns_site_desc text] "
			."[--ns_image_title title] [--ns_image_url url]\n";
		print STDERR "[--url_prefix prefix] [--quiet]\n";
		if ( eval "defined \$".$caller_pkg."::Usage" ) {
			print STDERR "   "
				.( eval "\$".$caller_pkg."::Usage" )."\n";
		}
		exit 1;
	}
	$debug and print STDERR "WebFetch: entered run from $caller_pkg\n";
	if ( defined $style ) {
		foreach ( split ( /,/, $style )) {
			$style_hash{$_} = 1;
		}
	}

	# Note: by the old (0.09 and earlier) WebFetch API, the fetch
	# routine creates all the savables, which $obj->save() will write
	# to disk with backups of old copies.  In 0.10 and later, in order
	# to add WebFetch-embedding capability, the fetch routine saves
	# its raw data without any HTML/XML/etc formatting in @{$obj->{data}}
	# and data-to-savable conversion routines in %{$obj->{actions}},
	# which contains several structures with key names matching software
	# processing features.  The purpose of this is to externalize the
	# captured data so other software can use it too.

	# create the new object
	# this also calls the $obj->fetch() routine for the module which
	# has inherited from WebFetch to do this
	$obj = eval 'new '.$caller_pkg.' (
		"dir" => $dir,
		(defined $group) ? ( "group" => $group ) : (),
		(defined $mode) ? ( "mode" => $mode ) : (),
		(defined $debug) ? ( "debug" => $debug ) : (),
		(defined $export) ? ( "export" => $export ) : (),
		(defined $xml_export) ? ( "xml_export" => $xml_export ) : (),
		(defined $ns_export) ? ( "ns_export" => $ns_export ) : (),
		(defined $ns_site_title) ? ( "ns_site_title" => $ns_site_title ) : (),
		(defined $ns_site_link) ? ( "ns_site_link" => $ns_site_link ) : (),
		(defined $ns_site_desc) ? ( "ns_site_desc" => $ns_site_desc ) : (),
		(defined $ns_image_title) ? ( "ns_image_title" => $ns_image_title ) : (),
		(defined $ns_image_url) ? ( "ns_image_url" => $ns_image_url ) : (),
		(defined $url_prefix) ? ( "url_prefix" => $url_prefix ) : (),
		(defined $font_size) ? ( "font_size" => $font_size ) : (),
		(defined $font_face) ? ( "font_face" => $font_face ) : (),
		(defined $style) ? ( "style" => \%style_hash ) : (),
		(defined $quiet) ? ( "quiet" => $quiet ) : (),
		)';
	if ( $@ ) {
		print STDERR "WebFetch: error: $@\n";
		exit 1;
	}

	# if the object had the data for the WebFetch-embedding API,
	# then data processing is external to the fetch routine
	# (This externalizes the data for other software to capture it.)
	if (( defined $obj->{data}) and ( defined $obj->{actions})) {

		# Add formats requested by the command line or parent program.
		# In WebFetch 0.09 and earlier, this had to be done in each
		# module.  WebFetch 0.10 externalizes the captured data so
		# that multiple schema-based export formats can be handled
		# here.
		if ( defined $obj->{export}) {
			( defined $obj->{actions}) or $obj->{actions} = {};
			( defined $obj->{actions}{wf})
				or $obj->{actions}{wf} = [];
			push @{$obj->{actions}{wf}}, [ $obj->{export} ];
		}
		if ( defined $obj->{xml_export}) {
			( defined $obj->{actions}) or $obj->{actions} = {};
			( defined $obj->{actions}{xml})
				or $obj->{actions}{xml} = [];
			push @{$obj->{actions}{xml}}, [ $obj->{xml_export} ];
		}
		if ( defined $obj->{ns_export}) {
			( defined $obj->{actions}) or $obj->{actions} = {};
			( defined $obj->{actions}{rdf})
				or $obj->{actions}{rdf} = [];
			push @{$obj->{actions}{rdf}}, [ $obj->{ns_export} ];
		}

		# NOTE: HTML exports are still the responsibility of the
		# WebFetch-derived modules.  Display tastes vary too much
		# to generalize at this level (yet).  This only handles
		# formats with built-in schema definitions.

		# perform requested actions on the data
		$obj->do_actions();
	}

	$result = $obj->save();
	if ( ! $result ) {
		my $savable;
		foreach $savable ( @{$obj->{savable}}) {
			(ref $savable eq "HASH") or next;
			if ( defined $savable->{error}) {
				print STDERR "WebFetch: (in "
					.$obj->{dir}.") error saving "
					.$savable->{file}.": "
					.$savable->{error}."\n"
			}
		}
	}
	return $result ? 0 : 1;
}

=item $obj->do_actions

I<C<do_actions> was added in WebFetch 0.10 as part of the
WebFetch Embedding API.>
Upon entry to this function, $obj must contain the following attributes:

=over 4

=item data

is a reference to a hash containing the following three (required)
keys:

=over 4

=item fields

is a reference to an array containing the names of the fetched data fields
in the order they appear in the records of the I<data> array.
This is necessary to define what each field is called
because any kind of data can be fetched from the web.

=item wk_names

is a reference to a hash which maps from
a key string with a "well-known" (to WebFetch) field type
to a field name used in this table.
The well-known names are defined as follows:

=over 4

=item title

a one-liner banner or title text
(plain text, no HTML tags)

=item url

URL/link to the news
(fully-qualified URL only, no HTML tags)

=item date

a date stamp,
which must be program-readable
by Perl's Date::Calc module in the Parse_Date() function
in order to support timestamp-related comparisons
and processing that some users have requested.
If the date cannot be parsed by Date::Calc,
either translate it when your module captures it,
or do not define this "well-known" field
because it wouldn't fit the definition.
(plain text, no HTML tags)

=item summary

a paragraph of summary text in HTML

=item comments

number of comments/replies at the news site
(plain text, no HTML tags)

=item author

a name, handle or login name representing the author of the news item
(plain text, no HTML tags)

=item category

a word or short phrase representing the category, topic or department
of the news item
(plain text, no HTML tags)

=item location

a location associated with the news item
(plain text, no HTML tags)

=back

The field names for this table are defined in the I<fields> array.

The hash only maps for the fields available in the table.
If no field representing a given well-known name is present
in the data fields,
that well-known name key must not be defined in this hash.

=item records

an array containing the data records.
Each record is itself a reference to an array of strings which are
the data fields.
This is effectively a two-dimensional array or a table.

Only one table-type set of data is permitted per fetch operation.
If more are needed, they should be arranged as separate fetches
with different parameters.

=back

=item actions

is a reference to a hash.
The hash keys are names for handler functions.
The WebFetch core provides internal handler functions called
I<fmt_handler_html> (for HTML output), 
I<fmt_handler_xml> (for XML output), 
I<fmt_handler_wf> (for WebFetch::General format), 
I<fmt_handler_rdf> (for MyNetscape RDF format). 
However, WebFetch modules may provide additional
format handler functions of their own by prepending
"fmt_handler_" to the key string used in the I<actions> array.

The values are array references containing
I<"action specs">,
which are themselves arrays of parameters
that will be passed to the handler functions
for generating output in a specific format.
There may be more than one entry for a given format if multiple outputs
with different parameters are needed.

The presence of values in this field mean that output is to be
generated in the specified format.
The presence of these would have been chosed by the WebFetch module that
created them - possibly by default settings or by a command-line argument
that directed a specific output format to be used.

For each valid action spec,
a separate "savable" (contents to be placed in a file)
will be generated from the contents of the I<data> variable.

The valid (but all optional) keys are

=over 4

=item html

the value must be a reference to an array which specifies all the
HTML generation (html_gen) operations that will take place upon the data.
Each entry in the array is itself an array reference,
containing the following parameters for a call to html_gen():

=over 4

=item filename

a file name or path string
(relative to the WebFetch output directory unless a full path is given)
for output of HTML text.

=item params

a hash reference containing optional name/value parameters for the
HTML format handler.

=over 4

=item filter_func

(optional)
a reference to code that, given a reference to an entry in
@{$self->{data}{records}},
returns true (1) or false (0) for whether it will be included in the
HTML output.
By default, all records are included.

=item sort_func

(optional)
a reference to code that, given references to two entries in
@{$self->{data}{records}},
returns the sort comparison value for the order they should be in.
By default, no sorting is done and all records (subject to filtering)
are accepted in order.

=item format_func

(optional)
a refernce to code that, given a reference to an entry in
@{$self->{data}{records}},
returns an HTML representation of the string.
By default, a standard HTML formatting is generated using the
well-known fields in the record.
(This default generation fails if none of the title, url or text
names are defined in %{$self->{data}{wk_names}}.

=back

=back

=item xml

the value must be a reference to an array which specifies all the
XML export (xml_export) operations that will take place upon the data.
Each entry in the array is itself an array reference,
containing the following parameters for a call to xml_export():

=over 4

=item filename

a file name or path string
(relative to the WebFetch output directory unless a full path is given)
for output of XML text.

=back

=item wf

the value must be a reference to an array which specifies all the
WebFetch export (wf_export) operations that will take place upon the data.
Each entry in the array is itself an array reference,
containing the following parameters for a call to wf_export():

=over 4

=item filename

a file name or path string
(relative to the WebFetch output directory unless a full path is given)
for output of the WebFetch::General export format.

=back

=item rdf

the value must be a reference to an array which specifies all the
Resource Description Framework (RDF) export (ns_export, used by MyNetscape)
operations that will take place upon the data.
Each entry in the array is itself an array reference,
containing the following parameters for a call to ns_export():

=over 4

=item filename

a file name or path string
(relative to the WebFetch output directory unless a full path is given)
for output of RDF format,
for the MyNetscape portal or other sites that can use RDF.

=item site_title

For exporting to MyNetscape, this sets the name of your site.
It cannot be more than 40 characters

=item site_link

For exporting to MyNetscape, this is the full URL MyNetscape will
use to link to your site.
It cannot be more than 500 characters.

=item site_desc

For exporting to MyNetscape, this is a short description of your site.
It cannot be more than 500 characters.

=item image_title

(optional)
For exporting to MyNetscape, this is the title (alt) text for the icon image.

=item image_url

(optional)
For exporting to MyNetscape, this is the URL MyNetscpae will use
for your icon image.
If this is present, the link on the image will be the same as your
$site_link parameter.

=back

=back

Additional valid keys may be created by modules that inherit from WebFetch
by supplying a method/function named with "fmt_handler_" preceding the
string used for the key.
For example, for an "xyz" format, the handler function would be
I<fmt_handler_xyz>.
The value (the "action spec") of the hash entry
must be an array reference.
Within that array are "action spec entries",
each of which is a reference to an array containing the list of
parameters that will be passed verbatim to the I<fmt_handler_xyz> function.

When the format handler function returns, it is expected to have
created entries in the $obj->{savables} array
(even if they only contain error messages explaining a failure),
which will be used by $obj->save() to save the files and print the
error messages.

For coding examples, use the I<fmt_handler_*> functions in WebFetch.pm itself.

=back

=back

=cut

sub do_actions
{
	my ( $self ) = @_;

	# we *really* need the data and actions to be set!
	# otherwise assume we're in WebFetch 0.09 compatibility mode and
	# $self->fetch() better have created its own savables already
	if (( !defined $self->{data}) or ( !defined $self->{actions})) {
		return
	}

	# loop through all the actions
	my $action_spec;
	foreach $action_spec ( keys %{$self->{actions}} ) {

		# check if there's a handler function for this action
		my $action_handler = "fmt_handler_".$action_spec;
		if ( $self->can($action_handler)) {

			# loop through action spec entries (parameter lists)
			my $entry;
			foreach $entry ( @{$self->{actions}{$action_spec}}) {
				# parameters must be in an ARRAY ref
				if (ref $entry ne "ARRAY" ) {
					carp "warning: entry in action spec "
						."\"".$action_spec."\""
						."expected to be ARRAY, found "
						.(ref $entry)." instead "
						."- ignored\n";
					next;
				}

				# everything looks OK - call the handler
				$self->$action_handler(@$entry);

				# if there were errors, the handler should
				# have created a savable entry which
				# contains only the error entry so that
				# it will be reported by $self->save()
			}
		} else {
			carp "warning: action \"$action_spec\" specified but "
				."\&{\$self->$action_handler}() "
				."not defined in "
				.(ref $self)." - ignored\n";
		}
	}
}

=item $obj->fetch

B<This function must be provided by each derived module to perform the
fetch operaton specific to that module.>
It will be called from C<new()> so you should not call it directly.
Your fetch function should extract some data from somewhere
and place of it in HTML or other meaningful form in the "savable" array.

Upon entry to this function, $obj must contain the following attributes:

=over 4

=item dir

The name of the directory to save in.
(If called from the command-line, this will already have been provided
by the required C<--dir> parameter.)

=item savable

a reference to an array where the "savable" items will be placed by
the $obj->fetch function.
(You only need to provide an array reference -
other WebFetch functions can write to it.)

In WebFetch 0.10 and later,
this parameter should no longer be supplied by the I<fetch> function
(unless you wish to use 0.09 backward compatibility)
because it is filled in by the I<do_actions>
after the I<fetch> function is completed
based on the I<data> and I<actions> variables
that are set in the I<fetch> function.
(See below.)

Each entry of the savable array is a hash reference with the following
attributes:

=over 4

=item file

file name to save in

=item content

scalar w/ entire text or raw content to write to the file

=item group

(optional) group setting to apply to file

=item mode

(optional) file permissions to apply to file

=back

Contents of savable items may be generated directly by derived modules
or with WebFetch's C<html_gen>, C<html_savable> or C<raw_savable>
functions.
These functions will set the group and mode parameters from the
object's own settings, which in turn could have originated from
the WebFetch command-line if this was called that way.

=back

Note that the fetch functions requirements changed in WebFetch 0.10.
The old requirement (0.09 and earlier) is supported for backward compatibility.

I<In WebFetch 0.09 and earlier>,
upon exit from this function, the $obj->savable array must contain
one entry for each file to be saved.
More than one array entry means more than one file to save.
The WebFetch infrastructure will save them, retaining backup copies
and setting file modes as needed.

I<Beginning in WebFetch 0.10>, the "WebFetch embedding" capability was introduced.
In order to do this, the captured data of the I<fetch> function 
had to be externalized where other Perl routines could access it.  
So the fetch function now only populates data structures
(including code references necessary to process the data.)

Upon exit from the function,
the following variables must be set in C<$obj>:

=over 4

=item data

is a reference to a hash which will be used by the I<do_actions> function.
(See above.)

=item actions

is a reference to a hash which will be used by the I<do_actions> function.
(See above.)

=back

=cut

# placeholder for fetch routines by derived classes
sub fetch
{
	die "WebFetch: fetch() "
		."function must be overridden by a derived module\n";
}


=item $obj->get

This WebFetch utility function will get a URL and return a reference
to a scalar with the retrieved contents.
Upon entry to this function, C<$obj> must contain the following attributes: 

=over 4

=item url

the URL to get

=item quiet

a flag which, when set to a non-zero (true) value,
suppresses printing of HTTP request errors on STDERR

=back

=cut

# utility function to get the contents of a URL
sub get
{
        my ( $self ) = @_;

	if ( $self->{debug}) {
		print STDERR "debug: get(".$self->{url}.")\n";
	}

        # send request, capture response
        my $ua = LWP::UserAgent->new;
	$ua->agent("WebFetch/$VERSION ".$ua->agent);
        my $request = HTTP::Request->new(GET => $self->{url});
        my $response = $ua->request($request);

        # abort on failure
        if ($response->is_error) {
                $self->{quiet} or print STDERR
			"The request received an error: "
			.$response->as_string."\n";
                exit 1;
        }

        # return the content
        my $content = $response->content;
	return \$content;
}

=item $obj->wf_export ( $filename, $fields, $links, [ $comment, [ $param ]] )

I<In WebFetch 0.10 and later, this should be used only in
format handler functions.  See do_handlers() for details.>

This WebFetch utility function generates contents for a WebFetch export
file, which can be placed on a web server to be read by other WebFetch sites.
The WebFetch::General module reads this format.
$obj->wf_export has the following parameters:

=over 4

=item $filename

the file to save the WebFetch export contents to;
this will be placed in the savable record with the contents
so the save function knows were to write them

=item $fields

a reference to an array containing a list of the names of the data fields
(in each entry of the @$lines array)

=item $lines

a reference to an array of arrays;
the outer array contains each line of the exported data;
the inner array is a list of the fields within that line
corresponding in index number to the field names in the @$fields array

=item $comment

(optional) a Human-readable string comment (probably describing the purpose
of the format and the definitions of the fields used) to be placed at the
top of the exported file

=item $param

(optional) a reference to a hash of global parameters for the exported data.
This is currently unused but reserved for future versions of WebFetch.

=back

=cut

# utility function to generate WebFetch Export format
# which WebFetch users can read with the WebFetch::General module
sub wf_export
{
	my ( $self, $filename, $fields, $lines, $comment, $param ) = @_;
	my ( @export_out, $line );
	my $delim = "";   # blank line is delimeter

	if ( $self->{debug}) {
		print STDERR "debug: entered wf_export, output to $filename\n";
	}

	# validate parameters
	if ( ! ref $fields or ref $fields ne "ARRAY" ) {
		die "WebFetch: export error: fields parameter is not an "
			."array reference\n";
	}
	if ( ! ref $lines or ref $lines ne "ARRAY" ) {
		die "WebFetch: export error: lines parameter is not an "
			."array reference\n";
	}
	if (( defined $param ) and ref $param ne "HASH" ) {
		die "WebFetch: export error: param parameter is not an "
			."hash reference\n";
	}

	# generate output header
	push @export_out, "[WebFetch export]";
	push @export_out, "Version: $VERSION";
	push @export_out, "# This was generated by the Perl5 WebFetch "
		."$VERSION module.";
	push @export_out, "# WebFetch info can be found at "
		."http://www.webfetch.org/";
	if ( defined $comment ) {
		my $c_line;
		push @export_out, "#";
		foreach $c_line ( split ( "\n", $comment )) {
			push @export_out, "# $c_line";
		}
	}

	# generate contents, each field has items in RFC822-like style
	foreach $line ( @$lines ) {
		push @export_out, $delim;
		my ( $field, $item );
		for ( $field = 0; $field <= $#{@$fields}; $field++ ) {
			$item = $line->[$field];
			( defined $item ) or last;
			$item =~ s/\n\n+/\n/sgo;     # remove blank lines
			$item =~ s/^\n+//o;          # remove leading newlines
			$item =~ s/\n+$//o;          # remove trailing newlines
			$item =~ s/\n/\\\n    /sgo;  # escape newlines with "\"
			push @export_out, $fields->[$field].": $item";
		}
	}

	# store contents
	$self->raw_savable( $filename,
		join ( "\n", @export_out )."\n" );
}


=item $obj->ns_export ( $filename, $lines, $site_title, $site_link, $site_desc, $image_title, $image_url)

I<In WebFetch 0.10 and later, this should be used only in
format handler functions.  See do_handlers() for details.>

This WebFetch utility function generates contents for a MyNetscape export
file, which can be placed on a web server to be read by the MyNetscape
site (my.netscape.com) if you create a "channel" for your site at MyNetscape.

Of the modules included with WebFetch, only WebFetch::SiteNews and
WebFetch::Genercal call $obj->ns_export().
The others will ignore it (because they're just obtaining data from
other sites themselves.)
You may use $obj->ns_export()
in your own modules which inherit from WebFetch.

=for html
For more info see <a href="http://my.netscape.com/publish/">http://my.netscape.com/publish/</a>

=for text
For more info see http://my.netscape.com/publish/

=for man
For more info see http://my.netscape.com/publish/

$obj->ns_export has the following parameters:

=over 4

=item $filename

(required)
the file to save the WebFetch export contents to;
this will be placed in the savable record with the contents
so the save function knows were to write them

=item $lines

(required)
a reference to an array of arrays;
the outer array contains each line of the exported data;
the inner array is a list of two fields within that line
consisting of a text title string in one entry and a
URL in the second entry.

=item $site_title

(required)
For exporting to MyNetscape, this sets the name of your site.
It cannot be more than 40 characters

=item $site_link

(required)
For exporting to MyNetscape, this is the full URL MyNetscape will
use to link to your site.
It cannot be more than 500 characters.

=item $site_desc

(required)
For exporting to MyNetscape, this is a short description of your site.
It cannot be more than 500 characters.

=item $image_title

(optional)
For exporting to MyNetscape, this is the title (alt) text for the icon image.

=item $image_url

(optional)
For exporting to MyNetscape, this is the URL MyNetscpae will use
for your icon image.
If this is present, the link on the image will be the same as your
$site_link parameter.

=back

=cut

# utility function to generate MyNetscape export format
# this can be used to export to MyNetscape channels (if you create one)
# for more info see http://my.netscape.com/publish/
sub ns_export
{
	my ( $self, $filename, $lines, $site_title, $site_link, $site_desc,
		$image_title, $image_url ) = @_;
	my ( @export_out, $line );


	if ( $self->{debug}) {
		print STDERR "debug: entered ns_export, output to $filename\n";
	}

	# validate parameters
	if ( ! ref $lines or ref $lines ne "ARRAY" ) {
		die "WebFetch: ns_export error: lines parameter is not an "
			."array reference\n";
	}
	if (( !defined $site_title ) or ( !defined $site_link ) or
		( !defined $site_desc ))
	{
		my @missing;
		( !defined $site_title ) and push @missing, "site_title";
		( !defined $site_link ) and push @missing, "site_link";
		( !defined $site_desc ) and push @missing, "site_desc";
		die "WebFetch: ns_export error: missing required parameters: "
			.join( " ", @missing )."\n";
	}

	# generate RDF header
	push @export_out, "<?xml version=\"1.0\"?>";
	push @export_out, "<rdf:RDF";
	push @export_out, "xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"";
	push @export_out, "xmlns=\"http://my.netscape.com/rdf/simple/0.9/\">";
	push @export_out, "";
	push @export_out, "  <channel>";
	push @export_out, "    <title>$site_title</title>";
	push @export_out, "    <link>$site_link</link>";
	push @export_out, "    <description>$site_desc</description>";
	push @export_out, "  </channel>";
	if ( defined $image_url ) {
		push @export_out, "";
		push @export_out, "  <image>";
		push @export_out, "    <title>"
			.((defined $image_title) ? $image_title : $site_title )
			."</title>";
		push @export_out, "    <url>$image_url</url>";
		push @export_out, "    <link>$site_link</link>";
		push @export_out, "  </image>";
	}

	# generate contents, each field has items in RFC822-like style
	my $max_item_count = 15;
	my $item_count = 0;
	foreach $line ( @$lines ) {
		my ( $title, $url ) = @$line;
		$title =~ s/\n\n+/\n/sgo;     # remove blank lines
		$title =~ s/^\n+//o;          # remove leading newlines
		$title =~ s/\n+$//o;          # remove trailing newlines
		$title =~ s/\n/ /sgo;         # remove newlines
		$title =~ s/^\s*//o;          # remove leading whitespace
		$title =~ s/\s*$//o;          # remove trailing whitespace
		$title =~ s/\&/&amp;/go;      # encode ampersands
		$title =~ s/\"/&quot;/go;     # encode quotes
		$title =~ s/\</&lt;/go;       # encode less-thans
		$title =~ s/\>/&gt;/go;       # encode greater-thans
		push @export_out, "";
		push @export_out, "  <item>";
		push @export_out, "    <title>$title</title>";
		push @export_out, "    <link>$url</link>";
		push @export_out, "  </item>";
		( $item_count++ < $max_item_count - 1 ) or last;
	}

	# generate RDF footer
	push @export_out, "";
	push @export_out, "</rdf:RDF>";

	# store contents
	$self->raw_savable( $filename,
		join ( "\n", @export_out )."\n" );
}

=item $obj->html_gen( $filename, $format_func, $links )

I<In WebFetch 0.10 and later, this should be used only in
format handler functions.  See do_handlers() for details.>

This WebFetch utility function generates some common formats of
HTML output used by WebFetch-derived modules.
The HTML output is stored in the $obj->{savable} array,
for which all the files in that array can later be saved by the
$obj->save function.
It has the following parameters:

=over 4

=item $filename

the file name to save the generated contents to;
this will be placed in the savable record with the contents
so the save function knows were to write them

=item $format_func

a refernce to code that formats each entry in @$links into a
line of HTML

=item $links

a reference to an array of arrays of parameters for C<&$format_func>;
each entry in the outer array is contents for a separate HTML line
and a separate call to C<&$format_func>

=back

Upon entry to this function, C<$obj> must contain the following attributes: 

=over 4

=item num_links

number of lines/links to display

=item savable

reference to an array of hashes which this function will use as
storage for filenames and contents to save
(you only need to provide an array reference - the function will write to it)

See $obj->fetch for details on the contents of the C<savable> parameter

=item table_sections

(optional) if present, this specifies the number of table columns to use;
the number of links from C<num_links> will be divided evenly between the
columns

=item style

(optional) a hash reference with style parameter names/values
that can modify the behavior of the funciton to use different HTML styles.
The recognized values are enumerated with WebFetch's I<--style> command line
option.
(When they reach this point, they are no longer a comma-delimited string -
WebFetch or another module has parsed them into a hash with the style
name as the key and the integer 1 for the value.)

=back

=cut

# utility function to generate HTML output
sub html_gen
{
        my ( $self, $filename, $format_func, $links ) = @_;

        # generate summary HTML links
        my $link_count=0;
        my @result;
	my $style_para = 0;
	my $style_ul = 0;
	my $style_bullet = 0;
	my $style_notable = 0;
	if (( defined $self->{style} ) and ref($self->{style}) eq "HASH" ) {
		$style_para = ( defined $self->{style}{para} ) ? $self->{style}{para} : 0;
		$style_notable = ( defined $self->{style}{notable} ) ? $self->{style}{notable} : 0;
		$style_ul = ( defined $self->{style}{ul} ) ? $self->{style}{ul} : 0;
		$style_bullet = ( defined $self->{style}{bullet} ) ? $self->{style}{bullet} : 0;
	}
	if ( ! $style_para and !$style_ul and ! $style_bullet ) {
		$style_bullet = 1;
	}

	if ( ! $style_notable ) {
		push @result, "<center>";
		push @result, "<table><tr><td valign=top>";
	}
	if ( $style_ul ) {
		push @result, "<ul>";
	}
	$self->font_start( \@result );
        if ( @$links >= 0 ) {
                my $entry;
                foreach $entry ( @$links ) {
                        push @result,
				( $style_ul ? "<li>" :
				( $style_bullet ? "&#149;&nbsp;" : "" ))
				.&$format_func(@$entry);
                        if ( ++$link_count >= $self->{num_links} ) {
                                last;
                        }
			if (( defined $self->{table_sections}) and
				! $style_para and ! $style_notable and
				$link_count == int(($self->{num_links}+1)
				/ $self->{table_sections}))
			{
				$self->font_end( \@result );
				push @result, "</td>";
				push @result, "<td width=45% valign=top>";
				$self->font_start( \@result );
			} else {
				if ( $style_para ) {
					push @result, "<p>";
				} elsif ( $style_bullet ) {
					push @result, "<br>";
				}
			}
                }
        } else {
                push @result, "<i>(There are technical difficulties with "
                        ."this information source.  "
                        ."Please check again later.)</i>";
        }
	$self->font_end( \@result );
	if ( $style_ul ) {
		push @result, "</ul>";
	}
	if ( ! $style_notable ) {
		push @result, "</td></tr></table>";
		push @result, "</center>";
	}

	$self->html_savable( $filename, join("\n",@result)."\n");
}

# internal-use function font_start, used by html_gen
sub font_start
{
	my ( $self, $result ) = @_;

	if (( defined $self->{font_size}) or ( defined $self->{font_face})) {
		push @$result, "<font"
			.(( defined $self->{font_size})
				? " size=".$self->{font_size} : "" )
			.(( defined $self->{font_face})
				? " face=\"".$self->{font_face}."\"" : "" )
			.">";
	}
}

# internal-use function font_end, used by html_gen
sub font_end
{
	my ( $self, $result ) = @_;

	if (( defined $self->{font_size}) or ( defined $self->{font_face})) {
		push @$result, "</font>";
	}
}

=item $obj->html_savable( $filename, $content )

I<In WebFetch 0.10 and later, this should be used only in
format handler functions.  See do_handlers() for details.>

This WebFetch utility function stores pre-generated HTML in a new entry in
the $obj->{savable} array, for later writing to a file.
It's basically a simple wrapper that puts HTML comments
warning that it's machine-generated around the provided HTML text.
This is generally a good idea so that neophyte webmasters
(and you know there are a lot of them in the world :-)
will see the warning before trying to manually modify
your automatically-generated text.

See $obj->fetch for details on the contents of the C<savable> parameter

=cut

# utility function to make a savable record for HTML text
sub html_savable
{
        my ( $self, $filename, $content ) = @_;

	$self->raw_savable( $filename,
		"<!--- begin text generated by "
		."Perl5 WebFetch $VERSION - do not manually edit --->\n"
		."<!--- WebFetch can be found at "
		."http://www.webfetch.org/ --->\n"
		.$content
		."<!--- end text generated by "
		."Perl5 WebFetch $VERSION - do not manually edit --->\n" );
}

=item $obj->raw_savable( $filename, $content )

I<In WebFetch 0.10 and later, this should be used only in
format handler functions.  See do_handlers() for details.>

This WebFetch utility function stores any raw content and a filename
in the $obj->{savable} array,
in preparation for writing to that file.
(The actual save operation may also automatically include keeping
backup files and setting the group and mode of the file.)

See $obj->fetch for details on the contents of the C<savable> parameter

=cut

# utility function to make a savable record for raw text
sub raw_savable
{
        my ( $self, $filename, $content ) = @_;

	if ( !defined $self->{savable}) {
		$self->{savable} = [];
	}
        push ( @{$self->{savable}}, {
                'file' => $filename,
                'content' => $content,
		(( defined $self->{group}) ? ('group' => $self->{group}) : ()),
		(( defined $self->{mode}) ? ('mode' => $self->{mode}) : ())
                });
}

=item $obj->save

This WebFetch utility function goes through all the entries in the
$obj->{savable} array and saves their contents,
providing several services such as keeping backup copies, 
and setting the group and mode of the file, if requested to do so.

If you call a WebFetch-derived module from the command-line run()
or fetch_main() functions, this will already be done for you.
Otherwise you will need to call it after populating the
C<savable> array with one entry per file to save.

Upon entry to this function, C<$obj> must contain the following attributes: 

=over 4

=item dir

directory to save files in

=item savable

names and contents for files to save

=back

See $obj->fetch for details on the contents of the C<savable> parameter

=cut

# file-save routines for all WebFetch-derived classes
sub save
{
	my $self = shift;

	if ( $self->{debug} ) {
		print STDERR "entering save()\n";
		Dumper($self);
	}

	# check if we have attributes needed to proceed
	if ( !defined $self->{"dir"}) {
		die "WebFetch: directory path missing - "
			."required for save\n";
	}
	if ( !defined $self->{savable}) {
		die "WebFetch: nothing to save\n";
	}
	if ( ref($self->{savable}) ne "ARRAY" ) {
		die "WebFetch: cannot save - savable is not an array\n";
	}

	# loop through "savable" (grouped content and filename destination)
	my $savable;
	foreach $savable ( @{$self->{savable}}) {

		if ( $self->{debug} ) {
			print STDERR "saving ".$savable->{file}."\n";
		}

		# verify contents of savable record
		if ( !defined $savable->{file}) {
			$savable->{error} = "missing file name - skipped";
			next;
		}
		if ( !defined $savable->{content}) {
			$savable->{error} = "missing content text - skipped";
			next;
		}

		# generate file names
		my $new_content = $self->{"dir"}."/N".$savable->{file};
		my $main_content = $self->{"dir"}."/".$savable->{file};
		my $old_content = $self->{"dir"}."/O".$savable->{file};

		# make sure the Nxx "new content" file does not exist yet
		if ( -f $new_content ) {
			if ( !unlink $new_content ) {
				$savable->{error} = "cannot unlink "
					.$new_content.": $!";
				next;
			}
		}

		# write content to the "new content" file
		if ( ! open ( new_content, ">$new_content" )) {
			$savable->{error} = "cannot open "
				.$new_content.": $!";
			next;
		}
		if ( !print new_content $savable->{content}) {
			$savable->{error} = "failed to write to "
				.$new_content.": $!";
			close new_content;
			next;
		}
		if ( !close new_content ) {
			# this can happen with NFS errors
			$savable->{error} = "failed to close "
				.$new_content.": $!";
			next;
		}

		# remove the "old content" file to get it out of the way
		if ( -f $old_content ) {
			if ( !unlink $old_content ) {
				$savable->{error} = "cannot unlink "
					.$old_content.": $!";
				next;
			}
		}

		# move the main content to the old content - now it's a backup
		if ( -f $main_content ) {
			if ( !rename $main_content, $old_content ) {
				$savable->{error} = "cannot rename "
					.$main_content." to "
					.$old_content.": $!";
				next;
			}
		}

		# chgrp the "new content" before final installation
		if ( defined $savable->{group}) {
			my $gid = $savable->{group};
			if ( $gid !~ /^[0-9]+$/o ) {
				$gid = (getgrnam($gid))[2];
				if ( ! defined $gid ) {
					$savable->{error} = "cannot chgrp "
						.$new_content.": "
						.$savable->{group}
						." does not exist";
					next;
				}
			}
			if ( ! chown $>, $gid, $new_content ) {
				$savable->{error} = "cannot chgrp "
					.$new_content." to "
					.$savable->{group}.": $!";
				next;
			}
		}

		# chmod the "new content" before final installation
		if ( defined $savable->{mode}) {
			if ( ! chmod oct($savable->{mode}), $new_content ) {
				$savable->{error} = "cannot chmod "
					.$new_content." to "
					.$savable->{mode}.": $!";
				next;
			}
		}

		# move the new content to the main content - final install
		if ( -f $new_content ) {
			if ( !rename $new_content, $main_content ) {
				$savable->{error} = "cannot rename "
					.$new_content." to "
					.$main_content.": $!";
				next;
			}
		}
	}

	# loop through savable to report any errors
	my $err_count = 0;
	foreach $savable ( @{$self->{savable}}) {
		if ( defined $savable->{error}) {
			print STDERR "WebFetch: failed to save "
				.$savable->{file}.": "
				.$savable->{error}."\n";
			$err_count++;
		}
	}
	if ( $err_count ) {
		die "WebFetch: $err_count errors - fetch/save failed\n";
	}

	# success if we got here
	return 1;
}

#
# functions to support format handlers
#

# initialize an internal hash of field names to field numbers
sub init_fname2fnum
{
	my ( $self ) = @_;

	# check if fname2fnum is already initialized
	if (( defined $self->{fname2fnum})
		and ref $self->{fname2fnum} eq "HASH" )
	{
		# already done - success
		return 1;
	}

	# check if prerequisite data exists
	if (( ! defined $self->{data} )
		or ( ! defined $self->{data}{fields}))
	{
		# missing prerequisites - failed
		return 0;
	}

	# initialize the fname2fnum hash
	my $i;
	$self->{fname2fnum} = {};
	for ( $i=0; $i < scalar(@{$self->{data}{fields}}); $i++ ) {
		# put the field number in as the value for the hash
		$self->{fname2fnum}{$self->{data}{fields}[$i]} = $i;
	}

	# OK, done
	return 1;
}

# initialize an internal hash of well-known names to field numbers
sub init_wk2fnum
{
	my ( $self ) = @_;

	$self->init_fname2fnum() or return 0;

	# check if wk2fnum is already initialized
	if (( defined $self->{wk2fnum})
		and ref $self->{wk2fnum} eq "HASH" )
	{
		# already done - success
		return 1;
	}

	# check for prerequisite data
	if ( ! defined $self->{data}{wk_names}) {
		return 0;
	}

	my $wk_key;
	$self->{wk2fnum} = {};
	foreach $wk_key ( keys %{$self->{data}{wk_names}}) {
		# perform consistency cross-check between wk_names and fields
		if ( !defined $self->{fname2fnum}{$self->{data}{wk_names}{$wk_key}})
		{
			# wk_names has a bad field name - carp about it!
			carp "warning: wk_names contains $wk_key"."->"
				.$self->{data}{wk_names}{$wk_key}
				." but "
				.$self->{data}{wk_names}{$wk_key}
				." is not in the fields list - ignored\n";
		} else {
			# it's OK - put it in the table
			$self->{wk2fnum}{$wk_key} =
				$self->{fname2fnum}{$self->{data}{wk_names}{$wk_key}};
		}
	}
	return 1;
}

# convert well-known name to field name
sub wk2fname
{
	my ( $self, $wk ) = @_;

	$self->init_fname2fnum() or return undef;

	# check for prerequisite data
	if (( ! defined $self->{data}{wk_names})
		or ( ! defined $self->{data}{wk_names}{$wk}))
	{
		return undef;
	}

	# double check that the field exists before pronouncing it OK
	# (perform consistency cross-check between wk_names and fields)
	if ( defined $self->{fname2fnum}{$self->{data}{wk_names}{$wk}}) {
		return $self->{data}{wk_names}{$wk};
	}

	# otherwise, wk_names has a bad field name.
	# But init_wk2fnum() may have already carped about it
	# so check whether we need to carp about it or not.
	if ( ! defined $self->{wk2fnum}) {
		carp "warning: wk_names contains $wk"."->"
			.$self->{data}{wk_names}{$wk}
			." but "
			.$self->{data}{wk_names}{$wk}
			." is not in the fields list - ignored\n";
	}
	return undef;
}

# convert a field name to a field number
sub fname2fnum
{
	my ( $self, $fname ) = @_;

	$self->init_fname2fnum() or return undef;
	return $self->{fname2fnum}{$fname};
}

# convert well-known name to field number
sub wk2fnum
{
	my ( $self, $wk ) = @_;

	$self->init_wk2fnum() or return undef;
	return $self->{wk2fnum}{$wk};
}

#
# format handler functions
# these do not have their own POD docs, but are defined in the
# $obj->do_actions() docs above
#

# HTML format handler
sub fmt_handler_html
{
	my ( $self, $filename, $params ) = @_;
	my $records = $self->{data}{records};

	# if we need to filter or sort, make a copy of the data records
	if (( defined $params->{filter_func})
		or ( defined $params->{sort_func}))
	{
		# filter/select items in the table if filter function exists
		my $i;
		if (( defined $params->{filter_func})
			and ref $params->{filter_func} eq "CODE" )
		{
			# create the new table
			$records = [];

			for ($i=0; $i<scalar(@{$self->{data}{records}}); $i++)
			{
				if ( &{$params->{filter_func}}(
					@{$self->{data}{records}[$i]}))
				{
					unshift @$records,
						$self->{data}{records}[$i];
				}
			}
		} else {
			# copy all the references in the table over
			# don't mess with the data itself
			$records = [ @{$self->{data}{records}} ];
		}

		# sort the table if sort/compare function is present
		if (( defined $params->{sort_func})
			and ref $params->{sort_func} eq "CODE" )
		{
			$records = [ sort {&{$params->{sort_func}}($a,$b)}
				@$records ];
		}
	}

	if (( defined $params->{format_func})
		and ref $params->{format_func} eq "CODE" )
	{
		$self->html_gen ( $filename,
			$params->{format_func},
			$records );
		return;
	}

	# get local copies of the values from wk2fnum so that we can
	# take advantage of closure scoping to grab these values instead
	# of doing a table lookup for every value every time the format
	# function iterates over every data item
	my ( $title_fnum, $url_fnum, $date_fnum, $summary_fnum,
		$comments_fnum, $author_fnum, $category_fnum,
		$location_fnum ) = (
			$self->wk2fnum("title"),
			$self->wk2fnum("url"),
			$self->wk2fnum("date"),
			$self->wk2fnum("summary"),
			$self->wk2fnum("comments"),
			$self->wk2fnum("author"),
			$self->wk2fnum("category"),
			$self->wk2fnum("location"));

	# generate the html and formatting function
	# This does a lot of conditional inclusion of well-known fields,
	# depending on their presence in a give data record.
	# The $_[...] notation is used to grab the data because this
	# anonymous function will be run once for every record in
	# @{$self->{data}{records}} with the data array/record passed
	# to it as the function's parameters.
	$self->html_gen ( $filename,
		sub { return ""
			.((defined $title_fnum )
				? ((defined $url_fnum )
					? "<a href=\"".$_[$url_fnum]."\">"
					: "")
				.$_[$title_fnum]
				.((defined $url_fnum )
					? "</a>"
					: "")
			: ((defined $summary_fnum )
				? $_[$summary_fnum]
				: "" ))
			.((defined $comments_fnum )
				? " (".$_[$comments_fnum].")"
				: "" )},
			$records );
}

# XML format handler
# This generates a "standalone" XML document with its own built-in DTD
# to define the fields.
# Note: we couldn't use XML::Writer because it only writes to a filehandle.
sub fmt_handler_xml
{
	my ( $self, $filename ) = @_;
	my ( @xml, $record, $field, $indent );

	# generate XML prolog/heading with a dynamically-generated XML DTD
	$indent = " " x 4;
	push @xml, "<?xml version=\"1.0\" standalone=\"yes\" ?>";
	push @xml, "";
	push @xml, "<!DOCTYPE webfetch_dynamic [";
	push @xml, $indent."<!ELEMENT webfetch_dynamic (record*)>";
	push @xml, $indent."<!ELEMENT record ("
		.join( ", ", @{$self->{data}{fields}})
		.")>";
	for ( $field = 0; $field < scalar @{$self->{data}{fields}}; $field++ )
	{
		push @xml, $indent.
			"<!ELEMENT ".$self->{data}{fields}[$field]
			."(#PCDATA)>";
	}
	push @xml, "]>";
	push @xml, "";

	# generate XML content
	push @xml, "<webfetch_dynamic>";
	foreach $record ( @{$self->{data}{records}}) {
		push @xml, $indent."<record>";
		for ( $field = 0; $field < scalar @{$self->{data}{fields}};
			$field++ )
		{
			push @xml, ( $indent x 2 )
				."<".$self->{data}{fields}[$field].">";
			push @xml, ( $indent x 3 )
				.$record->[$field];
			push @xml, ( $indent x 2 )
				."</".$self->{data}{fields}[$field].">";
		}
		push @xml, $indent."</record>";
	}
	push @xml, "</webfetch_dynamic>";

	# store the XML text as a savable
	$self->raw_savable( $filename, join ( "\n", @xml )."\n" );
}

# WebFetch::General format handler
sub fmt_handler_wf
{
	my ( $self, $filename ) = @_;

	$self->wf_export( $filename,
		$self->{data}{fields},
		$self->{data}{records},
		"Exported from ".(ref $self)."\n"
			."fields are "
			.join(", ", @{$self->{data}{fields}})."\n" );
}

# RDF format handler
sub fmt_handler_rdf
{
	my ( $self, $filename, $site_title, $site_link, $site_desc,
		$image_title, $image_url ) = @_;

	# get the field numbers for the well-known fields for title and url
	my ( $title_fnum, $url_fnum, );
	$title_fnum = $self->wk2fnum("title");
	$url_fnum = $self->wk2fnum("url");

	# if title or url is missing, we have to abort with an error message
	if (( !defined $title_fnum ) or ( !defined $url_fnum )) {
		my %savable = ( "file" => $filename,
			"error" => "cannot RDF export with missing fields: "
				.((!defined $title_fnum ) ? "title " : "" )
				.((!defined $url_fnum ) ? "url " : "" ));
		if ( !defined $self->{savable}) {
			$self->{savable} = [];
		}
		push @{$self->{savable}}, \%savable;
		return;
	}

	# check if we can shortcut the array processing
	my $data;
	if ( $title_fnum == 0 and $url_fnum == 1 ) {
		$data = $self->{data}{records};
	} else {
		# oh well, the fields weren't in the right order
		# extract a copy that contains title and url fields
		my $entry;
		$data = [];
		foreach $entry ( @{$self->{data}{records}}) {
			push @$data, [ $entry->[$title_fnum],
				$entry->[$url_fnum]];
		}
	}
	$self->ns_export( $filename, $data,
		$site_title, $site_link, $site_desc, $image_title,
		$image_url );
}

1;
__END__
# remainder of POD docs follow

=head2 WRITING NEW WebFetch-DERIVED MODULES

The easiest way to make a new WebFetch-derived module is to start
from the module closest to your fetch operation and modify it.
Make sure to change all of the following:

=over 4

=item fetch function

The fetch function is the meat of the operation.
Get the desired info from a local file or remote site and place the
contents that need to be saved in the C<savable> parameter.

=item module name

Be sure to catch and change them all.

=item file names

The code and documentation may refer to output files by name.

=item module parameters

Change the URL, number of links, etc as necessary.

=item command-line parameters

If you need to add command-line parameters, modify both the
B<C<@Options>> and B<C<$Usage>> variables.
Don't forget to add documentation for your command-line options
and remove old documentation for any you removed.

When adding documentation, if the existing formatting isn't enough
for your changes, there's more information about
Perl's
POD ("plain old documentation")
embedded documentation format at
http://www.cpan.org/doc/manual/html/pod/perlpod.html

=item authors

Add yourself as an author if you added any significant functionality.
But if you used anyone else's code, retain the existing author credits
in any module you modify to make a new one.

=item export function

If it's appropriate for users of your module to be able to export its
data to other sites, add an export() function.
Use the one in WebFetch::SiteNews as an example if you need to.

=back

Please consider contributing any useful changes back to the WebFetch
project at C<maint@webfetch.org>.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
Send patches, bug reports, suggestions and questions to
C<maint@webfetch.org>.

WebFetch is Open Source software distributed via the
Comprehensive Perl Archive Network (CPAN),
a worldwide network of Perl web mirror sites.
WebFetch may be copied under the same terms and licensing as Perl itelf.

=for html
A current copy of the source code and documentation may be found at
<a href="http://www.webfetch.org/">http://www.webfetch.org/</a>

=for text
A current copy of the source code and documentation may be found at
http://www.webfetch.org/

=for man
A current copy of the source code and documentation may be found at
http://www.webfetch.org/

=head1 SEE ALSO

=for html
<a href="http://www.perl.org/">perl</a>(1),
<a href="WebFetch::CNETnews.html">WebFetch::CNETnews</a>,
<a href="WebFetch::CNNsearch.html">WebFetch::CNNsearch</a>,
<a href="WebFetch::COLA.html">WebFetch::COLA</a>,
<a href="WebFetch::DebianNews.html">WebFetch::DebianNews</a>,
<a href="WebFetch::Freshmeat.html">WebFetch::Freshmeat</a>,
<a href="WebFetch::LinuxDevNet.html">WebFetch::LinuxDevNet</a>,
<a href="WebFetch::LinuxTelephony.html">WebFetch::LinuxTelephony</a>,
<a href="WebFetch::LinuxToday.html">WebFetch::LinuxToday</a>,
<a href="WebFetch::ListSubs.html">WebFetch::ListSubs</a>,
<a href="WebFetch::PerlStruct.html">WebFetch::PerlStruct</a>,
<a href="WebFetch::SiteNews.html">WebFetch::SiteNews</a>,
<a href="WebFetch::Slashdot.html">WebFetch::Slashdot</a>,
<a href="WebFetch::32BitsOnline.html">WebFetch::32BitsOnline</a>,
<a href="WebFetch::YahooBiz.html">WebFetch::YahooBiz</a>.

=for text
perl(1), WebFetch::CNETnews, WebFetch::CNNsearch, WebFetch::COLA,
WebFetch::DebianNews, WebFetch::Freshmeat,
WebFetch::LinuxDevNet, WebFetch::LinuxTelephony, WebFetch::LinuxToday,
WebFetch::ListSubs, WebFetch::PerlStruct,
WebFetch::SiteNews, WebFetch::Slashdot,
WebFetch::32BitsOnline, WebFetch::YahooBiz.

=for man
perl(1), WebFetch::CNETnews, WebFetch::CNNsearch, WebFetch::COLA,
WebFetch::DebianNews, WebFetch::Freshmeat,
WebFetch::LinuxDevNet, WebFetch::LinuxTelephony, WebFetch::LinuxToday,
WebFetch::ListSubs, WebFetch::PerlStruct,
WebFetch::SiteNews, WebFetch::Slashdot,
WebFetch::32BitsOnline, WebFetch::YahooBiz.

=cut
