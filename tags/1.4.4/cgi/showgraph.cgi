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
use RRDs;
use English qw(-no_match_vars);
use strict;
use warnings;

my ($cgi, $params) = getparams();
my $errmsg = readconfig('showgraph', 'cgilogfile');
if ($errmsg ne q()) {
    imgerror($cgi, $errmsg);
    croak($errmsg);
}
getdebug('showgraph', $params->{host}, $params->{service});
$errmsg = checkrrddir('read');
if ($errmsg ne q()) {
    debug(DBCRT, $errmsg);
    imgerror($cgi, $errmsg);
    exit;
}
$errmsg = readrrdoptsfile();
if ($errmsg ne q()) {
    debug(DBCRT, $errmsg);
    imgerror($cgi, $errmsg);
    exit;
}
$errmsg = readlabelsfile();
if ($errmsg ne q()) {
    debug(DBCRT, $errmsg);
    imgerror($cgi, $errmsg);
    exit;
}
$errmsg = loadperms( $cgi->remote_user() );
if ($errmsg ne q()) {
    debug(DBCRT, $errmsg);
    imgerror($cgi, $errmsg);
    exit;
}

if (! havepermission( $params->{host}, $params->{service} )) {
    $errmsg = $cgi->remote_user() . ' does not have permission to view data';
    if ( $params->{host} ) {
        if ( $params->{service} ) {
            $errmsg = $cgi->remote_user() . ' does not have permission to view service ' . $params->{service} . ' on host ' . $params->{host};
        } else {
            $errmsg = $cgi->remote_user() . ' does not have permission to view host ' . $params->{host};
        }
    }
    debug(DBINF, $errmsg);
    imgerror($cgi, $errmsg);
} elsif ($params->{host} eq q() || $params->{host} eq q(-)
         || $params->{service} eq q() || $params->{service} eq q(-)) {
    # if host or service is not specified, send an empty image
    imgerror($cgi, q());
} else {
    if (scalar @{$params->{db}} == 0) {
        my $defaultds = readdatasetdb();
        if ($defaultds->{$params->{service}}
            && scalar @{$defaultds->{$params->{service}}} > 0) {
            $params->{db} = $defaultds->{$params->{service}};
        } elsif ($params->{host} ne q() && $params->{host} ne q(-)
                 && $params->{service} ne q() && $params->{service} ne q(-)) {
            $params->{db} = dbfilelist($params->{host}, $params->{service});
        }
    }

    $OUTPUT_AUTOFLUSH = 1;     # Make sure headers arrive before image data
    print $cgi->header(-type => 'image/png')
        or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

    my ($ds);
    ($ds, $errmsg) = rrdline($params);

    if ($errmsg eq q()) {
        dumper(DBDEB, 'RRDs::graph', $ds);
        RRDs::graph(@{$ds});
        my $err = RRDs::error;
        if ($err) {
            print getimg($err)
                or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
        }
    } else {
        print getimg($errmsg)
            or debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
    }
}

__END__

=head1 NAME

showgraph.cgi - Graph Nagios data

=head1 DESCRIPTION

This CGI script generates a graph of RRD data as a PNG image.

=head1 USAGE

B<showgraph.cgi>?host=host_name&service=service_name

=head1 REQUIRED ARGUMENTS

host

service

=head1 OPTIONS

=over 4

=item host=host_name

=item service=service_name

=item db=database[,ds-name[,ds-name[,ds-name[...]]]]

=item period=(day | week | month | quarter | year)

=item geom=WIDTHxHEIGHT

=item rrdopts=<rrdgraph options>

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

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

Copy B<ngshared.pm> and B<nagiosgraph.conf> to a configuration directory
such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> as needed.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 SEE ALSO

B<nagiosgraph.conf>
B<ngshared.pm>
B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), adding color number nine, and adding support for
showhost.cgi and showservice.cgi.

Matthew Wall, showgroup.cgi, CSS and JavaScript in 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
