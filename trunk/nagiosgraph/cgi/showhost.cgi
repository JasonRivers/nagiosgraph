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

use ngshared qw(:SHOWHOST);
use CGI qw(-nosticky);
use English qw(-no_match_vars);
use strict;
use warnings;

my ($cgi, $params) = init('showhost');
my ($periods, $expanded_periods) = initperiods('host', $params);

my $ginfos = readhostdb($params->{host});
dumper(DBDEB, 'graphinfos', $ginfos);

# nagios and nagiosgraph may not share the same cgi directory
my $nagioscgiurl = $Config{nagiosgraphcgiurl};
if ($Config{nagioscgiurl}) { $nagioscgiurl = $Config{nagioscgiurl}; }

print printheader($cgi, { title => $params->{host},
                          call => 'host',
                          host => $params->{host},
                          hosturl => $nagioscgiurl . '/extinfo.cgi?type=1&host=' . $params->{host} }) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

# FIXME: db= handling is not consistent

my $now = time;
foreach my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    my $str = q();
    foreach my $info (@{$ginfos}) {
        $info->{host} = $params->{host};
        cfgparams($info, $params, $info->{service});

        my $url = $Config{nagiosgraphcgiurl} .
            '/showservice.cgi?service=' . $cgi->escape($info->{service});
        if ($info->{db}) {
            foreach my $db (@{$info->{db}}) {
                $url .= '&db=' . $db;
            }
            $url =~ tr/ /+/;
        }
        my $link = $cgi->a({href => $url}, trans($info->{service}, 1));

        $str .= printgraphlinks($cgi, $info, $period, $link) . "\n";
    }
    print printperiodlinks($cgi, $params, $period, $now, $str) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printscript($params->{host}, $params->{service}, $expanded_periods) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

print printfooter($cgi) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

__END__

=head1 NAME

showhost.cgi - Graph Nagios data for a given host

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
a page of HTML that displays a list of graphs for a single host.  The graph
data are retrieved from RRD files and are typically captured by insert.pl.

The showgraph.cgi script generates the graphs themselves.

=head1 USAGE

B<showhost.cgi>?host=host_name

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=over 4

=item host=host_name

=item period=(day week month quarter year)

=item geom=WIDTHxHEIGHT

=item rrdopts=-g

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_showhost setting from B<nagiosgraph.conf> to control the amount
of debug information that will be emitted by this script.  Debug output will
go to the web server error log.

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

The B<hostdb.conf> controls which services will be listed and the order in
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

Copy B<ngshared.pm>, B<nagiosgraph.conf>, and B<hostdb.conf> to a
configuration directory such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> and B<hostdb.conf> as needed.

To create links from Nagios web pages, add

=over 4

action_url https://server/nagios/cgi-bin/showhost.cgi?host=host1

=back

to the B<define host> (Nagios 3) or B<define hostextinfo> (Nagios 2.12) stanza
(changing the base URL and host1 as needed).

Copy the B<action.gif> file to the nagios/images directory, if desired.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<hostdb.conf> B<nagiosgraph.conf>
B<ngshared.pm> B<showgraph.cgi>
B<show.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), using showgraph.cgi, and adding links for show.cgi
and showservice.cgi.

Matthew Wall, showgroup.cgi, CSS and JavaScript in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
