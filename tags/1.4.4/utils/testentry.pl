#!/usr/bin/perl

# $Id$
# File:    $Id$
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

# Modify this script to test map entries before inserting into real
# map file. Run the script and check if the output is as expected.

## no critic (ProhibitNoStrict,ProhibitProlongedStrictureOverride)
## no critic (RequireCheckingReturnValueOfEval)
## no critic (RegularExpressions)
## no critic (RequireCheckedSyscalls)

use strict;
no strict 'subs';
use warnings;
use Data::Dumper;

use vars qw($VERSION);
$VERSION = '2.0';

my @s;

# Insert here the servicesdesc, output, and perfdata from the nagios plugin.
$_ = <<'DATA';
servicedesc:ping
output:Total RX Bytes: 4058.14 MB, Total TX Bytes: 2697.28 MB<br>Average Traffic: 3.57 kB/s (0.0%) in, 4.92 kB/s (0.0%) out| inUsage=0.0,85,98 outUsage=0.0,85,98
perfdata:
DATA

eval {

# Insert here a map entry to parse the nagios plugin data above.
/output:.*Average Traffic.*?([.\d]+) kB.+?([.\d]+) kB/
and push @s, [ 'rxbytes',
               [ 'in',  GAUGE, $1 ],
               [ 'out', GAUGE, $2 ] ];

};

print Data::Dumper->Dump( [\@s], [qw(*s)] );

__END__

=head1 NAME

testentry.pl - manually test individual map entries

=head1 DESCRIPTION

=head1 USAGE

Edit this file to include output from the Nagios perflog and the map rule that is to be tested.  Then run it.

B<testentry.pl>

=head1 CONFIGURATION

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2009 Andrew W. Mellon Foundation

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
