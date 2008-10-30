#!/usr/bin/perl

# File:    $Id$
# Author:  Soren Dossing, 2005
# License: OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

=head1 NAME

ngshared.pm - shared subroutines for insert.pl, show.cgi, showhost.cgi
and showservice.cgi

=head1 SYNOPSIS

B<use lib '/path/to/this/file';>
B<use ngshared;>

=head1 DESCRIPTION

A shared set of routines for reading configuration files, logging, etc.

=head1 INSTALLATION

Copy this file into a convinient directory (/etc/nagios/nagiosgraph, for
example) and modify the show*.cgi files to B<use lib> the directory this file
is in.

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into this
shared file (ngshared.pm) for use by insert.pl and the show*.cgi files.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<insert.pl> B<show.cgi> B<showhost.cgi> B<showservice.cgi>

=head1 COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

use strict;
use CGI qw/:standard/;
use Data::Dumper;
use Fcntl ':flock';
use File::Basename;
use RRDs;

use vars qw(%Config %Navmenu $colorsub $VERSION %Ctrans);
$colorsub = -1;
$VERSION = '1.1.1';

# Debug/logging support ########################################################
my $prog = basename($0);

# Write debug information to log file
sub debug ($$) {
	my ($level, $text) = @_;
	return if ($level > $Config{debug});
	$level = qw(none critical error warn info debug)[$level];
	# Get a lock on the LOG file (blocking call)
	flock(LOG, LOCK_EX);
	print LOG scalar (localtime) . " $prog $level - $text\n";
	flock(LOG, LOCK_UN);
}

# Dump to log the files read from Nagios
sub dumper ($$$;) {
	my ($level, $label, $vals) = @_;
	return if ($level > $Config{debug});
	my $dd = Data::Dumper->new([$vals], [$label]);
	$dd->Indent(1);
	my $out = $dd->Dump();
	chomp $out;
	debug($level, substr($out, 1));
}

sub getdebug ($;$$) {
	my ($type, $server, $service) = @_;
	#debug(5, "getdebug($type, $server, $service)");
	# All this allows debugging one service, or one server,
	# or one service on one server, for each line of input.
	my $base = 'debug_' . $type;
	my $host = 'debug_' . $type . '_host';
	my $serv = 'debug_' . $type . '_service';
	if (defined $Config{$base}) {
		#debug(5, "getdebug found $base");
		if (defined $Config{$host}) {
			#debug(5, "getdebug found $host");
			if ($Config{$host} eq $server) {
				if (defined $Config{$serv}) {
					#debug(5, "getdebug found $serv with $host");
					if ($Config{$serv} eq $service) {
						$Config{debug} = $Config{$base};
					}
				} else {
					$Config{debug} = $Config{$base};
				}
			}
		} elsif (defined $Config{$serv}) {
			#debug(5, "getdebug found $serv");
			if ($Config{$serv} eq $service) {
				$Config{debug} = $Config{$base};
			}
		} else {
			$Config{debug} = $Config{$base};
		}
	}
}

# HTTP support #################################################################
# URL encode a string
sub urlencode ($) {
	my $rval = shift;
	$rval =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	return $rval;
}

sub urldecode ($) {
	my $rval = shift;
	$rval =~ s/\+/ /g;
	$rval =~ s/%([0-9A-F]{2})/chr(hex($1))/eg;
	return $rval;
}

sub getfilename ($$;$) {
	my ($host, $service, $db) = @_;
	$db ||= '';
	debug(5, "getfilename($host, $service, $db)");
	my $directory = $Config{rrddir};
	debug(5, "getfilename dbseparator: '$Config{dbseparator}'");
	if ($Config{dbseparator} eq "subdir") {
		$directory .=	"/" . $host;
		unless (-e $directory) { # Create host specific directories
			mkdir $directory;
			debug(4, "getfilename creating directory $directory");
		}
		die "$directory not writable" unless -w $directory;
		if ($db) {
			return $directory, urlencode("${service}___${db}") . '.rrd';
		}
		return $directory, urlencode("${service}___");
	}
	# Build filename for traditional separation
	debug(5, "getfilename files stored in single folder structure");
	return $directory, urlencode("${host}_${service}_${db}") . '.rrd' if ($db);
	return $directory, urlencode("${host}_${service}_");
}

sub HTMLerror ($;$) {
	my ($msg, $bConf) = @_;
	print header(-type => "text/html", -expires => 0);
	print start_html(-id => "nagiosgraph", -title => 'NagiosGraph Error Page');
	# It might be an error but it doesn't have to look as one
	print '<STYLE TYPE="text/css">div.error { border: solid 1px #cc3333;' .
		' background-color: #fff6f3; padding: 0.75em; }</STYLE>';
	if (not $bConf) {
		print div({-class => "error"},
				  'Nagiosgraph has detected an error in the configuration file: '
				  . $INC[0] . '/nagiosgraph.conf.');
	}
	print div($msg);
	print end_html();
}

# Color subroutines ############################################################
# Choose a color for service
sub hashcolor ($;$) {
	my $label = shift;
	my $color = shift;
	$color ||= $Config{colorscheme};
	debug(5, "hashcolor($color)");

	# color 9 is user defined (or the default pastel rainbow from below).
	if ($color == 9) {
		# Wrap around, if we have more values than given colors
		$colorsub++;
		$colorsub = 0 if $colorsub >= scalar(@{$Config{color}});
		debug(5, "color = " . $Config{color}[$colorsub]);
		return $Config{color}[$colorsub];
	}

	my ($min, $max, $rval, $ii, @rgb) = (0, 0);
	# generate a starting value
	map { $color = (51 * $color + ord) % (216) } split //, $label;
	# turn the starting value into a red, green, blue triplet
	@rgb = (51 * int($color / 36), 51 * int($color / 6) % 6, 51 * ($color % 6));
	for $ii (0..2) {
		$min = $ii if $rgb[$ii] < $rgb[$min];
		$max = $ii if $rgb[$ii] > $rgb[$max];
	}
	# expand the color range, if needed
	$rgb[$min] = 102 if $rgb[$min] > 102;
	$rgb[$max] = 153 if $rgb[$max] < 153;
	# generate the hex color value
	$color = sprintf "%06X", $rgb[0] * 16 ** 4 + $rgb[1] * 256 + $rgb[2];
	debug(5, "color = $color");
	return $color;
}

# Configuration subroutines ####################################################
# Assumes subdir as separator
sub getgraphlist {
	# Builds a hash for available servers/services to graph
	my $current = $_;
	if (-d $current and $current !~ /^\./) { # Directories are for hostnames
		$Navmenu{$current}{'NAME'} = $current unless checkdirempty($current);
	} elsif (-f $current && $current =~ /\.rrd$/) { # Files are for services
		my ($host, $service);
		($host = $File::Find::dir) =~ s|^$Config{rrddir}/||;
		# We got the server to associate with and now
		# we get the service name by splitting on separator
		($service) = split(/___/, $current);
		${$Navmenu{$host}{'SERVICES'}{urldecode($service)}}++;
	}
}

# parse the min/max list into a dictionary for quick lookup
sub listtodict ($) {
	my $val = shift;
	my ($ii, %rval);
	debug(5, 'listtodict splitting on ' . $Config{$val . 'sep'});
	foreach $ii (split $Config{$val . 'sep'}, $Config{$val}) {
		if ($val eq 'hostservvar') {
			my @data = split(',', $ii);
			dumper(5, 'listtodict data', \@data);
			if (defined $rval{$data[0]}) {
				if (defined $rval{$data[0]}->{$data[1]}) {
					$rval{$data[0]}->{$data[1]}->{$data[2]} = 1;
				} else {
					$rval{$data[0]}->{$data[1]} = {$data[2] => 1};
				}
			} else {
				$rval{$data[0]} = {$data[1] => {$data[2] => 1}};
			}
		} else {
			$rval{$ii} = 1;
		}
	}
	dumper(5, 'listtodict rval', \%rval);
	return \%rval;
}

# Subroutine for checking that the directory with RRD file is not empty
sub checkdirempty ($;) {
	my $directory = shift;
	unless (opendir(DIR, $directory)) {
		debug(1, "couldn't open: $!");
		return 0;
	}
	my @files = readdir DIR;
	my $size = scalar @files;
	closedir DIR;
	return 0 if $size > 2;
	return 1;
}

# Read in the config file, check the log file and rrd directory
sub readconfig ($;$) {
	my ($rrdstate, $debug) = @_;
	# Read configuration data
	if ($debug) {
		open LOG, ">&=STDERR";
		$Config{debug} = $debug;
		dumper(5, 'INC', \@INC);
		debug(5, "opening $INC[0]/nagiosgraph.conf'");
	}
	open FH, $INC[0] . '/nagiosgraph.conf' or
		($Config{ngshared} = "$INC[0]/nagiosgraph.conf not found") and return;
	my ($key, $val);
	while (<FH>) {
		s/\s*#.*//;				# Strip comments
		/^(\S+)\s*=\s*(.*)$/ and do { # removes leading whitespace
			$key = $1;
			$val = $2;
			$val =~ s/\s+$//;	# removes trailing whitespace
			$Config{$key} = $val;
			$Config{debug} = $debug if $key eq 'debug' and defined $debug;
			debug(5, "Config $key:$val");
		};
	}
	close FH;
	$Config{maximumssep} ||= ',';
	$Config{maximums} = listtodict('maximums') if defined $Config{maximums};
	$Config{minimumssep} ||= ',';
	$Config{minimums} = listtodict('minimums') if defined $Config{minimums};
	$Config{hostservvarsep} ||= ';';
	$Config{hostservvar} = listtodict('hostservvar') if defined $Config{hostservvar};
	$Config{color} ||= 'D05050,D08050,D0D050,50D050,50D0D0,5050D0,D050D0';
	$Config{color} = [split(/\s*,\s*/, $Config{color})];
	# If debug is set make sure we can write to the log file
	if ($Config{debug} > 0) {
		if (not open LOG, ">>$Config{logfile}") {
			open LOG, ">&=STDERR";
			$Config{ngshared} = "cannot append to $Config{logfile}";
			return;
		}
		dumper(5, 'Config', \%Config);
	}
	if ($rrdstate eq 'write') {
		# Make sure rrddir exist and is writable
		unless (-w $Config{rrddir}) {
			mkdir $Config{rrddir} or $Config{ngshared} = $!;
		}
		$Config{ngshared} = "rrd dir $Config{rrddir} not writable"
			unless (-w $Config{rrddir} and not defined $Config{ngshared});
	} else {
		# Make sure rrddir is readable and not empty
		if (-r $Config{rrddir} ) {
			$Config{ngshared} = "$Config{rrddir} is empty"
				if checkdirempty($Config{rrddir});
			return;
		}
		$Config{ngshared} = "rrd dir $Config{rrddir} not readable";
	}
}

# show.cgi subroutines here for unit testability ###############################
# Shared routines ##############################################################
# Get list of matching rrd files
sub dbfilelist ($$) {
	my ($host, $serv) = @_;
	my ($directory, $filename) = (getfilename($host, $serv));
	debug(5, "scanning $directory for $filename");
	opendir DH, $directory;
	my @rrd = grep s/^${filename}(.+)\.rrd$/$1/, readdir DH;
	closedir DH;
	dumper(5, 'dbfilelist', \@rrd);
	return @rrd;
}

# Graphing routines ############################################################
# Find graphs and values
sub graphinfo ($$@) {
	my ($host, $service, @db) = @_;
	debug(5, "graphinfo($host, $service)");
	my ($hs, @rrd, $rrd, $ds, $dsout, @values, %H, %R);

	if ($Config{dbseparator} eq "subdir") {
		$hs = $host . "/" . urlencode("$service") . "___";
	} else {
		$hs = urlencode("${host}_${service}") . "_";
	}

	# Determine which files to read lines from
	dumper(5, 'db', \@db);
	if (@db) {
		my ($nn, $dd, $db, @lines, $ll, $line, $unit) = (0);
		for $dd (@db) {
			($db, @lines) = split ',', $dd;
			$rrd[$nn]{file} = $hs . urlencode("$db") . '.rrd';
			for $ll (@lines) {
				($line, $unit) = split '~', $ll;
				if ($unit) {
					$rrd[$nn]{line}{$line}{unit} = $unit if $unit;
				} else {
					$rrd[$nn]{line}{$line} = 1;
				}
			}
			$nn++;
		}
		debug(4, "Specified $hs db files in $Config{rrddir}: "
					 . join ', ', map { $_->{file} } @rrd);
	} else {
		@rrd = map {{ file=>$_ }}
					 map { "${hs}${_}.rrd" }
					 dbfilelist($host,$service);
		debug(4, "Listing $hs db files in $Config{rrddir}: "
					 . join ', ', map { $_->{file} } @rrd);
	}

	for $rrd ( @rrd ) {
		unless ( $rrd->{line} ) {
			$ds = RRDs::info("$Config{rrddir}/$rrd->{file}");
			my $ERR = RRDs::error();
			if ($ERR) {
				debug(2, "RRDs::info ERR " . $ERR);
				dumper(2, 'rrd', $rrd);
			}
			map { $rrd->{line}{$_} = 1 }
				grep { ! $H{$_}++ }
					map { /ds\[(.*)\]/; $1 }
						grep /ds\[(.*)\]/, keys %$ds;
		}
		debug(5, "DS $rrd->{file} lines: "
					 . join ', ', keys %{$rrd->{line}});
	}
	dumper(5, 'rrd', \@rrd);
	return \@rrd;
}

# Generate all the parameters for rrd to produce a graph
sub rrdline ($$$$$$$;) {
	my ($host, $service, $geom, $rrdopts, $G, $time, $fixedscale) = @_;
	debug(5, "rrdline($host, $service, $geom, $rrdopts, $time)");
	my ($g, $f, $v, $c, @ds);
	my $directory = $Config{rrddir};

	@ds = ('-', '-a', 'PNG', '--start', "-$time");
	# Identify where to pull data from and what to call it
	for $g ( @$G ) {
		$f = $g->{file};
		dumper(5, 'g', $g);

		# Compute the longest label length
		my $longest = (sort map(length,keys(%{ $g->{line} })))[-1];

		for $v ( sort keys %{ $g->{line} } ) {
			$c = hashcolor($v);
			debug(5, "file=$f line=$v color=$c");
			my ($sv, $serv, $pos) = ($v, $service, length($service) - length($v));
			$serv = substr($service, 0, $pos) if (substr($service, $pos) eq $v);
			my $label = sprintf("%-${longest}s", $sv);
			if (defined $Config{maximums}->{$serv}) {
				push @ds , "DEF:$sv=$directory/$f:$v:MAX"
								 , "$Config{plotas}:${sv}#$c:$label";
			} elsif (defined $Config{minimums}->{$serv}) {
				push @ds , "DEF:$sv=$directory/$f:$v:MIN"
								 , "$Config{plotas}:${sv}#$c:$label";
			} else {
				push @ds , "DEF:$sv=$directory/$f:$v:AVERAGE"
								 , "$Config{plotas}:${sv}#$c:$label";
			}
			my $format = '%6.2lf%s';
			if ($fixedscale) { $format = '%6.2lf'; }

			# Graph labels
			push @ds, "GPRINT:$sv:MAX:Max\\: $format"
							, "GPRINT:$sv:AVERAGE:Avg\\: $format"
							, "GPRINT:$sv:MIN:Min\\: $format"
							, "GPRINT:$sv:LAST:Cur\\: ${format}\\n";
		}
	}

	# Dimensions of graph if geom is specified
	if ( $geom ) {
		my ($w, $h) = split 'x', $geom;
		push @ds, '-w', $w, '-h', $h;
	} else {
		push @ds, '-w', 600; # just make the graph wider than default
	}
	# Additional parameters to rrd graph, if specified
	if ( $rrdopts ) {
		push @ds, split /\s+/, $rrdopts;
	}
	if ( $fixedscale ) {
		push @ds, "-X", "0";
	}
	return @ds;
}

# Server/service menu routines #################################################
# Inserts the navigation menu (top of the page)
sub printNavMenu ($$$;) {
	my ($host, $service, $fixedscale) = @_;
	# Get list of servers/services
	find(\&getgraphlist, $Config{rrddir});
	# Create Javascript Arrays for client-side menu navigation
	print "<script type=\"text/javascript\">\n";
	print "	function newOpt(serv) {\n"; 
	print "		switch (serv) {\n";
	foreach my $system (sort keys %Navmenu) {
		my $crname = $Navmenu{$system}{'NAME'};
		# JavaScript doesn't like "-" characters in variable names
		$crname =~s/\W/_/g;
		# JavaScript names can't start with digits
		$crname =~s/^(\d)/_$1/;
		print "			case \"$crname\":\n"; 
		#print "var ". $crname . " = new Array(\"" .
		print "				var aa = new Array(\"" .
			join('","', sort(keys(%{$Navmenu{$system}{'SERVICES'}}))) . "\");\n"; 
		print "				break;\n"; 
	}
	print "			default:\n\n"; 
	print "			}\n"; 
	print "		return aa;\n"; 
	print "	}\n";

	# Bulk Javascript code
	print <<END;
	//Swaps the secondary (services) menu content after a server is selected
	function setOptionText(element) {
		var server = element.options[element.selectedIndex].text;
		//Converts - in hostnames to _ for matching array name
		server = server.replace(/-/g,"_");
		server = server.replace(/\\./g,"_");
		var svchosen = window.document.menuform.services;
		var opciones = newOpt(server);
		// Adjust service dropdown menu length depending on host selected
		svchosen.length = opciones.length;
		for (i = 0; i < opciones.length; i++) {
			svchosen.options[i].text = opciones[i];
		}
		if (opciones.length == 1 && arguments.length == 1) {
			jumpto(svchosen);
		}
	}
	//Once a service is selected this function loads the new page
	function jumpto(element) {
		var svr = escape (document.menuform.servidors.value);
		var svc = escape (element.options[element.selectedIndex].text);
		var newURL = location.pathname + "?host=";
		newURL += svr + "&" + "service=" + svc;
		newURL += getURLparams();
		window.location.assign ( newURL ) ;
	}
	//Auxiliary URL builder function for "jumpto" keeping the params
	function getURLparams() {
		var query=this.location.search.substring(1);
		var myParams="";
		if (query.length > 0){
			var params = query.split("&");

			for (var i=0 ; i<params.length ; i++){
				var pos = params[i].indexOf("=");
				var name = params[i].substring(0, pos);
				var value = params[i].substring(pos + 1);

				//Append "safe" params (geom, rrdopts)
				if ( name == "geom" || name == "rrdopts") {
					myParams+= "&" + name + "=" + value;
				}
				// Jumpto defines host & service, checkbox selects fixedscale and
				//	we can't determine db from JS so we discard it (enter manually)
			}

		}
		// Keep track of fixedscale parameter
		if ( document.menuform.FixedScale.checked) {
			myParams+= "&" + "fixedscale";
		}
		return (myParams);
	}

	//Forces the service menu to be filled with the correct entries
	//when the page loads
	function preloadSVC(name) {
		var notfound = true;
		var i = 0;
		while (notfound && i < document.menuform.servidors.length) {
			if (document.menuform.servidors.options[i].text == name) {
				notfound = false;
				document.menuform.servidors.selectedIndex = i;
			}
			i++;
		}
		setOptionText(document.menuform.servidors, 1);
	}
</script>
END
	# Create main form
	my @svrlist = sort keys %Navmenu;
	my @ServiceNames = sort keys %{$Navmenu{$host}{'SERVICES'}};
	print div({-id=>'mainnav'}, "\n",
		start_form(-method=>'GET', -name=>'menuform'),
		# Selecting a new server shows the associated services menu
		trans('selecthost') . ': ',
		popup_menu(-name=>'servidors', -value=>\@svrlist,
				   -default=>"$host", -onChange=>"setOptionText(this)"),
		# Selecting a new service reloads the page with the new graphs
		"\n" . trans('selectserv') . ': ',
		popup_menu(-name=>'services', -value=>\@ServiceNames,
				   -onChange=>"jumpto(this)", default=>"$service"), "\n",
		checkbox(-name=>'FixedScale', -label=>trans('fixedscale'),
			-checked=>$fixedscale), "\n",
		button(-name=>'go', -value=>trans('submit'),
			-onClick=>'jumpto(document.menuform.services)'),
		end_form . "\n") .
		# Preload selected host services
		"<script type=\"text/javascript\">var prtHost=\"$host\";" .
		"preloadSVC(prtHost);</script>\n";
}

# Full page routine ############################################################
# Determine the number of graphs that will be displayed on the page
# and the time period they will cover.
sub graphsizes ($;) {
	my $conf = shift;
	# Pre-defined available graph sizes
	#	 Daily		=  33h = 118800s
	#	 Weekly		=   9d = 777600s
	#	 Monthly	=   5w = 3024000s
	#	 Quarterly	=  14w = 8467200s
	#	 Yearly		= 400d = 34560000s

	# Values in config file
	my @config_times = split(/ /, $conf);
	my @final_t;

	# [Label, period span, offset] (in seconds)
	my @default_times = (['dai', 118800, 86400], ['week', 777600, 604800],
		['month', 3024000, 2592000], ['year', 34560000, 31536000]);

	# Configuration entry was absent or empty. Use default
	if (! @config_times) {
		@final_t = @default_times;
	} else {
		# Try to match known entries from configuration file
		grep(/^day$/, @config_times) and push @final_t, $default_times[0];
		grep(/^week$/, @config_times) and push @final_t, $default_times[1];
		grep(/^month$/, @config_times) and push @final_t, $default_times[2];
		grep(/^quarter$/, @config_times) and push @final_t,
			['quarter', 8467200, 7776000];
		grep(/^year$/, @config_times) and push @final_t, $default_times[3];

		# Final check to see if we matched any known entry or use default
		@final_t = @default_times unless @final_t;
	}

	return @final_t;
}

# Graph labels, if so configured
sub getlabels ($$) {
	my ($service, $db) = @_;
	debug(5, "getlabels($service, $db)");
	my $val = trans($service, 1);
	if ($val ne $service) {
		debug(5, "returning [$val]");
		return [$val];
	}
	my ($ii, @labels);
	foreach $ii (split(',', $db)) {
		$val = trans($ii);
		if ($val ne $ii ) {
			push @labels, $val;
		}
	}
	@labels = (trans('graph')) unless @labels;
	dumper(5, "returning labels", \@labels);
	return \@labels;
}

sub printlabels ($;) {
	my ($labels) = @_;
	return if $Config{nolabels};
	unless (scalar @$labels == 1 and $labels->[0] eq trans('graph')) {
		my ($start, $ii) = (0);
		print '<div>';
		$start = 1 if (@$labels > 1);
		for ($ii = $start; $ii < @$labels; $ii++) {
			print div({-class => "graph_description"},
				cite(small($labels->[$ii]))) . "\n";
		}
		print "</div>\n";
	}
}

# insert.pl subroutines here for unit testability ##############################
# Check that we have some data to work on
sub inputdata () {
	my @inputlines;
	if ( $ARGV[0] ) {
		@inputlines = $ARGV[0];
	} elsif ( defined $Config{perflog} ) {
		if (-s $Config{perflog}) {
			my $worklog = $Config{perflog} . ".nagiosgraph";
			rename($Config{perflog}, $worklog);
			open PERFLOG, $worklog;
			while (<PERFLOG>) {
				push @inputlines, $_;
			}
			close PERFLOG;
			unlink($worklog);
		}
		debug(5, "inputdata empty $Config{perflog}") unless (@inputlines);
	}
	return @inputlines;
}

# Process received data
sub getRRAs ($@) {
	my ($service, @RRAs) = @_;
	my $choice;
	if (defined $Config{maximums}->{$service}) {
		$choice = 'MAX';
	} elsif (defined $Config{minimums}->{$service}) {
		$choice = 'MIN';
	} else {
		$choice = 'AVERAGE';
	}
	return "RRA:$choice:0.5:1:$RRAs[0]", "RRA:$choice:0.5:6:$RRAs[1]",
		   "RRA:$choice:0.5:24:$RRAs[2]", "RRA:$choice:0.5:288:$RRAs[3]";
}

# Create new rrd databases if necessary
sub createrrd ($$$$) {
	my ($host, $service, $start, $labels) = @_;
	debug(5, "createrrd($host, $service, $start, $labels->[0])");
	my ($directory,				# modifiable directory name for rrd database
		@filenames,				# rrd file name(s)
		@datasets,
		$db,
		@RRAs,
		@resolution,
		@ds,
		$ii,
		$v,
		$t,
		$u);

	if (defined $Config{resolution}) {
		@resolution = split(/ /, $Config{resolution});
		dumper(4, 'createrrd resolution',  \@resolution);
	}

	$RRAs[0] = defined $resolution[0] ? $resolution[0] : 600;
	$RRAs[1] = defined $resolution[1] ? $resolution[1] : 700;
	$RRAs[2] = defined $resolution[2] ? $resolution[2] : 775;
	$RRAs[3] = defined $resolution[3] ? $resolution[3] : 797;

	$db = shift @$labels;
	($directory, $filenames[0]) = getfilename($host, $service, $db);
	debug(5, "createrrd checking $directory/$filenames[0]");
	@ds = ("$directory/$filenames[0]", '--start', $start);
	push @datasets, [];
	for ($ii = 0; $ii < @$labels; $ii++) {
		($v, $t) = ($labels->[$ii]->[0], $labels->[$ii]->[1]);
		$u = $t eq 'DERIVE' ? '0' : 'U' ;
		if (defined $Config{hostservvar}->{$host} and
			defined $Config{hostservvar}->{$host}->{$service} and
			defined $Config{hostservvar}->{$host}->{$service}->{$v}) {
			my $filename = (getfilename($host, $service . $v, $db))[1];
			push @filenames, $filename;
			push @datasets, [$ii];
			my @dsub = ("$directory/$filename", '--start', $start);
			push @dsub, "DS:$v:$t:$Config{heartbeat}:$u:U";
			push @dsub, getRRAs($service, @RRAs);
			dumper(5, 'createrrd DSub', \@dsub);
			unless (-e "$directory/$filename") {
				RRDs::create(@dsub);
				my $ERR = RRDs::error();
				if ($ERR) {
					debug(2, 'createrrd RRDs::create ERR ' . $ERR);
					dumper(2, 'createrrd dsub', \@dsub) if $Config{debug} < 5;
				}
			}
			next;
		} else {
			push @ds, "DS:$v:$t:$Config{heartbeat}:$u:U";
			push @{$datasets[0]}, $ii;
		}
	}
	unless (-e "$directory/$filenames[0]") {
		if (scalar @ds == 3) {
			if (scalar @filenames == 1) {
				debug(1, "createrrd no data sources defined for $directory/$filenames[0]");
				dumper(1, 'createrrd labels', $labels);
				return;
			}
		}
		push @ds, getRRAs($service, @RRAs);
		dumper(5, 'createrrd DS', \@ds);
		RRDs::create(@ds);
		my $ERR = RRDs::error();
		if ($ERR) {
			debug(2, 'createrrd RRDs::create ERR ' . $ERR);
			dumper(2, 'createrrd ds', \@ds) if $Config{debug} < 5;
		}
	}
	dumper(5, 'createrrd filenames', \@filenames);
	dumper(5, 'createrrd datasets', \@datasets);
	return \@filenames, \@datasets;
}

# Use RRDs to update rrd file
sub rrdupdate ($$$$$;) {
	my ($file, $time, $values, $host, $set) = @_;
	debug(5, "rrdupdate($file, $time, $values, $host, $set)");
	my ($directory, @dataset, $ii) = ($Config{rrddir});

	# Select target folder depending on config settings
	$directory .= "/" . $host if ($Config{dbseparator} eq "subdir");

	push @dataset, "$directory/$file",  $time;
	for ($ii = 0; $ii < @$values; $ii++) {
		for (@$set) {
			if ($ii == $_) {
				$values->[$ii]->[2] ||= 0;
				$dataset[1] .= ":$values->[$ii]->[2]";
				last;
			}
		}
	}

	dumper(4, "rrdupdate RRDs::update", \@dataset);
	RRDs::update(@dataset);
	my $ERR = RRDs::error();
	if ($ERR) {
		debug(2, "rrdupdate RRDs::update ERR " . $ERR);
		dumper(2, 'rrdupdate dataset', \@dataset) if $Config{debug} < 4;
	}
}

# Read the map file and define a subroutine that parses performance data
sub getrules ($;) {
	my $file = shift;
	my (@rules, $rules);
	open FH, $file;
	while (<FH>) {
		push @rules, $_;
	}
	close FH;
	$rules = 'sub evalrules {
		$_ = $_[0];
		my ($d, @s) = ($_);
		no strict "subs";' . join('', @rules) . '
		use strict "subs";
		return () if ($s[0] eq "ignore");
		debug(3, "perfdata not recognized:\ndate||host||desc||out||data for:\n" .
			$d) unless @s;
		return @s;
	}';
	undef $@;
	eval $rules;
	debug(2, "Map file eval error: $@ in: $rules") if $@;
}

# Process all input performance data
sub processdata (@) {
	debug(5, 'processdata(' . scalar(@_) . ')');
	my (@data, $debug, $s, $rrds, $sets, $ii);
	for my $line (@_) {
		@data = split(/\|\|/, $line);
		# Suggested by Andrew McGill for 0.9.0, but I'm (Alan Brenner) not sure
		# it is still needed due to urlencoding in file names by getfilename.
		# replace spaces with - in the description so rrd doesn't choke
		# $data[2] =~ s/\W+/-/g;
		$debug = $Config{debug};
		getdebug('insert', $data[1], $data[2]);
		dumper(5, 'processdata data', \@data);
		$_ = "servicedescr:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
		for $s ( evalrules($_) ) {
			($rrds, $sets) = createrrd($data[1], $data[2], $data[0] - 1, $s);
			next unless $rrds;
			for ($ii = 0; $ii < @$rrds; $ii++) {
				rrdupdate($rrds->[$ii], $data[0], $s, $data[1], $sets->[$ii]);
			}
		}
		$Config{debug} = $debug;
	}
}

# I18N #########################################################################
%Ctrans = (
	# These come from the time, timehost and timeservice values defined in
	# nagiosgraph.conf. +ly is the adverb form.
	dai => 'Today',
	daily => 'Daily',
	day => 'Today',
	week => 'This Week',
	weekly => 'Weekly',
	month => 'This Month',
	monthly => 'Monthly',
	year => 'This Year',
	yearly => 'Yearly',

	# These come from Nagios, so are just from what I use.
	apcupsd => 'Uninterruptible Power Supply Status', 
	bps => 'Bits Per Second',
	clamdb => 'Clam Database',
	diskgb => 'Disk Usage in GigaBytes',
	http => 'Bits Per Second',
	load => 'System Load Average',
	losspct => 'Loss Percentage',
	'Mem: swap' => 'Swap Utilization',
	mailq => 'Pending Output E-mail Messages',
	memory => 'Memory Usage',
	ping => 'Ping Loss Percentage and Round Trip Average',
	PLW => 'Perl Log Watcher Events',
	procs => 'Processes',
	qsize => 'Messages in Outbound Queue',
	rta => 'Round Trip Average',
	smtp => 'E-mail Status',

	# These are used as is, in the source. Verify with:
	# grep trans cgi/* etc/* | sed -e 's/^.*trans(\([^)]*\).*/\1/' | sort -u
	asof => 'as of',
	configerror => 'Configuration Error',
	createdby => 'Created by',
	fixedscale => 'Fixed Scale',
	graph => 'Graph',
	next => 'next',
	nohostgiven => 'Bad URL &mdash; no host given',
	noservicegiven => 'Bad URL &mdash; no service given',
	perfforhost => 'Performance data for host',
	perfforserv => 'Performance data for service',
	previous => 'previous',
	selecthost => 'Select server',
	selectserv => 'Select service',
	service => 'service',
	submit => 'Update Graphs',
	testcolor => 'Show Colors',
	typesome => 'Type some space seperated nagiosgraph line names here',
);

sub trans ($;$;) {
	my ($text, $quiet) = @_;
	return $Config{$text} if $Config{$text};
	return $Config{urlencode($text)} if $Config{urlencode($text)};
	unless ($Config{warned} or $quiet) {
		debug(3, "define '" . urlencode($text) . "' in nagiosgraph.conf");
		$Config{warned} = 1;
	}
	# The hope is not to get to here except in the case of upgrades where
	# nagiosgraph.conf doesn't have the translation values.
	return $Ctrans{$text} if $Ctrans{$text};
	unless ($Config{ctrans} or $quiet) {
		debug(1, "define '$text' in ngshared.pm (in %Ctrans) and report it, please");
		$Config{ctrans} = 1;
	}
	# This can get ugly, so make sure %Ctrans has everything.
	return $text
}

1;
