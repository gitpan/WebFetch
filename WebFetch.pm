#
# WebFetch - infrastructure for downloading ("fetching") information from
# various sources around the Internet or the local system in order to
# present them for display
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#
# $Revision: 1.16 $
# $Log: WebFetch.pm,v $
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
Popular sites need their uses to refrain from making automated
requests too often because they add up on an enormous scale
on the Internet.
Some sites such as Freshmeat prefer no shorter than hourly intervals.
Slashdot prefers no shorter than half-hourly intervals.
When in doubt, ask the site maintainers what they prefer.

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
use vars qw($VERSION @ISA @EXPORT);

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
$VERSION = '0.03';
my $debug;

# Preloaded methods go here.

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
	$self->init(@_);
	$self->fetch();
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
For more info see <a href="http://my.netscape.com/publish/">http://my.netscape.com/publish/</a>

=for text
For more info see http://my.netscape.com/publish/

=for man
For more info see http://my.netscape.com/publish/

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
	my ( $obj, $dir, $group, $mode, $export, $ns_export, $quiet,
		$url_prefix, $ns_site_title, $ns_site_link, $ns_site_desc,
		$ns_image_title, $ns_image_url );


	my $result = GetOptions (
		"dir=s" => \$dir,
		"group:s" => \$group,
		"mode:s" => \$mode, 
		"export:s" => \$export,
		"ns_export:s" => \$ns_export,
		"ns_site_title:s" => \$ns_site_title,
		"ns_site_link:s" => \$ns_site_link,
		"ns_site_desc:s" => \$ns_site_desc,
		"ns_image_title:s" => \$ns_image_title,
		"ns_image_url:s" => \$ns_image_url,
		"url_prefix:s" => \$url_prefix,
		"quiet" => \$quiet,
		"debug" => \$debug,
		( eval "defined \@".$caller_pkg."::Options" )
			? eval  "\@".$caller_pkg."::Options"
			: ());
	if ( ! $result ) {
		print STDERR "usage: $0 --dir dirpath "
			."[--group group] [--mode mode] [--export file]\n";
		print STDERR "   [--ns_export file] [--ns_site_title title] "
			."[--ns_site_link url] [--ns_site_desc text]\n";
		print STDERR "   [--ns_image_title title] "
			."[--ns_image_url url] [--url_prefix prefix]\n";
		print STDERR "[--quiet]\n";
		if ( eval "defined \$".$caller_pkg."::Usage" ) {
			print STDERR "   "
				.( eval "\$".$caller_pkg."::Usage" )."\n";
		}
		exit 1;
	}
	$debug and print STDERR "WebFetch: entered run from $caller_pkg\n";
	$obj = eval 'new '.$caller_pkg.' (
		"dir" => $dir,
		(defined $group) ? ( "group" => $group ) : (),
		(defined $mode) ? ( "mode" => $mode ) : (),
		(defined $debug) ? ( "debug" => $debug ) : (),
		(defined $export) ? ( "export" => $export ) : (),
		(defined $ns_export) ? ( "ns_export" => $ns_export ) : (),
		(defined $ns_site_title) ? ( "ns_site_title" => $ns_site_title ) : (),
		(defined $ns_site_link) ? ( "ns_site_link" => $ns_site_link ) : (),
		(defined $ns_site_desc) ? ( "ns_site_desc" => $ns_site_desc ) : (),
		(defined $ns_image_title) ? ( "ns_image_title" => $ns_image_title ) : (),
		(defined $ns_image_url) ? ( "ns_image_url" => $ns_image_url ) : (),
		(defined $url_prefix) ? ( "url_prefix" => $url_prefix ) : (),
		(defined $quiet) ? ( "quiet" => $quiet ) : (),
		)';
	if ( $@ ) {
		print STDERR "WebFetch: error: $@\n";
		exit 1;
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

Upon exit from this function, the $obj->savable array must contain
one entry for each file to be saved.
More than one array entry means more than one file to save.
The WebFetch infrastructure will save them, retaining backup copies
and setting file modes as needed.

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
		."http://www.svlug.org/sw/webfetch/";
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


=item $obj->ns_export ( $filename, $lines )

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

the file to save the WebFetch export contents to;
this will be placed in the savable record with the contents
so the save function knows were to write them

=item $lines

a reference to an array of arrays;
the outer array contains each line of the exported data;
the inner array is a list of two fields within that line
consisting of a text title string in one entry and a
URL in the second entry.

=item $site_title

For exporting to MyNetscape, this sets the name of your site.
It cannot be more than 40 characters

=item $site_link

For exporting to MyNetscape, this is the full URL MyNetscape will
use to link to your site.
It cannot be more than 500 characters.

=item $site_desc

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

=item $obj->html_gen( $filename, $format_func, $links, [ $style ] )

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

=item $style

(optional) a hash reference with style parameter names/values
that can modify the behavior of the funciton to use different HTML styles;
recognized values are

=over 4

=item para

use paragraph breaks between lines/links instead of unordered lists

=back

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

=back

=cut

# utility function to generate HTML output
sub html_gen
{
        my ( $self, $filename, $format_func, $links, $style ) = @_;
 
        # generate summary HTML links
        my $link_count=0;
        my @result;
	my $style_para = 0;
	my $style_ul = 0;
	if (( defined $style ) and ref($style) eq "HASH" ) {
		$style_para = ( defined $style->{para} ) ? $style->{para} : 0;
	}
	if ( ! $style_para ) {
		$style_ul = 1;
	}

        push @result, "<center>";
        push @result, "<table><tr><td>";
        if ( @$links >= 0 ) {
                my $entry;
                foreach $entry ( @$links ) {
                        push @result, ( $style_ul ? "<li>" : "" )
				.&$format_func(@$entry);
                        if ( ++$link_count >= $self->{num_links} ) {
                                last;
                        }
			if (( defined $self->{table_sections}) and
				$link_count == int(($self->{num_links}+1)
				/ $self->{table_sections}))
			{
				push @result, "</td>";
				push @result, "<td width=45% valign=top>";
			} else {
				$style_para and push @result, "<p>";
			}
                }
        } else {
                push @result, "<i>(There are technical difficulties with "
                        ."this information source.  "
                        ."Please check again later.)</i>";
        }
        push @result, "</td></tr></table>";
        push @result, "</center>";
 
	$self->html_savable( $filename, join("\n",@result)."\n");
}

=item $obj->html_savable( $filename, $content )

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
		."Perl5 WebFetch - do not manually edit --->\n"
		."<!--- WebFetch can be found at "
		."http://www.svlug.org/sw/webfetch/ --->\n"
		.$content
		."<!--- end text generated by "
		."Perl5 WebFetch - do not manually edit --->\n" );
}

=item $obj->raw_savable( $filename, $content )

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

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# remainder of POD docs follow

=back

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
project at C<webfetch-maint@svlug.org>.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
Send patches, bug reports, suggestions and questions to
C<webfetch-maint@svlug.org>.

WebFetch is Open Source software distributed via the
Comprehensive Perl Archive Network (CPAN),
a worldwide network of Perl web mirror sites.
WebFetch may be copied under the same terms and licensing as Perl itelf.

=for html
A current copy of the source code and documentation may be found at
<a href="http://www.svlug.org/sw/webfetch/">http://www.svlug.org/sw/webfetch/</a>

=for text
A current copy of the source code and documentation may be found at
http://www.svlug.org/sw/webfetch/

=for man
A current copy of the source code and documentation may be found at
http://www.svlug.org/sw/webfetch/

=head1 SEE ALSO

=for html
<a href="http://www.perl.org/">perl</a>(1),
<a href="WebFetch::EGAuthors.html">WebFetch::EGAuthors</a>,
<a href="WebFetch::Freshmeat.html">WebFetch::Freshmeat</a>,
<a href="WebFetch::LinuxToday.html">WebFetch::LinuxToday</a>,
<a href="WebFetch::ListSubs.html">WebFetch::ListSubs</a>,
<a href="WebFetch::SiteNews.html">WebFetch::SiteNews</a>,
<a href="WebFetch::Slashdot.html">WebFetch::Slashdot</a>,
<a href="WebFetch::YahooBiz.html">WebFetch::YahooBiz</a>.

=for text
perl(1), WebFetch::EGAuthors, WebFetch::Freshmeat, WebFetch::LinuxToday,
WebFetch::ListSubs, WebFetch::SiteNews, WebFetch::Slashdot,
WebFetch::YahooBiz.

=for man
perl(1), WebFetch::EGAuthors, WebFetch::Freshmeat, WebFetch::LinuxToday,
WebFetch::ListSubs, WebFetch::SiteNews, WebFetch::Slashdot,
WebFetch::YahooBiz.

=cut
