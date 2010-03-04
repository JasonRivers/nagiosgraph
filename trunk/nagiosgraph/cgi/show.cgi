#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) 2005 Soren Dossing
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# The configuration file and ngshared.pm must be in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.
use lib '/opt/nagiosgraph/etc';

# Main program - change nothing below

use ngshared qw(:SHOW);
use CGI qw(-nosticky);
use English qw(-no_match_vars);
use strict;
use warnings;

my $sts = gettimestamp();
my ($cgi, $params) = init('show');
my ($periods, $expanded_periods) = initperiods('both', $params);

my $defaultds = readdatasetdb();
if (scalar @{$params->{db}} == 0) {
    if ($defaultds->{$params->{service}}
        && scalar @{$defaultds->{$params->{service}}} > 0) {
        $params->{db} = $defaultds->{$params->{service}};
    } elsif ($params->{host} ne q() && $params->{host} ne q(-)
             && $params->{service} ne q() && $params->{service} ne q(-)) {
        $params->{db} = dbfilelist($params->{host}, $params->{service});
    }
}

cfgparams($params, $params, $params->{service});

print printheader($cgi, { title => "$params->{host} - $params->{service}",
                          call => 'both',
                          host => $params->{host},
                          hosturl => $Config{nagiosgraphcgiurl} . '/showhost.cgi?host=' . $cgi->escape($params->{host}),
                          service => $params->{service},
                          serviceurl => $Config{nagiosgraphcgiurl} . '/showservice.cgi?service=' . $cgi->escape($params->{service}),
                          defaultdatasets => $defaultds }) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $now = time;
for my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    my $str = printgraphlinks($cgi, $params, $period);
    print printperiodlinks($cgi, $params, $period, $now, $str) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printinitscript($params->{host},$params->{service},$expanded_periods) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $ets = gettimestamp();

print printfooter($cgi, $sts, $ets) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

__END__

=head1 NAME

show.cgi - Graph Nagios data

=head1 DESCRIPTION

Run this via a web server to generate a page of graph data.

The showgraph.cgi script generates the graphs themselves.

=head1 USAGE

B<show.cgi>?host=host_name&service=service_name

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=over 4

=item host=host_name

=item service=service_description

=item db=database[,dataset[,dataset[,dataset[...]]]]

=item period=(day week month quarter year)

=item geom=WIDTHxHEIGHT

=item rrdopts=<rrdgraph options>

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_show setting from B<nagiosgraph.conf> to control the amount
of debug information that will be emitted by this script.  Debug output will
go to the nagiosgraph log or web server error log.

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

=head1 DEPENDENCIES

=over 4

=item B<showgraph.cgi>

This generates the graphs shown in the HTML generated here.

=item B<Nagios>

While this could probably run without Nagios, as long as RRD databases exist,
it is intended to work along side Nagios.

=item B<rrdtool>

This provides the data storage and graphing system.

=item B<RRDs>

This provides the perl interface to rrdtool.

=back

=head1 INSTALLATION

Copy B<ngshared.pm> and B<nagiosgraph.conf> to a configuration directory
such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> as needed.

To create links from Nagios web pages, add extinfo definitions in the 
Nagios configuration.  For example,

=begin text

    define serviceextinfo {
      service_description Current Load
      host_name           host1, host2
      action_url          show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$
    }

=end text

The service_description must match an existing service.  Only the hosts
listed in host_name will have an action icon next to the service name on
a detail page.

Copy the B<action.gif> file to the nagios/images directory, if desired.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<nagiosgraph.conf>
B<ngshared.pm> B<showgraph.cgi>
B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), adding color number nine, and adding support for
showhost.cgi and showservice.cgi.

Craig Dunn: support for service based graph options via rrdopts.conf file

Matthew Wall, showgroup.cgi, CSS and JavaScript in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
