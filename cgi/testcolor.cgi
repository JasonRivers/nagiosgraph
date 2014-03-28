#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
# Author:  2005 (c) Soren Dossing
# Author:  2008 (c) Alan Brenner, Ithaka Harbors
# Author:  2010 (c) Matthew Wall

## no critic (ProhibitConstantPragma)

# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use ngshared;
use English qw(-no_match_vars);
use strict;
use warnings;

use constant COLS => 9;
use constant WORDS => 'losspct losswarn losscrit rta rtawarn rtacrit';

# Read the configuration to get any custom color scheme
my $errmsg = readconfig('testcolor', 'cgilogfile');
if ($errmsg ne q()) {
    htmlerror($errmsg);
    croak($errmsg);
}
my $cgi = new CGI;  ## no critic (ProhibitIndirectSyntax)
$cgi->autoEscape(0);
my $lang = $cgi->param('language') ? $cgi->param('language') : q();
$errmsg = readi18nfile($lang);
if ($errmsg ne q()) {
    debug(DBWRN, $errmsg);
}

# Suggest some commonly used keywords
my $w = $cgi->param('words') ? join q( ), $cgi->param('words') : WORDS;

print $cgi->header,
    $cgi->start_html(-id => 'nagiosgraph',
                     -title => 'nagiosgraph: ' . _('Show Colors'),
                     getstyle()) . "\n" .
    $cgi->start_form . $cgi->p(_('Enter names separated by spaces') . q(:)) .
    $cgi->textfield({name => 'words', size => '80', value => $w}) . q( ) .
    $cgi->submit .
    $cgi->hidden({name => 'language', value => $lang}) .
    $cgi->end_form . $cgi->br() . "\n" or
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
            print $cgi->td({bgcolor => "#$h", width => '20'}, '&nbsp;') or
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

testcolor.cgi - generate a table of colors to show which will be used for lines in graphs

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
an HTML page with the colors that will be used in graphs.

=head1 USAGE

B<testcolor.cgi>

In the text field, enter one or more names, separated by spaces.  A grid of
colors will be generated with one row for each of the names.  Each column
corresponds to a different color palette.

Color palette 9 is defined by a list of RGB colors in B<nagiosgraph.conf>

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

Create a custom color palette in the nagiosgraph configuration file by defining
a comma-delimited list of colors.  Here are some sample palettes.

# rainbow: reddish, orange, yellow, green, light blue, dark blue, purple, grey
colors = D05050,D08050,D0D050,50D050,50D0D0,5050D0,D050D0,505050
# light/dark pairs: blue, green, purple, orange
colors = 90d080,30a030,90c0e0,304090,ffc0ff,a050a0,ffc060,c07020
# green from light to dark
colors = 80d080,50a050,308030

=head1 DEPENDENCIES

=over 4

=item B<ngshared.pm>

This is the nagiosgraph perl library.  It contains code used by this script.

=back

=head1 INSTALLATION

Copy B<ngshared.pm> and B<nagiosgraph.conf> to a configuration directory
such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> as needed.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<nagiosgraph.conf>
B<ngshared.pm>
B<showgraph.cgi>
B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Alan Brenner, moved subroutines into a shared file (ngshared.pm), added color
number nine, and added support for showhost.cgi and showservice.cgi.

Matthew Wall, showgroup.cgi, CSS and JavaScript in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
