#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2004 Soren Dossing
# Author:  (c) 2005 Robert Teeter
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use ngshared;
use English qw(-no_match_vars);
use strict;
use warnings;

my $sts = gettimestamp();
my ($cgi, $params) = init('showhost');
my ($periods, $expanded_periods) = initperiods('host', $params);

my $ginfos = readhostdb($params->{host});

# nagios and nagiosgraph may not share the same cgi directory
my $nagioscgiurl = $Config{nagiosgraphcgiurl};
if ($Config{nagioscgiurl}) { $nagioscgiurl = $Config{nagioscgiurl}; }

print printheader($cgi,
    {
        title   => $params->{host},
        call    => 'host',
        host    => $params->{host},
        hosturl => $nagioscgiurl . '/extinfo.cgi?type=1&host=' . $params->{host}
    }
) or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $now = time;
foreach my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    my $str = q();
    foreach my $info (@{$ginfos}) {
        $info->{host} = $params->{host};
        cfgparams($info, $params);

        my $url = $Config{nagiosgraphcgiurl} . '/show.cgi?' .
            'host=' . $cgi->escape($info->{host}) .
            '&service=' . $cgi->escape($info->{service});
        if ($info->{db}) {
            foreach my $db (@{$info->{db}}) {
                $url .= '&db=' . $db;
            }
            $url =~ tr/ /+/;
        }
        my $label = $info->{service_label} ?
            $info->{service_label} : getlabel($info->{service});
        my $link = $cgi->a({href => $url}, $label);

        $str .= printgraphlinks($cgi, $info, $period, $link) . "\n";
    }
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

showhost.cgi - Graph Nagios data for a specific host

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
a page of HTML that displays a list of graphs for a single host.  The graph
data are retrieved from RRD files.

The showgraph.cgi script generates the graphs themselves.

=head1 USAGE

B<showhost.cgi>?host=host_name

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=over 4

=item host=host_name

=item period=(day week month quarter year)

=item geom=WIDTHxHEIGHT

=item rrdopts=<rrdgraph options>

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_showhost setting from B<nagiosgraph.conf> to control the amount
of debug information that will be emitted by this script.  Debug output will
go to the web server error log.

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

B<nagiosgraph.conf> B<hostdb.conf> B<datasetdb.conf>
B<ngshared.pm>
B<showgraph.cgi>
B<show.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005

Alan Brenner - moved subroutines into a shared file (ngshared.pm), using
showgraph.cgi, and adding links for show.cgi and showservice.cgi.

Matthew Wall, showgroup.cgi, CSS and JavaScript in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
