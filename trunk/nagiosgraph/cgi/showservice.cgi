#!/usr/bin/perl

# File:    $Id$
# This program is based upon show.cgi, and showhost.cgi
# Author:  (c) Soren Dossing, 2004
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Robert Teeter, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';
# The configuration loader will look for nagiosgraph.conf in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.

# Main program - change nothing below

use ngshared;
use CGI;
use English qw(-no_match_vars);
use File::Find;
use strict;
use warnings;

my $cgi = new CGI;              ## no critic (ProhibitIndirectSyntax)
$cgi->autoEscape(0);
readconfig('read');
if (defined $Config{ngshared}) {
    debug(1, $Config{ngshared});
    htmlerror($cgi, $Config{ngshared});
    exit;
}
# Expect service input
my $params = getparams($cgi, 'showservice', ['service', ]);
dumper(DBDEB, 'params', $params);

# See if we have custom debug level
getdebug('showservice', q(), $params->{service});

# see if the time periods were specified.  ensure list is space-delimited.
my $periods = (defined $params->{period} && $params->{period} ne q())
    ? $params->{period} : $Config{timeservice};
$periods =~ s/,/ /g;            ## no critic (RegularExpressions)

# use stylesheet if specified
my @style;
if ($Config{stylesheet}) {
    @style = (-style => {-src => "$Config{stylesheet}"});
}

find(\&getgraphlist, $Config{rrddir});
my ($hdb, $sdb, $dbinfo) = readservdb($params->{service});
dumper(DBDEB, 'hdb', $hdb);
if ($params->{db}) { $dbinfo->{db} = $params->{db}; }
dumper(DBDEB, 'dbinfo', $dbinfo);
my $label = (exists $dbinfo->{label}) ? $dbinfo->{label} : $params->{service};
debug(DBDEB, "default = $label");

$dbinfo->{rrdopts} = (defined $Config{rrdopts}{$params->{service}})
    ? $Config{rrdopts}{$params->{service}}
    : $params->{rrdopts};

$dbinfo->{geom} = $params->{geom};
$dbinfo->{fixedscale} = $params->{fixedscale};
$dbinfo->{offset} = 0;

# Draw the page
print printheader($cgi,
                  {title => $params->{service},
                   style => \@style,
                   call => 'service',
                   default => $label,
                   fixedscale => $params->{fixedscale},
                   label => $cgi->unescape($label)}) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $now = time;
foreach my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    print printperiodlinks($cgi, $params, $period, $now) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    foreach my $host (@{$hdb}) {
        debug(DBDEB, "host = $host");
        $dbinfo->{host} = $host;
        my $url = $Config{nagiosgraphcgiurl} .
            '/show.cgi?host=' . $cgi->escape($host) .
            '&service=' . $cgi->escape($params->{service});
        $url =~ tr/ /+/;
        my $link = $cgi->a({href => $url}, $host);
        print printgraphlinks($cgi, $dbinfo, $period) . "\n" or
            debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    }
}

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

=head1 CONFIGURATION

=head1 REQUIRED ARGUMENTS

A service description must be specified.

=head1 OPTIONS

service=service_description

period=(day week month quarter year)

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_showservice setting from B<nagiosgraph.conf> to control the
amount of debug information that will be emitted by this script.

=head1 DEPENDENCIES

=over 4

=item B<Nagios>

While this could probably run without Nagios, as long as RRD databases exist,
it is intended to work along side Nagios.

=item B<showgraph.cgi>

This generates the graphs shown in the HTML generated here.

=back

=head1 INSTALLATION

Copy this file into Nagios' cgi directory (for the Apache web server, see where
the ScriptAlias for /nagios/cgi-bin points), and make sure it is executable by
the web server.

Install the B<ngshared.pm> file and edit this file to change the B<use lib>
line (line 12) to point to the directory containing B<ngshared.pm>.

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