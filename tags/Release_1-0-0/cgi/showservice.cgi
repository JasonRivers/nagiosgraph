#!/usr/bin/perl

# This program is based upon show.cgi, and showhost.cgi
# Author:  (c) Soren Dossing, 2004
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Robert Teeter, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';

=head1 NAME

showhost.cgi - Graph Nagios data for a given host

=head1 SYNOPSIS

B<showhost.cgi>

=head1 DESCRIPTION

Run this via a web server cgi to generate an HTML page of data stored by
insert.pl. The show.cgi script generates the graphs themselves.

=head1 REQUIREMENTS

=over 4

=item B<Nagios>

While this could probably run without Nagios, as long as RRD databases exist,
it is intended to work along side Nagios.

=item B<show.cgi>

This generates the graphs shown in the HTML generated here.

=back

=head1 INSTALLATION

Copy this file into Nagios' cgi directory (for the Apache web server, see where
the ScriptAlias for /nagios/cgi-bin points), and make sure it is executable by
the web server.

Install the B<ngshared.pm> file and edit this file to change the B<use lib> line
(line 11) to point to the directory containing B<ngshared.pm>.

Create or edit the example B<servdb.conf>, which must reside in the same
directory as B<ngshared.pm>.

Copy the images/action.gif file to the nagios/images directory, if desired.

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005

Alan Brenner - alan.brenner@ithaka.org; I've written this based on Robert
Teeter's showhost.cgi.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<servdb.conf> B<nagiosgraph.conf> B<showhost.cgi> B<ngshared.pm>

=head1 COPYRIGHT

Copyright (C) 2008 Ithaka Harbors, Inc.

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
use CGI qw/:standard/;
use File::Find;

# Main program - change nothing below

# Write a pretty page with various graphs
sub page ($;){
	my ($service) = @_;
	debug(5, "page($service)");

	# Define graph sizes
	#   Daily   =  33h =   118800s
	my @times = (['daily', 118800]);
	my (@hdb,
		@sdb,
		$time,
		$host,
		%dbinfo,
		%dbtmp,
		@gl,
		$imgprm,
		$directory,
		$filename
		);

	# Read service/database data
	open SD, "$Config{servdb}" or die "cannot open $Config{servdb}";
	while (<SD>) {
		chomp($_);
		s/\s*#.*//;    # Strip comments
		if ($_) {
			debug(5, "CGI ServDB $_");
			if (substr($_, 0, 4) eq 'host') {
				@hdb = split(/\s*,\s*/, (split('=', $_))[1]);
			} else {
				%dbtmp = ($_ =~ /([^=&]+)=([^&]*)/g);
				#dumper(5, 'dbtmp', \%dbtmp);
				$dbtmp{service} = urldecode($dbtmp{service});
				push @sdb, $dbtmp{service};
				debug(5, "$dbtmp{service} eq $service");
				if ($dbtmp{service} eq $service) {
					%dbinfo = ($_ =~ /([^=&]+)=([^&]*)/g);
				}
			}
		}
	}
	close SD;
	dumper(5, 'hdb', \@hdb);
	$dbinfo{db} = param('db') if param('db');
	dumper(5, 'dbinfo', \%dbinfo);

	print "<script type=\"text/javascript\">\n" .
		"function jumpto(element) {\n" .
		"	var svr = escape(document.menuform.servidors.value);\n" .
		"	window.location.assign(location.pathname + \"?service=\" + svr);\n" .
		"}\n</script>\n";
	find(\&getgraphlist, $Config{rrddir});
	my @svrlist = sort(@sdb);
	dumper(5, 'srvlist', \@svrlist);
	print div({-id=>'mainnav'}, "\n",
		start_form(-name=>'menuform'),
		"Select service: ",
		popup_menu(-name=>'servidors', -value=>\@svrlist,
				   -default=>"$service", -onChange=>"jumpto(this)"),
		end_form);

	my $label = $service;
	$label = $dbinfo{label} if exists $dbinfo{label};
	print h1("Nagiosgraph") . "\n" . 
		p('Performance data for service: ' . strong(tt(urldecode($label))) .
			' for today: ' . strong(scalar(localtime))) . "\n";
	if (@hdb) {
		for $time ( @times ) {
			dumper(5, 'time', $time);
			for $host ( @hdb ) {
				debug(5, "host = $host");
				$imgprm = join('&', "host=$host", "service=$service",
					"db=$dbinfo{db}", "graph=$time->[1]");
				@gl = split ',', $dbinfo{db};
				($directory, $filename) = getfilename($host, urldecode($service), $gl[0]);
				$filename = $directory . '/' . $filename;
				debug(5, "checkfile $filename");
				if ( -f "$filename") {
					debug (5, "checkfile using $filename");
					print h2(a({href => $Config{nagioscgiurl} .
							'/show.cgi?host=' . urlencode($host) .
							'&service=' . urlencode($service)}, $host));
					print img({src=>"show.cgi?$imgprm"}) . "\n";
				} else {
					debug(5, "$filename not found");
				}
			}
		}
	} else {
		debug(5, "no servdb array in nagiosgraph configuration");
	}
}

readconfig('read');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	HTMLerror($Config{ngshared});
	exit;
}

# Expect host, service and db input
my $service;
$service = param('service') if param('service');
$Config{debug} = $Config{debug_showservice}
	if (defined $Config{debug_showservice} and
		(not defined $Config{debug_showservice_service} or
		 $Config{debug_showservice_service} eq $service));
debug (5, "service = $service");
my @style;
@style = (-style => {-src => "$Config{stylesheet}"}) if ($Config{stylesheet});
# Draw a page
print header, start_html(-id => "nagiosgraph",
	-title => "nagiosgraph: $service",
	#-head => meta({ -http_equiv => "Refresh", -content => "300" }),
	@style) . "\n";
page($service);
print div({-id => "footer"}, hr(),
	small( "Created by " . a({href => "http://nagiosgraph.wiki.sourceforge.net/"},
		"Nagiosgraph") . "." ));
print end_html();

