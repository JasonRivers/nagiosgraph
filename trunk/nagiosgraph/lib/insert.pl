#!/usr/bin/perl

# File:		$Id: insert.pl,v 1.25 2007/06/12 19:00:06 toriniasty Stab $
# Author:	(c) Soren Dossing, 2005
# License:	OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';

=head1 NAME

insert.pl - Store performance data returned by Nagios plugins in rrdtool.

=head1 SYNOPSIS

B<insert.pl "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$">

=head1 DESCRIPTION

Run this via Nagios (using insert.sh, if needed).

=head1 REQUIREMENTS

=over 4

=item B<Nagios>

This provides the data collection system.

=item B<rrdtool>

This provides the data storage and graphing system.

=back

=head1 INSTALLATION

Copy this file someplace, and make sure it is executable by Nagios.

Install the B<ngshared.pm> file and edit this file to change the B<use lib> line
(line 10) to point to the directory containing B<ngshared.pm>.

Create or edit the example B<nagiosgraph.conf>, which must reside in the same
directory as B<ngshared.pm>.

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

define command {
 command_name process-service-perfdata
 command_line /usr/local/lib/nagios/insert.pl "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$"
}

=back

Other configurations may be possible, but this works for me (Alan Brenner) with
Nagios 2.12 on Mac OS 10.5.

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving all subroutines into a
shared file (ngshared.pm) for unit testing and sharing code, tweaking logging,
etc.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<nagiosgraph.conf> B<ngshared.pm>

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
use RRDs;

my (@perfdata);					# data returned by inputdata for processdata

readconfig('write');			# specify 'write' to check creation of RRD files
if (defined $Config{ngshared}) { # ngshared is set on an error
	debug(1, $Config{ngshared});
	exit;
}
$Config{debug} = $Config{debug_insert} if defined $Config{debug_insert} and
	not defined $Config{debug_insert_host} and
	not defined $Config{debug_insert_service};

# Read the map file and define a subroutine that parses performance data
getrules($Config{mapfile}) and exit;

if ($Config{perfloop}) {
	while (1) {					# check the file every 30 seconds and load data
		@perfdata = inputdata();
		processdata(@perfdata) if @perfdata;
		sleep 30;
	}
} else {						# run once with the line at $ARGV[0]
	@perfdata = inputdata();
	processdata(@perfdata) if @perfdata;
}

debug(5, 'nagiosgraph exited');
