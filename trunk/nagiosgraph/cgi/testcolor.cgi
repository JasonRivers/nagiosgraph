#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  2005 (c) Soren Dossing
# Author:  2008 (c) Alan Brenner, Ithaka Harbors
# Author:  2010 (c) Matthew Wall

# The configuration file and ngshared.pm must be in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.
use lib '/opt/nagiosgraph/etc';


# Main program - change nothing below

use ngshared;
use English qw(-no_match_vars);
use strict;
use warnings;

use constant COLS => 9; ## no critic (ProhibitConstantPragma)

# Read the configuration to get any custom color scheme
readconfig('read');
if (defined $Config{ngshared}) {
    debug(DBCRT, $Config{ngshared});
    htmlerror($Config{ngshared});
    exit;
}

# See if we have custom debug level
getdebug('testcolor');

my $cgi = new CGI;  ## no critic (ProhibitIndirectSyntax)
$cgi->autoEscape(0);

# Suggest some commonly used keywords
my $w = $cgi->param('words')
    ? join q( ), $cgi->param('words') : 'response rta pctfree';

# Start each page with an input field
my @style;
if ($Config{stylesheet}) {
    @style = ( -style => {-src => "$Config{stylesheet}"} );
}
print $cgi->header,
    $cgi->start_html(-id => 'nagiosgraph',
                     -title => 'nagiosgraph: ' . trans('testcolor'),
                     @style) . "\n" .
    $cgi->start_form . $cgi->p(trans('typesome') . q(:)) .
    $cgi->textfield({name => 'words', size => '80', value => $w}) . q( ) .
    $cgi->submit . $cgi->end_form . $cgi->br() . "\n" or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

# Render a table of colors of all schemes for each keyword
if ( $cgi->param('words') ) {
    print '<table cellpadding=0><tr><td></td>' or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    for my $ii (1..COLS) {
        print $cgi->th($ii) or
            debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    }
    print "</tr>\n" or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    for my $w ( split /\s+/, $cgi->param('words') ) { ## no critic (RegularExpressions)
        print '<tr>' . $cgi->td( { -align => 'right' }, $w) or
            debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
        for my $c (1..COLS) {
            my $h = hashcolor($w, $c);
            print $cgi->td({bgcolor => "#$h"}, '&nbsp;') or
                debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
        }
        print "</tr>\n" or
            debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    }
    print "</table>\n" or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printfooter($cgi) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

__END__

=head1 NAME

testcolor.cgi - generate a table of colors to show what colors will be used for lines in graphs

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
an HTML page with the colors that will be used in graphs.

=head1 USAGE

B<testcolor.cgi>

In the text field, enter one or more names, separated by spaces.  A grid of
colors will be generated with one row for each of the names.  Each column
corresponds to a different color palette.

Color palette 9 is defined by a list of RGB colors in B<nagiosgraph.conf>

=head1 CONFIGURATION

Create a custom color palette in the nagiosgraph configuration file by creating
a comma-delimited list of colors.  Here are some sample palettes.

# rainbow: reddish, orange, yellow, green, light blue, dark blue, purple, grey
colors = D05050,D08050,D0D050,50D050,50D0D0,5050D0,D050D0,505050
# light/dark pairs: blue, green, purple, orange
colors = 90d080,30a030,90c0e0,304090,ffc0ff,a050a0,ffc060,c07020
# green from light to dark
colors = 80d080,50a050,308030

=head1 INSTALLATION

Copy this file into Nagios' cgi directory (for the Apache web server, see where
the ScriptAlias for /nagios/cgi-bin points), and make sure it is executable by
the web server.

Install the B<ngshared.pm> file and edit this file to change the B<use lib>
line to point to the directory containing B<ngshared.pm>.

=head1 SEE ALSO

B<nagiosgraph.conf> B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), using showgraph.cgi, and adding links for show.cgi
and showservice.cgi.

Matthew Wall, added features, bug fixes and refactoring in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the OSI Artistic License:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.
