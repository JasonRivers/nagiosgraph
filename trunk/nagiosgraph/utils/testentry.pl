#!/usr/bin/perl

# File:    $Id: testentry.pl,v 1.4 2005/10/08 05:55:08 sauber Stab $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

# Modify this script to test map entries before inserting into real
# map file. Run the script and check if the output is as expected.

use strict;
no strict "subs";
use Data::Dumper;
my @s;

# Insert servicesdescr, output and perfdata here as it appears in log file.
#
$_ = <<DATA;
servicedescr:ping
output:Total RX Bytes: 4058.14 MB, Total TX Bytes: 2697.28 MB<br>Average Traffic: 3.57 kB/s (0.0%) in, 4.92 kB/s (0.0%) out| inUsage=0.0,85,98 outUsage=0.0,85,98
perfdata:
DATA

eval {

# Insert here a map entry to parse the nagios plugin data above.
#
/output:.*Average Traffic.*?([.\d]+) kB.+?([.\d]+) kB/
and push @s, [ rxbytes,
               [ in,  GAUGE, $1 ],
               [ out, GAUGE, $2 ] ];

};

print Data::Dumper->Dump([\@s], [qw(*s)]);
