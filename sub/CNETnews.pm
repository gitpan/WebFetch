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
  if ( !defined $self->{url}) {
	  if ( defined $search_string ) {
		  $self->{url} = "http://news.cnet.com/news/search/results/1,10199,,00.html?qt=$search_string";
	  } elsif ( defined $alt_url ) {
		  $self->{url} = $alt_url;
	  } else {
		  $self->{url} = $WebFetch::CNETnews::url;
	  }
  }
  if ( ! defined $self->{filename}) {
	  $self->{filename} = (defined $alt_file)
	  ? $alt_file
	  : $WebFetch::CNETnews::filename;
  }
  if ( ! defined $self->{num_links}) {
	  $self->{num_links} = $WebFetch::CNETnews::num_links;
  }
  my $hl_re = (defined $alt_hl_re)
  	? $alt_hl_re
	: 'size=[\"\']?\+1[\"\']?><b><p>.*?</b></font>';
  my $search_re = (defined $alt_search_re)
  	? $alt_search_re
	: '<font color=[\"]?\#009933[\"]?>\&\#149\;<\/font>.*?<br>';

  # set up Webfetch Embedding API data
  $self->{data} = {}; 
  $self->{actions} = {}; 
  $self->{data}{fields} = [ "title", "url" ];
  # defined which fields match to which "well-known field names"
  $self->{data}{wk_names} = {
    "title" => "title",
    "url" => "url",
  };
  $self->{data}{records} = [];

  # find the links
  my $content = $self->get;
  my $re = ( defined $search_string ) ? $search_re : $hl_re;
  my ( @lines, $line, @links, $link );
  @lines = split ( /\n/, $$content );
  foreach $line ( @lines ) {
    my ( $match, $headline );
    ( $line =~ /$re/i ) or next;
    @links = ( $line =~ /($re)/ig );
    my $p = new HTML::LinkExtor;
    foreach $link ( @links ) {
      $p->parse($link);
      if ( $link =~ /<a.*?>(.*?)<\/a>/i) { $headline = $1; }
      foreach ($p->links()) {
        next unless (shift(@$_) eq 'a');
        my (%attr) = @$_;
        my $url = URI->new_abs($attr{'href'}, $self->{url})->as_string();
        push( @{$self->{data}{records}}, [ $headline, $url ]);
        last;
      }
    }
  }

  # create the HTML actions list
  $self->{actions}{html} = [];
  my $params = {};
  $params->{format_func} = sub {
    # generate HTML text
    my $url_fnum = $self->fname2fnum("url");
    my $title_fnum = $self->fname2fnum("title");
    return "<a href=\"".$_[$url_fnum]."\">".$_[$title_fnum]."</a>";
  };

  # put parameters for fmt_handler_html() on the html list
  push @{$self->{actions}{html}}, [ $self->{filename}, $params ];
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

C<perl -w -MWebFetch::CNETnews -e "&fetch_main" -- --dir directory [--alt_url url]  [--alt_file file] [--search search_string]>

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
C<maint@webfetch.org>.

=head1 SEE ALSO

=for html
<a href="WebFetch.html">WebFetch</a>

=for text
WebFetch

=for man
WebFetch

=cut
