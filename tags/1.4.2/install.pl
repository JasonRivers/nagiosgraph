#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

use lib 'etc';
use ngshared;
use English qw(-no_match_vars);
use File::Copy;
use File::Path;
use strict;
use warnings;

use constant RWPATH => oct 755; ## no critic (ProhibitConstantPragma)

use vars qw($VERSION);
$VERSION = '0.2';

sub searchdirs {
    my ($base, $subs, $default, $val, $conf) = @_;
    return $conf->{$val} if -d $conf->{$val};
    foreach my $sub (@{$subs}) {
        foreach my $dir (@{$base}) {
            return "$dir$sub" if -d "$dir$sub";
        }
    }
    return $default;
}

sub getpreviousconfig {
    my ($conf) = @_;
    my $inst = "$conf->{etc}/.install";
    if (-f $inst) {
        my ($key, $val);
        open my $CONF, '<', $inst or croak "cannot open $inst: $OS_ERROR\n";  ## no critic (RequireBriefOpen) -- yes perlcritic is drainbamaged
        while (<$CONF>) {
            ## no critic (RegularExpressions)
            s/\s*#.*//;             # Strip comments
            /^(\S+) \s* = \s* (.*)$/x and do { # removes leading whitespace
                $key = $1;
                $val = $2;
                $val =~ s/\s+$//;   # removes trailing whitespace
                $conf->{$key} = $val;
            };
        }
        close $CONF or carp "cannot close $inst: $OS_ERROR";
    }
    return;
}

sub getanswer {
    my ($question, $default) = @_;
    print $question . '? [' . $default . "]\n"; ## no critic (RequireCheckedSyscalls) -- because perlcritic thinks an error printing to the terminal isn't a serious OS problem
    my $answer = readline *STDIN;
    chomp $answer;
    return $default if ($answer =~ /^\s*$/); ## no critic (RegularExpressions) -- because perlcritic doesn't get that some regex's really are simple
    return $answer;
}

sub getfiles {
    my $directory = shift;
    opendir DH, $directory;
    my @files = grep { !/^\./ } readdir DH; ## no critic (RegularExpressions)
    closedir DH;
    return @files;
}

sub backup {
    my ($src, $ext) = @_;
    return if not -f $src;
    print "backing up $src to $src.$ext\n"; ## no critic (RequireCheckedSyscalls)
    #link $src, "$src.$PID";
    #unlink "$src";
    return;
}

sub copyfiles {
    my ($source, $destdir, $conf) = @_;
    if (not $conf->{$source}) {
        print "No destination given.\n"; ## no critic (RequireCheckedSyscalls)
        return;
    }
    my ($destd, $file);
    $file = $destdir . $conf->{$source};
    if (not -d $file) { mkpath $file , 0, RWPATH; }
    foreach my $ii (getfiles($source)) {
        if ($source eq 'share') {
            if (substr($ii, - length 'gif') eq 'gif') {
                # Don't copy images when RPM packaging, since they will conflict
                next if $destdir;
                $destd = $conf->{share} . '/images';
                if (not -d $destd) { mkpath $destd, 0, RWPATH; }
                # Only backup the Nagios provided image.
                if (not -f "$destd/$ii.orig") { backup("$destd/$ii", 'orig'); }
            } elsif (substr($ii, - length 'css') eq 'css') {
                $destd = $conf->{share} . '/stylesheets';
                $file = "$destdir$destd";
                if (not -d $file) { mkpath $file, 0, RWPATH; }
                # Stylesheets may be modified by the end user.
                backup("$destdir$destd/$ii", $PID);
            } elsif (substr($ii, - length 'js') eq 'js') {
                $destd = $conf->{share};
                $file = "$destdir$destd";
                if (not -d $file) { mkpath $file, 0, RWPATH; }
            }
        } elsif ($source eq 'etc') {
            # Configuration files better be modified by the end user.
            backup($destdir . $conf->{$source} . "/$ii", $PID);
            $destd = $conf->{$source};
        } else {
            $destd = $conf->{$source};
        }
        print "installing $source/$ii to $destdir$destd/$ii\n"; ## no critic (RequireCheckedSyscalls)
        copy("$source/$ii", "$destdir$destd/$ii");
    }
    return;
}

sub getconf {
    my ($destdir) = @_;
    my %conf;
    my @conf = (
        (env => 'NGETC', conf => 'etc',
         base => ['/etc', '/usr/local/etc', '/opt'],
         subd => ['/nagios/nagiosgraph', '/nagiosgraph', '/nagios'],
         def => '/etc/nagios/nagiosgraph',
         msg => 'Where should the configuration files go'),
        (env => 'NCGI', conf => 'cgi',
         base => ['/usr/local/lib64', '/usr/local/lib', '/usr/lib64', '/usr/lib'],
         subd => ['/nagios/cgi'],
         def => '/usr/local/lib/nagios/cgi',
         msg => 'Where should the cgi files go'),
        (env => 'NLIB', conf => 'lib',
         base => ['/usr/local/lib64', '/usr/local/lib', '/usr/lib64', '/usr/lib', '/usr/libexec'],
         subd => ['/nagios'],
         def => '/usr/local/lib/nagios',
         msg => 'Where should the executable files go'),
        (env => 'NSHARE', conf => 'share',
         base => ['/usr/local/share', '/usr/share', '/opt'],
         subd => ['/nagios'],
         def => '/usr/local/share/nagios',
         msg => 'Where should the CSS, javascript, and image files go'),
        (env => 'NGSHARE', conf => 'ngshare',
         base => ['/usr/local/share', '/usr/share', '/opt'],
         subd => ['/nagiosgraph'],
         def => '/usr/local/share/nagiosgraph',
         msg => 'Where should the documentation go'),);
    foreach my $ii (@conf) {
        if ($ENV{$ii->{env}}) {
            $conf{$ii->{conf}} = $ENV{$ii->{env}};
        } else {
            $conf{$ii->{conf}} = searchdirs($ii->{base}, $ii->{subd}, $ii->{def}, $ii->{conf}, \%conf);
            $conf{$ii->{conf}} = getanswer($ii->{msg}, $conf{$ii->{conf}});
            if ($ii->{conf} eq 'etc') { getpreviousconfig(\%conf); }
        }
    }

    if (not $destdir and
        getanswer('Modify the Nagios configuration', 'N') =~ /^\s*y/xism) {
        $conf{nagios} = searchdirs(['/usr/local/etc', '/usr/local', '/etc', '/opt'],
                                   ['/nagios'], '/etc/nagios', 'nagios', \%conf);
        $conf{nagios} = getanswer('Where are the Nagios configuration files',
            $conf{nagios});
    } else {
        $conf{nag} = 'N';
    }

    return \%conf;
}

# I'm doing this this way in case .deb packaging uses a similar mechanism.
my $destdir;
if ($ENV{DESTDIR}) {
    $destdir = $ENV{DESTDIR};
} else {
    $destdir = q();
}

my $conf = getconf($destdir);

copyfiles('etc', $destdir, $conf);
copyfiles('cgi', $destdir, $conf);
copyfiles('lib', $destdir, $conf);
copyfiles('share', $destdir, $conf);

my $file = $destdir . $conf->{ngshare};
if (not -d $file) { mkpath $file, 0, RWPATH; }
foreach my $ii (qw(AUTHORS CHANGELOG INSTALL README TODO)) {
    print "installing $ii to $file/$ii\n"; ## no critic (RequireCheckedSyscalls)
    copy($ii, "$file/$ii");
}
foreach my $ii (qw(examples utils)) {
    $file = $destdir . $conf-> {ngshare} . "/$ii";
    if (not -d $file) { mkpath $file, 0, RWPATH; }
    foreach my $jj (getfiles($ii)) {
        print "installing $ii/$jj to $$file/$jj\n"; ## no critic (RequireCheckedSyscalls)
        copy("$ii/$jj", "$file/$jj");
    }
}
if ($destdir) { # We need to copy the images in share
    $file = $destdir . $conf->{ngshare};
    foreach my $ii (getfiles('share')) {
        if (substr($ii, - length 'gif') eq 'gif') {
            print "installing share/$ii to $file/$ii\n"; ## no critic (RequireCheckedSyscalls)
            copy("share/$ii", "$file/$ii");
        }
    }
}

if (not defined $conf->{nag}) {
    print "updating Nagios configuration\n"; ## no critic (RequireCheckedSyscalls)
} else {
    delete $conf->{nag};
}

$conf->{version} = $VERSION;
$file = $destdir . $conf->{etc} . '/.install';
if (open my $FH, '>', $file) {
    foreach my $ii (sort keys %{$conf}) {
        print ${FH} "$ii = $conf->{$ii}\n" or carp "cannot write to $file: $OS_ERROR\n";
    }
    close $FH or carp "cannot close $file: $OS_ERROR\n";
}

__END__

=head1 NAME

install.pl - Install nagiosgraph.

=head1 DESCRIPTION

Run this directly or via `make install`. This copies the contents of the cgi,
etc, lib and share directories into a user configurable set of destinations.

=head1 USAGE

B<install.pl>

=head1 CONFIGURATION

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

Automate this script for use in rpmbuild, etc., by setting these environment
variables:

=over 4

B<NGETC> - the configuration files directory
B<NGSHARE> - documentation, examples, etc. for Nagiosgraph itself

B<NCGI> - the Nagios CGI program directory
B<NLIB> - directory for the programs that only get run by Nagios
B<NSHARE> - the base of the Nagios shared directory

B<DESTDIR> - RPM packaging directory

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over 4

=item B<Nagios>

This provides the data collection system.

=item B<rrdtool>

This provides the data storage and graphing system.

=item B<RRDs>

This provides the perl interface to rrdtool.

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this simple and tested.

=head1 AUTHOR

Alan Brenner - alan.brenner@ithaka.org, the original author in 2008.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
