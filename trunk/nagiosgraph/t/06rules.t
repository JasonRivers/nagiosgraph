#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

# this file contains a set of plugin output/perfdata strings that are run
# against the map file that was distributed in each nagiosgraph release.
# when new output/perfdata are added, you must also add a result string for
# each map configuration (e.g. 1.3, 1.4.3, etc).

use FindBin;
use Test;
use strict;

BEGIN {
    plan tests => 153;
    eval "require RRDs; RRDs->import();
          use CGI qw(:standard escape unescape);
          use Data::Dumper;
          use File::Copy qw(copy);
          use lib \"$FindBin::Bin/../etc\";
          use ngshared;";
    exit 0 if $@;
}

my $logfile = 'test.log';

sub formatdata {
    my (@data) = @_;
    return "hostname:$data[1]\nservicedesc:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
}

sub setup {
    my ($mapfile) = @_;
    open $LOG, '+>', $logfile;
#    $Config{debug} = 5;
    copy "examples/$mapfile", "etc/$mapfile";
    undef &evalrules;
    my $rval = getrules( $mapfile );
    ok($rval, '');
}

sub teardown {
    my ($mapfile) = @_;
    close $LOG;
    unlink $logfile;
    unlink "etc/$mapfile";
}

sub runtests {
    my ($desc, $mapfile, $idx, $data_ref) = @_;
    setup($mapfile);

    foreach my $d (@{$data_ref}) {
        my @a = @{$d};
        my @data = @{$a[0]};
        my $e = $a[$idx];
        my $n = 1;
        while ($e eq 'ditto' && $idx-$n > 0) {
            $e = $a[$idx-$n];
            $n++;
        }
        $e = "\n          $e\n        " if $e ne '';
        my $msg = "\nmap:$desc host:$data[1] service:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
        my @s = evalrules( formatdata( @data ) );
        ok(Dumper(\@s), "\$VAR1 = [$e];\n", $msg);
    }

    teardown($mapfile);
}

# these are the data from various plugins.  this array should grow as much as
# possible to represent the output from as many plugins as possible.  the data
# include both standard plugin output as well as error output.
#
# a value of 'ditto' means use the string from the previous release.
#
# indices for nagiosgraph releases:
#   1 - 1.3
#   2 - 1.4.3
#   3 - 1.4.4
#
my @testdata = 
    (
     # these are the output and performance strings from the 1.3 map file

     [
      ['0', 'host', 'CHECK_NRPE', 'CHECK_NRPE: Socket timeout', ''],
      "",
      "'ignore'",
      "'ignore'",
      ],

     [
      ['0', 'host', 'NRPE', 'NRPE: Unable to read output', ''],
      "",
      "'ignore'",
      "'ignore'",
      ],

     [
      ['0', 'host', 'service', 'CRITICAL - Socket timeout after', ''],
      "",
      "'ignore'",
      "'ignore'",
      ],

     [
      ['0', 'host', 'service', 'Connection refused by host', ''],
      "",
      "'ignore'",
      "'ignore'",
      ],

     [
      ['0', 'host', 'service', 'CRITICAL - Plugin timed out after', ''],
      "",
      "'ignore'",
      "'ignore'",
      ],

     [
      ['0', 'host', 'PING', 'PING OK - Packet loss = 0%, RTA = 0.00 ms', '']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "" # FIXME
      ],

     [
      ['0', 'host', 'DISK', 'DISK OK - free space: /tmp 663 MB (90%)', '']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "" # FIXME
      ],

     [
      ['0', 'host', 'DISK', 'DISK OK - free space: / 12372 mB (77% inode=96%): /raid 882442 mB (88% inode=91%)', '/=12372mB;14417;15698;96;16019 /raid=882441mB;999780;999780;91;999780']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "[
            '/',
            [
              'data',
              'GAUGE',
              '12972982272'
            ],
            [
              'warn',
              'GAUGE',
              '15117320192'
            ],
            [
              'crit',
              'GAUGE',
              '16460546048'
            ],
            [
              'min',
              'GAUGE',
              100663296
            ],
            [
              'max',
              'GAUGE',
              '16797138944'
            ]
          ],
          [
            '/raid',
            [
              'data',
              'GAUGE',
              '925306454016'
            ],
            [
              'warn',
              'GAUGE',
              '1048345313280'
            ],
            [
              'crit',
              'GAUGE',
              '1048345313280'
            ],
            [
              'min',
              'GAUGE',
              95420416
            ],
            [
              'max',
              'GAUGE',
              '1048345313280'
            ]
          ]"
      ],

     [
      ['0', 'host', 'DNS', 'DNS OK - 0.008 seconds response time (test.test.1M IN A192.169.0.47)', 'time=8260us;;;0']
      ,  "[
            'dns',
            [
              'response',
              'GAUGE',
              '0.008'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.00826'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'IMAP', 'IMAP OK - 0.009 second response time on port 143', '']
      ,  "[
            'imap',
            [
              'response',
              'GAUGE',
              '0.009'
            ]
          ]"
      ,  "ditto"
      ,  "" # FIXME
      ],

     [
      ['0', 'host', 'LDAP', 'LDAP OK - 0.004 seconds response time', 'time=3657us;;;0']
      ,  "[
            'ldap',
            [
              'response',
              'GAUGE',
              '0.004'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.003657'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'Load Average', 'OK - load average: 0.66, 0.70, 0.73', 'load1=0;15;30;0 load5=0;10;25;0 load15=0;5;20;0']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "[
            'load1',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '15'
            ],
            [
              'crit',
              'GAUGE',
              '30'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ],
          [
            'load5',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '10'
            ],
            [
              'crit',
              'GAUGE',
              '25'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ],
          [
            'load15',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '5'
            ],
            [
              'crit',
              'GAUGE',
              '20'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'mailq', 'WARNING: mailq is 5717 (threshold w = 5000)', 'unsent=5717;5000;10000;0']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "[
            'unsent',
            [
              'data',
              'GAUGE',
              '5717'
            ],
            [
              'warn',
              'GAUGE',
              '5000'
            ],
            [
              'crit',
              'GAUGE',
              '10000'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'netstat', 'OK', 'udpInDatagrams=46517147, udpOutDatagrams=46192507, udpInErrors=0, tcpActiveOpens=1451583, tcpPassiveOpens=1076181, tcpAttemptFails=1909, tcpEstabResets=5045, tcpCurrEstab=6, tcpOutDataBytes=3162434373, tcpInDataBytes=1942718261, tcpRetransBytes=215439']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "ditto"
      ],

     [
      ['0', 'host', 'NTP', 'NTP OK: Offset 0.001083 secs, jitter 14.84 msec, peer is stratum 1', '']
      ,  "[
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
          ]"
      ,  "[
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
          ],
          [
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ]
          ]"
      ,  "[
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
          ]"
      ],

     [
      ['0', 'host', 'POP', 'POP OK - 0.008 second response time on port 110', '']
      ,  "[
            'pop3',
            [
              'response',
              'GAUGE',
              '0.008'
            ]
          ]"
      ,  "ditto"
      ,  "" # FIXME
      ],

     [
      ['0', 'host', 'PROCS', 'PROCS OK: 43 processes', '']
      ,  "[
            'procs',
            [
              'procs',
              'GAUGE',
              '43'
            ]
          ]"
      ,  "ditto"
      ,  "ditto"
      ],

     [
      ['0', 'host', 'SMTP', 'SMTP OK - 0.187 sec. response time', '']
      ,  "[
            'smtp',
            [
              'response',
              'GAUGE',
              '0.187'
            ]
          ]"
      ,  "ditto"
      ,  "" # FIXME
      ],

     [
      ['0', 'host', 'SWAP', 'SWAP OK: 96% free (2616 MB out of 2744 MB)', 'swap=2616MB;274;54;0;2744']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "[
            'swap',
            [
              'data',
              'GAUGE',
              2743074816
            ],
            [
              'warn',
              'GAUGE',
              287309824
            ],
            [
              'crit',
              'GAUGE',
              56623104
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              2877292544
            ]
          ]"
      ],

     [
      ['0', 'host', 'USERS', 'USERS OK - 4 users currently logged in', 'users=4;5;10;0']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "[
            'users',
            [
              'data',
              'GAUGE',
              '4'
            ],
            [
              'warn',
              'GAUGE',
              '5'
            ],
            [
              'crit',
              'GAUGE',
              '10'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'PROCS', 'PROCS OK: 0 processes with STATE = Z', '']
      ,  "[
            'zombie',
            [
              'zombies',
              'GAUGE',
              '0'
            ]
          ]"
      ,  "ditto"
      ,  "ditto"
      ],

     [
      ['0', 'host', 'HTTP', 'HTTP OK HTTP/1.1 200 OK - 1456 bytes in 0.003 seconds', '']
      ,  "[
            'http',
            [
              'bps',
              'GAUGE',
              '485333.333333333'
            ]
          ]"
      ,  "ditto"
      ,  "" # FIXME
      ],

     [
      ['0', 'host', 'TCP', 'TCP OK - 0.061 second response time on port 22', 'time=0.060777s;0.000000;0.000000;0.000000;10.000000']
      ,  "[
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
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.060777'
            ],
            [
              'warn',
              'GAUGE',
              '0.000000'
            ],
            [
              'crit',
              'GAUGE',
              '0.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ],
            [
              'max',
              'GAUGE',
              '10.000000'
            ]
          ]"
      ],



     # rules to handle these were added in 1.4

     [
      ['0', 'host', 'ups-charge', 'Battery Charge: 100.0%', 'charge=100.0;50;10']
      ,  ""
      ,  "[
            'charge',
            [
              'charge',
              'GAUGE',
              '100.0'
            ]
          ]"
      ,  "[
            'charge',
            [
              'data',
              'GAUGE',
              '100.0'
            ],
            [
              'warn',
              'GAUGE',
              '50'
            ],
            [
              'crit',
              'GAUGE',
              '10'
            ]
          ]"
      ],

     [
      ['0', 'host', 'ups-time', 'OK - Time Left: 42.0 Minutes', 'timeleft=42.0;20;10']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'timeleft',
            [
              'data',
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
          ]"
      ],

     [
      ['0', 'host', 'ups-load', 'OK - Load: 5.2%', 'load=3.6;30;40']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'load',
            [
              'data',
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
          ]"
      ],

     [
      ['0', 'host', 'ups-temp', 'OK - Internal Temperature: 25.6 C', 'temperature=25.6;30;40']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'temperature',
            [
              'data',
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
          ]"
      ],

     [
      ['0', 'host', 'uptime', 'OK - uptime is 36 Days, 2 Hours, 42 Minutes', '']
      ,  ""
      ,  "[
            'data',
            [
              'days',
              'GAUGE',
              '36'
            ]
          ]"
      ,  "ditto"
      ],

     [
      ['0', 'host', 'ntp', 'NTP OK: Offset 0.001083 secs', '']
      ,  ""
      ,   "[
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ]
          ]"
      ,  "ditto"
      ],

     [
      ['0', 'host', 'NTP', 'NTP OK: Offset 0.001083 secs', 'offset=1032.98;60.00000;120.00000;']
      ,  ""
      ,  "[
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ]
          ]"
      ,  "[
            'offset',
            [
              'data',
              'GAUGE',
              '1032.98'
            ],
            [
              'warn',
              'GAUGE',
              '60.00000'
            ],
            [
              'crit',
              'GAUGE',
              '120.00000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'NTP', 'NTP OK: Offset 0.001083 secs', 'offset=1032.98s;60.00000;120.00000;']
      ,  ""
      ,  "[
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
            ]
          ]"
      ,  "[
            'offset',
            [
              'data',
              'GAUGE',
              '1032.98'
            ],
            [
              'warn',
              'GAUGE',
              '60.00000'
            ],
            [
              'crit',
              'GAUGE',
              '120.00000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'proc', 'OK: Total: 90, Zombie: 0, RSDT: 23', 'total=90 zombie=0 rsdt=23']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'total',
            [
              'data',
              'GAUGE',
              '90'
            ]
          ],
          [
            'zombie',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ],
          [
            'rsdt',
            [
              'data',
              'GAUGE',
              '23'
            ]
          ]"
      ],

     [
      ['0', 'host', 'cpu', 'User: 14%, Nice: 0%, System: 1%, Idle: 83%', 'user=14.17 nice=0 sys=1.9488 idle=83.87']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'user',
            [
              'data',
              'GAUGE',
              '14.17'
            ]
          ],
          [
            'nice',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ],
          [
            'sys',
            [
              'data',
              'GAUGE',
              '1.9488'
            ]
          ],
          [
            'idle',
            [
              'data',
              'GAUGE',
              '83.87'
            ]
          ]"
      ],

     [
      ['0', 'host', 'mem', 'Real Free: 25924 kB, Swap Free: 1505472 kb', 'total=514560 free=25924 swaptot=1506172 swapfree=1505472']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'total',
            [
              'data',
              'GAUGE',
              '514560'
            ]
          ],
          [
            'free',
            [
              'data',
              'GAUGE',
              '25924'
            ]
          ],
          [
            'swaptot',
            [
              'data',
              'GAUGE',
              '1506172'
            ]
          ],
          [
            'swapfree',
            [
              'data',
              'GAUGE',
              '1505472'
            ]
          ]"
      ],

     [
      ['0', 'host', 'net', 'Received 3956221475, Transmitted = 571374458', 'rbyte=3956221475 rpacket=36097353 rerr=0 rdrop=0 rmult=0 tbyte=571374458 tpacket=62062295 terr=6 tdrop=0 tmult=0']
      ,  ""
      ,  "[
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
          ]"
      ,  "[
            'rbyte',
            [
              'data',
              'GAUGE',
              '3956221475'
            ]
          ],
          [
            'rpacket',
            [
              'data',
              'GAUGE',
              '36097353'
            ]
          ],
          [
            'rerr',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ],
          [
            'rdrop',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ],
          [
            'rmult',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ],
          [
            'tbyte',
            [
              'data',
              'GAUGE',
              '571374458'
            ]
          ],
          [
            'tpacket',
            [
              'data',
              'GAUGE',
              '62062295'
            ]
          ],
          [
            'terr',
            [
              'data',
              'GAUGE',
              '6'
            ]
          ],
          [
            'tdrop',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ],
          [
            'tmult',
            [
              'data',
              'GAUGE',
              '0'
            ]
          ]"
      ],



     # the 1.4.4 release removed some redundant rules and favors perfdata
     # over output whenever possible.

     [
      ['0', 'host', 'service', 'Connection refused', ''],
      "",
      "",
      "'ignore'",
      ],

     [
      ['0', 'host', 'service', 'Error code 255: plugin may be missing', ''],
      "",
      "",
      "'ignore'",
      ],

     [
      ['0', 'host', 'PING', 'PING OK - Packet loss = 0%, RTA = 0.45 ms', 'rta=0.449000ms;200.000000;500.000000;0.000000 pl=0%;10;20;0']
      ,  "[
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
              '0.00045'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'rta',
            [
              'data',
              'GAUGE',
              '0.000449'
            ],
            [
              'warn',
              'GAUGE',
              '0.2'
            ],
            [
              'crit',
              'GAUGE',
              '0.5'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ],
          [
            'pl',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '10'
            ],
            [
              'crit',
              'GAUGE',
              '20'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'DISK', 'DISK CRITICAL - free space: / 66772 MB (95% inode=98%); /lib/init/rw 251 MB (100% inode=99%); /dev 9 MB (92% inode=97%); /dev/shm 251 MB (100% inode=99%);', ' /=3157MB;73662;73572;0;73672 /lib/init/rw=0MB;241;151;0;251 /dev=0MB;0;-90;0;10 /dev/shm=0MB;241;151;0;251']
      ,  "[
            '/',
            [
              'free',
              'GAUGE',
              '3310354432'
            ],
            [
              'user',
              'GAUGE',
              '77240205312'
            ],
            [
              'root',
              'GAUGE',
              '77145833472'
            ],
            [
              'max',
              'GAUGE',
              '77250691072'
            ],
            [
              'blockpct',
              'GAUGE',
              '95'
            ],
            [
              'inodepct',
              'GAUGE',
              '98'
            ]
          ]"
      ,  "ditto"
      ,  "[
            '/',
            [
              'data',
              'GAUGE',
              3310354432
            ],
            [
              'warn',
              'GAUGE',
              '77240205312'
            ],
            [
              'crit',
              'GAUGE',
              '77145833472'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '77250691072'
            ]
          ],
          [
            '/lib/init/rw',
            [
              'data',
              'GAUGE',
              0
            ],
            [
              'warn',
              'GAUGE',
              252706816
            ],
            [
              'crit',
              'GAUGE',
              158334976
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              263192576
            ]
          ],
          [
            '/dev',
            [
              'data',
              'GAUGE',
              0
            ],
            [
              'warn',
              'GAUGE',
              0
            ],
            [
              'crit',
              'GAUGE',
              -94371840
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              10485760
            ]
          ],
          [
            '/dev/shm',
            [
              'data',
              'GAUGE',
              0
            ],
            [
              'warn',
              'GAUGE',
              252706816
            ],
            [
              'crit',
              'GAUGE',
              158334976
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              263192576
            ]
          ]"
      ],

     [
      ['0', 'host', 'DNS', 'DNS OK: 0.340 seconds response time. example.com returns 192.0.32.10', 'time=0.018895s;;;0.000000']
      ,  "[
            'dns',
            [
              'response',
              'GAUGE',
              '0.340'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.018895'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'IMAP', 'IMAP OK - 0.014 second response time on port 143 [* OK mail00 Cyrus IMAP4 v2.2.13-Debian-2.2.13-13ubuntu3 server ready]', 'time=0.014317s;10.000000;20.000000;0.000000;10.000000']
      ,  "[
            'imap',
            [
              'response',
              'GAUGE',
              '0.014'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.014317'
            ],
            [
              'warn',
              'GAUGE',
              '10.000000'
            ],
            [
              'crit',
              'GAUGE',
              '20.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ],
            [
              'max',
              'GAUGE',
              '10.000000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'LDAP', 'LDAP OK - 0.007 seconds response time', 'time=0.007343s;5.000000;120.000000;0.000000']
      ,  "[
            'ldap',
            [
              'response',
              'GAUGE',
              '0.007'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.007343'
            ],
            [
              'warn',
              'GAUGE',
              '5.000000'
            ],
            [
              'crit',
              'GAUGE',
              '120.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'LOAD', 'OK - load average: 0.22, 0.44, 0.62', 'load1=0.220;2.000;6.000;0; load5=0.440;3.000;7.000;0; load15=0.620;4.000;8.000;0; ']
      ,  "[
            'load',
            [
              'avg1min',
              'GAUGE',
              '0.22'
            ],
            [
              'avg5min',
              'GAUGE',
              '0.44'
            ],
            [
              'avg15min',
              'GAUGE',
              '0.62'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'load1',
            [
              'data',
              'GAUGE',
              '0.220'
            ],
            [
              'warn',
              'GAUGE',
              '2.000'
            ],
            [
              'crit',
              'GAUGE',
              '6.000'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ],
          [
            'load5',
            [
              'data',
              'GAUGE',
              '0.440'
            ],
            [
              'warn',
              'GAUGE',
              '3.000'
            ],
            [
              'crit',
              'GAUGE',
              '7.000'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ],
          [
            'load15',
            [
              'data',
              'GAUGE',
              '0.620'
            ],
            [
              'warn',
              'GAUGE',
              '4.000'
            ],
            [
              'crit',
              'GAUGE',
              '8.000'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'MAILQ', 'OK: mailq is empty', 'unsent=0;10;30;0']
      ,  "[
            'mailq',
            [
              'qsize',
              'GAUGE',
              '0'
            ],
            [
              'qwarn',
              'GAUGE',
              '10'
            ],
            [
              'qcrit',
              'GAUGE',
              '30'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'unsent',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '10'
            ],
            [
              'crit',
              'GAUGE',
              '30'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'POP', 'POP OK - 0.005 second response time on port 110 [+OK mail00 Cyrus POP3 v2.2.13-Debian-2.2.13-13ubuntu3 server ready]', 'time=0.005265s;10.000000;20.000000;0.000000;10.000000']
      ,  "[
            'pop3',
            [
              'response',
              'GAUGE',
              '0.005'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.005265'
            ],
            [
              'warn',
              'GAUGE',
              '10.000000'
            ],
            [
              'crit',
              'GAUGE',
              '20.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ],
            [
              'max',
              'GAUGE',
              '10.000000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'SMTP', 'SMTP OK - 0.007 sec. response time', 'time=0.006936s;10.000000;20.000000;0.000000']
      ,  "[
            'smtp',
            [
              'response',
              'GAUGE',
              '0.007'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.006936'
            ],
            [
              'warn',
              'GAUGE',
              '10.000000'
            ],
            [
              'crit',
              'GAUGE',
              '20.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ]
          ]"
      ],

     [
      ['0', 'host', 'SWAP', 'SWAP OK - 100% free (1470 MB out of 1470 MB) ', 'swap=1470MB;441;147;0;1470']
      ,  "[
            'swap',
            [
              'swapfree',
              'GAUGE',
              '1541406720'
            ],
            [
              'swapwarn',
              'GAUGE',
              '462422016'
            ],
            [
              'swapcrit',
              'GAUGE',
              '154140672'
            ],
            [
              'swapmax',
              'GAUGE',
              '1541406720'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'swap',
            [
              'data',
              'GAUGE',
              1541406720
            ],
            [
              'warn',
              'GAUGE',
              462422016
            ],
            [
              'crit',
              'GAUGE',
              154140672
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              1541406720
            ]
          ]"
      ],

     [
      ['0', 'host', 'USERS', 'USERS OK - 4 users currently logged in ', 'users=4;10;20;0']
      ,  "[
            'procs',
            [
              'users',
              'GAUGE',
              '4'
            ],
            [
              'uwarn',
              'GAUGE',
              '10'
            ],
            [
              'ucrit',
              'GAUGE',
              '20'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'users',
            [
              'data',
              'GAUGE',
              '4'
            ],
            [
              'warn',
              'GAUGE',
              '10'
            ],
            [
              'crit',
              'GAUGE',
              '20'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'HTTP', 'HTTP OK: HTTP/1.1 200 OK - 3645 bytes in 0.006 second response time ', 'time=0.006432s;1.000000;2.000000;0.000000 size=3645B;;;0']
      ,  "[
            'http',
            [
              'bps',
              'GAUGE',
              '607500'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.006432'
            ],
            [
              'warn',
              'GAUGE',
              '1.000000'
            ],
            [
              'crit',
              'GAUGE',
              '2.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ]
          ],
          [
            'size',
            [
              'data',
              'GAUGE',
              '3645'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]"
      ],

     [
      ['0', 'host', 'TCP', 'TCP OK - 0.039 second response time on port 22', 'time=0.039076s;10.000000;20.000000;0.000000;10.000000']
      ,  "[
            'tcp_22',
            [
              'connect_time',
              'GAUGE',
              '0.039076'
            ],
            [
              'warning_time',
              'GAUGE',
              '0.000000'
            ],
            [
              'critical_time',
              'GAUGE',
              '20.000000'
            ],
            [
              'socket_timeout',
              'GAUGE',
              '10.000000'
            ]
          ]"
      ,  "ditto"
      ,  "[
            'time',
            [
              'data',
              'GAUGE',
              '0.039076'
            ],
            [
              'warn',
              'GAUGE',
              '10.000000'
            ],
            [
              'crit',
              'GAUGE',
              '20.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ],
            [
              'max',
              'GAUGE',
              '10.000000'
            ]
          ]"
      ],

#     [
#      ['0', 'host', '', '', '']
#      ,  ""
#      ,  ""
#      ,  ""
#      ],

#     [
#      ['0', 'host', '', '', '']
#      ,  ""
#      ,  ""
#      ,  ""
#      ],

#     [
#      ['0', 'host', '', '', '']
#      ,  ""
#      ,  ""
#      ,  ""
#      ],

     );





sub testrules_1_3 {
    runtests('1.3', 'map_1_3', 1, \@testdata);
}

sub testrules_1_4_3 {
    runtests('1.4.3', 'map_1_4_3', 2, \@testdata);
}

sub testrules_1_4_4 {
    runtests('1.4.4', 'map_1_4_4', 3, \@testdata);
}


testrules_1_3();
testrules_1_4_3();
testrules_1_4_4();
