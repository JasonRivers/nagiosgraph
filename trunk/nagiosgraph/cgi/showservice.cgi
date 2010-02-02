#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2004 Soren Dossing
# Author:  (c) 2005 Robert Teeter
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# The configuration file and ngshared.pm must be in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.
use lib '/opt/nagiosgraph/etc';

# Main program - change nothing below

use ngshared;
use CGI qw(-nosticky);
use English qw(-no_match_vars);
use strict;
use warnings;

my ($cgi, $params) = init('showservice');
my ($periods, $expanded_periods) = initperiods('service', $params);

my ($hosts) = readservdb($params->{service}, $params->{db});
dumper(DBDEB, 'hosts', $hosts);

cfgparams($params, $params, $params->{service});

print printheader($cgi, { title => $params->{service},
                          call => 'service',
                          service => $params->{service} }) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $now = time;
foreach my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    my $str = q();
    foreach my $host (@{$hosts}) {
        $params->{host} = $host;

        my $url = $Config{nagiosgraphcgiurl} .
            '/show.cgi?host=' . $cgi->escape($host) .
            '&service=' . $cgi->escape($params->{service});
        my $link = $cgi->a({href => $url}, $host);

        $str .= printgraphlinks($cgi, $params, $period, $link) . "\n";
    }
    print printperiodlinks($cgi, $params, $period, $now, $str) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printscript(q(), $params->{service}, $expanded_periods) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

print printfooter($cgi) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

__END__

=head1 NAME

showservice.cgi - Graph Nagios data for a given service

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
a page of HTML that displays a list of graphs for a single service on multiple
hosts.  The graph data are retrieved from RRD files and are typically captured
by insert.pl.

The showgraph.cgi script generates the graphs themselves.

=head1 USAGE

B<showservice.cgi>?service=service_description

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

service=service_description

period=(day week month quarter year)

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_showservice setting from B<nagiosgraph.conf> to control the 
amount of debug information that will be emitted by this script.

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

The B<servdb.conf> controls which services will be listed and the order in
which those services will appear.

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

Copy this file into Nagios' cgi directory (for the Apache web server, see where
the ScriptAlias for /nagios/cgi-bin points), and make sure it is executable by
the web server.

Install the B<ngshared.pm> file and edit this file to change the B<use lib>
line to point to the directory containing B<ngshared.pm>.

Create or edit the example B<servdb.conf>, which must reside in the same
directory as B<ngshared.pm>.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<servdb.conf> B<nagiosgraph.conf> B<showgraph.cgi> B<showhost.cgi> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've written this based on Robert
Teeter's showhost.cgi.

Matthew Wall, added features, bug fixes and refactoring in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the OSI Artistic License:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.
