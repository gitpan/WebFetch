#
# General.pm - get news via WebFetch general export format
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::General;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $filename $url $format );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );
@Options = ( "file=s" => \$filename,
	"url=s" => \$url,
	"format:s" => \$format );
$Usage = "--file output-filename --url source-url [--format format]";

# configuration parameters
$WebFetch::General::num_links = 5;
$WebFetch::General::default_format = "<a href=\"%url%\">%text%</a>";

# no user-servicable parts beyond this point

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::General::url;
	$self->{num_links} = $WebFetch::General::num_links;
	if ( defined $format ) {
		$self->{"format"} = $format;
	} else {
		$self->{"format"} = $WebFetch::General::default_format;
	}

	# process the links
	my $content = $self->get;
	my @content = split /\r{0,1}\n/, $$content;
	my $first = shift @content;
	if ( $first ne "[WebFetch export]" ) {
		print STDERR "WebFetch::General: unexpected $first\n";
		die "WebFetch::General: input file not exported by WebFetch\n";
	}
	my ( $i, $state, $current, $prev_attr, @parts );
	$current = {};
	$prev_attr = undef;
	for ( $i=0; $i <= $#content; $i++ ) {
		my $line = $content[$i];
		$line =~ /^\s*#/ and next;	# skip comments
		while ( $line =~ /\\$/ ) {
			$line =~ s/\\$//;
			$line .= $content[++$i];
			$line =~ s/\#.*//;
		}

		if ( keys %$current and $line =~ /^\s*$/ ) {
			push @parts, $current;
			$current = {};
			$prev_attr = undef;
		} elsif ( $line =~ /^([^:\s]+):\s*(.*)/ ) {
			$current->{$1}=$2;
		}
	}
	my $global = shift @parts;	# first "part" is global settings

	# split up the response into each of its subjects
	my ( $part, @content_links );
	my @fields = ( $self->{"format"} =~ /%([^%]*)%/ );
	foreach $part ( @parts ) {
		my ( $fname, $subparts );
		$subparts= [];
		foreach $fname ( @fields ) {
			push @$subparts, "".((defined $part->{$fname})
				? $part->{$fname} : "" );
		}
		push ( @content_links, $subparts);
	}
        $self->html_gen( $WebFetch::General::filename,
                sub { $self->wf_format(@_); },
                \@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ @fields ],
                        \@content_links,
                        "Exported from WebFetch::General\n" );
        }
}

sub wf_format
{
	my ( $self, @subparts ) = @_;
	my $text = $self->{"format"};

	while ( $text =~ /^([^%]*)%([^%]*)%(.*)/ ) {
		$text = $1.($subparts[0]).$3;
		shift @subparts;
	}
	return $text;
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::General - download and save General headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::General;>

From the command line:

C<perl C<-w> -MWebFetch::General C<-e> "&fetch_main" -- --dir I<directory>
   --file I<output-filename> --url I<source-url> [--format I<format>]>

=head1 DESCRIPTION

This module gets the current headlines from any WebFetch site that
exports its news with the "WebFetch Export" format.
You can do this with the --export command-line parameter.
It works for any WebFetch module that defines the I<export()> function,
which includes all the modules that come packaged with WebFetch.

The webmaster of a remote site only needs to arrange for a cron job to
update a WebFetch Export file, and let others know the URL to reach
that file.
(On the exporting site, it is most likely they'll use
WebFetch::SiteNews to export their own news.)
Then you can use the WebFetch::General module to read the
remote file and generate and HTML summary of the news.

After WebFetch::General runs,
the file specified in the --file parameter will be created or replaced.
If there already was a file by that name, it will be moved to
a filename with "O" (for old) prepended to the file name.

=head1 FORMAT STRINGS

WebFetch::General uses a format string to generate HTML from the
incoming data.
The default format for retrieved data is

<a href="%url%">%text%</a>

This means that fields named "url" and "text" must exist in the incoming
WebFetch-exported data, and will be used to fill in the I<%url%> and
I<%text%> strings, respectively.
You may use the --format parameter to specify any format you wish.
But the field names you choose in the format must match fields defined
in the input stream.
Otherwise they will fail to be expanded.

=head1 THE "WebFetch Export" FILE FORMAT

This is an example WebFetch Export file generated by WebFetch::SiteNews:

    [WebFetch export]
    Version: 0.02
    # This was generated by the Perl5 WebFetch module.
    # WebFetch info can be found at http://www.svlug.org/sw/webfetch/
    #
    # Exported from WebFetch::SiteNews
    # "date" is the date of the news
    # "title" is a one-liner title
    # "url" is url to the news source
    # "text" is the news text

    date: March 21, 1999
    title: WebFetch 0.03 beta released
    url: http://www.svlug.org/sw/webfetch/news.shtml#19990321-000
    text:   &<;a href="WebFetch-0.03.tar.Z"&>;WebFetch 0.03 beta&<;/a&>; released

    date: January 11, 1999
    title: WebFetch 0.01 beta released
    url: http://www.svlug.org/sw/webfetch/news.shtml#19990111-000
    text:   &<;a href="WebFetch-0.01.tar.Z"&>;WebFetch 0.01 beta&<;/a&>; released

Each news item is separated by a blank line.

Within each news item, the fields use a "name: value" format,
similar to RFC822 headers (i.e. as in e-mail and news.)

The names of the fields are chosen by the exporting module.
Though for the convenience of the user,
the author of an exporting module should keep in mind the
default WebFetch::General format uses fields called "url" and "text".
If you use fields by different names, warn your receiving users
that they will need to make a format to use with WebFetch::General,
though you may provide them with one in their setup instructions.

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
