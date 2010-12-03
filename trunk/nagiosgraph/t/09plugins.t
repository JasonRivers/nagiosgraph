#!/usr/bin/perl
# $Id: 03defaults.t 361 2010-06-07 16:22:36Z mwall $
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Matthew Wall, 2010

use strict;
use FindBin;
use Test;
use File::Copy qw(copy);
use Data::Dumper;
use lib "$FindBin::Bin/../etc";
use ngshared;

BEGIN { plan tests => 58; }
my $logfile = 'test.log';
my $mapfile = 'map_minimal';

sub formatdata {
    my (@data) = @_;
    return "hostname:$data[1]\nservicedesc:$data[2]\noutput:$data[3]\nperfdata:$data[4]";    
}

sub setup {
    open $LOG, '+>', $logfile;
#    $Config{debug} = 5;
    undef &evalrules;
    copy "examples/$mapfile", "etc/$mapfile";
    my $rval = getrules( $mapfile );
    ok($rval, q());
}

sub teardown {
    close $LOG;
    unlink $logfile;
    unlink "etc/$mapfile";
}


# check_apt
sub test_apt {
    my @data = ('0', 'host', 'check_apt', 'APT OK: 0 packages available for upgrade (0 critical updates).', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_breeze { }


# check_by_ssh -H host -C uptime
sub test_by_ssh {
    my @data = ('0', 'host', 'check_by_ssh', '17:52  up 20 days, 10:03, 3 users, load averages: 0.02 0.42 0.76', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_clamd { }


sub test_cluster { }


# check_dhcp
sub test_dhcp {
    my @data = ('0', 'host', 'check_dhcp', 'OK: Received 1 DHCPOFFER(s), max lease time = 7200 sec.', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_dig -l 192.168.0.1 -w 10 -c 20 -H hostname
sub test_dig {
    my @data = ('0', 'host', 'check_dig', 'DNS OK - 0.106 seconds response time (192.168.32.1.  0 IN A 192.168.32.1)', 'time=0.106366s;10.000000;20.000000;0.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.106366'
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
          ]
        ];\n");
}


# check_disk -w 30 -c 40
sub test_disk {
    my @data = ('0', 'host', 'check_disk', 'DISK CRITICAL - free space: / 66778 MB (95% inode=98%); /lib/init/rw 251 MB (100% inode=99%); /dev 9 MB (92% inode=97%); /dev/shm 251 MB (100% inode=99%);', ' /=3151MB;73642;73632;0;73672 /lib/init/rw=0MB;221;211;0;251 /dev=0MB;-20;-30;0;10 /dev/shm=0MB;221;211;0;251');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              3304062976
            ],
            [
              'warn',
              'GAUGE',
              '77219233792'
            ],
            [
              'crit',
              'GAUGE',
              '77208748032'
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
              231735296
            ],
            [
              'crit',
              'GAUGE',
              221249536
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
              -20971520
            ],
            [
              'crit',
              'GAUGE',
              -31457280
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
              231735296
            ],
            [
              'crit',
              'GAUGE',
              221249536
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
          ]
        ];\n");
}


# check_disk_smb -H mozzarella -s dev -w 50 -c 80
sub test_disk_smb {
    my @data = ('0', 'host', 'check_disk_smb', 'Disk ok - 444.32G (90%) free on \\mozzarella\dev', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_dns -H ns
sub test_dns {
    my @data = ('0', 'host', 'check_dns', 'DNS OK: 0.019 seconds response time. ns returns 192.168.0.1', 'time=0.019294s;;;0.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.019294'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ]
          ]
        ];\n");
}


# check_dummy 2 hello
sub test_dummy {
    my @data = ('0', 'host', 'check_dummy', 'CRITICAL: hello', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_file_age -w 10 -c 50 -f /home/nagios/.bashrc
sub test_file_age {
    my @data = ('0', 'host', 'check_file_age', 'FILE_AGE CRITICAL: /home/nagios/.bashrc is 80625296 seconds old and 3116 bytes', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_flexlm { }


# check_ftp -H ftp.mozilla.org -w 10 -c 20
sub test_ftp {
    my @data = ('0', 'host', 'check_ftp', 'FTP OK - 0.215 second response time on port 21', 'time=0.215314s;10.000000;20.000000;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.215314'
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
          ]
        ];\n");
}


sub test_hpjd { }


# check_http -H www.mozilla.com
sub test_http {
    my @data = ('0', 'host', 'check_http', 'HTTP OK: HTTP/1.1 302 Found - 514 bytes in 0.725 second response time ', 'time=0.724819s;;;0.000000 size=514B;;;0');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.724819'
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
              '514'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");
}


# check_icmp -H localhost
sub test_icmp {
    my @data = ('0', 'host', 'check_icmp', 'OK - localhost: rta 0.058ms, lost 0%', 'rta=0.058ms;200.000;500.000;0; pl=0%;40;80;; rtmax=0.154ms;;;; rtmin=0.031ms;;;;');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '5.8e-05'
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
              '40'
            ],
            [
              'crit',
              'GAUGE',
              '80'
            ]
          ],
          [
            'rtmax',
            [
              'data',
              'GAUGE',
              '0.000154'
            ]
          ],
          [
            'rtmin',
            [
              'data',
              'GAUGE',
              '3.1e-05'
            ]
          ]
        ];\n");
}


# check_ide_smart -d /dev/hda -n
sub test_ide_smart {
    my @data = ('0', 'host', 'check_ide_smart', 'OK - Operational (23/23 tests passed)', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_ifoperstatus { }


sub test_ifstatus { }


# check_imap -H imap.example.com -w 10 -c 20
sub test_imap {
    my @data = ('0', 'host', 'check_imap', 'IMAP OK - 0.005 second response time on port 143 [* OK mail00 Cyrus IMAP4 v2.2.13-Debian-2.2.13-13ubuntu3 server ready]', 'time=0.005343s;10.000000;20.000000;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.005343'
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
          ]
        ];\n");
}


# check_ircd -H irc.etree.org -w 10 -c 20
sub test_ircd {
    my @data = ('0', 'host', 'check_ircd', 'Warning Number Of Clients Connected : 12 (Limit = 10)', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_jabber -H jabber.org -w 10 -c 20
# check_jabber -H jabber.se -w 10 -c 20
sub test_jabber {
    my @data = ('0', 'host', 'check_jabber', 'JABBER WARNING - Unexpected response from host/socket on port 5222', 'time=0.093963s;0.000000;0.000000;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.093963'
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
          ]
        ];\n");

    @data = ('0', 'host', 'check_jabber', 'JABBER OK - 0.281 second response time on port 5222', 'time=0.281089s;10.000000;20.000000;0.000000;10.000000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.281089'
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
          ]
        ];\n");
}


# check_ldap -3 -H ldap.example.com -b dc=example,dc=com -w 10 -c 20
sub test_ldap {
    my @data = ('0', 'host', 'check_ldap', 'LDAP OK - 0.014 seconds response time', 'time=0.013883s;10.000000;20.000000;0.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.013883'
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
          ]
        ];\n");
}


# check_ldaps -3
sub test_ldaps {
#    my @data = ('0', 'host', 'check_ldaps', '', '');
#    my @s = evalrules( formatdata( @data ) );
#    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_load -w 1,1,1 -c 3,3,3
sub test_load {
    my @data = ('0', 'host', 'check_load', 'OK - load average: 0.98, 0.28, 0.26', 'load1=0.980;1.000;3.000;0; load5=0.280;1.000;3.000;0; load15=0.260;1.000;3.000;0;');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'load1',
            [
              'data',
              'GAUGE',
              '0.980'
            ],
            [
              'warn',
              'GAUGE',
              '1.000'
            ],
            [
              'crit',
              'GAUGE',
              '3.000'
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
              '0.280'
            ],
            [
              'warn',
              'GAUGE',
              '1.000'
            ],
            [
              'crit',
              'GAUGE',
              '3.000'
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
              '0.260'
            ],
            [
              'warn',
              'GAUGE',
              '1.000'
            ],
            [
              'crit',
              'GAUGE',
              '3.000'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");
}


# check_log -F /var/log/mail.log
sub test_log {
    my @data = ('0', 'host', 'check_log', 'Log check ok - 0 pattern matches found', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_mailq -w 10 -c 20
sub test_mailq {
    my @data = ('0', 'host', 'check_mailq', 'OK: mailq is empty', 'unsent=0;10;20;0');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
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
              '20'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");
}


sub test_mrtg { }


sub test_mrtgtraf { }


# check_mysql
sub test_mysql {
    my @data = ('0', 'host', 'check_mysql', 'Uptime: 27396472  Threads: 1  Questions: 1193380  Slow queries: 1  Opens: 55  Flush tables: 1  Open tables: 49  Queries per second avg: 0.044', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_mysql_query -w 10 -c 20 -d database -q 'select * from Users;'
sub test_mysql_query {
    my @data = ('0', 'host', 'check_mysql_query', 'QUERY OK: \'select * from Users;\' returned 1.000000', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_nagios { }


# check_nntp -H gail.ripco.com -w 10 -c 20
sub test_nntp {
    my @data = ('0', 'host', 'check_nntp', 'NNTP OK - 0.155 second response time on port 119 [200 news.ripco.com InterNetNews NNRP server INN 2.4.5 ready (posting ok).]', 'time=0.155183s;10.000000;20.000000;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.155183'
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
          ]
        ];\n");
}


# check_nntps -H gail.ripco.com -w 10 -c 20
sub test_nntps {
    my @data = ('0', 'host', 'check_nntps', 'NNTPS OK - 0.387 second response time on port 563 [200 news.ripco.com InterNetNews NNRP server INN 2.4.5 ready (posting ok).]', 'time=0.387024s;10.000000;20.000000;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.387024'
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
          ]
        ];\n");
}


sub test_nrpe { }



# check_nt -H 10.44.100.82 -p 12489 -v CPULOAD -w 80 -c 90 -l 5,80,90,10,80,90
# check_nt -H 10.44.100.82 -p 12489 -v USEDDISKSPACE -d SHOWALL -l c
sub test_nt {
    my @data = ('0', 'host', 'check_nt', 'CPU Load 0% (5 min average) 0% (10 min average)', "'5 min avg Load'=0%;80;90;0;100 '10 min avg Load'=0%;80;90;0;100");
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '5 min avg Load',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '100'
            ]
          ],
          [
            '10 min avg Load',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '100'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'check_nt', 'c:\\ - total: 97.24 Gb - used: 75.66 Gb (78%) - free 21.58 Gb (22%)', "'c:\\ Used Space'=75.66Gb;0.00;0.00;0.00;97.24");
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'c:\\\\ Used Space',
            [
              'data',
              'GAUGE',
              '75.66'
            ],
            [
              'warn',
              'GAUGE',
              '0.00'
            ],
            [
              'crit',
              'GAUGE',
              '0.00'
            ],
            [
              'min',
              'GAUGE',
              '0.00'
            ],
            [
              'max',
              'GAUGE',
              '97.24'
            ]
          ]
        ];\n");
}


# check_ntp -H time
sub test_ntp {
    my @data = ('0', 'host', 'check_ntp', 'NTP OK: Offset 1.524139524 secs', 'offset=1.524140s;60.000000;120.000000;');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'offset',
            [
              'data',
              'GAUGE',
              '1.524140'
            ],
            [
              'warn',
              'GAUGE',
              '60.000000'
            ],
            [
              'crit',
              'GAUGE',
              '120.000000'
            ]
          ]
        ];\n");
}


# check_ntp_peer -H time
sub test_ntp_peer {
    my @data = ('0', 'host', 'check_ntp_peer', 'NTP OK: Offset -0.087309 secs', 'offset=-0.087309s;60.000000;120.000000;');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'offset',
            [
              'data',
              'GAUGE',
              '-0.087309'
            ],
            [
              'warn',
              'GAUGE',
              '60.000000'
            ],
            [
              'crit',
              'GAUGE',
              '120.000000'
            ]
          ]
        ];\n");
}


# check_ntp_time -H time
sub test_ntp_time {
    my @data = ('0', 'host', 'check_ntp_time', 'NTP OK: Offset 1.67337656 secs', 'offset=1.673377s;60.000000;120.000000;');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'offset',
            [
              'data',
              'GAUGE',
              '1.673377'
            ],
            [
              'warn',
              'GAUGE',
              '60.000000'
            ],
            [
              'crit',
              'GAUGE',
              '120.000000'
            ]
          ]
        ];\n");
}



sub test_nwstat { }


sub test_openvpn { }


sub test_oracle { }


sub test_overcr { }


# check_ping -H example.com -w 100,10% -c 200,20%
sub test_ping {
    my @data = ('0', 'host', 'check_ping', 'PING OK - Packet loss = 0%, RTA = 0.47 ms', 'rta=0.473000ms;100.000000;200.000000;0.000000 pl=0%;10;20;0');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.000473'
            ],
            [
              'warn',
              'GAUGE',
              '0.1'
            ],
            [
              'crit',
              'GAUGE',
              '0.2'
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
          ]
        ];\n");
}


# check_pop -H pop.example.com -w 10 -c 20
sub test_pop {
    my @data = ('0', 'host', 'check_pop', 'POP OK - 0.056 second response time on port 110 [+OK mail00 Cyrus POP3 v2.2.13-Debian-2.2.13-13ubuntu3 server ready]', 'time=0.055559s;10.000000;20.000000;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.055559'
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
          ]
        ];\n");
}


# check_procs -w 100 -c 200
sub test_procs {
    my @data = ('0', 'host', 'check_procs', 'PROCS OK: 68 processes', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_real { }


# check_rpc -H mozzarella -C nfs
sub test_rpc {
    my @data = ('0', 'host', 'check_rpc', 'OK: RPC program nfs version 2 version 3 version 4 udp running', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_sensors
sub test_sensors {
    my @data = ('0', 'host', 'check_sensors', 'sensor ok', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


sub test_simap { }


# check_smtp -H smtp.example.com
sub test_smtp {
    my @data = ('0', 'host', 'check_smtp', 'SMTP OK - 0.044 sec. response time', 'time=0.044291s;;;0.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.044291'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ]
          ]
        ];\n");
}


# check_snmp
sub test_snmp {
    my @data = ('0', 'host', 'check_snmp', 'SNMP OK - 3499', 'iso.3.6.1.4.1.nnnn.x.y.1.1.1.5.1.4.1=3499c');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'iso.3.6.1.4.1.nnnn.x.y.1.1.1.5.1.4.1',
            [
              'data',
              'COUNTER',
              '3499'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'check_snmp', 'SNMP OK - 3499', 'iso.3.6.1.4.1.nnnn.x.y.1.1.1.5.1.4.1=3499c iso.3.6.1.4.1.nnnn.x.y.1.1.1.5.1.4.2=1200c');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'iso.3.6.1.4.1.nnnn.x.y.1.1.1.5.1.4.1',
            [
              'data',
              'COUNTER',
              '3499'
            ]
          ],
          [
            'iso.3.6.1.4.1.nnnn.x.y.1.1.1.5.1.4.2',
            [
              'data',
              'COUNTER',
              '1200'
            ]
          ]
        ];\n");
}


# check_spop -H pop.example.com
sub test_spop {
    my @data = ('0', 'host', 'check_spop', 'SPOP OK - 0.230 second response time on port 995 [+OK mail00 Cyrus POP3 v2.2.13-Debian-2.2.13-13ubuntu3 server ready]', 'time=0.230375s;;;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.230375'
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
          ]
        ];\n");
}


# check_ssh -H example.com
sub test_ssh {
    my @data = ('0', 'host', 'check_ssh', 'SSH OK - OpenSSH_5.1p1 Debian-5ubuntu1 (protocol 2.0)', '');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
}


# check_ssmtp -H smtp.example.com -p 993
sub test_ssmtp {
    my @data = ('0', 'host', 'check_ssmtp', 'SSMTP WARNING - Unexpected response from host/socket: * OK mail00 Cyrus IMAP4 v2.2.13-Debian-2.2.13-13ubuntu3 server ready', 'time=0.198066s;;;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.198066'
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
          ]
        ];\n");
}


# check_swap -w 60% -c 50%
# check_swap -w 60 -c 50
sub test_swap {
    my @data = ('0', 'host', 'check_swap', 'SWAP OK - 100% free (1470 MB out of 1470 MB) ', 'swap=1470MB;882;735;0;1470');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'swap',
            [
              'data',
              'GAUGE',
              1541406720
            ],
            [
              'warn',
              'GAUGE',
              924844032
            ],
            [
              'crit',
              'GAUGE',
              770703360
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
          ]
        ];\n");

    @data = ('0', 'host', 'check_swap', 'SWAP OK - 100% free (1470 MB out of 1470 MB) ', 'swap=1470MB;0;0;0;1470');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'swap',
            [
              'data',
              'GAUGE',
              1541406720
            ],
            [
              'warn',
              'GAUGE',
              0
            ],
            [
              'crit',
              'GAUGE',
              0
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
          ]
        ];\n");
}


# check_tcp -H www.example.com -p 80
# check_tcp -H www.example.com -p 80 -w 10 -c 20
sub test_tcp {
    my @data = ('0', 'host', 'check_tcp', 'TCP OK - 0.004 second response time on port 80', 'time=0.003611s;;;0.000000;10.000000');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.003611'
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
          ]
        ];\n");

    @data = ('0', 'host', 'check_tcp', 'TCP OK - 0.004 second response time on port 80', 'time=0.014151s;10.000000;20.000000;0.000000;10.000000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0.014151'
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
          ]
        ];\n");
}


# check_time -H time.mit.edu
# check_time -H time.mit.edu -W 10 -C 20
# check_time -H time.mit.edu -W 10 -C 20 -w 10 -c 20
sub test_time {
    my @data = ('0', 'host', 'check_time', 'TIME OK - 1 second time difference', 'time=0s;;;0 offset=1s;;;0');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ],
          [
            'offset',
            [
              'data',
              'GAUGE',
              '1'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'check_time', 'TIME OK - 1 second time difference', 'time=0s;10;20;0 offset=1s;;;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
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
          ],
          [
            'offset',
            [
              'data',
              'GAUGE',
              '1'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'check_time', 'TIME OK - 1 second time difference', 'time=0s;10;20;0 offset=1s;10;20;0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'time',
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
          ],
          [
            'offset',
            [
              'data',
              'GAUGE',
              '1'
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
          ]
        ];\n");
}


sub test_udp { }


sub test_ups { }


# check_users -w 10 -c 20
sub test_users {
    my @data = ('0', 'host', 'check_users', 'USERS OK - 3 users currently logged in ', 'users=3;10;20;0');
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'users',
            [
              'data',
              'GAUGE',
              '3'
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
          ]
        ];\n");
}


sub test_wave { }



# check_nrpe with nsclient++
sub test_nsclient {
    # check_nrpe -c CheckCPU -a warn=80 crit=90 time=20m time=10s time=4
    my @data = ('0', 'host', 'check_nsclient', 'OK CPU Load ok.', "'20m'=0%;80;90; '10s'=1%;80;90; '4'=0%;80;90;");
    my @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '20m',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ]
          ],
          [
            '10s',
            [
              'data',
              'GAUGE',
              '1'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ]
          ],
          [
            '4',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ]
          ]
        ];\n");

    # check_nrpe -c CheckMEM -a MaxWarn=10% MaxCrit=20% ShowAll type=page
    @data = ('0', 'host', 'check_nsclient', 'WARNING: page file: Total: 15.8G - Used: 1.91G (12%) - Free: 13.9G (88%) > warning', "'page file %'=12%;10;20; 'page file'=1.90G;1.57;3.15;0;15.76;");
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'page file %',
            [
              'data',
              'GAUGE',
              '12'
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
            ]
          ],
          [
            'page file',
            [
              'data',
              'GAUGE',
              '2040109465.6'
            ],
            [
              'warn',
              'GAUGE',
              '1685774663.68'
            ],
            [
              'crit',
              'GAUGE',
              '3382286745.6'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '16922171146.24'
            ]
          ]
        ];\n");

    # check_nrpe -c CheckMEM -a MaxWarn=10% MaxCrit=20% ShowAll type=physical
    @data = ('0', 'host', 'check_nsclient', 'CRITICAL: physical memory: Total: 7.86G - Used: 2.79G (35%) - Free: 5.08G (65%) > critical', "'physical memory %'=35%;10;20; 'physical memory'=2854.67M;805.18;1610.36;0;8051.80;");
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'physical memory %',
            [
              'data',
              'GAUGE',
              '35'
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
            ]
          ],
          [
            'physical memory',
            [
              'data',
              'GAUGE',
              '2993338449.92'
            ],
            [
              'warn',
              'GAUGE',
              '844292423.68'
            ],
            [
              'crit',
              'GAUGE',
              '1688584847.36'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '8442924236.8'
            ]
          ]
        ];\n");

    # check_nrpe -c CheckMEM -a MaxWarn=80% MaxCrit=90% ShowAll type=physical type=page type=virtual
    @data = ('0', 'host', 'check_nsclient', 'OK: physical memory: 2.79G, page file: 1.91G, virtual memory: 52.8M', "'physical memory %'=35%;80;90; 'physical memory'=2.78G;6.2;7.07;0;7.86; 'page file %'=12%;80;90; 'page file'=1.90G;12.61;14.1;0;15.76; 'virtual memory %'=0%;80;90; 'virtual memory'=52.8M;6710886.;7549747.08;0;8388607.87;");
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'physical memory %',
            [
              'data',
              'GAUGE',
              '35'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ]
          ],
          [
            'physical memory',
            [
              'data',
              'GAUGE',
              '2985002270.72'
            ],
            [
              'warn',
              'GAUGE',
              '6657199308.8'
            ],
            [
              'crit',
              'GAUGE',
              '7591354695.68'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '8439610736.64'
            ]
          ],
          [
            'page file %',
            [
              'data',
              'GAUGE',
              '12'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ]
          ],
          [
            'page file',
            [
              'data',
              'GAUGE',
              '2040109465.6'
            ],
            [
              'warn',
              'GAUGE',
              '13539884400.64'
            ],
            [
              'crit',
              'GAUGE',
              '15139759718.4'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '16922171146.24'
            ]
          ],
          [
            'virtual memory %',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '80'
            ],
            [
              'crit',
              'GAUGE',
              '90'
            ]
          ],
          [
            'virtual memory',
            [
              'data',
              'GAUGE',
              '55364812.8'
            ],
            [
              'warn',
              'GAUGE',
              '7036873998336'
            ],
            [
              'crit',
              'GAUGE',
              '7916483594158.08'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '8796092885893.12'
            ]
          ]
        ];\n");

    # check_nrpe -c CheckProcState -a MaxWarnCount=4 -MaxCritCount=10 ShowAll
    @data = ('0', 'host', 'check_nsclient', 'OK: All processes are running.', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    # check_nrpe -c CheckServiceState -a ShowAll
    @data = ('0', 'host', 'check_nsclient', 'OK: All services are in their appropriate state.', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    # check_nrpe -c CheckUpTime -a MinWarn=1d MinCrit=12h
    @data = ('0', 'host', 'check_nsclient', 'OK all counters within bounds.', "'uptime'=3922472000;86400000;43200000;");
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'uptime',
            [
              'data',
              'GAUGE',
              '3922472000'
            ],
            [
              'warn',
              'GAUGE',
              '86400000'
            ],
            [
              'crit',
              'GAUGE',
              '43200000'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'check_nsclient', 'OK: Everything seems fine.', "'CPU'=1;50;80;");
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'CPU',
            [
              'data',
              'GAUGE',
              '1'
            ],
            [
              'warn',
              'GAUGE',
              '50'
            ],
            [
              'crit',
              'GAUGE',
              '80'
            ]
          ]
        ];\n");
}



setup();
test_apt();
test_breeze();
test_by_ssh();
test_clamd();
test_cluster();
test_dhcp();
test_dig();
test_disk();
test_disk_smb();
test_dns();
test_dummy();
test_file_age();
test_flexlm();
test_ftp();
test_hpjd();
test_http();
test_icmp();
test_ide_smart();
test_ifoperstatus();
test_ifstatus();
test_imap();
test_ircd();
test_jabber();
test_ldap();
test_ldaps();
test_load();
test_log();
test_mailq();
test_mrtg();
test_mrtgtraf();
test_mysql();
test_mysql_query();
test_nagios();
test_nntp();
test_nntps();
test_nrpe();
test_nt();
test_ntp();
test_ntp_peer();
test_ntp_time();
test_nwstat();
test_openvpn();
test_oracle();
test_overcr();
test_ping();
test_pop();
test_procs();
test_real();
test_rpc();
test_sensors();
test_simap();
test_smtp();
test_snmp();
test_spop();
test_ssh();
test_ssmtp();
test_swap();
test_tcp();
test_time();
test_udp();
test_ups();
test_users();
test_wave();
test_nsclient();
teardown();
