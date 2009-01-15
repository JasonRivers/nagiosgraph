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

buildjs.pl - Build a JavaScript file for the current configuration for show.cgi.

=head1 SYNOPSIS

B<buildjs.pl>

=head1 DESCRIPTION

Run this after any addition or removal of servers in the Nagios configuration,
or any change to the map that will cause new RRD files, or data items within the
RRD files.

=head1 INSTALLATION

Copy this file into a PATH directory (/usr/local/bin, for example).

Install the B<ngshared.pm> file and edit this file to change the B<use lib> line
(line 10) to point to the directory containing B<ngshared.pm>.

Copy the nagiosgraph.js file into the Nagios lib directory
(/usr/local/lib/nagios, for example).

Create or edit the example B<nagiosgraph.conf>, which must reside in the same
directory as B<ngshared.pm>. Modify the three JavaScript related entries.

=head1 AUTHOR

Alan Brenner - alan.brenner@ithaka.org; I've created this from the ngshared.pm
file in order to generate the JavaScript file once per change, rather than every
run of show.cgi.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<ngshared.pm> B<nagiosgraph.conf> B<show.cgi>

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
use File::Find;

use strict;

my (@servers, 					# server list in order
	%servers,					# hash of servers -> list of services
	@services,					# list of services on a server
	@dataitems,					# list of values in the current data set
	$com1, $com2,				# booleans for whether or a comma gets printed
	$ii, $jj, $kk);				# for loop counters

readconfig('read');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	exit;
}
getdebug('buildjs');

open OUT, ">&=STDOUT"; #">$Config{javascriptfs}" or die "$!\n";

# Get list of servers/services
find(\&getgraphlist, $Config{rrddir});
dumper(5, 'printNavMenu: Navmenu', \%Navmenu);

@servers = sort keys %Navmenu;

foreach $ii (@servers) {
	@services = sort(keys(%{$Navmenu{$ii}}));
	foreach $jj (@services) {
		foreach $kk (@{$Navmenu{$ii}{$jj}}) {
			@dataitems = getDataItems(join('/', getfilename($ii, $jj, $kk)));
			if (not exists $servers{$ii}) {
				$servers{$ii} = {};
			}
			if (not exists $servers{$ii}{$jj}) {
				$servers{$ii}{$jj} = [];
			}
			push @{$servers{$ii}{$jj}}, [$kk, @dataitems];
		}
	}
}
dumper(5, 'servers', \%servers);

# Create Javascript Arrays for client-side menu navigation
print OUT "menudata = new Object();\n";
foreach $ii (@servers) {
	$jj = jsName($ii);
	print OUT "menudata[\"$jj\"] = [\n";
	@services = sort(keys(%{$Navmenu{$ii}}));
	dumper(5, 'printNavMenu: keys', \@services);
	$com1 = 0;
	foreach $jj (@services) {
		if ($com1) {
			print OUT "  ,"
		} else {
			print OUT "   "
		}
		print OUT "[\"$jj\",";
		$com2 = 0;
		foreach $kk (@{$servers{$ii}{$jj}}) {
			print OUT ',' if $com2;
			print OUT "[\"" . join('","', @$kk) . "\"]";
			$com2 = 1;
		}
		print OUT "]\n";
		$com1 = 1;
	}
	print OUT "  ];\n";
}

open IN, "<$Config{javascriptsource}" or
	die "Cannot open $Config{javascriptsource}: $!\n";
while (<IN>) {
	print OUT $_;
}
close IN or die "$!\n";
close OUT or die "$!\n";