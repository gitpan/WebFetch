#
# ListSubs.pm - get headlines from ListSubs
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::ListSubs;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $listfile $outfile $title %tld );

use Exporter;
use AutoLoader;
use Carp;
use WebFetch;
use Locale::Country;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main );
@Options = (
	"list=s" => \$listfile,
	"out=s" => \$outfile,
	"title:s" => \$title
);
$Usage = "--list mail-list-file --out output-file";

# country aliasing needed for Locale::Country
# (This basically lists the deviations from ISO 3166 in the country TLDs)
Locale::Country::_alias_code('uk' => 'gb');

# no user-servicable parts beyond this point

# top-level domains (excluding countries)
%tld = (
        "com" => "Commercial Organization",
        "org" => "Non-profit Organization",
        "net" => "Network Provider",
        "edu" => "Educational Institution",
        "gov" => "US Government",
        "mil" => "US Military",
        "int" => "International Treaty Organization"
);

# array indices
sub entry_domain { 0; }
sub entry_total { 1; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# get the list of addresses
	if ( ! open LISTFILE, "$listfile" ) {
		croak "WebFetch::ListSubs: could not open $listfile: $!\n";
	}
	my @content = (<LISTFILE>);  # gulp the file
	close LISTFILE;

	# find all the addresses in the list 
	my ( @content_lines, %found );
	my $total = 0;
	foreach ( @content ) {
		chop;
		/^\s*#/ and next;       # skip comments
		/^\s*$/ and next;       # skip blank lines
		s/\s*#.*//;             # strip comments from lines with content
		/\./ or next;           # no dots?  no domains!
		s/\s*$//;               # strip trailing spaces
		s/^\s*//;               # strip leading spaces
	 
		# by this point, now we have an e-mail address
		s/^.*\.//;              # strip everything but top-level domain
		tr/[A-Z]/[a-z]/;        # shove into lower case
		if ( defined $found{$_}) {
			$found{$_}++;
		} else {
			$found{$_} = 1;
		}
		$total++;
	}

	# generate HTML summary table and store
	my ( $key, @listsubs_text, @listsubs_export );
        push @listsubs_text, "<table border=2>";
        if ( defined $title ) {
                push @listsubs_text, "<tr><th colspan=3 align=center>"
			."$title</th></tr>";
        }
        push @listsubs_text, "<tr><td>$total</td><td colspan=2>Total</a></tr>";
	foreach $key ( sort {
			# sort by number of subscriptions and domain name
			( $found{$b} != $found{$a} )
				? ( $found{$b} <=> $found{$a} )
				: ( $a cmp $b )
		} keys %found )
	{
		push @listsubs_text, "<tr>";
		push @listsubs_text, "<td>".$found{$key}."</td>";
		push @listsubs_text, "<td>".$key."</td>";
		push @listsubs_text, "<td>".get_tld($key)."</td>";
		push @listsubs_text, "</tr>";
		push @listsubs_export, [ $found{$key}, $key, get_tld($key) ];
	}
        push @listsubs_text, "</table>";
	$self->html_savable( $outfile, join("\n",@listsubs_text)."\n" );

        # export content if --export was specified
        if ( defined $self->{export}) {
                $self->wf_export( $self->{export},
                        [ "total", "domain", "description" ],
                        \@listsubs_export,
                        "Exported from WebFetch::ListSubs\n"
                                ."\"total\" is number of subscribers\n"
                                ."\"domain\" is the domain name\n"
                                ."\"description\" is the domain description" );
        }
}

# look up description from top-level domain name
sub get_tld
{
	my ( $domain ) = @_;
	my ( $name );

	# check for generic top-level domain names
	if ( defined $tld{$domain}) {
		return $tld{$domain};

	# check for ISO 3166 country codes
	} elsif ( $name = code2country($domain)) {
		return $name;

	# otherwise give up
	} else {
		return "(not recognized)";
	}
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::ListSubs - summarize mail list subscriptions

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::ListSubs;>

From the command line:

C<perl C<-w> -MWebFetch::ListSubs C<-e> "&fetch_main" -- --dir I<directory>
   --list I<mail-list-file> --out I<output-file> [--title I<table-title>]>

=head1 DESCRIPTION

This module gets the current subscriptions from a mail list file
(used by a mail list server on the same machine) and summarizes the
subscriptions by top-level domain.
The mail list file is in a format used by Majordomo, SmartList,
Smail, Exim and many others - one address per line.
Comments (beginning with "#") and blank lines are allowed but ignored.

The contents of the mail list are read from the file named in the
C<--list> parameter.
The summary as an HTML table is written to the file named by
the C<--out> parameter.
The optional C<--title> parameter may be used to put a title on the
HTML table produced by this fetch operation.

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
