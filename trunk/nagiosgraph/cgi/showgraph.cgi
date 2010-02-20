#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) 2005 Soren Dossing
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# The configuration file and ngshared.pm must be in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.
use lib '/opt/nagiosgraph/etc';

# Main program - change nothing below

use ngshared qw(:SHOWGRAPH);
use RRDs;
use CGI;
use English qw(-no_match_vars);
use MIME::Base64;
use strict;
use warnings;

my ($cgi, $params) = init('showgraph');

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

$OUTPUT_AUTOFLUSH = 1;          # Make sure headers arrive before image data
print $cgi->header(-type => 'image/png') or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my @ds = rrdline($params);
dumper(DBDEB, 'RRDs::graph', \@ds);

RRDs::graph(@ds);
if (RRDs::error) {
    debug(DBERR, 'RRDs::graph ERR ' . RRDs::error);
    print decode_base64(       # send a small, clear image on errors
        'iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAIXRFWHRTb2Z0d2FyZQBHcmFwaGlj' .
        'Q29udmVydGVyIChJbnRlbCl3h/oZAAAAGUlEQVR4nGL4//8/AzrGEKCCIAAAAP//AwB4w0q2n+sy' .
        'HQAAAABJRU5ErkJggg==') or
        debug(DBCRT, "error sending HTML to web server: $OS_ERROR");
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

host=host_name

service=service_name

geom=default

period=(day | week | month | quarter | year)

rrdopts=<rrdgraph options>

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
