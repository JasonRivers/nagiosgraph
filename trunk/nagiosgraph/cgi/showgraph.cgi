#!/usr/bin/perl

# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) 2005 Soren Dossing
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# The configuration file and ngshared.pm must be in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.
use lib '/opt/nagiosgraph/etc';

# Main program - change nothing below

use ngshared;
use RRDs;
use CGI;
use English qw(-no_match_vars);
use File::Find;
use MIME::Base64;
use strict;
use warnings;

readconfig('read');
if (defined $Config{ngshared}) {
    debug(1, $Config{ngshared});
    htmlerror($Config{ngshared});
    exit;
}

my $cgi = new CGI;  ## no critic (ProhibitIndirectSyntax)
$cgi->autoEscape(0);

my $params = getparams($cgi, 'showgraph');
getdebug('showgraph', $params->{host}, $params->{service});

dumper(DBDEB, 'config', \%Config);
dumper(DBDEB, 'params', $params);

# Draw a graph
$OUTPUT_AUTOFLUSH = 1;          # Make sure headers arrive before image data
print $cgi->header(-type => 'image/png') or
    debug(DBCRT, "error sending HTML to web server: $OS_ERROR");

my @ds = rrdline($params);      # Figure out db files and line labels
dumper(DBDEB, 'RRDs::graph', \@ds);

RRDs::graph(@ds);
if (RRDs::error) {
    debug(DBERR, 'RRDs::graph ERR ' . RRDs::error);
    if ($Config{debug} < DBINF) { dumper(DBERR, 'RRDs::graph', \@ds); }
    print decode_base64(       # send a small, clear image on errors
        'iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAIXRFWHRTb2Z0d2FyZQBHcmFwaGlj' .
        'Q29udmVydGVyIChJbnRlbCl3h/oZAAAAGUlEQVR4nGL4//8/AzrGEKCCIAAAAP//AwB4w0q2n+sy' .
        'HQAAAABJRU5ErkJggg==');
}

exit 0;



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

graph=118800

geom=default

rrdopts=-u+100+-l+0+-r+-snow-118800+-enow-0

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

=head1 SEE ALSO

B<nagiosgraph.conf> B<showhost.cgi> B<showservice.cgi> B<ngshared.pm>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), adding color number nine, and adding support for
showhost.cgi and showservice.cgi.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
