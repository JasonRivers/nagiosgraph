#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The configuration file and ngshared.pm must be in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.
use lib '/opt/nagiosgraph/etc';


# Main program - change nothing below

use ngshared;
use RRDs;
use strict;
use warnings;

use constant SLEEP => 30;    ## no critic (ProhibitConstantPragma)

use vars qw($VERSION);
$VERSION = '2.0';

my $errmsg = readconfig();
if ( $errmsg ne q() ) { croak $errmsg; }
initlog('insert');
$errmsg = checkrrddir('write');
if ( $errmsg ne q() ) { croak $errmsg; }

# Read the map file and define a subroutine that parses performance data
getrules( $Config{mapfile} ) and exit;

if ( $Config{perfloop} ) {
    while (1) {    # check the file every 30 seconds and load data
        my @perfdata = inputdata();
        if (@perfdata) { processdata(@perfdata); }
        debug( DBDEB, 'insert.pl waiting for more input' );
        sleep SLEEP;
    }
} else {           # run once with the line at $ARGV[0]
    my @perfdata = inputdata();
    if (@perfdata) { processdata(@perfdata); }
}

debug( DBDEB, 'insert.pl exited' );

__END__

=head1 NAME

insert.pl - Store performance data returned by Nagios plugins using rrdtool.

=head1 DESCRIPTION

Run this via Nagios.  insert.sh might be required on some platforms.

=head1 USAGE

B<insert.pl "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$">

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_insert setting from B<nagiosgraph.conf> to control the amount
of debug information that will be emitted by this script.  Debug output will
go to the nagiosgraph log file.

=head1 DEPENDENCIES

=over 4

=item B<Nagios>

This provides the data collection system.

=item B<rrdtool>

This provides the data storage and graphing system.

=item B<RRDs>

This provides the perl interface to rrdtool.

=back

=head1 INSTALLATION

Copy B<ngshared.pm> and B<nagiosgraph.conf> to a configuration directory
such as /etc/nagiosgraph.

Copy this file to an executable directory such as /usr/local/nagiosgraph/bin.
Make sure this file is executable by Nagios.

Modify the B<use lib> line to point to the configuration directory.

Edit B<nagiosgraph.conf> as needed.

These steps describe the basic, run for every data event configuration. See the
INSTALL file for the long running process confiugration.

In the Nagios configuration set

=over 4

process_performance_data=1

=back

and

=over 4

service_perfdata_command=process-service-perfdata

=back

and create a command like:

=over 4

=begin text

  define command {
    command_name process-service-perfdata
    command_line /usr/local/lib/nagios/insert.pl "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$"
  }

=end text

=back

Other configurations may be possible, but this works for me (Alan Brenner) with
Nagios 2.12 on Mac OS 10.5.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this simple and tested.

=head1 SEE ALSO

B<nagiosgraph.conf> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving all subroutines into a
shared file (ngshared.pm) for unit testing and sharing code, tweaking logging,
etc.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
