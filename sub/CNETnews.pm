#
# CNETnews.pm - get headlines from c|net
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::CNETnews;

use strict;
use vars qw(
  $VERSION @ISA @EXPORT @Options $alt_url $alt_file $alt_hl_re $alt_search_re
  $search_string
);

use Exporter;
use AutoLoader;
use WebFetch;
use HTML::LinkExtor;
use URI;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(fetch_main);
$alt_url = undef;
$alt_file = undef;
$alt_hl_re = undef;
$alt_search_re = undef;
$search_string = undef;
@Options = (
  "url:s" => \$alt_url,
  "file:s" => \$alt_file,
  "search:s" => \$search_string,
  "headline-regex:s" => \$alt_hl_re,
  "search-regex:s" => \$alt_search_re,
);

# configuration parameters
$WebFetch::CNETnews::filename = "cnet.html";
$WebFetch::CNETnews::num_links = 5;
$WebFetch::CNETnews::url = "http://www.news.com/";

# no user-servicable parts beyond this point

# array indices
sub entry_link { 0; }
sub entry_text { 1; }


sub fetch_main { WebFetch::run(); }

sub fetch {
  my ($self) = shift;

  # set parameters for WebFetch routines
  if ( defined $search_string ) {
	  $self->{url} = "http://www.news.com/Searching/Results/1,18,,00.html?newscomTopics=0&querystr=$search_string";
  } elsif ( defined $alt_url ) {
	  $self->{url} = $alt_url;
  } else {
	  $self->{url} = $WebFetch::CNETnews::url;
  }
  $self->{filename} = (defined $alt_file) ?
    $alt_file
  : $WebFetch::CNETnews::filename;
  $self->{num_links} = $WebFetch::CNETnews::num_links;
  my $hl_re = (defined $alt_hl_re)
  	? $alt_hl_re : 'size=\"?\+1\"?><b>(.*?)</b></font>';
  my $search_re = (defined $alt_search_re)
  	? $alt_search_re : '<font color=\"\#009933\">\&\#149\;<\/font>\&nbsp\; (<a href=.*<\/a>), [A-Za-z0-9, ]*<br>';

  # find the links
  my $content = $self->get;
  my $re = ( defined $search_string ) ? $search_re : $hl_re;
  my ( @links, @lines, $line );
  @lines = split ( /\n/, $$content );
  foreach $line ( @lines ) {
    my ( $match, $headline );
    ( $line =~ /$re/i ) or next;
    my $p = new HTML::LinkExtor;
    $p->parse($line);
    if ( $line =~ /<a.*?>(.*?)<\/a>/i) { $headline = $1; }
    foreach ($p->links()) {
      next unless (shift(@$_) eq 'a');
      my (%attr) = @$_;
      my $url = URI->new_abs($attr{'href'}, $self->{url})->as_string();
      push(@links, [ $url, $headline ]);
      last;
    }
  }

  # passback our links
  $self->html_gen($self->{filename},
  	sub { return "<a href=\"".$_[&entry_link]."\">"
		.$_[&entry_text]."</a>";},
	\@links);
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::CNETnews - download and save c|net news.com headlines or news search

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::CNETnews;>

From the command line:

C<perl C<-w> -MWebFetch::CNETnews C<-e> "&fetch_main" -- --dir I<directory> [--alt_url I<url>]  [--alt_file I<file>] [--search I<search_string>]>

=head1 DESCRIPTION

This module gets the current headlines from news.com.

The optional C<--alt_url> parameter allows you to select a different
URL to get the headlines from.

After this runs, by default the file C<cnet.html> will be created or replaced.
If there already was an C<cnet.html> file, it will be moved to C<Ocnet.html>.
These filenames can be overridden by the C<--alt_file> parameter.

If the optional C<--search> parameter is used, WebFetch::CNETnews will
search the c|net News.Com site for the search string
instead of getting the front-page headlines.

=head1 AUTHOR

WebFetch was written by Ian Kluft
for the Silicon Valley Linux User Group (SVLUG).
The WebFetch::CNETnews module was contributed by Jamie Heilman.
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
