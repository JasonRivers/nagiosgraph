#!/usr/bin/perl

# This program is based upon show.cgi, and showhost.cgi
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

Robert Teeter, the original author of showhost.cgi in 2005.

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

my ($service,					# Required service to show data for
	@style,						# CSS, if so configured
	@times,						# time periods to show
	@hdb,
	@sdb,
	$time,
	$host,
	%dbinfo,
	%dbtmp,
	@gl,
	$ii,						# temporary value for directory and for loops
	$filename,
	$label, $labels,			# data labels from nagiosgraph.conf
	$title,						# boolean for when to print the labels
	$url						# url parameters for showgraph.cgi
	);

readconfig('read');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	HTMLerror($Config{ngshared});
	exit;
}

# Expect service input
if (param('service')) {
	$service = urldecode(param('service'));
} else {
	HTMLerror(trans('noservicegiven'), 1);
	exit;
}

getdebug('showservice', '', $service); # See if we have custom debug level

# Define graph sizes
@times = graphsizes($Config{timeservice});

# Read service/database data
if (not open SD, "$Config{servdb}") {
	debug(5, "cannot open $Config{servdb} from nagiosgraph configuration");
	HTMLerror(trans('configerror'));
	exit;
}
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
if (not @hdb) {
	debug(5, "no hostdb array in $Config{hostdb}");
	HTMLerror(trans('configerror'));
	exit;
}
if (not @sdb) {
	debug(5, "no servdb array in $Config{hostdb}");
	HTMLerror(trans('configerror'));
	exit;
}

@style = (-style => {-src => "$Config{stylesheet}"}) if ($Config{stylesheet});

# Draw a page
print header, start_html(-id => "nagiosgraph",
	-title => "nagiosgraph: $service",
	#-head => meta({ -http_equiv => "Refresh", -content => "300" }),
	@style) . "\n";

print "<script type=\"text/javascript\">\n" .
	"function jumpto(element) {\n" .
	"	var svr = escape(document.menuform.servidors.value);\n" .
	"	window.location.assign(location.pathname + \"?service=\" + svr);\n" .
	"}\n</script>\n";
find(\&getgraphlist, $Config{rrddir});
my @svrlist = sort(@sdb);
dumper(5, 'srvlist', \@svrlist);
foreach $ii (@svrlist) {
	debug(5, "checking $ii vs $service and " . urldecode($service));
	if ($ii eq $service) {
		$label = $service;
		last;
	}
	$label = urldecode($service);
	if ($ii eq $label) {
		last;
	}
	undef $label;
}
debug(5, "default = $label");
print div({-id=>'mainnav'}, "\n",
	start_form(-name=>'menuform'), trans('selectserv') . ': ',
	popup_menu(-name=>'servidors', -value=>\@svrlist,
			   -default=>"$label", -onChange=>'jumpto(this)'),
	end_form);

if (exists $dbinfo{label}) {
	$label = $dbinfo{label};
} else {
	$label = $service;
}
print h1("Nagiosgraph") . "\n" .
	p(trans('perfforserv') . ': ' . strong(tt(urldecode($label))) . ' ' .
		trans('asof') . ': ' . strong(scalar(localtime))) . "\n";

if (exists $Config{graphlabels} and not exists $Config{nolabels}) {
	$title = 1;
} else {
	$title = 0;
}
foreach $time ( @times ) {
	dumper(5, 'time', $time);
	print h2(trans($time->[0]));
	foreach $host ( @hdb ) {
		debug(5, "host = $host");
		@gl = split ',', $dbinfo{db};
		($ii, $filename) = getfilename($host, urldecode($service), $gl[0]);
		$filename = $ii . '/' . $filename;
		debug(5, "checkfile $filename");
		if ( -f "$filename") {
			# file found, so generate a heading and graph URL
			debug (5, "checkfile using $filename");
			$labels = getLabels($service, $dbinfo{db});
			# URL to showgraph.cgi generated graph
			$url = join('&', "host=$host", "service=$dbinfo{service}",
				"db=$dbinfo{db}", "graph=$time->[1]");
			$url .= '&rrdopts=' . urlLabels($labels) if $title;
			print h2(a({href => $Config{nagioscgiurl} .
					'/show.cgi?host=' . urlencode($host) .
					'&service=' . urlencode($service)}, $host)) . "\n" .
				# URL to showgraph.cgi generated graph
				div({-class => "graphs"}, img({src => 'showgraph.cgi?' . $url,
					alt => join(', ', @$labels)})) . "\n";
			printLabels($labels) unless $title;
		} else {
			debug(5, "$filename not found");
		}
	}
}

print div({-id => "footer"}, hr(),
	small(trans('createdby') . ' ' .
	a({href => "http://nagiosgraph.wiki.sourceforge.net/"},
	"Nagiosgraph " . $VERSION) . "." ));
print end_html();

