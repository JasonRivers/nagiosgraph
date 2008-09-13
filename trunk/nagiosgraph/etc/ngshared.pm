#!/usr/bin/perl

# File:    $Id$
# Author:  Soren Dossing, 2005
# License: OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';

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

require Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(%Config %Navmenu debug dumper urlencode urldecode HTMLerror
	hashcolor getgraphlist listtodict readconfig);

use strict;
use Data::Dumper;
use Fcntl ':flock';
use File::Basename;

use vars qw(%Config %Navmenu $colorsub);
$colorsub = -1;

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
sub dumper ($$$) {
	my ($level, $label, $vals) = @_;
	return if ($level > $Config{debug});
	my $dd = Data::Dumper->new([$vals], [$label]);
	$dd->Indent(1);
	my $out = $dd->Dump();
	chomp $out;
	debug($level, $out);
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
	if ($Config{dbseparator} eq "subdir") {
		$directory .=	"/" . $host;
		unless (-e $directory) { # Create host specific directories
			mkdir $directory;
			debug(4, "Creating directory $directory");
		}
		die "$directory not writable" unless -w $directory;
		if ($db) {
			return $directory, urlencode("${service}___${db}") . '.rrd';
		}
		return $directory, urlencode("${service}___");
	}
	# Build filename for traditional separation
	debug(5, "Files stored in single folder structure");
	return $directory, urlencode("${host}_${service}_${db}") . '.rrd' if ($db);
	return $directory, urlencode("${host}_${service}_");
}

sub HTMLerror {
	my $msg = join(" ", @_);
	print header(-type => "text/html", -expires => 0);
	print start_html(-id => "nagiosgraph", -title => 'NagiosGraph Error Page');
	# It might be an error but it doesn't have to look as one
	print '<STYLE TYPE="text/css">div.error { border: solid 1px #cc3333;' .
		' background-color: #fff6f3; padding: 0.75em; }</STYLE>';
	print div({-class => "error"},
			  'Nagiosgraph has detected an error in the configuration file: '
			  . $INC[0] . '/nagiosgraph.conf', br(), $msg);
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
	debug(5, 'splitting on ' . $Config{$val . 'sep'});
	foreach $ii (split $Config{$val . 'sep'}, $Config{$val}) {
		if ($val eq 'hostservvar') {
			debug(1, $val);
			my @data = split(',', $ii);
			dumper(1, 'data', \@data);
			dumper(1, 'rval', \%rval);
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
	return \%rval;
}

# Subroutine for checking that the directory with RRD file is not empty
sub checkdirempty ($) {
	my $directory = shift;
	opendir (DIR, $directory ) or die "couldn't open: $!";
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
	$Config{debug} = $debug if defined $debug;
	open FH, $INC[0] . '/nagiosgraph.conf' or
		($Config{ngshared} = "$INC[0]/nagiosgraph.conf not found") and return; 
	while (<FH>) {
		s/\s*#.*//;		# Strip comments
		/^(\w+)\s*=\s*(.*)\s*$/ and do {
			$Config{$1} = $2;
			$Config{debug} = $debug if defined $debug;
			debug(5, "Config $1:$2");
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
		open LOG, ">>$Config{logfile}" or
			($Config{ngshared} = "cannot append to $Config{logfile}") and return;
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

1;