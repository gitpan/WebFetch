#
# 32BitsOnline.pm - get headlines from 32BitsOnline
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::32BitsOnline;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $features );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );
@Options = ( "features" => \$features );
$Usage = "[--features]";

# configuration parameters
$WebFetch::32BitsOnline::feature_filename = "32bitsonline_feature.html";
$WebFetch::32BitsOnline::news_filename = "32bitsonline_news.html";
$WebFetch::32BitsOnline::num_links = 5;
$WebFetch::32BitsOnline::news_url = "http://www.32bitsonline.com/latest_news.txt";
$WebFetch::32BitsOnline::feature_url = "http://www.32bitsonline.com/latest_feature.txt";

# no user-servicable parts beyond this point

# array indices
sub entry_title { 0; }
sub entry_link { 1; }
sub entry_date { 2; }
sub entry_summary { 3; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	if ( $features ) {
		$self->{url} = $WebFetch::32BitsOnline::feature_url;
		$self->{filename} = $WebFetch::32BitsOnline::feature_filename;
	} else {
		$self->{url} = $WebFetch::32BitsOnline::news_url;
		$self->{filename} = $WebFetch::32BitsOnline::news_filename;
	}
	$self->{num_links} = $WebFetch::32BitsOnline::num_links;

	# process the links
	my $content = $self->get;
	my @lines = split ( /\n/, $$content );

	# split up the response into each of its subjects
	my ( $line, @content_links );
	for ( $line = 0; $line <= $#lines; $line += ( $features ? 4 : 2 )) {
		if ( $features ) {
			push ( @content_links, [ $lines[$line],
				$lines[$line+2], $lines[$line+1],
				$lines[$line+3]]);
		} else {
			push ( @content_links, [ @lines[$line..$line+1 ]]);
		}
	}
        $self->html_gen( $self->{filename},
			sub { return "<a href=\"".$_[&entry_link]."\">"
				.$_[&entry_title]."</a>"
				.( $features ? "<br>".$_[&entry_summary]."<p>"
				: "" ); },
                \@content_links );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "title", "url",
				$features ? ( "date", "summary" ) : () ],
                        \@content_links,
                        "Exported from WebFetch::32BitsOnline\n"
                                ."\"title\" is article title\n"
                                ."\"url\" is article URL\n"
				.( $features
					?  "\"date\" is timestamp"
					."\"summary\" is a text summary"
					: "" ));
        }
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::32BitsOnline - download and save 32BitsOnline headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::32BitsOnline;>

From the command line:

C<perl C<-w> -MWebFetch::32BitsOnline C<-e> "&fetch_main" -- --dir I<directory>
	[--features] >

=head1 DESCRIPTION

This module gets the current headlines from 32BitsOnline.

After this runs, the file C<32bitsonline.html> will be created or replaced.
If there already was an C<32bitsonline.html> file, it will be moved to
C<O32bitsonline.html>.

By default, I<WebFetch::32BitsOnlin> fetches the news headlines from
32BitsOnline.
If the optional C<--features> parameter is used, it will fetch the
latest feature articles from 32BitsOnline instead.

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
