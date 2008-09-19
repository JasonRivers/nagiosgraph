#!/usr/bin/perl

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

=head1 NAME

showhost.cgi - Graph Nagios data for a given host

=head1 SYNOPSIS

B<showhost.cgi>

=head1 DESCRIPTION

Run this via a web server cgi to generate an HTML page of data stored by
insert.pl. The showgraph.cgi script generates the graphs themselves.

=head1 REQUIREMENTS

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

Install the B<ngshared.pm> file and edit this file to change the B<use lib> line
(line 11) to point to the directory containing B<ngshared.pm>.

Create or edit the example B<hostdb.conf>, which must reside in the same
directory as B<ngshared.pm>.

To link a web page generated by this script from Nagios, add

=over 4

action_url https://server/nagios/cgi-bin/showhost.cgi?host=host1

=back

to the B<define host> (Nagios 3) or B<define hostextinfo> (Nagios 2.12) stanza
(changing the base URL and host1 as needed).

Copy the images/action.gif file to the nagios/images directory, if desired.

=head1 AUTHOR

Soren Dossing, the original author of show.cgi in 2004.

Robert Teeter, the original author of showhost.cgi in 2005

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), using showgraph.cgi, and adding links for show.cgi
and showservice.cgi.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<hostdb.conf> B<nagiosgraph.conf> B<showservice.cgi> B<ngshared.pm>

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

use ngshared qw(:SHOWHOST);

use strict;
use CGI qw/:standard/;
use File::Find;

my ($host,						# Required hostname to show data for
	@style,						# CSS, if so configured
	@times,						# time periods to show
	@sdb,
	$time,
	$dbinfo,
	%dbinfo,
	@gl,
	$ii,						# temporary value for directory and for loops
	$filename,
	@svrlist,
	$labels						# data labels from nagiosgraph.conf
);

readconfig('read');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	HTMLerror($Config{ngshared});
	exit;
}

# Expect host input
if (param('host')) {
	$host = param('host');
} else {
	HTMLerror(trans('nohostgiven'), 1);
	exit;
}

getdebug('showhost', $host, ''); # See if we have custom debug level

# Define graph sizes
@times = graphsizes($Config{timehost});

# Read host/database data
if (not open DB, $Config{hostdb}) {
	debug(5, "cannot open $Config{hostdb} from nagiosgraph configuration");
	HTMLerror(trans('configerror'));
	exit;
}
while (<DB>) {
	chomp($_);
	s/\s*#.*//;    # Strip comments
	if ($_) {
		debug(5, "readdb $_");
		push @sdb, $_;
	}
}
close DB;
if (not @sdb) {
	debug(5, "no servdb array in $Config{hostdb}");
	HTMLerror(trans('configerror'));
	exit;
}

@style = (-style => {-src => "$Config{stylesheet}"}) if ($Config{stylesheet});

# Draw a page
print header, start_html(-id => "nagiosgraph",
	-title => "nagiosgraph: $host",
	#-head => meta({ -http_equiv => "Refresh", -content => "300" }),
	@style) . "\n";

print "<script type=\"text/javascript\">\n" .
	"function jumpto(element) {\n" .
	"	var svr = escape(document.menuform.servidors.value);\n" .
	"	window.location.assign(location.pathname + \"?host=\" + svr);\n" .
	"}\n</script>\n";
find(\&getgraphlist, $Config{rrddir});
@svrlist = sort(keys(%Navmenu));
dumper(5, 'srvlist', \@svrlist);
print div({-id=>'mainnav'}, "\n",
	start_form(-name=>'menuform'), trans('selecthost') . ': ',
	popup_menu(-name=>'servidors', -value=>\@svrlist,
			   -default=>"$host", -onChange=>"jumpto(this)"),
	end_form);

print h1("Nagiosgraph") . "\n" . 
	p(trans('perfforhost') . ': ' . strong(tt(
		a({href => "$Config{nagioscgiurl}/extinfo.cgi?type=1&host=$host"},
			$host))) . ' ' . trans('asof') . ': ' .
		strong(scalar(localtime))) . "\n";

foreach $time ( @times ) {
	dumper(5, 'time', $time);
	print h2(trans($time->[0]));
	foreach $dbinfo ( @sdb ) {
		chomp $dbinfo;
		# split each line by '&' into a hash with key before = and val after 
		%dbinfo = ($dbinfo =~ /([^=&]+)=([^&]*)/g);
		dumper(5, 'dbinfo', \%dbinfo);
		@gl = split ',', $dbinfo{db};
		($ii, $filename) = getfilename($host, urldecode($dbinfo{service}), $gl[0]);
		$filename = $ii . '/' . $filename;
		debug(5, "checkfile $filename");
		if ( -f "$filename") {
			# file found, so generate a heading and graph URL
			debug(5, "checkfile using $filename");
			if (defined $dbinfo{label}) {
				$ii = urldecode($dbinfo{label});
			} else {
				$ii = urldecode($dbinfo{service});
			}
			$labels = getlabels($dbinfo{service}, $dbinfo{db});
			print h2(a({href => $Config{nagioscgiurl} .
					'/showservice.cgi?service=' . urlencode($dbinfo{service}) .
					'&db=' . $dbinfo{db}}, $ii)) . "\n" .
				# URL to showgraph.cgi generated graph
				div({-class => "graphs"}, img({src => 'showgraph.cgi?' .
					join('&', "host=$host", "service=$dbinfo{service}",
						"db=$dbinfo{db}", "graph=$time->[1]"),
					alt => join(', ', @$labels)})) . "\n";
			printlabels($labels);
		} else {
			debug(5, "$filename not found");
		}
	}
}

print div({-id => "footer"}, hr(),
	small(trans('createdby') . ' ' .
	a({href => "http://nagiosgraph.wiki.sourceforge.net/"},
	"Nagiosgraph") . "." ));
print end_html();

