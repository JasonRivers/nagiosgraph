#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010
#
# NAME
# insert.pl - Store performance data returned by Nagios plugins using rrdtool.
#
# USAGE
# There are two standard processing configurations: batch and immediate.
#
# Batch Mode
# Nagios periodically invokes insert.pl.  Data are extracted from the Nagios
# perflog file.
#
# Immediate Mode
# Nagios invokes insert.pl on each service check.  Data are extracted from the
# command line.
#
# CONFIGURATION
# The nagiosgraph.conf file controls the behavior of this script.
#
# DIAGNOSTICS
# Use the debug_insert setting in nagiosgraph.conf to control the amount of
# logging information that will be emitted by this script.  Output will go
# to the nagiosgraph log file.


# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use ngshared;
use strict;
use warnings;

use constant MINPOLL => 30;    ## no critic (ProhibitConstantPragma)

use vars qw($VERSION);
$VERSION = '2.0.1';

my $errmsg = readconfig('insert');
if ( $errmsg ne q() ) { croak $errmsg; }
debug( DBDEB, 'insert.pl processing started' );
$errmsg = checkrrddir('write');
if ( $errmsg ne q() ) { croak $errmsg; }

# Read the map file and define a subroutine that parses performance data
getrules( $Config{mapfile} ) and exit;

if ( $ARGV[0] ) {
    processdata( $ARGV[0] );
}
elsif ( defined $Config{perfloop} && $Config{perfloop} > 0 ) {
    my $poll = ( $Config{perfloop} < MINPOLL ) ? MINPOLL : $Config{perfloop};
    debug( DBINF, 'insert.pl using poll interval of ' . $poll . ' seconds' );
    while (1) {
        my @perfdata = readperfdata( $Config{perflog} );
        if (@perfdata) { processdata(@perfdata); }
        debug( DBDEB, 'insert.pl waiting for input' );
        sleep $poll;
    }
}
else {
    my @perfdata = readperfdata( $Config{perflog} );
    if (@perfdata) { processdata(@perfdata); }
}

debug( DBDEB, 'insert.pl processing complete' );
