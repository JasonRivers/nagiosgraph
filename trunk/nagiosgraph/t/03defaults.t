#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

use FindBin;
use Test;
use strict;

BEGIN {
    eval "require RRDs; RRDs->import();
          use Data::Dumper;
          use lib \"$FindBin::Bin/../etc\";
          use ngshared;";
    if ($@) {
        plan tests => 0;
        exit 0;
    } else {
        plan tests => 99;
    }
}

my $logfile = 'test.log';

# Check the default configuration.  this is coded into a test to help ensure
# backward compatibility and no regressions.  if there is a change, we need
# to know about it and handle it explicitly.

sub testconfig {
    my $fn = "$FindBin::Bin/testlog.txt";
    $Config{junklog} = $fn;;

    open $LOG, '+>', $logfile;
    readconfig('read', 'junklog');
    ok($Config{logfile}, '/var/nagiosgraph/nagiosgraph.log');
    ok($Config{cgilogfile}, '/var/nagiosgraph/nagiosgraph-cgi.log');
    ok($Config{perflog}, '/var/nagios/perfdata.log');
    ok($Config{rrddir}, '/var/nagiosgraph/rrd');
    ok($Config{mapfile}, '/etc/nagiosgraph/map');
    ok($Config{labelfile}, undef);
    ok($Config{authfile}, undef);
    ok($Config{hostdb}, undef);
    ok($Config{servdb}, undef);
    ok($Config{groupdb}, '/etc/nagiosgraph/groupdb.conf');
    ok($Config{datasetdb}, undef);
    ok($Config{nagiosgraphcgiurl}, '/nagiosgraph/cgi-bin');
    ok($Config{nagioscgiurl}, undef);
    ok($Config{javascript}, '/nagiosgraph/nagiosgraph.js');
    ok($Config{stylesheet}, '/nagiosgraph/nagiosgraph.css');
    ok($Config{debug}, 3);
    ok($Config{debug_insert}, undef);
    ok($Config{debug_insert_host}, undef);
    ok($Config{debug_insert_service}, undef);
    ok($Config{debug_show}, undef);
    ok($Config{debug_show_host}, undef);
    ok($Config{debug_show_service}, undef);
    ok($Config{debug_showhost}, undef);
    ok($Config{debug_showhost_host}, undef);
    ok($Config{debug_showhost_service}, undef);
    ok($Config{debug_showservice}, undef);
    ok($Config{debug_showservice_host}, undef);
    ok($Config{debug_showservice_service}, undef);
    ok($Config{debug_showgroup}, undef);
    ok($Config{debug_showgroup_host}, undef);
    ok($Config{debug_showgroup_service}, undef);
    ok($Config{debug_showgraph}, undef);
    ok($Config{debug_showgraph_host}, undef);
    ok($Config{debug_showgraph_service}, undef);
    ok($Config{debug_testcolor}, undef);
    ok($Config{geometries}, '650x50,800x100,1000x200,2000x100');
    ok($Config{default_geometry}, undef);
    ok($Config{colorscheme}, 1);
    ok(Dumper($Config{colors}), "\$VAR1 = [
          'D05050',
          'D08050',
          'D0D050',
          '50D050',
          '50D0D0',
          '5050D0',
          'D050D0',
          '505050'
        ];\n");
    ok($Config{colormax}, '888888');
    ok($Config{colormin}, 'BBBBBB');
    ok($Config{plotas}, 'LINE2');
    ok(Dumper($Config{plotasLINE1}), "\$VAR1 = {
          'avg15min' => 1,
          'avg5min' => 1
        };\n");
    ok(Dumper($Config{plotasLINE2}), "\$VAR1 = {};\n");
    ok(Dumper($Config{plotasLINE3}), "\$VAR1 = {};\n");
    ok(Dumper($Config{plotasAREA}), "\$VAR1 = {
          'system' => 1,
          'user' => 1,
          'idle' => 1,
          'nice' => 1
        };\n");
    ok(Dumper($Config{plotasTICK}), "\$VAR1 = {};\n");
    ok(Dumper($Config{stack}), "\$VAR1 = {
          'system' => 1,
          'user' => 1,
          'nice' => 1
        };\n");
    ok(Dumper($Config{lineformat}), "\$VAR1 = {
          'warn,LINE1,D0D050' => 1,
          'rtacrit,LINE1,D05050' => 1,
          'rtawarn,LINE1,D0D050' => 1,
          'losswarn,LINE1,D0D050' => 1,
          'crit,LINE1,D05050' => 1,
          'losscrit,LINE1,D05050' => 1
        };\n");
    ok($Config{timeall}, 'day,week,month,year');
    ok($Config{timehost}, 'day,week,month');
    ok($Config{timeservice}, 'day,week');
    ok($Config{timegroup}, 'day,week');
    ok($Config{expand_timeall}, 'day,week,month,year');
    ok($Config{expand_timehost}, 'week');
    ok($Config{expand_timeservice}, 'week');
    ok($Config{expand_timegroup}, 'day');
    ok($Config{timeformat_now}, "%H:%M:%S %d %b %Y %Z");
    ok($Config{timeformat_day}, "%H:%M %e %b");
    ok($Config{timeformat_week}, "%e %b");
    ok($Config{timeformat_month}, "Week %U");
    ok($Config{timeformat_quarter}, "Week %U");
    ok($Config{timeformat_year}, "%b %Y");
    ok($Config{refresh}, undef);
    ok($Config{hidengtitle}, undef);
    ok($Config{showprocessingtime}, undef);
    ok($Config{showtitle}, 'true');
    ok($Config{showdesc}, undef);
    ok($Config{showgraphtitle}, undef);
    ok($Config{hidelegend}, undef);
    ok($Config{graphonly}, undef);
    ok(Dumper($Config{maximums}), "\$VAR1 = {
          'Procs: total' => 1,
          'PLW' => 1,
          'Current Load' => 1,
          'Procs: zombie' => 1,
          'User Count' => 1
        };\n");
    ok(Dumper($Config{minimums}), "\$VAR1 = {
          'Mem: swap' => 1,
          'APCUPSD' => 1,
          'Mem: free' => 1
        };\n");
    ok(Dumper($Config{withmaximums}), "\$VAR1 = {
          'PING' => 1
        };\n");
    ok(Dumper($Config{withminimums}), "\$VAR1 = {
          'PING' => 1
        };\n");
    ok(Dumper($Config{negate}), "\$VAR1 = {};\n");
    ok(Dumper($Config{hostservvar}), "\$VAR1 = {};\n");
    ok(Dumper($Config{altautoscale}), "\$VAR1 = {};\n");
    ok(Dumper($Config{altautoscalemin}), "\$VAR1 = {};\n");
    ok(Dumper($Config{altautoscalemax}), "\$VAR1 = {};\n");
    ok(Dumper($Config{nogridfit}), "\$VAR1 = {};\n");
    ok(Dumper($Config{logarithmic}), "\$VAR1 = {};\n");
    ok($Config{rrdopts}, undef);
    ok($Config{rrdoptsfile}, undef);
    ok($Config{perfloop}, undef);
    ok($Config{heartbeat}, 600);
    ok($Config{heartbeats}, undef);
    ok($Config{heartbeatlist}, undef);
    ok($Config{stepsize}, 300);
    ok($Config{stepsizes}, undef);
    ok($Config{stepsizelist}, undef);
    ok($Config{resolution}, '600 700 775 797');
    ok($Config{resolutions}, undef);
    ok($Config{resolutionlist}, undef);
    ok($Config{dbseparator}, 'subdir');
    ok($Config{dbfile}, undef); # backward compatibility
    ok($Config{authzmethod}, undef);
    ok($Config{authzfile}, undef);
    ok($Config{language}, undef);
    close $LOG;
    unlink $logfile;
    unlink $fn;
}

testconfig();
