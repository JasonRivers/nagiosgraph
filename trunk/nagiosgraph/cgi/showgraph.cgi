#!/usr/bin/perl

# File:    $Id$
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008; Soren Dossing, 2005
# License: OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license-2.0.php

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';
# The configuration loader will look for nagiosgraph.conf in this directory.
# So take note upgraders, there is no $configfile = '....' line anymore.

=head1 NAME

showgraph.cgi - Graph Nagios data

=head1 SYNOPSIS

B<showgraph.cgi>

=head1 DESCRIPTION

Run this via a web server cgi to generate an HTML page of data stored by
insert.pl (including the graphs).

=head1 REQUIREMENTS

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

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), adding color number nine, and adding support for
showhost.cgi and showservice.cgi.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<nagiosgraph.conf> B<showhost.cgi> B<showservice.cgi> B<ngshared.pm>

=head1 COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

# Main program - change nothing below

use ngshared;

use strict;
use RRDs;
use CGI qw/:standard/;
use File::Find;

# Expect host, service and db input
my $host = param('host') if param('host');
my $service = param('service') if param('service');
my @db = param('db') if param('db');
my $graph = param('graph') if param('graph');
my $geom = param('geom') if param('geom');
my $rrdopts = param('rrdopts') if param('rrdopts');
# Changed fixedscale checking since empty param was returning undef from CGI.pm
my @paramlist = param();
my $fixedscale = 0;
$fixedscale = 1 if (grep /fixedscale/, @paramlist);

# Main #########################################################################
readconfig('read');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	HTMLerror($Config{ngshared});
	exit;
}
getdebug('showgraph', $host, $service); # See if we have custom debug level

$Config{linewidth} = 2 unless $Config{linewidth};

# Draw a graph
$| = 1; # Make sure headers arrive before image data
print header(-type => "image/png");
# Figure out db files and line labels
my $G = graphinfo($host, $service, @db);
my @ds = rrdline($host, $service, $geom, $rrdopts, $G, $graph, $fixedscale);
dumper(4, "RRDs::graph", \@ds);
RRDs::graph(@ds);
if (RRDs::error) {
	debug(2, "RRDs::graph ERR " . RRDs::error);
	dumper(2, "RRDs::graph", \@ds) if $Config{debug} < 4;
}
