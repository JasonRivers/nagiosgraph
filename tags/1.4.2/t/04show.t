#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

# this file contains subroutines to test the cgi scripts.  although we could
# compare HTML output from the cgi to something expected, that is a rather
# brittle set of tests.  prolly better to compare for just a portion of the
# HTML.

use strict;
use FindBin;
use File::Copy qw(copy);
use File::Path qw(rmtree);
use Test;
use lib "$FindBin::Bin/../etc";
use ngshared qw(createrrd %Config);

BEGIN { plan tests => 0; }

my $src = $FindBin::Bin . '/..';
my $dst = $FindBin::Bin . '/cgitest';
my $app = $dst . '/cgi/show.cgi';

# copy file from src to dst, replace indicated lines.
sub copyfile {
    my ($src, $dst, $fn, %repl) = @_;
    my $ifile = "$src/$fn";
    my $ofile = "$dst/$fn";
    if ( open my $FH, $ifile ) {
        if ( open my $OFH, ">$ofile" ) {
            while( <$FH> ) {
                my $line = $_;
                foreach my $k (keys %repl) {
                    $line =~ s/$k/$repl{$k}/;
                }
                print $OFH $line;
            }
            close $OFH;
        } else {
            croak("cannot write file $ofile");
        }
        close $FH;
    } else {
        croak("cannot read file $ifile");
    }
}

# create directories and copy files used in the tests
sub setup {
    rmtree($dst);
    mkdir $dst;
    mkdir $dst . '/cgi';
    mkdir $dst . '/etc';
    mkdir $dst . '/rrd';
    mkdir $dst . '/log';
    copyfile("$src/etc", "$dst/etc", 'ngshared.pm');
    copyfile("$src/cgi", "$dst/cgi", 'show.cgi',
             ('/opt/nagiosgraph/etc' => "$dst/etc"));
    chmod 0775, "$dst/cgi/show.cgi";
    copyfile("$src/etc", "$dst/etc", 'nagiosgraph.conf',
             ('/etc/nagiosgraph' => "$dst/etc",
              '/var/log' => "$dst/log",
              '/var/nagiosgraph/rrd' => "$dst/rrd",));
}

sub teardown {
    rmtree($dst);
}

# create rrd files used in the tests
#   host   service   db     ds1,ds2,...
#   host0  PING      ping   losspct,rta
#   host0  HTTP      http   Bps
sub setupdata {
    $Config{dbseparator} = 'subdir';
    $Config{heartbeat} = 600;
    $Config{rrddir} = "$dst/rrd";

    my $testvar = ['ping',
                   ['losspct', 'GAUGE', 0],
                   ['rta', 'GAUGE', .006] ];
    my @result = createrrd('host0', 'PING', 1221495632, $testvar);
    $testvar = ['http',
                ['Bps', 'GAUGE', 0] ];
    @result = createrrd('host0', 'HTTP', 1221495632, $testvar);
}

sub teardowndata {
    rmtree("$dst/rrd");
}



# no data in the rrd directory
sub testnodata {
    setup();
    ok(`$app`, "");
    teardown();
}

# basic data in the rrd directory, no cgi arguments
sub testnoargs {
    setup();
    setupdata();
    ok(`$app`, "");
    teardowndata();
    teardown();
}

sub testperiod {
    setup();
    setupdata();
    ok(`$app period=week`, "");
    teardowndata();
    teardown();
}


#testnodata();
#testnoargs();
#testperiod();
