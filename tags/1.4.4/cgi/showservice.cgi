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
my ( $cgi, $params ) = init('showservice');
my ( $periods, $expanded_periods ) = initperiods( 'service', $params );

my $defaultds = readdatasetdb();
if (scalar @{$params->{db}} == 0
    && $defaultds->{$params->{service}}
    && scalar @{$defaultds->{$params->{service}}} > 0 ) {
    $params->{db} = $defaultds->{$params->{service}};
}
my $hosts = readservdb( $params->{service}, $params->{db} );

cfgparams( $params, $params );

print printheader($cgi,
    {
        title           => $params->{service},
        call            => 'service',
        service         => $params->{service},
        defaultdatasets => $defaultds,
    }
) or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $now = time;
foreach my $period ( graphsizes($periods) ) {
    dumper( DBDEB, 'period', $period );
    my $str = q();
    foreach my $host ( @{$hosts} ) {
        $params->{host} = $host;

        if ( scalar @{ $params->{db} } == 0 ) {
            $params->{db} = dbfilelist( $host, $params->{service} );
        }

        my $url = $Config{nagiosgraphcgiurl} . '/show.cgi?'
            . 'host=' . $cgi->escape($host)
            . '&service=' . $cgi->escape( $params->{service} );
        my $link = $cgi->a( {href => $url}, $host );

        $str .= printgraphlinks( $cgi, $params, $period, $link ) . "\n";
    }
    print printperiodlinks( $cgi, $params, $period, $now, $str )
        or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printinitscript( q(), $params->{service}, $expanded_periods )
    or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my $ets = gettimestamp();

print printfooter( $cgi, $sts, $ets )
    or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

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

=over 4

=item service=service_description

=item db=database[,ds-name[,ds-name[,ds-name[...]]]]

=item period=(day week month quarter year)

=item geom=WIDTHxHEIGHT

=item rrdopts=<rrdgraph options>

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

Use the debug_showservice setting from B<nagiosgraph.conf> to control the 
amount of debug information that will be emitted by this script.  Output will
go to the nagiosgraph log or web server error log.

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

Copy B<ngshared.pm>, B<nagiosgraph.conf>, and B<servdb.conf> to a
configuration directory such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> and B<servdb.conf> as needed.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<servdb.conf> B<nagiosgraph.conf>
B<ngshared.pm> B<showgraph.cgi>
B<show.cgi> B<showhost.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've written this based on Robert
Teeter's showhost.cgi.

Matthew Wall, showgroup.cgi, CSS and JavaScript in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the OSI Artistic License:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.