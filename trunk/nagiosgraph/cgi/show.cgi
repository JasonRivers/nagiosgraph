#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) 2005 Soren Dossing
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use ngshared;
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

cfgparams($params, $params);

print printheader($cgi,
    {
        title           => "$params->{host} - $params->{service}",
        call            => 'both',
        host            => $params->{host},
        hosturl         => $Config{nagiosgraphcgiurl} . '/showhost.cgi?host=' . $cgi->escape($params->{host}),
        service         => $params->{service},
        serviceurl      => $Config{nagiosgraphcgiurl} . '/showservice.cgi?service=' . $cgi->escape($params->{service}),
        defaultdatasets => $defaultds,
    }
) or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

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

show.cgi - Graph Nagios data for a specific service on a specific host

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
a page of HTML that displays a list of graphs for a single service on a single
host.  The graph data are retrieved from RRD files.

The showgraph.cgi script generates the graphs themselves.

=head1 USAGE

B<show.cgi>?host=host_name&service=service_name

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=over 4

=item host=host_name

=item service=service_description

=item db=database[,ds-name[,ds-name[,ds-name[...]]]]

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

=item B<ngshared.pm>

This is the nagiosgraph perl library.  It contains code used by this script.

=item B<showgraph.cgi>

This generates the graphs that are embedded in the HTML.

=item B<rrdtool>

This provides the data storage and graphing system.

=item B<RRDs>

This provides the perl interface to rrdtool.

=item B<Nagios>

Although this CGI script can be used with RRD files independent of Nagios, it
is designed to be used with Nagios.

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

B<nagiosgraph.conf> B<datasetdb.conf>
B<ngshared.pm>
B<showgraph.cgi>
B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner, moved subroutines into a shared file (ngshared.pm), added color
number nine, and added support for showhost.cgi and showservice.cgi.

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
