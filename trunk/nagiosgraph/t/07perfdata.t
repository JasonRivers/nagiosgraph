#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Matthew Wall, 2010

# the tests in this file exercise the rule parsing, specifically for the
# default map rule (the one that looks at performance data).  the tests should
# cover as many combinations and permutations of performance data formatting as
# possible.
#
# the tests in this file use the minimal map definition - just the perfdata
# rule.
#
# ensure that any standards-compliant plugin perfdata will be handled.
# ensure that any bogus perfdata will be reported.
# test for various units
# test for variations in perfdata formatting

## no critic (RequireUseWarnings)
## no critic (RequireBriefOpen)
## no critic (ProhibitImplicitNewlines)
## no critic (ProhibitEmptyQuotes)
## no critic (ProhibitQuotedWordLists)
## no critic (RequireInterpolationOfMetachars)

use FindBin;
use Test;
use strict;

BEGIN {
    my $rc = eval {
        require RRDs; RRDs->import();
        use Carp;
        use Data::Dumper;
        use English qw(-no_match_vars);
        use File::Copy qw(copy);
        use lib "$FindBin::Bin/../etc";
        use ngshared;
    };
    if ($rc) {
        plan tests => 0;
        exit 0;
    } else {
        plan tests => 52;
    }
}

my $logfile = 'test.log';
my $mapfile = 'map_minimal';

sub formatdata {
    my (@data) = @_;
    return "hostname:$data[1]\nservicedesc:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
}

sub setup {
    open $LOG, '+>', $logfile or carp "open LOG ($logfile) failed: $OS_ERROR";
#    $Config{debug} = 5;
    undef &evalrules; ## no critic (ProhibitAmpersandSigils)
    copy "examples/$mapfile", "etc/$mapfile";
    my $rval = getrules( $mapfile );
    ok($rval, q());
    return;
}

sub teardown {
    close $LOG or carp "close LOG failed: $OS_ERROR";
    unlink $logfile;
    unlink "etc/$mapfile";
    return;
}


sub testnoperfdata {
    my @s;
    my @data;

    # no perfdata
    @data = ('0', 'host', 'ping', 'PING OK', '');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");
    return;
}


sub testperfdatalabels {
    my @s;
    my @data;

    @data = ('0', 'host', 'ping', 'PING OK', 'name=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'name',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'name with spaces=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'name with spaces',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', '\'quote\'dname\'=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'quote\\'dname',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', '\'quotedname\'=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'quotedname',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', '\'quoted name\'=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'quoted name',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'namethatismorethannineteencharacterslong=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'namethatismorethannineteencharacterslong',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'hyphenated-name=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'hyphenated-name',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a!@#$%^&*()=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a!@#\$%^&*()',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a:b=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a:b',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', ':=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            ':',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'bill\'s value=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'bill\\'s value',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

# FIXME: too many backslashes?

    @data = ('0', 'host', 'ping', 'PING OK', 'c:\\=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'c:\\\\',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', '\\\\server\\share=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '\\\\\\\\server\\\\share',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    return;
}


# ensure that the range formats are handled correctly.  these are from the
# nagios plug-in development guidelines:
#
# 10         < 0 or > 10
# 10:        < 10
# ~:10       > 10
# 10:20      < 10 or > 20
# @10:20     >= 10 and <= 20
#
sub testranges {
    my @s;
    my @data;

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;10;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '10'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;10:;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_hi',
              'GAUGE',
              '10'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;~:10;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_lo',
              'GAUGE',
              '10'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;10:20;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_lo',
              'GAUGE',
              '10'
            ],
            [
              'warn_hi',
              'GAUGE',
              '20'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;@10:20;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_lo',
              'GAUGE',
              '10'
            ],
            [
              'warn_hi',
              'GAUGE',
              '20'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;-10.1;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn',
              'GAUGE',
              '-10.1'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;-10.1:;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_hi',
              'GAUGE',
              '-10.1'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;~:-10.1;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_lo',
              'GAUGE',
              '-10.1'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;-10.1:20.2;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_lo',
              'GAUGE',
              '-10.1'
            ],
            [
              'warn_hi',
              'GAUGE',
              '20.2'
            ]
          ]
        ];\n");

    @data = ('0', 'host', 'ping', 'PING OK', 'a=0;@-10.1:20.2;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '0'
            ],
            [
              'warn_lo',
              'GAUGE',
              '-10.1'
            ],
            [
              'warn_hi',
              'GAUGE',
              '20.2'
            ]
          ]
        ];\n");

    return;
}


sub testrandomperfdata {
    my @s;
    my @data;

    # single name-value pair
    @data = ('0', 'host', 'ping', 'PING OK', 'a=2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    # multiple items
    @data = ('0', 'host', 'ping', 'PING OK', 'a=2 b=3');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ],
          [
            'b',
            [
              'data',
              'GAUGE',
              '3'
            ]
          ]
        ];\n");

    # spaces before the equals
    @data = ('0', 'host', 'ping', 'PING OK', 'a =2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'a',
            [
              'data',
              'GAUGE',
              '2'
            ]
          ]
        ];\n");

    # spaces after the equals
    @data = ('0', 'host', 'ping', 'PING OK', 'a= 2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    # spaces before and after the equals
    @data = ('0', 'host', 'ping', 'PING OK', 'a = 2');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [];\n");

    return;
}


sub testmultipleperfdata {
    my @s;
    my @data;

    @data = ('0', 'host', 'disk', 'DISK OK - free space: / 23733 MB (90% inode=96%)', '/=2481MB;27567;27607;0;27617 /home=2481MB;27567;27607;0;27617 /var=200MB;240;250;0;256');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              2601517056
            ],
            [
              'warn',
              'GAUGE',
              '28906094592'
            ],
            [
              'crit',
              'GAUGE',
              '28948037632'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '28958523392'
            ]
          ],
          [
            '/home',
            [
              'data',
              'GAUGE',
              2601517056
            ],
            [
              'warn',
              'GAUGE',
              '28906094592'
            ],
            [
              'crit',
              'GAUGE',
              '28948037632'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '28958523392'
            ]
          ],
          [
            '/var',
            [
              'data',
              'GAUGE',
              209715200
            ],
            [
              'warn',
              'GAUGE',
              251658240
            ],
            [
              'crit',
              'GAUGE',
              262144000
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              268435456
            ]
          ]
        ];\n");

    return;
}


sub testunits {
    my @s;
    my @data;

    # single set of perfdata, with units of s
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.544000s;300.000000;800.000000;0.000000;1000.0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.544000'
            ],
            [
              'warn',
              'GAUGE',
              '300.000000'
            ],
            [
              'crit',
              'GAUGE',
              '800.000000'
            ],
            [
              'min',
              'GAUGE',
              '0.000000'
            ],
            [
              'max',
              'GAUGE',
              '1000.0'
            ]
          ]
        ];\n");

    # single set of perfdata, with units of us
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.544000us;300.000000;800.000000;0.000000;1000.0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '5.44e-07'
            ],
            [
              'warn',
              'GAUGE',
              '0.0003'
            ],
            [
              'crit',
              'GAUGE',
              '0.0008'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '0.001'
            ]
          ]
        ];\n");

    # single set of perfdata, with units of ms
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.544000ms;300.000000;800.000000;0.000000;1000.0');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.000544'
            ],
            [
              'warn',
              'GAUGE',
              '0.3'
            ],
            [
              'crit',
              'GAUGE',
              '0.8'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '1'
            ]
          ]
        ];\n");

    # units of percent
    @data = ('0', 'host', 'ping', 'PING OK', 'pl=0%;20;60;0;100');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
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
              '20'
            ],
            [
              'crit',
              'GAUGE',
              '60'
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

    # units of B
    @data = ('0', 'host', 'disk', 'DISK OK', '/=200B;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              '200'
            ],
            [
              'warn',
              'GAUGE',
              '500'
            ],
            [
              'crit',
              'GAUGE',
              '1000'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '1000'
            ]
          ]
        ];\n");

    # units of KB
    @data = ('0', 'host', 'disk', 'DISK OK', '/=200KB;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              204800
            ],
            [
              'warn',
              'GAUGE',
              512000
            ],
            [
              'crit',
              'GAUGE',
              1024000
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              1024000
            ]
          ]
        ];\n");

    # units of MB
    @data = ('0', 'host', 'disk', 'DISK OK', '/=200MB;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              209715200
            ],
            [
              'warn',
              'GAUGE',
              524288000
            ],
            [
              'crit',
              'GAUGE',
              1048576000
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              1048576000
            ]
          ]
        ];\n");

    # units of GB
    @data = ('0', 'host', 'disk', 'DISK OK', '/=200GB;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              '214748364800'
            ],
            [
              'warn',
              'GAUGE',
              '536870912000'
            ],
            [
              'crit',
              'GAUGE',
              '1073741824000'
            ],
            [
              'min',
              'GAUGE',
              0
            ],
            [
              'max',
              'GAUGE',
              '1073741824000'
            ]
          ]
        ];\n");

    # units of TB
    @data = ('0', 'host', 'disk', 'DISK OK', '/=200TB;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              '219902325555200'
            ],
            [
              'warn',
              'GAUGE',
              '549755813888000'
            ],
            [
              'crit',
              'GAUGE',
              '1.099511627776e+15'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '1.099511627776e+15'
            ]
          ]
        ];\n");

    # units of PB
    @data = ('0', 'host', 'disk', 'DISK OK', '/=200PB;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            '/',
            [
              'data',
              'GAUGE',
              '2.25179981368525e+17'
            ],
            [
              'warn',
              'GAUGE',
              '5.62949953421312e+17'
            ],
            [
              'crit',
              'GAUGE',
              '1.12589990684262e+18'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '1.12589990684262e+18'
            ]
          ]
        ];\n");

    # units of counter
    @data = ('0', 'host', 'net', 'OK', 'sent=200c;500;1000;0;1000');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'sent',
            [
              'data',
              'COUNTER',
              '200'
            ],
            [
              'warn',
              'COUNTER',
              '500'
            ],
            [
              'crit',
              'COUNTER',
              '1000'
            ],
            [
              'min',
              'COUNTER',
              '0'
            ],
            [
              'max',
              'COUNTER',
              '1000'
            ]
          ]
        ];\n");

    # two different sets of perfdata, each with different units
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.544000ms;300.000000;800.000000;0.000000;1000.0 pl=0%;20;60;0;100');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.000544'
            ],
            [
              'warn',
              'GAUGE',
              '0.3'
            ],
            [
              'crit',
              'GAUGE',
              '0.8'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '1'
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
              '20'
            ],
            [
              'crit',
              'GAUGE',
              '60'
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

    return;
}


sub testminmax {
    my @s;
    my @data;

    # no min/max/crit/warn
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ]
          ]
        ];\n");

    # no min/max/crit/warn, with semi-colons
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s;;;');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ]
          ]
        ];\n");

    # crit only
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s;;5');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ],
            [
              'crit',
              'GAUGE',
              '5'
            ]
          ]
        ];\n");

    # warn only
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s;5');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ],
            [
              'warn',
              'GAUGE',
              '5'
            ]
          ]
        ];\n");

    # min only
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s;;;5');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ],
            [
              'min',
              'GAUGE',
              '5'
            ]
          ]
        ];\n");

    # max only
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s;;;;5');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ],
            [
              'max',
              'GAUGE',
              '5'
            ]
          ]
        ];\n");

    # min and max
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.5s;;;0;5');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.5'
            ],
            [
              'min',
              'GAUGE',
              '0'
            ],
            [
              'max',
              'GAUGE',
              '5'
            ]
          ]
        ];\n");

    # partial set of perfdata - no max value for one, no min/max for the other
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.544000ms;300.000000;800.000000;0.000000 pl=0%;20;60');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.000544'
            ],
            [
              'warn',
              'GAUGE',
              '0.3'
            ],
            [
              'crit',
              'GAUGE',
              '0.8'
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
              '20'
            ],
            [
              'crit',
              'GAUGE',
              '60'
            ]
          ]
        ];\n");

    # no min/max values
    @data = ('0', 'host', 'ping', 'PING OK', 'rta=0.544000ms;300.000000;800.000000 pl=0%;20;60');
    @s = evalrules( formatdata( @data ) );
    ok(Dumper(\@s), "\$VAR1 = [
          [
            'rta',
            [
              'data',
              'GAUGE',
              '0.000544'
            ],
            [
              'warn',
              'GAUGE',
              '0.3'
            ],
            [
              'crit',
              'GAUGE',
              '0.8'
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
              '20'
            ],
            [
              'crit',
              'GAUGE',
              '60'
            ]
          ]
        ];\n");

    return;
}


setup();
testnoperfdata();
testperfdatalabels();
testranges();
testrandomperfdata();
testmultipleperfdata();
testunits();
testminmax();
teardown();
