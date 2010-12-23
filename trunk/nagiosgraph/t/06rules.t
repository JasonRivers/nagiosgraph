#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

# test map rules for output from various plugins.  these tests are designed
# to ensure we know exactly what will happen with each release.  there are
# tests for each version of the map file.

# FIXME: create a standard block of output/performance data then run that
#        block through the map file from each release.

use strict;
use FindBin;
use Test;
use File::Copy qw(copy);
use Data::Dumper;
use lib "$FindBin::Bin/../etc";
use ngshared;

BEGIN { plan tests => 94; }
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

# these map rules were in the 1.3 release.  i have no idea how long they
# have been around or when they were first introduced.
sub testrules_1_3 {
    my $mapfile = 'map_1_3';
    setup($mapfile);

    my @data = ('0', 'host', 'CHECK_NRPE', 'CHECK_NRPE: Socket timeout', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    @data = ('0', 'host', 'NRPE', 'NRPE: Unable to read output', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    @data = ('0', 'host', 'service', 'CRITICAL - Socket timeout after', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    @data = ('0', 'host', 'service', 'Connection refused by host', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    @data = ('0', 'host', 'service', 'CRITICAL - Plugin timed out after', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

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

    teardown($mapfile);
}


# these are in the map file in nagiosgraph 1.4.3
sub testrules_1_4_3 {
    my $mapfile = 'map_1_4_3';
    setup($mapfile);

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
          ],
          [
            'ntp',
            [
              'offset',
              'GAUGE',
              '0.001083'
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

    teardown($mapfile);
}



# these are in the map file in nagiosgraph 1.4.4
sub testrules_1_4_4 {
    my $mapfile = 'map_1_4_4';
    setup($mapfile);

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

    @data = ('0', 'host', 'NTP', 'NTP OK: Offset 0.001083 secs', 'offset=1032.98s;60.00000;120.00000;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

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

    teardown($mapfile);
}


testrules_1_3();
testrules_1_4_3();
testrules_1_4_4();
