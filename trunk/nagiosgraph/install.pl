#!/usr/bin/perl
# File:		$Id$
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# License:	OSI Artistic License
#			http://www.opensource.org/licenses/artistic-license.php

=head1 NAME

install.pl - Install nagiosgraph.

=head1 SYNOPSIS

B<install.pl>

=head1 DESCRIPTION

Run this directly or via `make install`. This copies the contents of the cgi,
etc, lib and share directories into a user configurable set of destinations.

Automate this script for use in rpmbuild, etc., by setting these environment
variables:

=over 4

B<NGETC> - the configuration files directory
B<NGSHARE> - documentation, extra examples, etc. for Nagiosgraph itself

B<NCGI> - the Nagios CGI program directory
B<NLIB> - directory for the programs that only get run by Nagios
B<NSHARE> - the base of the Nagios shared directory

B<DESTDIR> - RPM packaging directory

=back

=head1 REQUIREMENTS

=over 4

=item B<Nagios>

This provides the data collection system.

=back

=head1 AUTHOR

Alan Brenner - alan.brenner@ithaka.org, the original author in 2008.

=head1 BUGS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

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

use lib 'etc';
use ngshared;
use File::Copy;
use File::Path;
use strict;
use vars qw (%conf $ii $destdir);

sub searchdirs ($$$$) {
	my ($base, $subs, $default, $val) = @_;
	return $conf{$val} if -d $conf{$val};
	my ($sub, $dir);
	foreach $sub (@$subs) {
		foreach $dir (@$base) {
			return "$dir$sub" if -d "$dir$sub";
		}
	}
	return $default;
}

sub getpreviousconfig () {
	if (-f "$conf{etc}/.install" and open CONF, "<$conf{etc}/.install") {
		my ($key, $val);
		while (<CONF>) {
			s/\s*#.*//;				# Strip comments
			/^(\S+)\s*=\s*(.*)$/ and do { # removes leading whitespace
				$key = $1;
				$val = $2;
				$val =~ s/\s+$//;	# removes trailing whitespace
				$conf{$key} = $val;
			};
		}
		close CONF;
	}
}

sub getanswer ($$) {
	my ($question, $default) = @_;
	print $question . '? [' . $default . "]\n";
	my $answer = readline *STDIN;
	chomp $answer;
	return $default if ($answer =~ /^\s*$/);
	return $answer;
}

sub getfiles ($;) {
	my $directory = shift;
	opendir DH, $directory;
	my @files = grep !/^\./, readdir DH;
	closedir DH;
	return @files;
}

sub backup ($$) {
	my ($src, $ext) = @_;
	return unless -f $src;
	print "backing up $src to $src.$ext\n";
	#link $src, "$src.$$";
	#unlink "$src";
}

sub copyfiles ($;) {
	my ($source) = @_;
	if (not $conf{$source}) {
		print "No destination given.\n";
		return;
	}
	my ($ii, $destd);
	mkpath("$destdir$conf{$source}", 0, 0755) unless -d "$destdir$conf{$source}";
	foreach $ii (getfiles($source)) {
		if ($source eq 'share') {
			if (substr($ii, -3) eq 'gif') {
				# Don't copy images when RPM packaging, since they will conflict
				next if $destdir;
				$destd = "$conf{share}/images";
				mkpath($destd, 0, 0755) unless -d $destd;
				# Only backup the Nagios provided image.
				backup("$destd/$ii", 'orig') if not -f "$destd/$ii.orig";
			} elsif (substr($ii, -3) eq 'css') {
				$destd = "$conf{share}/stylesheets";
				mkpath("$destdir$destd", 0, 0755) unless -d "$destdir$destd";
				# Stylesheets may be modified by the end user.
				backup("$destdir$destd/$ii", $$);
			}
		} elsif ($source eq 'etc') {
			# Configuration files better be modified by the end user.
			backup("$destdir$conf{$source}/$ii", $$);
			$destd = $conf{$source};
		} else {
			$destd = $conf{$source};
		}
		print "installing $source/$ii to $destdir$destd/$ii\n";
		copy("$source/$ii", "$destdir$destd/$ii");
	}
}

# I'm doing this this way in case .deb packaging uses a similar mechanism.
if ($ENV{DESTDIR}) {
	$destdir = $ENV{DESTDIR};
} else {
	$destdir = '';
}

if ($ENV{NGETC}) {
	$conf{etc} = $ENV{NGETC};
} else {
	$conf{etc} = searchdirs(['/etc', '/usr/local/etc', '/opt'],
		['/nagios/nagiosgraph', '/nagiosgraph', '/nagios'], 
		'/etc/nagios/nagiosgraph', 'conf');
	$conf{etc} = getanswer('Where should the configuration files go',
		$conf{etc});
	getpreviousconfig();
}

if ($ENV{NCGI}) {
	$conf{cgi} = $ENV{NCGI};
} else {
	$conf{cgi} = searchdirs(['/usr/local/lib64', '/usr/local/lib', '/usr/lib64',
		'/usr/lib'], ['/nagios/cgi'], '/usr/local/lib/nagios/cgi', 'cgi');
	$conf{cgi} = getanswer('Where should the cgi files go', $conf{cgi});
}

if ($ENV{NLIB}) {
	$conf{lib} = $ENV{NLIB};
} else {
	$conf{lib} = searchdirs(['/usr/local/lib64', '/usr/local/lib', '/usr/lib64',
		'/usr/lib', '/usr/libexec'], ['/nagios'],
		'/usr/local/lib/nagios', 'lib');
	$conf{lib} = getanswer('Where should the data loading files go',
		$conf{lib});
}

if ($ENV{NSHARE}) {
	$conf{share} = $ENV{NSHARE};
} else {
	$conf{share} = searchdirs(['/usr/local/share', '/usr/share', '/opt'],
		['/nagios'], '/usr/local/share/nagios', 'share');
	$conf{share} = getanswer('Where should the CSS and GIF files go',
		$conf{share});
}

if ($ENV{NGSHARE}) {
	$conf{ngshare} = $ENV{NGSHARE};
} else {
	$conf{ngshare} = searchdirs(['/usr/local/share', '/usr/share', '/opt'],
		['/nagiosgraph'], '/usr/local/share/nagiosgraph', 'ngshare');
	$conf{ngshare} = getanswer('Where should the nagiosgraph documentation go',
		$conf{ngshare});
}

if (not $destdir and
	getanswer('Modify the Nagios configuration', 'N') =~ /^\s*y/i) {
	$conf{nagios} = searchdirs(['/usr/local/etc', '/usr/local', '/etc', '/opt'],
		['/nagios'], '/etc/nagios', 'nagios');
	$conf{nagios} = getanswer('Where are the Nagios configuration files',
		$conf{nagios});
} else {
	$conf{nag} = 'N'; 
}

copyfiles('etc');
copyfiles('cgi');
copyfiles('lib');
copyfiles('share');

mkpath("$destdir$conf{ngshare}", 0, 0755) unless -d "$destdir$conf{ngshare}";
foreach $ii (qw(AUTHORS CHANGELOG INSTALL README README.map TODO)) {
	print "installing $ii to $destdir$conf{ngshare}/$ii\n";
	copy($ii, "$destdir$conf{ngshare}/$ii");
}
foreach $ii (qw(more_examples utils)) {
	mkpath("$destdir$conf{ngshare}/$ii", 0, 0755)
		unless -d "$destdir$conf{ngshare}/$ii";
	foreach my $jj (getfiles($ii)) {
		print "installing $ii/$jj to $destdir$conf{ngshare}/$ii/$jj\n";
		copy("$ii/$jj", "$destdir$conf{ngshare}/$ii/$jj");
	}
}
if ($destdir) { # We need to copy the images in share
	foreach $ii (getfiles('share')) {
		if (substr($ii, -3) eq 'gif') {
			print "installing share/$ii to $destdir$conf{ngshare}/$ii\n";
			copy("share/$ii", "$destdir$conf{ngshare}/$ii");
		}
	}
}

if (not defined $conf{nag}) {
	print "updating Nagios configuration\n";
} else {
	delete $conf{nag};
}

$conf{version} = $VERSION;
if (open CONF, ">$destdir$conf{etc}/.install") {
	foreach $ii (sort keys %conf) {
		print CONF "$ii = $conf{$ii}\n";
	}
	close CONF;
}
