#!/usr/bin/perl
# $Id: 02ngshared.t 468 2011-01-08 20:30:46Z mwall $
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

# tests to ensure backward compatibility.  any deprecated configuration
# parameters and/or formatting go here.

## no critic (RequireUseWarnings)
## no critic (ProhibitMagicNumbers)
## no critic (ProhibitImplicitNewlines)

use FindBin;
use Test;
use strict;

BEGIN {
    my $rc = eval {
        require RRDs; RRDs->import();
        use CGI qw(:standard escape unescape);
        use Data::Dumper;
        use File::Find;
        use File::Path qw(rmtree);
        use lib "$FindBin::Bin/../etc";
        use ngshared;
    };
    if ($rc) {
        plan tests => 0;
        exit 0;
    } else {
        plan tests => 45;
    }
}

sub testconvertdeprecated {
    my %cfg;
    $cfg{lineformat} = 'warn,LINE3,FFFFFF';
    convertdeprecated(\%cfg);
    ok($cfg{lineformat}, 'warn=LINE3,FFFFFF');
    $cfg{lineformat} = 'warn,LINE3,FFFFFF;crit,STACK,FFAAFF';
    convertdeprecated(\%cfg);
    ok($cfg{lineformat}, 'warn=LINE3,FFFFFF;crit=STACK,FFAAFF');
    return;
}

# plotasLINE1
# plotasLINE2
# plotasLINE3
# plotasAREA
# plotasTICK
# stack
#
# 1.4.3 and earlier used this format:
#   datasource1[,datasource2[,datasource3[,...]]]
# 1.4.4 introduced this format:
#   [[[host,]service,]database,]datasource;[[[h2,]s2,]db2,]ds2
#
# lineformat
#
# 1.4.3 and earlier used this format:
#   ds-name,linestyle[,color][,STACK]
# 1.4.4 introduced this format:
#   [[[host,]service,]database,]ds-name=linestyle[,color][,STACK]
#
sub testlineformats {
    $Config{colorscheme} = 1;
    $Config{plotas} = 'LINE1';
    $Config{plotasLINE1} = 'avg5min,avg15min';
    $Config{plotasLINE2} = 'a';
    $Config{plotasLINE3} = 'b';
    $Config{plotasAREA} = 'ping';
    $Config{plotasTICK} = 'http';
    $Config{stack} = 's';

    $Config{plotasLINE1list} = str2list($Config{plotasLINE1}, q(,));
    $Config{plotasLINE2list} = str2list($Config{plotasLINE2}, q(,));
    $Config{plotasLINE3list} = str2list($Config{plotasLINE3}, q(,));
    $Config{plotasAREAlist} = str2list($Config{plotasAREA}, q(,));
    $Config{plotasTICKlist} = str2list($Config{plotasTICK}, q(,));
    $Config{stacklist} = str2list($Config{stack}, q(,));

    my ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'foo');
    ok($linestyle, 'LINE1');
    ok($linecolor, '000399');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'ping');
    ok($linestyle, 'AREA');
    ok($linecolor, '990333');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'http');
    ok($linestyle, 'TICK');
    ok($linecolor, '000099');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'avg15min');
    ok($linestyle, 'LINE1');
    ok($linecolor, '6600FF');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'a');
    ok($linestyle, 'LINE2');
    ok($linecolor, 'CC00CC');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'b');
    ok($linestyle, 'LINE3');
    ok($linecolor, 'CC00FF');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 's');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'CC03CC');
    ok($stack, 1);

    # test basic lineformat behavior

    $Config{lineformat} = 'warn,LINE1,D0D050;crit,LINE2,D05050;total,AREA,dddddd88';
    convertdeprecated(\%Config);
    $Config{lineformatlist} = str2list($Config{lineformat});
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'crit');
    ok($linestyle, 'LINE2');
    ok($linecolor, 'D05050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'total');
    ok($linestyle, 'AREA');
    ok($linecolor, 'dddddd88');
    ok($stack, 0);

    # test various lineformat combinations and permutations

    $Config{lineformat} = 'warn,LINE1,D0D050;crit,D05050,LINE2;total,STACK,AREA,dddddd88';
    convertdeprecated(\%Config);
    $Config{lineformatlist} = str2list($Config{lineformat});
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'crit');
    ok($linestyle, 'LINE2');
    ok($linecolor, 'D05050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'total');
    ok($linestyle, 'AREA');
    ok($linecolor, 'dddddd88');
    ok($stack, 1);

    return;
}

# maximums, minimums, and lasts
# 1.4.3 and earlier used this format:
#   service1[,service2[,service3[,...]]]
# 1.4.4 introduced this format:
#   [host,]service,database;[[host,]service2,database][;...]
sub testrras {
    my $xff = 0.5;
    my @steps = (1, 6, 24, 288);
    my @rows = (1, 2, 3, 4);

    undef $Config{maximums};
    undef $Config{maximumslist};
    undef $Config{minimums};
    undef $Config{minimumslist};
    undef $Config{lasts};
    undef $Config{lastslist};

    $Config{maximums} = 'Current Load,PLW,Procs: total,User Count';
    $Config{maximumslist} = str2list($Config{maximums}, q(,));
    my @result = main::getrras('host1', 'Current Load', q(),
                               $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:MAX:0.5:1:1',
          'RRA:MAX:0.5:6:2',
          'RRA:MAX:0.5:24:3',
          'RRA:MAX:0.5:288:4'
        ];\n");
    $Config{minimums} = 'APCUPSD,fruitloops';
    $Config{minimumslist} = str2list($Config{minimums}, q(,));
    @result = main::getrras('host1', 'APCUPSD', q(),
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:MIN:0.5:1:1',
          'RRA:MIN:0.5:6:2',
          'RRA:MIN:0.5:24:3',
          'RRA:MIN:0.5:288:4'
        ];\n");
    $Config{lasts} = 'sunset,sunrise';
    $Config{lastslist} = str2list($Config{lasts}, q(,));
    @result = main::getrras('host1', 'sunset', q(),
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:LAST:0.5:1:1',
          'RRA:LAST:0.5:6:2',
          'RRA:LAST:0.5:24:3',
          'RRA:LAST:0.5:288:4'
        ];\n");
    # default
    @result = main::getrras('host1', 'other value', q(),
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:AVERAGE:0.5:1:1',
          'RRA:AVERAGE:0.5:6:2',
          'RRA:AVERAGE:0.5:24:3',
          'RRA:AVERAGE:0.5:288:4'
        ];\n");

    return;
}


testconvertdeprecated();
testlineformats();
testrras();
