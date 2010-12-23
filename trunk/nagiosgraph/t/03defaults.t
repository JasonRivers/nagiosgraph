#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

use strict;
use FindBin;
use Test;
use Data::Dumper;
use lib "$FindBin::Bin/../etc";
use ngshared;

BEGIN { plan tests => 134; }
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

sub formatdata {
    my (@data) = @_;
    return "hostname:$data[1]\nservicedesc:$data[2]\noutput:$data[3]\nperfdata:$data[4]";    
}

sub testmaprules {
    open $LOG, '+>', $logfile;
#    $Config{debug} = 5;

    my $rval = getrules( 'map' );
    ok($rval, '');

    # these map rules were in the 1.3 release.  i have no idea how long they
    # have been around or when they were first introduced.

    my @data = ('0', 'host', 'CHECK_NRPE', 'CHECK_NRPE: Socket timeout', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [\n          'ignore'\n        ];\n");

    @data = ('0', 'host', 'NRPE', 'NRPE: Unable to read output', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [\n          'ignore'\n        ];\n");

    @data = ('0', 'host', 'service', 'CRITICAL - Socket timeout after', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [\n          'ignore'\n        ];\n");

    @data = ('0', 'host', 'service', 'Connection refused by host', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [\n          'ignore'\n        ];\n");

    @data = ('0', 'host', 'service', 'CRITICAL - Plugin timed out after', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [\n          'ignore'\n        ];\n");

    @data = ('0', 'host', 'PING', 'PING OK - Packet loss = 0%, RTA = 0.00 ms', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'pingloss',
            [
              'losspct',
              'GAUGE',
              '0'
            ]
          ],
          [
            'pingrta',
            [
              'rta',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'DISK', 'DISK OK - free space: /tmp 663 MB (90%)', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/tmp',
            [
              'bytesfree',
              'GAUGE',
              '695205888'
            ],
            [
              'bytesmax',
              'GAUGE',
              '772450986.666667'
            ],
            [
              'pctfree',
              'GAUGE',
              '90'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'DISK', 'DISK OK - free space: / 12372 mB (77% inode=96%): /raid 882442 mB (88% inode=91%)', '/=12372mB;14417;15698;96;16019 /raid=882441mB;999780;999780;91;999780');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'free',
              'GAUGE',
              '12972982272'
            ],
            [
              'user',
              'GAUGE',
              '15117320192'
            ],
            [
              'root',
              'GAUGE',
              '16460546048'
            ],
            [
              'max',
              'GAUGE',
              '16797138944'
            ],
            [
              'blockpct',
              'GAUGE',
              '77'
            ],
            [
              'inodepct',
              'GAUGE',
              '96'
            ]
          ],
          [
            '/raid',
            [
              'free',
              'GAUGE',
              '925306454016'
            ],
            [
              'user',
              'GAUGE',
              '1048345313280'
            ],
            [
              'root',
              'GAUGE',
              '1048345313280'
            ],
            [
              'max',
              'GAUGE',
              '1048345313280'
            ],
            [
              'blockpct',
              'GAUGE',
              '88'
            ],
            [
              'inodepct',
              'GAUGE',
              '91'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'DNS', 'DNS OK - 0.008 seconds response time (test.test.1M IN A192.169.0.47)', 'time=8260us;;;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'dns',
            [
              'response',
              'GAUGE',
              '0.008'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'IMAP', 'IMAP OK - 0.009 second response time on port 143', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'imap',
            [
              'response',
              'GAUGE',
              '0.009'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'LDAP', 'LDAP OK - 0.004 seconds response time', 'time=3657us;;;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'ldap',
            [
              'response',
              'GAUGE',
              '0.004'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'Load Average', 'OK - load average: 0.66, 0.70, 0.73', 'load1=0;15;30;0 load5=0;10;25;0 load15=0;5;20;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'load',
            [
              'avg1min',
              'GAUGE',
              '0.66'
            ],
            [
              'avg5min',
              'GAUGE',
              '0.70'
            ],
            [
              'avg15min',
              'GAUGE',
              '0.73'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'mailq', 'WARNING: mailq is 5717 (threshold w = 5000)', 'unsent=5717;5000;10000;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'mailq',
            [
              'qsize',
              'GAUGE',
              '5717'
            ],
            [
              'qwarn',
              'GAUGE',
              '5000'
            ],
            [
              'qcrit',
              'GAUGE',
              '10000'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'netstat', 'OK', 'udpInDatagrams=46517147, udpOutDatagrams=46192507, udpInErrors=0, tcpActiveOpens=1451583, tcpPassiveOpens=1076181, tcpAttemptFails=1909, tcpEstabResets=5045, tcpCurrEstab=6, tcpOutDataBytes=3162434373, tcpInDataBytes=1942718261, tcpRetransBytes=215439');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'udp',
            [
              'InPkts',
              'DERIVE',
              155057
            ],
            [
              'OutPkts',
              'DERIVE',
              153975
            ],
            [
              'Errors',
              'DERIVE',
              0
            ]
          ],
          [
            'tcp',
            [
              'ActOpens',
              'DERIVE',
              4838
            ],
            [
              'PsvOpens',
              'DERIVE',
              3587
            ],
            [
              'AttmptFails',
              'DERIVE',
              6
            ],
            [
              'OutBytes',
              'DERIVE',
              84331583
            ],
            [
              'InBytes',
              'DERIVE',
              51805820
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'NTP', 'NTP OK: Offset 0.001083 secs, jitter 14.84 msec, peer is stratum 1', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ],
            [
              'jitter',
              'GAUGE',
              '0.01484'
            ],
            [
              'stratum',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'POP', 'POP OK - 0.008 second response time on port 110', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'pop3',
            [
              'response',
              'GAUGE',
              '0.008'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'PROCS', 'PROCS OK: 43 processes', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'procs',
            [
              'procs',
              'GAUGE',
              '43'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'SMTP', 'SMTP OK - 0.187 sec. response time', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'smtp',
            [
              'response',
              'GAUGE',
              '0.187'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'SWAP', 'SWAP OK: 96% free (2616 MB out of 2744 MB)', 'swap=2616MB;274;54;0;2744');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'swap',
            [
              'swapfree',
              'GAUGE',
              '2743074816'
            ],
            [
              'swapwarn',
              'GAUGE',
              '287309824'
            ],
            [
              'swapcrit',
              'GAUGE',
              '56623104'
            ],
            [
              'swapmax',
              'GAUGE',
              '2877292544'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'USERS', 'USERS OK - 4 users currently logged in', 'users=4;5;10;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'procs',
            [
              'users',
              'GAUGE',
              '4'
            ],
            [
              'uwarn',
              'GAUGE',
              '5'
            ],
            [
              'ucrit',
              'GAUGE',
              '10'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'PROCS', 'PROCS OK: 0 processes with STATE = Z', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'zombie',
            [
              'zombies',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'HTTP', 'HTTP OK HTTP/1.1 200 OK - 1456 bytes in 0.003 seconds', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'http',
            [
              'bps',
              'GAUGE',
              '485333.333333333'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'TCP', 'TCP OK - 0.061 second response time on port 22', 'time=0.060777s;0.000000;0.000000;0.000000;10.000000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'tcp_22',
            [
              'connect_time',
              'GAUGE',
              '0.060777'
            ],
            [
              'warning_time',
              'GAUGE',
              '0.000000'
            ],
            [
              'critical_time',
              'GAUGE',
              '0.000000'
            ],
            [
              'socket_timeout',
              'GAUGE',
              '10.000000'
            ]
          ]
        ];\n");

    # these are map rules added with the 1.4 release

    @data = ('0', 'host', 'ups-charge', 'Battery Charge: 100.0%', 'charge=100.0;50;10');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'charge',
            [
              'charge',
              'GAUGE',
              '100.0'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ups-time', 'OK - Time Left: 42.0 Minutes', 'timeleft=42.0;20;10');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'timeleft',
              'GAUGE',
              '42.0'
            ],
            [
              'warn',
              'GAUGE',
              '20'
            ],
            [
              'crit',
              'GAUGE',
              '10'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ups-load', 'OK - Load: 5.2%', 'load=3.6;30;40');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'load',
            [
              'load',
              'GAUGE',
              '3.6'
            ],
            [
              'warn',
              'GAUGE',
              '30'
            ],
            [
              'crit',
              'GAUGE',
              '40'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ups-temp', 'OK - Internal Temperature: 25.6 C', 'temperature=25.6;30;40');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'temp',
            [
              'temperature',
              'GAUGE',
              '25.6'
            ],
            [
              'warn',
              'GAUGE',
              '30'
            ],
            [
              'crit',
              'GAUGE',
              '40'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'uptime', 'OK - uptime is 36 Days, 2 Hours, 42 Minutes', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'data',
            [
              'days',
              'GAUGE',
              '36'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ntp', 'NTP OK: Offset 0.001083 secs', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'NTP', 'NTP OK: Offset 0.001083 secs', 'offset=1032.98;60.00000; 120.00000;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'proc', 'OK: Total: 90, Zombie: 0, RSDT: 23', 'total=90 zombie=0 rsdt=23');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'data',
            [
              'total',
              'GAUGE',
              '90'
            ],
            [
              'zombie',
              'GAUGE',
              '0'
            ],
            [
              'rsdt',
              'GAUGE',
              '23'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'cpu', 'User: 14%, Nice: 0%, System: 1%, Idle: 83%', 'user=14.17 nice=0 sys=1.9488 idle=83.87');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'cpu',
            [
              'user',
              'GAUGE',
              '14.17'
            ],
            [
              'nice',
              'GAUGE',
              '0'
            ],
            [
              'system',
              'GAUGE',
              '1.9488'
            ],
            [
              'idle',
              'GAUGE',
              '83.87'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'mem', 'Real Free: 25924 kB, Swap Free: 1505472 kb', 'total=514560 free=25924 swaptot=1506172 swapfree=1505472');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'data',
            [
              'real_total',
              'GAUGE',
              '514560'
            ],
            [
              'real_free',
              'GAUGE',
              '25924'
            ],
            [
              'swap_total',
              'GAUGE',
              '1506172'
            ],
            [
              'swap_free',
              'GAUGE',
              '1505472'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'net', 'Received 3956221475, Transmitted = 571374458', 'rbyte=3956221475 rpacket=36097353 rerr=0 rdrop=0 rmult=0 tbyte=571374458 tpacket=62062295 terr=6 tdrop=0 tmult=0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'data',
            [
              'byte_received',
              'COUNTER',
              '3956221475'
            ],
            [
              'byte_transmitted',
              'COUNTER',
              '571374458'
            ],
            [
              'packet_received',
              'COUNTER',
              '36097353'
            ],
            [
              'packet_transmitted',
              'COUNTER',
              '62062295'
            ],
            [
              'error_received',
              'COUNTER',
              '0'
            ],
            [
              'error_transmitted',
              'COUNTER',
              '6'
            ],
            [
              'drop_received',
              'COUNTER',
              '0'
            ],
            [
              'drop_transmitted',
              'COUNTER',
              '0'
            ],
            [
              'multi_received',
              'COUNTER',
              '0'
            ],
            [
              'multi_transmitted',
              'COUNTER',
              '0'
            ]
          ]
        ];\n");

    # these are in the map file, but not enabled by default

#    @data = ('0', 'host', '', '', '');
#    @s = evalrules( formatdata( @data ) );
#    ok(Dumper(\@s), "");

    close $LOG;
    unlink $logfile;
}


testconfig();
testmaprules();
