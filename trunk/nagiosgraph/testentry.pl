#!/usr/bin/perl

use Data::Dumper;

$_ = <<DATA;
servicedescr:ping
output:PING OK - Packet loss = 0%, RTA = 0.31 ms
perfdata:
DATA

/output:PING.*?(\d+)%.+?([.\d]+)\sms/
and push @s, [ ping,
               [ losspct, GAUGE, $1      ],
               [ rta,     GAUGE, $2/1000 ] ];

print Data::Dumper->Dump([\@s], [qw(*s)]);
