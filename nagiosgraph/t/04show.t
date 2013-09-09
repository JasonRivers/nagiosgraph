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

## no critic (RequireUseWarnings)
## no critic (ProhibitMagicNumbers)
## no critic (RequireNumberSeparators)
## no critic (RequireBriefOpen)
## no critic (ProhibitPackageVars)
## no critic (ProhibitImplicitNewlines)

use FindBin;
use Test;
use strict;

BEGIN {
## no critic (ProhibitStringyEval)
## no critic (ProhibitPunctuationVars)
    my $rc = eval "
        require RRDs; RRDs->import();
        use Carp;
        use English qw(-no_match_vars);
        use File::Copy qw(copy);
        use File::Path qw(rmtree);
        use IPC::Open3 qw(open3);
        use lib \"$FindBin::Bin/../etc\";
        use ngshared;
    ";
    if ($@) {
        plan tests => 0;
        exit 0;
    } else {
        plan tests => 0;
    }
}

my $src = $FindBin::Bin . '/..';
my $dst = $FindBin::Bin . '/cgitest';
my $app = $dst . '/cgi/show.cgi';

# copy file from src to dst, replace indicated lines.
sub copyfile {
    my ($src, $dst, $fn, %repl) = @_;
    my $ifile = "$src/$fn";
    my $ofile = "$dst/$fn";
    if ( open my $FH, '<', $ifile ) {
        if ( open my $OFH, '>', $ofile ) {
            while( <$FH> ) {
                my $line = $_;
                foreach my $k (keys %repl) {
                    $line =~ s/$k/$repl{$k}/xm;
                }
                print ${OFH} $line or carp "print failed: $OS_ERROR";
            }
            close ${OFH} or carp "close $ofile failed: $OS_ERROR";
        } else {
            carp "cannot write file $ofile: $OS_ERROR";
        }
        close $FH or carp "close $ifile failed: $OS_ERROR";
    } else {
        carp "cannot read file $ifile: $OS_ERROR";
    }
    return;
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
    return;
}

sub teardown {
    rmtree($dst);
    return;
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
    return;
}

sub teardowndata {
    rmtree("$dst/rrd");
    return;
}



# no data in the rrd directory
sub testnodata {
    setup();
    my ($CHILD_IN, $CHILD_OUT, $CHILD_ERR);
    open3($CHILD_IN, $CHILD_OUT, $CHILD_ERR, $app);
    ok($CHILD_OUT, q());
    teardown();
    return;
}

# basic data in the rrd directory, no cgi arguments
sub testnoargs {
    setup();
    setupdata();
    my ($CHILD_IN, $CHILD_OUT, $CHILD_ERR);
    open3($CHILD_IN, $CHILD_OUT, $CHILD_ERR, $app);
    ok($CHILD_OUT, q());
    teardowndata();
    teardown();
    return;
}

sub testperiod {
    setup();
    setupdata();
    my ($CHILD_IN, $CHILD_OUT, $CHILD_ERR);
    open3($CHILD_IN, $CHILD_OUT, $CHILD_ERR, "$app period=week");
    ok($CHILD_OUT, q());
    teardowndata();
    teardown();
    return;
}


#testnodata();
#testnoargs();
#testperiod();
