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

my ($cgi, $params) = init('showgroup');
my ($periods, $expanded_periods) = initperiods('group', $params);

if (! $params->{group}) { $params->{group} = q(); }

my ($gnames, $ginfos) = readgroupdb($params->{group});
dumper(DBDEB, 'groups', $gnames);
dumper(DBDEB, 'graphinfos', $ginfos);

print printheader($cgi, { title => $params->{group},
                          call => 'group',
                          group => $params->{group},
                          grouplist => \@{$gnames} }) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $url = $ENV{REQUEST_URI};
my $now = time;
foreach my $period (graphsizes($periods)) {
    dumper(DBDEB, 'period', $period);
    my $str = q();
    foreach my $info (@{$ginfos}) {
        cfgparams($info, $params, $info->{service});

        my $surl = $Config{nagiosgraphcgiurl} .
            '/showservice.cgi?service=' . $cgi->escape($info->{service});
        if ($info->{db}) {
            $surl .= join('&db=' . @{$info->{db}});
            $surl =~ tr/ /+/;
        }
        my $hurl = $Config{nagiosgraphcgiurl} .
            '/showhost.cgi?host=' . $cgi->escape($info->{host});
        my $link = $cgi->a({href => $surl}, trans($info->{service}, 1)) .
            q( ) . trans('on') . q( ) .
            $cgi->a({href => $hurl}, $info->{host});

        $str .= printgraphlinks($cgi, $info, $period, $link) . "\n";
    }
    print printperiodlinks($cgi, $url, $params, $period, $now, $str) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printscript('', '', $expanded_periods) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

print printfooter($cgi) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

__END__

=head1 NAME

showgroup.cgi - Graph Nagios data for a given host or service group

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
a page of HTML that displays a list of graphs for a group of hosts and/or 
services.  The graph data are retrieved from RRD files and are typically
captured by insert.pl.

The showgraph.cgi script generates the graphs themselves.

=head1 USAGE

B<showgroup.cgi>?group=group_name

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

Groups of services and hosts are defined in the B<groupdb.conf> file.

=head1 OPTIONS

group=group_name

period=(day week month quarter year)

=head1 DIAGNOSTICS

Use the debug_showgroup setting from B<nagiosgraph.conf> to control the amount
of debug information that will be emitted by this script.  Debug output will
go to the web server error log.

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

Create or edit the example B<groupdb.conf>, which must reside in the same
directory as B<ngshared.pm>.

=head1 SEE ALSO

B<groupdb.conf> B<nagiosgraph.conf> B<showgraph.cgi> B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005

Alan Brenner, author of ngshared.pm and many other parts in 2008.

Matthew Wall, author of showgroup.cgi in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 Matthew Wall

This program is free software; you can redistribute it and/or modify it
under the terms of the OSI Artistic License:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.
