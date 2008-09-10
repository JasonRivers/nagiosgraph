#!/usr/bin/perl

# File:    $Id$
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The ngshared.pm file must be in this directory.
use lib '/etc/nagios/nagiosgraph';

=head1 NAME

testcolor.cgi - generate a table of colors to show what color get used in graphs

=head1 SYNOPSIS

B<testcolor.cgi>

=head1 DESCRIPTION

Run this via a web server cgi to generate an HTML page of the color
configuration stored in nagiosgraph.conf.

=head1 INSTALLATION

Copy this file into Nagios' cgi directory (for the Apache web server, see where
the ScriptAlias for /nagios/cgi-bin points), and make sure it is executable by
the web server.

Install the B<ngshared.pm> file and edit this file to change the B<use lib> line
(line 10) to point to the directory containing B<ngshared.pm>.

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from Soren's by moving
the hashcolor subroutine into the shared library (ngshared.pm), ensuring that
show.cgi and this generate the same colors for the same input.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<nagiosgraph.conf> B<show.cgi> B<ngshared.pm>

=head1 COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

# Main program - change nothing below

use ngshared;

use strict;
use CGI qw/:standard/;

# Read the configuration to get any custom color scheme
readconfig('read');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	HTMLerror($Config{ngshared});
	exit;
}

# Suggest some commonly used keywords
my $w = param('words') ? join ' ', param('words') : 'response rta pctfree';

# Start each page with an input field
my @style;
@style = ( -style => {-src => "$Config{stylesheet}"} ) if ($Config{stylesheet});
print header, start_html(-id => "nagiosgraph",
	-title => "nagiosgraph: testcolor",
	@style) . "\n" .
	start_form .
	p('Type some space seperated nagiosgraph line names here:') .
	textfield({name => 'words', size => '80', value => $w}) .
	submit . end_form . br . "\n";

# Render a table of colors of all schemes for each keyword
if ( param('words') ) {
	print "<table cellpadding=0><tr><td></td>";
	print th($_) for 1..9;
	print "</tr>\n";
	for my $w ( split /\s+/, param('words') ) {
		print '<tr>' . td($w);
		for my $c ( 1..9 ) {
			my $h = hashcolor($w, $c);
			print td({bgcolor => "#$h"}, '&nbsp;');
			#print "\n  <td><table bgcolor=#000000><tr><td bgcolor=#$h>&nbsp;</td></tr></table></td>";
		}
		print "</tr>\n";
	}
	print "</table>\n";
}

# End of page
print div({-id => "footer"}, hr(),
	small( "Created by " . a({href => "http://nagiosgraph.wiki.sourceforge.net/"},
	"Nagiosgraph") . "." ));
print end_html();
