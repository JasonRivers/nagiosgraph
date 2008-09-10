#!/usr/bin/perl

# File:		$Id: insert.pl,v 1.25 2007/06/12 19:00:06 toriniasty Stab $
# Author:	(c) Soren Dossing, 2005
# License:	OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';

=head1 NAME

insert.pl - Store performance data returned by Nagios plugins in rrdtool.

=head1 SYNOPSIS

B<insert.pl "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$">

=head1 DESCRIPTION

Run this via Nagios (using insert.sh, if needed).

=head1 REQUIREMENTS

=over 4

=item B<Nagios>

This provides the data collection system.

=item B<rrdtool>

This provides the data storage and graphing system.

=back

=head1 INSTALLATION

Copy this file someplace, and make sure it is executable by Nagios.

Install the B<ngshared.pm> file and edit this file to change the B<use lib> line
(line 10) to point to the directory containing B<ngshared.pm>.

Create or edit the example B<nagiosgraph.conf>, which must reside in the same
directory as B<ngshared.pm>.

In the Nagios configuration set

=over 4

process_performance_data=1

=back

and

=over 4

service_perfdata_command=process-service-perfdata

=back

and create a command like:

=over 4

define command {
 command_name process-service-perfdata
 command_line /usr/local/lib/nagios/insert.pl "$LASTSERVICECHECK$||$HOSTNAME$||$SERVICEDESC$||$SERVICEOUTPUT$||$SERVICEPERFDATA$"
}

=back

Other configurations may be possible, but this works for me (Alan Brenner) with
Nagios 2.12 on Mac OS 10.5.

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version
at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into a
shared file (ngshared.pm), tweaking logging, etc.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<nagiosgraph.conf> B<ngshared.pm>

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
			@inputlines = <PERFLOG>;
			close PERFLOG;
			unlink($worklog);
		}
	}

	# Quit if there are no data to process
	unless ( @inputlines ) {
		debug(4, 'No input data.');
		if ($ARGV[0]) {
			debug(5, "Got '$ARGV[0]' on command line")
		} else {
			debug(5, "empty $Config{perflog}");
		}
		#exit 1; # no, no, no don't exit. leave that to higher up to decide.
	}
	return @inputlines;
}

# Process received data ########################################################
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
		dumper(4, 'resol',  \@resolution);
	}

	$RRAs[0] = defined $resolution[0] ? $resolution[0] : 600;
	$RRAs[1] = defined $resolution[1] ? $resolution[1] : 700;
	$RRAs[2] = defined $resolution[2] ? $resolution[2] : 775;
	$RRAs[3] = defined $resolution[3] ? $resolution[3] : 797;

	$db = shift @$labels;
	($directory, $filenames[0]) = getfilename($host, $service, $db);
	debug(5, "Checking $directory/$filenames[0]");
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
			dumper(5, 'DSub', \@dsub);
			unless (-e "$directory/$filename") {
				RRDs::create(@dsub);
				if (RRDs::error) {
					debug(2, 'RRDs::create ERR ' . RRDs::error);
					dumper(2, 'dsub', \@dsub) if $Config{debug} < 5;
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
				debug(1, "no data sources defined for $directory/$filenames[0]");
				dumper(1, 'labels', $labels);
				return;
			}
		}
		push @ds, getRRAs($service, @RRAs);
		dumper(5, 'DS', \@ds);
		RRDs::create(@ds);
		if (RRDs::error) {
			debug(2, 'RRDs::create ERR ' . RRDs::error);
			dumper(2, 'ds', \@ds) if $Config{debug} < 5;
		}
	}
	dumper(5, 'filenames', \@filenames);
	dumper(5, 'datasets', \@datasets);
	return \@filenames, \@datasets;
}

# Use RRDs to update rrd file
sub rrdupdate ($$$$$;) {
	my ($file, $time, $values, $host, $set) = @_;
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

	dumper(4, "RRDs::update", \@dataset);
	RRDs::update(@dataset);
	if (RRDs::error) {
		debug(2, "RRDs::update ERR " . RRDs::error);
		dumper(2, 'dataset', \@dataset) if $Config{debug} < 4;
	}
}

# Process all input performance data
sub processdata (@) {
	my (@data, $S, $s, $rrds, $sets, $ii);
	for my $line (@_) {
		@data = split(/\|\|/, $line);
		# All this allows debugging one service, or one server,
		# or one service on one server
		if (defined $Config{debug_insert}) {
			if (defined $Config{debug_insert_host}) {
				if ($Config{debug_insert_host} eq $data[1]) {
					if (defined $Config{debug_insert_service}) {
						if ($Config{debug_insert_service} eq $data[2]) {
							$Config{debug_save} = $Config{debug};
							$Config{debug} = $Config{debug_insert};
						}
					} else {
						$Config{debug_save} = $Config{debug};
						$Config{debug} = $Config{debug_insert};
					}
				}
			} elsif (defined $Config{debug_insert_service} and
					 $Config{debug_insert_service} eq $data[2]) {
				$Config{debug_save} = $Config{debug};
				$Config{debug} = $Config{debug_insert};
			}
		}
		dumper(5, 'perfdata', \@data);
		$_ = "servicedescr:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
		$S = evalrules($_);
		for $s ( @$S ) {
			($rrds, $sets) = createrrd($data[1], $data[2], $data[0] - 1, $s);
			for ($ii = 0; $ii < @$rrds; $ii++) {
				rrdupdate($rrds->[$ii], $data[0], $s, $data[1], $sets->[$ii]);
			}
		}
		$Config{debug} = $Config{debug_save};
	}
}

# Main #########################################################################
#	- Read config and input
#	- Update rrd files
#	- Create them first if necesary.

readconfig('write');
if (defined $Config{ngshared}) {
	debug(1, $Config{ngshared});
	exit;
}
$Config{debug} = $Config{debug_insert} if defined $Config{debug_insert} and
	not defined $Config{debug_insert_host} and
	not defined $Config{debug_insert_service};

our @perfdata = inputdata();
exit 0 unless @perfdata;

# Read the map file and define a subroutine that parses performance data
undef $/;
open FH, $Config{mapfile};
my $rules = <FH>;
close FH;
$rules = 'sub evalrules {
	$_ =$_[0];
	my ($d, @s) = ($_);
	no strict "subs";' . $rules . '
	use strict "subs";
	return () if ($s[0] eq "ignore");
	debug(3, "perfdata not recognized:\ndate||host||desc||out||data for:\n" .
		join("\n", @perfdata)) unless @s;
	return \@s;
}';
undef $@;
eval $rules;
debug(2, "Map file eval error: $@") if $@;

#while (1) {
processdata(@perfdata) if @perfdata;
#	sleep 30;
#}

debug(5, 'nagiosgraph exited');
