#!/bin/sh
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# License: OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license-2.0.php

# I've needed to use this with Nagios 2.12 on Mac OS X 10.5 in order to get
# perl to run.

#define command {
#    command_name    process-service-perfdata
#    command_line    /usr/local/lib/nagios/insert.sh "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$"
#}

/usr/bin/perl /usr/local/lib/nagios/insert.pl "$*"
