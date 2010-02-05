#!/usr/bin/perl

# File:    $Id$
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

# Modify this script to test map entries before inserting into real
# map file. Run the script and check if the output is as expected.

use strict;
no strict 'subs'; ## no critic (ProhibitNoStrict,ProhibitProlongedStrictureOverride)
use warnings;
use Data::Dumper;

use vars qw($VERSION);
$VERSION = '2.0';

my @s;

# Insert servicesdescr, output and perfdata here as it appears in log file.
#
$_ = <<'DATA';
servicedescr:ping
output:Total RX Bytes: 4058.14 MB, Total TX Bytes: 2697.28 MB<br>Average Traffic: 3.57 kB/s (0.0%) in, 4.92 kB/s (0.0%) out| inUsage=0.0,85,98 outUsage=0.0,85,98
perfdata:
DATA

eval { ## no critic (RequireCheckingReturnValueOfEval)

# Insert here a map entry to parse the nagios plugin data above.
## no critic (RegularExpressions)
/output:.*Average Traffic.*?([.\d]+) kB.+?([.\d]+) kB/
and push @s, [ 'rxbytes',
               [ 'in',  GAUGE, $1 ],
               [ 'out', GAUGE, $2 ] ];

};

print Data::Dumper->Dump([\@s], [qw(*s)]); ## no critic (RequireCheckedSyscalls)

__END__

=head1 NAME

testentry.pl - Install nagiosgraph.

=head1 DESCRIPTION

=head1 USAGE

B<testentry.pl>

=head1 CONFIGURATION

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over 4

=item B<Nagios>

This provides the data collection system.

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org, added perldoc and other changes.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2009 Andrew W. Mellon Foundation

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
