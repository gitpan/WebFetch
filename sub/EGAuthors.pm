#
# EGAuthors.pm - get a list of top mail-list authors from eGroups
#
# Copyright (c) 1998,1999 Ian Kluft. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the
# same terms as Perl itself.
#

package WebFetch::EGAuthors;

use strict;
use vars qw($VERSION @ISA @EXPORT @Options $Usage $listname $aliasfile );

use Exporter;
use AutoLoader;
use Carp;
use WebFetch;;

@ISA = qw(Exporter AutoLoader WebFetch);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw( fetch_main

);
@Options = (
	"list=s" => \$listname,
	"aliases:s" => \$aliasfile
	);
$Usage = "--list list-name [--aliases alias-file]";

# configuration parameters
$WebFetch::EGAuthors::filename = "eg-authors.html";
$WebFetch::EGAuthors::num_links = 5;
$WebFetch::EGAuthors::url = "http://www.egroups.com/group/";

# the search portion of the URL needs to be saved to run after
# command-line processing
$WebFetch::EGAuthors::search = sub {
	$listname."/info.html?method=showtopauthors";
};


# no user-servicable parts beyond this point

# array indices
sub entry_name { 0; }
sub entry_total { 1; }

sub fetch_main { WebFetch::run(); }

sub fetch
{
	my ( $self ) = @_;

	# set parameters for WebFetch routines
	$self->{url} = $WebFetch::EGAuthors::url
		.&$WebFetch::EGAuthors::search();

	# get the aliases table, if any
	my ( %aliases );
	if ( defined $aliasfile ) {
		if ( ! open ALIASFILE, $aliasfile ) {
			croak "WebFetch::EGAuthors: failed to open "
				."$aliasfile: $!\n";
		}
		while ( <ALIASFILE> ) {
			chop;
			/^\s*$/ and next;	# ignore blank lines
			/^\s*#/ and next;	# ignore comments
			if ( /^(.*)\s*==\s*(.*)$/ ) {
				my ( $alias, $real ) = ( $1, $2 );
				$real =~ s/^\s*//;
				$alias =~ s/^\s*//;
				$real =~ s/\s*$//;
				$alias =~ s/\s*$//;
				$aliases{$alias} = $real;
			}
		}
		close ALIASFILE;
		if ( $self->{debug}) {
			print STDERR "debug: read ".int(keys %aliases)
				." aliases\n";
		}
	}

	# process the input lines
	my $content = $self->get;
	my @lines = split ( '\n', $$content );
	my ( %authors, $line, $state );
	if ( $self->{debug}) {
		print STDERR "debug: got ".($#lines+1)." lines from "
			.length($content)." characters\n";
	}
	$state = 0;
	for ( $line = 0; $line <= $#lines; $line++ ) {
		my ( $name, $value );

		# skip to the table
		if ( $state == 0 ) {
			if ( $lines[$line] =~ /^<font .*posts/ ) {
				$state = 1
			}
			next;
		}

	 	# detect end of table
		if ( $lines[$line] =~ /<\/table>/ ) {
			last;
		}
	 
		# find each table row
		if ( $lines[$line] !~ /^<tr>$/ ) {
			next;
		}

		# decode the row
		$name = $lines[$line+1];
		$name =~ s/<[^>]*>//g;
		$value = $lines[$line+3];
		$value =~ s/<[^>]*>//g;
		$line += 4;
	 
		if ( defined $aliases{$name}) {
			$name = $aliases{$name};
		}
	 
		my ( $key ) = lc $name;
		if ( defined $authors{$key}) {
			$authors{$key}[1] += $value;
		} else {
			$authors{$key} = [ $name, $value ];
		}
	}
	if ( $self->{debug}) {
		print STDERR "debug: identified ".int(keys %authors)
			." authors\n";
	}

	# generate HTML
	my ( $author, @authors_text, @authors_export );
	push @authors_text, "<table>";
	foreach $author ( sort { $authors{$b}[1] <=> $authors{$a}[1] }
		keys %authors )
	{
		push @authors_text, "<tr>";
		push @authors_text, "<td>".$authors{$author}[1]."</td>";
		push @authors_text, "<td>".$authors{$author}[0]."</td>";
		push @authors_text, "</tr>";
		push @authors_export, $authors{$author};
	}
	push @authors_text, "</table>";
	$self->html_savable( $WebFetch::EGAuthors::filename,
		join("\n",@authors_text)."\n" );

	# export content if --export was specified
	if ( defined $self->{export}) {
		$self->wf_export( $self->{export},
			[ "name", "total" ],
			\@authors_export,
			"Exported from WebFetch::EGAuthors\n"
				."\"name\" is author name\n"
				."\"total\" is number of messages" );
	}
}

1;
__END__
# POD docs follow

=head1 NAME

WebFetch::EGAuthors - download a list of top mail-list authors from eGroups

=head1 SYNOPSIS

In perl scripts:

C<use WebFetch::EGAuthors;>

From the command line:

C<perl C<-w> -MWebFetch::EGAuthors C<-e> "&fetch_main" -- --dir I<directory>
    --list I<list-name> [--aliases I<alias-file>]>

=head1 DESCRIPTION

This module gets a list of top mail-list authors from eGroups.

After this runs, the file C<eg-authors.html> will be created or replaced.
If there already was an C<eg-authors.html> file, it will be moved to
C<Oeg-authors.html>.

The C<--list> parameter names ther eGroups list that you want a top-authors
list for.

The optional C<--aliases> parameter names a local file with aliases 
for names found on the list.
The reason for this aliasing capability is because sometimes users
use nicknames, a plain e-mail address
or different versions of their name from different accounts,
or may change them over time.
Since a site posting one of these
top-authors lists for its own users usually knows who the people are,
this allows the maintainer to put different totals for the same person
into one sum.
The format of the aliases file is as follows:

C<  alias-name == real-name>

Comment lines may begin with a hash "#" and will be ignored.

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
