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
use warnings;
use CGI qw/:standard/;
use Data::Dumper;
use Fcntl qw(:DEFAULT :flock);
use File::Basename;
use RRDs;

use vars qw(%Config %Navmenu $colorsub $VERSION %Ctrans);
$colorsub = -1;
$VERSION = '1.3.1';

# Debug/logging support ########################################################
my $prog = basename($0);

# Write debug information to log file
sub debug ($$) {
	my ($level, $text) = @_;
	eval {
		return if ($level > $Config{debug});
	};
	return if $@;
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
sub urlencode ($;) {
	my $rval = shift;
	$rval =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	return $rval;
}

sub urldecode ($;) {
	my $rval = shift;
	return '' unless $rval;
	$rval =~ s/\+/ /g;
	$rval =~ s/%([0-9A-F]{2})/chr(hex($1))/eg;
	return $rval;
}

sub getfilename ($$;$;) {
	my ($host, $service, $db) = @_;
	$db ||= '';
	debug(5, "getfilename($host, $service, $db)");
	my ($directory, $filename) = $Config{rrddir};
	debug(5, "getfilename: dbseparator: '$Config{dbseparator}'");
	if ($Config{dbseparator} eq "subdir") {
		$directory .=	"/" . $host;
		unless (-e $directory) { # Create host specific directories
			debug(4, "getfilename: creating directory $directory");
			mkdir $directory, 0775;
			die "$directory not writable" unless -w $directory;
		}
		if ($db) {
			$filename = urlencode("${service}___${db}") . '.rrd';
		} else {
			$filename = urlencode("${service}___");
		}
	} else {
		# Build filename for traditional separation
		if ($db) {
			return $directory, urlencode("${host}_${service}_${db}") . '.rrd'
		} else {
			$filename = urlencode("${host}_${service}_");
		}
	}
	debug(5, "getfilename: returning: $directory, $filename");
	return $directory, $filename;
}

sub HTMLerror ($;$;) {
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
sub hashcolor ($;$;) {
	my $label = shift;
	my $color = shift;
	$color ||= $Config{colorscheme};
	debug(5, "hashcolor($color)");

	# color 9 is user defined (or the default pastel rainbow from below).
	if ($color == 9) {
		# Wrap around, if we have more values than given colors
		$colorsub++;
		$colorsub = 0 if $colorsub >= scalar(@{$Config{color}});
		debug(5, "hashcolor: returning color = " . $Config{color}[$colorsub]);
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
	debug(5, "hashcolor: returning color = $color");
	return $color;
}

# Configuration subroutines ####################################################
# parse the min/max list into a dictionary for quick lookup
sub listtodict ($;$;) {
	my ($val, $commasplit) = @_;
	my ($ii, %rval);
	debug(5, 'listtodict splitting on ' . $Config{$val . 'sep'});
	foreach $ii (split $Config{$val . 'sep'}, $Config{$val}) {
		if ($val eq 'hostservvar') {
			my @data = split(',', $ii);
			dumper(5, 'listtodict hostservvar data', \@data);
			if (defined $rval{$data[0]}) {
				if (defined $rval{$data[0]}->{$data[1]}) {
					$rval{$data[0]}->{$data[1]}->{$data[2]} = 1;
				} else {
					$rval{$data[0]}->{$data[1]} = {$data[2] => 1};
				}
			} else {
				$rval{$data[0]} = {$data[1] => {$data[2] => 1}};
			}
		} elsif ($commasplit) {
			my @data = split(',', $ii);
			dumper(5, 'listtodict commasplit data', \@data);
			$rval{$data[0]} = $data[1];
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
sub readconfig ($;$;) {
	my ($rrdstate, $debug) = @_;
	# Read configuration data
	if ($debug) {
		open LOG, ">&=STDERR";
		$Config{debug} = $debug;
		dumper(5, 'INC', \@INC);
		debug(5, "opening $INC[0]/nagiosgraph.conf'");
	}
	open FH, $INC[0] . '/nagiosgraph.conf' or
		($Config{ngshared} = "$INC[0]/nagiosgraph.conf not found") and
		print $Config{ngshared} and return;
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
	$Config{withmaximumssep} ||= ',';
	$Config{withmaximums} = listtodict('withmaximums')
		if defined $Config{withmaximums};
	$Config{withminimumssep} ||= ',';
	$Config{withminimums} = listtodict('withminimums')
		if defined $Config{withminimums};
	$Config{hostservvarsep} ||= ';';
	$Config{hostservvar} = listtodict('hostservvar')
		if defined $Config{hostservvar};
	$Config{altautoscalesep} ||= ',';
	$Config{altautoscale} = listtodict('altautoscale')
		if defined $Config{altautoscale};
	$Config{altautoscalemaxsep} ||= ';';
	$Config{altautoscalemax} = listtodict('altautoscalemax', 1)
		if defined $Config{altautoscalemax};
	$Config{altautoscaleminsep} ||= ';';
	$Config{altautoscalemin} = listtodict('altautoscalemin', 1)
		if defined $Config{altautoscalemin};
	$Config{nogridfitsep} ||= ',';
	$Config{nogridfit} = listtodict('nogridfit')
		if defined $Config{nogridfit};
	$Config{logarithmicsep} ||= ',';
	$Config{logarithmic} = listtodict('logarithmic')
		if defined $Config{logarithmic};
	$Config{color} ||= 'D05050,D08050,D0D050,50D050,50D0D0,5050D0,D050D0';
	$Config{color} = [split(/\s*,\s*/, $Config{color})];
	$Config{time} ||= 'day week month';
	$Config{timehost} ||= 'day';
	$Config{timeserver} ||= 'day';
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
	if ($Config{dbfile}) {
		require $Config{dbfile};
		$Config{userdb} = $Config{rrddir} . '/users';
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
# Return a list of the data 'lines' in an rrd file
sub getDataItems ($;) {
	my ($file) = @_;
	my ($ds,					# return value from RRDs::info
		$ERR,					# RRDs error value
		%dupes);				# temporary hash to filter duplicate values with
	if (-f $file) {
		$ds = RRDs::info($file);
	} else {
		$ds = RRDs::info("$Config{rrddir}/$file");
	}
	$ERR = RRDs::error();
	if ($ERR) {
		debug(2, "getDataItems: RRDs::info ERR " . $ERR);
		dumper(2, 'getDataItems: ds', $ds);
	}
	return grep { ! $dupes{$_}++ }			# filters duplicate data set names
		map { /ds\[(.*)\]/; $1 }			# returns just the data set names
			grep /ds\[(.*)\]/, keys %$ds;	# gets just the data set fields
}

# Find graphs and values
sub graphinfo ($$@) {
	my ($host, $service, @db) = @_;
	debug(5, "graphinfo($host, $service)");
	my ($hs,					# host/service
		@rrd,					# the returned list of hashes
		$rrd,					# for loop value for each entry in @rrd
		$ds);

	if ($Config{dbseparator} eq "subdir") {
		$hs = $host . "/" . urlencode("$service") . "___";
	} else {
		$hs = urlencode("${host}_${service}") . "_";
	}

	# Determine which files to read lines from
	dumper(5, 'graphinfo: db', \@db);
	if (@db) {
		my ($nn,				# index of @rrd, for inserting entries
			$dd,				# for loop value for each entry in given @db
			$db,				# RRD file name, without extension
			@lines,				# entries after file name from $db
			$ll,				# for loop value for each entry in @lines
			$line,				# value split from $ll
			$unit) = (0);		# value split from $ll
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
		debug(4, "graphinfo: Specified $hs db files in $Config{rrddir}: "
					 . join ', ', map { $_->{file} } @rrd);
	} else {
		@rrd = map {{ file=>$_ }}
					 map { "${hs}${_}.rrd" }
					 dbfilelist($host, $service);
		debug(4, "graphinfo: Listing $hs db files in $Config{rrddir}: "
					 . join ', ', map { $_->{file} } @rrd);
	}

	for $rrd ( @rrd ) {
		unless ( $rrd->{line} ) {
			map { $rrd->{line}{$_} = 1 } getDataItems($rrd->{file});
		}
		debug(5, "graphinfo: DS $rrd->{file} lines: "
					 . join ', ', keys %{$rrd->{line}});
	}
	dumper(5, 'graphinfo: rrd', \@rrd);
	return \@rrd;
}

# Generate all the parameters for rrd to produce a graph
sub rrdline ($$$$$$$;) {
	my ($host, $service, $geom, $rrdopts, $graphinfo, $time, $fixedscale) = @_;
	debug(5, "rrdline($host, $service, $geom, $rrdopts, $time)");
	my ($ii,					# for loop counter
		$file,					# current rrd data file
		$dataset,				# current data item in the rrd file
		$color,					# return value from hashcolor()
		@ds);					# array of strings for use as the command line
	my $directory = $Config{rrddir};

	@ds = ('-', '-a', 'PNG', '--start', "-$time");
	# Identify where to pull data from and what to call it
	for $ii (@$graphinfo) {
		$file = $ii->{file};
		dumper(5, 'rrdline: this graphinfo entry', $ii);

		# Compute the longest label length
		my $longest = (sort map(length,keys(%{$ii->{line}})))[-1];

		for $dataset (sort keys %{$ii->{line}}) {
			$color = hashcolor($dataset);
			debug(5, "rrdline: file=$file dataset=$dataset color=$color");
			my ($serv, $pos) = ($service, length($service) - length($dataset));
			$serv = substr($service, 0, $pos) if (substr($service, $pos) eq $dataset);
			my $label = sprintf("%-${longest}s", $dataset);
			debug(5, "rrdline: label = $label");
			if (defined $Config{maximums}->{$serv}) {
				push @ds, "DEF:$dataset=$directory/$file:$dataset:MAX"
						, "CDEF:ceil$dataset=$dataset,CEIL"
						, "$Config{plotas}:${dataset}#$color:$label";
			} elsif (defined $Config{minimums}->{$serv}) {
				push @ds, "DEF:$dataset=$directory/$file:$dataset:MIN"
						, "CDEF:floor$dataset=$dataset,FLOOR"
						, "$Config{plotas}:${dataset}#$color:$label";
			} else {
				push @ds, "DEF:$dataset=$directory/$file:$dataset:AVERAGE"
						, "$Config{plotas}:${dataset}#$color:$label";
			}
			my $format = '%6.2lf%s';
			$format = '%6.2lf' if ($fixedscale);
			debug(5, "rrdline: format = $format");
			if ($time > 120000) {	# long enough to start getting summation
				if (defined $Config{withmaximums}->{$serv}) {
					my $maxcolor = '888888'; #$color;
					push @ds, "DEF:${dataset}_max=$directory/${file}_max:$dataset:MAX"
							, "LINE1:${dataset}_max#${maxcolor}:maximum";
				}
				if (defined $Config{withminimums}->{$serv}) {
					my $mincolor = 'BBBBBB'; #color;
					push @ds, "DEF:${dataset}_min=$directory/${file}_min:$dataset:MIN"
							, "LINE1:${dataset}_min#${mincolor}:minimum";
				}
				if (defined $Config{withmaximums}->{$serv}) {
					push @ds, "CDEF:${dataset}_maxif=${dataset}_max,UN",
							, "CDEF:${dataset}_maxi=${dataset}_maxif,${dataset},${dataset}_max,IF"
							, "GPRINT:${dataset}_maxi:MAX:Max\\: $format";
				} else {
					push @ds, "GPRINT:$dataset:MAX:Max\\: $format";
				}
				push @ds, "GPRINT:$dataset:AVERAGE:Avg\\: $format";
				if (defined $Config{withminimums}->{$serv}) {
					push @ds, "CDEF:${dataset}_minif=${dataset}_min,UN",
							, "CDEF:${dataset}_mini=${dataset}_minif,${dataset},${dataset}_min,IF"
							, "GPRINT:${dataset}_mini:MIN:Min\\: $format\\n"
				} else {
					push @ds, "GPRINT:$dataset:MIN:Min\\: $format\\n"
				}
			} else {
				push @ds, "GPRINT:$dataset:MAX:Max\\: $format"
						, "GPRINT:$dataset:AVERAGE:Avg\\: $format"
						, "GPRINT:$dataset:MIN:Min\\: $format"
						, "GPRINT:$dataset:LAST:Cur\\: ${format}\\n";
			}
		}
	}

	# Dimensions of graph if geom is specified
	if ($geom) {
		my ($w, $h) = split 'x', $geom;
		push @ds, '-w', $w, '-h', $h;
	} else {
		push @ds, '-w', 600; # just make the graph wider than default
	}
	# Additional parameters to rrd graph, if specified
	if ($rrdopts) {
		my $opt = '';
		foreach $ii (split(/\s+/, $rrdopts)) {
			if (substr($ii, 0, 1) eq '-') {
				$opt = $ii;
				push @ds, $opt;
			} else {
				if ($ds[-1] eq $opt) {
					push @ds, $ii;
				} else {
					$ds[-1] .= " $ii";
				}
			}
		}
	}
	push @ds, "-X", "0" if ($fixedscale);
	push @ds, '-A' if (defined $Config{altautoscale} and
					   exists $Config{altautoscale}{$service} and
					   index($rrdopts, '-A') == -1);
	push @ds, '-J', $Config{altautoscalemin}
		if (defined $Config{altautoscalemin} and
			exists $Config{altautoscalemin}{$service} and
			index($rrdopts, '-J') == -1);
	push @ds, '-M', $Config{altautoscalemax}
		if (defined $Config{altautoscalemax} and
			exists $Config{altautoscalemax}{$service} and
			index($rrdopts, '-M') == -1);
	push @ds, '-N' if (defined $Config{nogridfit} and
					   exists $Config{nogridfit}{$service} and
					   index($rrdopts, '-N') == -1);
	push @ds, '-o' if (defined $Config{logarithmic} and
					   exists $Config{logarithmic}{$service} and
					   index($rrdopts, '-o') == -1);
	debug(5, "rrdline: returning");
	return @ds;
}

# Server/service menu routines #################################################
# Assumes subdir as separator
sub getgraphlist {
	# Builds a hash for available servers/services to graph
	my $current = $_;
	if (-d $current and $current !~ /^\./) { # Directories are for hostnames
		%{$Navmenu{$current}} = () unless checkdirempty($current);
	} elsif (-f $current && $current =~ /\.rrd$/) { # Files are for services
		my ($host, $service, $dataset);
		($host = $File::Find::dir) =~ s|^$Config{rrddir}/||;
		# We got the server to associate with and now
		# we get the service name by splitting on separator
		($service, $dataset) = split(/___/, $current);
		$dataset = substr($dataset, 0, -4) if $dataset;
		#debug(5, "getgraphlist: service = $service, dataset = $dataset");
		if (not exists $Navmenu{$host}{urldecode($service)}) {
			@{$Navmenu{$host}{urldecode($service)}} = (urldecode($dataset));
		} else {
			push @{$Navmenu{$host}{urldecode($service)}}, urldecode($dataset);
		}
	}
}

# If configured, check to see if this user is allowed to see this host.
sub checkPerms ($$;$) {
	my ($host, $user, $authz) = @_;
	return 1 unless $Config{userdb}; # not configured = yes
	my $untie = 1;
	if ($authz) {
		$untie = 0;
	} else {
		tie(%$authz, $Config{dbfile}, $Config{userdb}, O_RDONLY) or return;
	}
	if ($authz->{$host} and $authz->{$host}{$user}) {
		untie %$authz if $untie;
		return 1;
	}
	untie %$authz if $untie;
	return 0;
}

# Inserts the navigation menu (top of the page)
sub printNavMenu ($$$$) {
	my ($host, $service, $fixedscale, $userid) = @_;
	my (@servers, 				# server list in order
		%servers,				# hash of servers -> list of services
		@services,				# list of services on a server
		@dataitems,				# list of values in the current data set
		$com1, $com2,			# booleans for whether or a comma gets printed
		$ii, $jj, $kk);			# for loop counters
	# Get list of servers/services
	find(\&getgraphlist, $Config{rrddir});
	dumper(5, 'printNavMenu: Navmenu', \%Navmenu);

	# Verify the connected user is allowed to see this host.
	if ($Config{userdb}) {
		my %authz;
		tie(%authz, $Config{dbfile}, $Config{userdb}, O_RDONLY) or return;
		foreach $ii (sort keys %Navmenu) {
			push(@servers, $ii) if checkPerms($ii, $userid, \%authz);
		}
		untie %authz;
	} else {
		@servers = sort keys %Navmenu;
	}

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
	print "<script type=\"text/javascript\">\n";
	# Create Javascript Arrays for client-side menu navigation
	print "menudata = new Array();\n";
	for ($ii = 0; $ii < @servers; $ii++) {
		print "menudata[$ii] = [\"$servers[$ii]\", \n";
		@services = sort(keys(%{$Navmenu{$servers[$ii]}}));
		dumper(5, 'printNavMenu: keys', \@services);
		$com1 = 0;
		foreach $jj (@services) {
			if ($com1) {
				print " ,"
			} else {
				print "  "
			}
			print "[\"$jj\",";
			$com2 = 0;
			foreach $kk (@{$servers{$servers[$ii]}{$jj}}) {
				print ',' if $com2;
				print "[\"" . join('","', @$kk) . "\"]";
				$com2 = 1;
			}
			print "]\n";
			$com1 = 1;
		}
		print "];\n";
	}
	print "</script>\n";
	print "<script type=\"text/javascript\" src=\"" .
		$Config{javascript} . "\"></script>\n";

	# Create main form
	print div({-id=>'mainnav'}, "\n",
		start_form(-method=>'GET', -name=>'menuform'),
		# Selecting a new server shows the associated services menu
		trans('selecthost') . ': ',
		popup_menu(-name=>'servidors', -values=>[$host],
				   -onChange=>"setService(this)", -default=>"$host"), "\n",
		# Selecting a new service reloads the page with the new graphs
        trans('selectserv') . ': ',
		popup_menu(-name=>'services', -values=>[$service],
				   -onChange=>"setDb(this)", default=>"$service"), "\n",
		checkbox(-name=>'FixedScale', -label=>trans('fixedscale'),
			-checked=>$fixedscale), "\n",
		button(-name=>'go', -label=>trans('submit'), -onClick=>'jumpto()'),
		"\n",
		div({-id=>'subnav'}, br(), #, -style=>'visibility: visible'
			"\n", trans('selectitems'), "\n",
			popup_menu(-name=>'db', -values=>[],
				-size=>2, -multiple=>1), "\n",
			button(-name=>'clear', -label=>trans('clear'),
				-onClick=>'clearitems()')),
		end_form), "\n",
		# Preload selected host services
		"<script type=\"text/javascript\">preloadSVC(\"$host\",",
		"\"$service\");</script>\n";
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
sub getLabels ($$) {
	my ($service, $db) = @_;
	debug(5, "getLabels($service, $db)");
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

sub urlLabels ($;) {
	my $labels = shift;
	my ($start, @url, $ii) = (0);
	$start = 1 if (@$labels > 1);
	for ($ii = $start; $ii < @$labels; $ii++) {
		push @url, urlencode($labels->[$ii]);
	}
	return '-t%20' . join(",%20", @url);
}

sub printLabels ($;) {
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
sub getRRAs ($$;$;) {
	my ($service, $RRAs, $choice) = @_;
	unless ($choice) {
		if (defined $Config{maximums}->{$service}) {
			$choice = 'MAX';
		} elsif (defined $Config{minimums}->{$service}) {
			$choice = 'MIN';
		} else {
			$choice = 'AVERAGE';
		}
	}
	return "RRA:$choice:0.5:1:$RRAs->[0]", "RRA:$choice:0.5:6:$RRAs->[1]",
		   "RRA:$choice:0.5:24:$RRAs->[2]", "RRA:$choice:0.5:288:$RRAs->[3]";
}

# Create new rrd databases if necessary
sub runCreate ($;) {
	my $ds = shift;
	dumper(5, 'runCreate DS', $ds);
	RRDs::create(@$ds);
	my $ERR = RRDs::error();
	if ($ERR) {
		debug(2, 'runCreate RRDs::create ERR ' . $ERR);
		dumper(2, 'runCreate ds', $ds) if $Config{debug} < 5;
	}
}

sub checkDataSources ($$$$) {
	my ($dsmin, $directory, $filenames, $labels) = @_;
	if (scalar @$dsmin == 3 and scalar @$filenames == 1) {
		debug(1, "createrrd no data sources defined for $directory/$filenames->[0]");
		dumper(1, 'createrrd labels', $labels);
		return 0;
	}
	return 1;
}

sub createrrd ($$$$) {
	my ($host, $service, $start, $labels) = @_;
	debug(5, "createrrd($host, $service, $start, $labels->[0])");
	my ($directory,				# modifiable directory name for rrd database
		@filenames,				# rrd file name(s)
		@datasets,
		$db,					# value of $labels->[0]
		@RRAs,					# number of rows of data kept in each data set
		@resolution,			# temporary hold for configuration values
		@ds,					# rrd create options for regular data
		@dsmin,					# rrd create options for minimum points
		@dsmax,					# rrd create options for maximum points
		$ii,					# for loop counter
		$dsname,				# data set name
		$dstype,				# data set type
		$min);					# expected data set minimum

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
	@dsmin = ("$directory/$filenames[0]_min", '--start', $start);
	@dsmax = ("$directory/$filenames[0]_max", '--start', $start);
	push @datasets, [];
	for ($ii = 0; $ii < @$labels; $ii++) {
		($dsname, $dstype) = ($labels->[$ii]->[0], $labels->[$ii]->[1]);
		$min = $dstype eq 'DERIVE' ? '0' : 'U' ;
		if (defined $Config{hostservvar}->{$host} and
			defined $Config{hostservvar}->{$host}->{$service} and
			defined $Config{hostservvar}->{$host}->{$service}->{$dsname}) {
			my $filename = (getfilename($host, $service . $dsname, $db))[1];
			push @filenames, $filename;
			push @datasets, [$ii];
			if (not -e "$directory/$filename") {
				runCreate(["$directory/$filename", '--start', $start,
					"DS:$dsname:$dstype:$Config{heartbeat}:$min:U",
					getRRAs($service, \@RRAs)]);
			}
			if (defined $Config{withminimums}->{$service} and
				not -e "$directory/${filename}_min") {
				runCreate(["$directory/${filename}_min", '--start', $start,
					"DS:$dsname:$dstype:$Config{heartbeat}:$min:U",
					getRRAs($service, \@RRAs, 'MIN')]);
			}
			if (defined $Config{withmaximums}->{$service} and
				not -e "$directory/${filename}_max") {
				runCreate(["$directory/${filename}_max", '--start', $start,
					"DS:$dsname:$dstype:$Config{heartbeat}:$min:U",
					getRRAs($service, \@RRAs, 'MAX')]);
			}
			next;
		} else {
			push @ds, "DS:$dsname:$dstype:$Config{heartbeat}:$min:U";
			push @{$datasets[0]}, $ii;
			if (defined $Config{withminimums}->{$service}) {
				push @dsmin, "DS:$dsname:$dstype:$Config{heartbeat}:$min:U";
			}
			if (defined $Config{withmaximums}->{$service}) {
				push @dsmax, "DS:$dsname:$dstype:$Config{heartbeat}:$min:U";
			}
		}
	}
	if (not -e "$directory/$filenames[0]" and
		checkDataSources(\@ds, $directory, \@filenames, $labels)) {
		push @ds, getRRAs($service, \@RRAs);
		runCreate(\@ds);
	}
	dumper(5, 'createrrd filenames', \@filenames);
	dumper(5, 'createrrd datasets', \@datasets);
	if (defined $Config{withminimums}->{$service} and
		not -e "$directory/$filenames[0]_min" and
		checkDataSources(\@dsmin, $directory, \@filenames, $labels)) {
		push @dsmin, getRRAs($service, \@RRAs, 'MIN');
		runCreate(\@dsmin);
	}
	if (defined $Config{withmaximums}->{$service} and
		not -e "$directory/$filenames[0]_max" and
		checkDataSources(\@dsmax, $directory, \@filenames, $labels)) {
		push @dsmax, getRRAs($service, \@RRAs, 'MAX');
		runCreate(\@dsmax);
	}
	return \@filenames, \@datasets;
}

# Use RRDs to update rrd file
sub runUpdate ($;) {
	my $dataset = shift;
	dumper(4, "runUpdate dataset", $dataset);
	RRDs::update(@$dataset);
	my $ERR = RRDs::error();
	if ($ERR) {
		debug(2, "runUpdate RRDs::update ERR " . $ERR);
		dumper(2, 'runUpdate dataset', $dataset) if $Config{debug} < 4;
	}
}

sub rrdUpdate ($$$$$;) {
	my ($file, $time, $values, $host, $set) = @_;
	debug(5, "rrdUpdate($file, $time, " . join(' ', @$values) . ", $host, " .
		join(' ', @$set) . ")");
	my ($directory, @dataset, $ii, $service) = ($Config{rrddir});

	# Select target folder depending on config settings
	$directory .= "/$host" if ($Config{dbseparator} eq "subdir");

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
	runUpdate(\@dataset);

	$service = (split('_', $file))[0];
	if (defined $Config{withminimums}->{$service}) {
		$dataset[0] = "$directory/${file}_min";
		runUpdate(\@dataset);
	}
	if (defined $Config{withmaximums}->{$service}) {
		$dataset[0] = "$directory/${file}_max";
		runUpdate(\@dataset);
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
				rrdUpdate($rrds->[$ii], $data[0], $s, $data[1], $sets->[$ii]);
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
	diskpct => 'Disk Usage in Percent',
	http => 'Bits Per Second',
	load => 'System Load Average',
	losspct => 'Loss Percentage',
	'Mem: swap' => 'Swap Utilization',
	mailq => 'Pending Output E-mail Messages',
	memory => 'Memory Usage',
	ping => 'Ping Loss Percentage and Round Trip Average',
	pingloss => 'Ping Loss Percentage',
	pingrta => 'Ping Round Trip Average',
	PLW => 'Perl Log Watcher Events',
	procs => 'Processes',
	qsize => 'Messages in Outbound Queue',
	rta => 'Round Trip Average',
	smtp => 'E-mail Status',

	# These are used as is, in the source. Verify with:
	# grep trans cgi/* etc/* | sed -e 's/^.*trans(\([^)]*\).*/\1/' | sort -u
	asof => 'as of',
	clear => 'clear the list',
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
	selectall => 'select all items',
	selecthost => 'Select server',
	selectitems => 'Optionally, select the data set(s) to graph:',
	selectserv => 'Select service',
	service => 'service',
	submit => 'Update Graphs',
	testcolor => 'Show Colors',
	typesome => 'Type some space seperated nagiosgraph line names here',
);

sub trans ($;$;) {
	my ($text, $quiet) = @_;
	return urldecode($text) if substr($text, 0, 3) eq '%2F';
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
