#!/usr/bin/perl

# File:    $Id$
# This program is based upon show.cgi
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

use ngshared qw(:SHOWHOST);

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
# Expect host input
my $params = getparams($cgi, 'showhost', ['host', ]);
dumper(DBDEB, 'params', $params);

# See if we have custom debug level
getdebug('showhost', $params->{host}, q());

# see if the time periods were specified.  ensure list is space-delimited.
my $periods = (defined $params->{period} && $params->{period} ne q())
    ? $params->{period} : $Config{timehost};
$periods =~ s/,/ /g;            ## no critic (RegularExpressions)

# use stylesheet if specified
my @style;
if ($Config{stylesheet}) {
    @style = (-style => {-src => "$Config{stylesheet}"});
}

find(\&getgraphlist, $Config{rrddir});

my $hdb = readhostdb($params->{host});

# Draw a page
my ($host, $fixedscale) = ('', 0);
if ($params->{host}) { $host = $params->{host}; }
if ($params->{fixedscale}) { $fixedscale = $params->{fixedscale}; }
print printheader($cgi,
                  {title => $host,
                   style => \@style,
                   call => 'host',
                   default => $host,
                   fixedscale => $fixedscale,
                   label => $cgi->a({href => $Config{nagiosgraphcgiurl} .
                                        '/extinfo.cgi?type=1&host=' . $host},
                                    $host)}) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $now = time;
foreach my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    print printperiodlinks($cgi, $params, $period, $now) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    foreach my $dbinfo (@{$hdb}) {
         $dbinfo->{rrdopts} = (defined $Config{rrdopts}{$dbinfo->{service}})
            ? $Config{rrdopts}{$dbinfo->{service}}
            : $params->{rrdopts};
        $dbinfo->{host} = $params->{host};
        $dbinfo->{geom} = $params->{geom};
        $dbinfo->{fixedscale} = $params->{fixedscale};
        $dbinfo->{offset} = 0;
        dumper(DBDEB, 'dbinfo', $dbinfo);
        my $url = $Config{nagiosgraphcgiurl} .
            '/showservice.cgi?service=' . $dbinfo->{service} .
            join '&db=' . @{$dbinfo->{db}};
        $url =~ tr/ /+/;
        my $link = $cgi->a({href => $url},
                           defined $dbinfo->{label} ? $dbinfo->{label} :
                               $dbinfo->{service});
        print printgraphlinks($cgi, $dbinfo, $period, $link) . "\n" or
            debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    }
}

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

=head1 CONFIGURATION

The B<hostdb.conf> controls which services will be listed and the order in
which those services will appear.

=head1 REQUIRED ARGUMENTS

A host name must be specified.

=head1 OPTIONS

host=host_name

period=(day week month quarter year)

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_showhost setting from B<nagiosgraph.conf> to control the amount
of debug information that will be emitted by this script.

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

Create or edit the example B<hostdb.conf>, which must reside in the same
directory as B<ngshared.pm>.

To link a web page generated by this script from Nagios, add

=over 4

action_url https://server/nagios/cgi-bin/showhost.cgi?host=host1

=back

to the B<define host> (Nagios 3) or B<define hostextinfo> (Nagios 2.12) stanza
(changing the base URL and host1 as needed).

Copy the images/action.gif file to the nagios/images directory, if desired.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<hostdb.conf> B<nagiosgraph.conf> B<showgraph.cgi> B<showservice.cgi> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), using showgraph.cgi, and adding links for show.cgi
and showservice.cgi.

Matthew Wall, added features, bug fixes and refactoring in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the OSI Artistic License:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.