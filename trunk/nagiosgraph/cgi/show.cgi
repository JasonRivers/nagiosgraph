#!/usr/bin/perl ## no critic (RequireVersionVar)

# File:    $Id$
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008; Soren Dossing, 2005
# License: OSI Artistic License
#            http://www.opensource.org/licenses/artistic-license-2.0.php

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';
# The configuration loader will look for nagiosgraph.conf in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.

# Main program - change nothing below

use ngshared;
use CGI;
use File::Find;
use English qw(-no_match_vars);
use RRDs;
use strict;
use warnings;

my ($params,                    # Required hostname to show data for
    @style,                     # CSS, if so configured
    $cgi,                       # CGI.pm instance
    $url,                       # base of link to previous/next
    $periods);                  # time periods to graph

$cgi = new CGI;                 ## no critic (ProhibitIndirectSyntax)
$cgi->autoEscape(0);
readconfig('read');
if (defined $Config{ngshared}) {
    debug(DBCRT, $Config{ngshared});
    htmlerror($cgi, $Config{ngshared});
    exit;
}
if (not $Config{linewidth}) { $Config{linewidth} = 2; }

# comment this out, if running readconfig with a DBDEB second parameter
dumper(DBDEB, 'config', \%Config);

# Expect host and service
$params = getparams($cgi, 'show', ['host', 'service']);
if (defined $Config{rrdopts}{$params->{service}}) {
    $params->{rrdopts} = $Config{rrdopts}{$params->{service}};
}
dumper(DBDEB, 'params', $params);

# see if the time periods were specified.  ensure list is space-delimited.
$periods = (defined $params->{period} && $params->{period} ne q())
    ? $params->{period} : $Config{timeall};
$periods =~ s/,/ /g;            ## no critic (RegularExpressions)

# use stylesheet if specified
if ($Config{stylesheet}) {
    @style = ( -style => {-src => "$Config{stylesheet}"} );
}

# Draw the full page
print $cgi->header, $cgi->start_html(-id => 'nagiosgraph',
    -title => "nagiosgraph: $params->{host}-$params->{service}",
    -head => $cgi->meta({ -http_equiv => 'Refresh', -content => '300' }),
    @style) . "\n" . printnavmenu($cgi, $params->{host}, $params->{service},
                                  $params->{fixedscale}, $cgi->remote_user()) .
    $cgi->br({-clear=>'all'}) . "\n" .
    $cgi->h1('Nagiosgraph') . "\n" .
    $cgi->p(trans('perfforhost') . ': ' . $cgi->strong($cgi->tt(
        $cgi->a({href => $Config{nagiosgraphcgiurl} . '/showhost.cgi?host=' .
                $cgi->escape($params->{host})}, $params->{host}))) . ', ' .
        trans('service') . ': ' .
        $cgi->strong($cgi->tt($cgi->a({href => $Config{nagiosgraphcgiurl} .
                '/showservice.cgi?service=' .
                $cgi->escape($params->{service})}, $params->{service}))) .
        q( ) . trans('asof') . ': ' . $cgi->strong(scalar localtime)) . "\n" or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

for my $period (graphsizes($periods)) {
    print $cgi->a({-id => trans($period->[0])},
        $cgi->div({-class=>'period_title'},
                  trans($period->[0] . 'ly'))) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    $url = buildurl($params->{host},
                    $params->{service},
                    {geom => $params->{geom},
                     rrdopts => $params->{rrdopts},
                     db => $params->{db}});
    print $cgi->a({-href=>"?$url&offset=" .
            ($params->{offset} + $period->[2]) . q(#) . $period->[0]},
            trans('previous')) . ' / ' .
        $cgi->a({-href=>"?$url&offset=" .
          ($params->{offset} - $period->[2] . q(#) . $period->[0]) }, trans('next')) .
        $cgi->br() . "\n" . printgraphlinks($cgi, $params, $period) or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
}

print printfooter($cgi) or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

__END__

=head1 NAME

show.cgi - Graph Nagios data

=head1 DESCRIPTION

Run this via a web server cgi to generate an HTML page of data stored by
insert.pl (including the graphs).

=head1 USAGE

B<show.cgi>

=head1 CONFIGURATION

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

period=(day week month quarter year)

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over 4

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
line (line 9) to point to the directory containing B<ngshared.pm>.

Create or edit the example B<nagiosgraph.conf>, which must reside in the same
directory as B<ngshared.pm>.

To link a web page generated by this script from Nagios, add definitions like:

=over 4

define serviceextinfo {
 service_description Current Load
 host_name           host1, host2
 action_url          show.cgi?host=$HOSTNAME$&service=$SERVICEDESC$
}

=back

to the Nagios configuration file(s). The service_description must match an
existing service. Only the hosts listed in host_name will have an action icon
next to the service name on a detail page.

Copy the images/action.gif file to the nagios/images directory, if desired.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<nagiosgraph.conf> B<showhost.cgi> B<showservice.cgi> B<showgraph.cgi> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), adding color number nine, and adding support for
showhost.cgi and showservice.cgi.

Craig Dunn: support for service based graph options via rrdopts.conf file

Matthew Wall, minor feature additions, bug fixing and refactoring in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the OSI Artistic License:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.
