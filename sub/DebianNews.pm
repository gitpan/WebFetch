#
# DebianNews.pm - get news headlines from the Debian organization.
#
# Copyright (c) 1999 Chuck Ritter (critter@roadport.com).
# All rights reserved. This program is free software;
# you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::DebianNews;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options );

use Exporter;
use AutoLoader;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);
#@Options = ();   # No command-line options added by this module

# configuration parameters
$WebFetch::DebianNews::filename = "debiannews.html";
$WebFetch::DebianNews::num_links = 8;
$WebFetch::DebianNews::table_sections = 1;
$WebFetch::DebianNews::url = "http://www.debian.org/News/";

# no user-servicable parts beyond this point

# array indices
sub entry_text { 0; }
sub entry_date { 1; }
sub entry_link { 2; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::DebianNews::url;
	$self->{num_links} = $WebFetch::DebianNews::num_links;
	$self->{table_sections} = $WebFetch::DebianNews::table_sections;

	# process the links
	my $content = $self->get;
	my ( @content_links, @lines );
	@lines = split ( /\n/, $$content );

	foreach (@lines) {
		if ($_ =~ /<tt>\[(.*?)\]<\/tt>\s*<strong>?<a href=\"?([^\"\>]*?)"?>(.+?)<\/a>/ ) {
			my $link = $self->{url}."/".$2;
			my $date = $1;
			my $text = $3;
			push @content_links, [ $text, $date, $link ];
		}
	}
	
	$self->html_gen( $WebFetch::DebianNews::filename,
		sub { return "<a href=\"".$_[&entry_link]."\">"
			.$_[&entry_text]
			."</a> (".$_[&entry_date].")"; },
		\@content_links );

	# export content if --export was specified
	if ( defined $self->{export}) {
		$self->wf_export( $self->{export},
			[ "title", "date", "url" ],
			\@content_links,
			"Exported from WebFetch::DebianNews\n"
				."\"title\" is article title\n"
				."\"date\" is the date stamp\n"
				."\"url\" is article URL" );
	}
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::DebianNews - download and save Debian News headlines

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::DebianNews>

>From the command line:

C<perl -w -MWebFetch::DebianNews -e "&fetch_main" -- --dir directory>

=head1 DESCRIPTION

This module gets the current headlines from the Debian Linux organization.

After this runs, the file C<debiannews.html> will be created or replaced.
If there already was an C<debiannews.html> file, it will be moved to
C<Odebiannews.html>.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
The WebFetch::DebianNews module was written by Chuck Ritter.
Send patches or maintenance requests for this module to
C<critter@roadport.com>.
Send general patches, bug reports, suggestions and questions to
C<maint@webfetch.org>.

=head1 SEE ALSO

=for html
<a href="WebFetch.html">WebFetch</a>

=for text
WebFetch

=for man
WebFetch

=cut

