#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

# FIXME: these tests are still not self-contained, since many depend on the
#        state of global variables (%Config, i'm lookin' at you!).  the globals
#        should be reduced/eliminated and the subroutines refactored so that
#        have fewer side effects and global dependencies.

## no critic (RequireUseWarnings)
## no critic (ProhibitImplicitNewlines)
## no critic (ProhibitMagicNumbers)
## no critic (RequireNumberSeparators)
## no critic (RequireBriefOpen)
## no critic (ProhibitPostfixControls)
## no critic (ProhibitEmptyQuotes)
## no critic (ProhibitQuotedWordLists)
## no critic (ProhibitNoisyQuotes)
## no critic (RequireExtendedFormatting)
## no critic (RequireLineBoundaryMatching)
## no critic (ProhibitEscapedCharacters)

use FindBin;
use Test;
use strict;

use CGI qw(:standard escape unescape);
use Carp;
use Data::Dumper;
use File::Find;
use File::Path qw(rmtree);
use English qw(-no_match_vars);
use lib "$FindBin::Bin/../etc";
use ngshared;

BEGIN {
## no critic (ProhibitStringyEval)
## no critic (ProhibitPunctuationVars)
    my $rc = eval "
        require RRDs; RRDs->import();
        use CGI qw(:standard escape unescape);
        use Carp;
        use Data::Dumper;
        use English qw(-no_match_vars);
        use File::Find;
        use File::Path qw(rmtree);
        use lib \"$FindBin::Bin/../etc\";
        use ngshared;
    ";
    if ($@) {
        plan tests => 0;
        exit 0;
    } else {
        plan tests => 665;
    }
}

my ($log);
my $curdir = $FindBin::Bin; ## no critic (ProhibitPackageVars)

# ensure that we have a clean slate from which to work
sub setup {
    rmtree($curdir . '/testbox');
    return;
}

sub writefile {
    my ($fn, @data) = @_;
    open my $TEST, '>', $fn or carp "open $fn failed; $OS_ERROR";
    foreach my $line (@data) {
        print ${TEST} $line . "\n" or carp "print failed: $OS_ERROR";
    }
    close $TEST or carp "close $fn failed: $OS_ERROR";
    return;
}

sub dumpdata {
    my ($log, $val, $label) = @_;
    open my $TMP, '>>', 'test.log' or carp "open test.log failed: $OS_ERROR";
    if ($label) {
        my $dd = Data::Dumper->new([$val], [$label]);
        $dd->Indent(1);
        print ${TMP} $dd->Dump() or carp "print failed: $OS_ERROR";
    }
    print ${TMP} $log or carp "print failed: $OS_ERROR";
    close $TMP or carp "close test.log failed: $OS_ERROR";
    return;
}

sub printdata {
    my ($data) = @_;
    my $dd = Data::Dumper->new([$data]);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    return $dd->Dump;
}

sub readtestfile {
    my ($fn) = @_;
    my $contents = q();
    if (open my $FILE, '<', $fn) {
        while(<$FILE>) {
            $contents .= $_;
        }
        close $FILE or carp "close $fn failed: $OS_ERROR";
    }
    return $contents;
}

sub gettestrrddir {
    return $curdir . q(/) . 'rrd';
}

sub setupdebug {
    my ($level, $fn) = @_;
    $level ||= 5;
    $fn ||= 'test-debug.txt';
    $Config{debug} = $level;
    open $LOG, '+>', $fn or carp "open LOG ($fn) failed: $OS_ERROR";
    return;
}

sub teardowndebug {
    close $LOG or carp "close LOG failed: $OS_ERROR";
    $Config{debug} = 0;
    return;
}

sub setuphsdata {
    undef %hsdata;
    scanhsdata();
    return;
}

sub teardownhsdata {
    undef %hsdata;
    return;
}

sub setupauthhosts {
    undef %hsdata;
    scanhsdata();
    %authhosts = getserverlist('');
    return;
}

sub teardownauthhosts {
    undef %hsdata;
    undef %authhosts;
    return;
}

# create rrd files used in the tests
#   host   service      db           ds1,ds2,...
#   host0  PING         ping         losspct,rta
#   host0  HTTP         http         Bps
#   host1  HTTP         http         Bps
#   host2  PING         ping         losspct,rta
#   host3  ping         loss         losspct,losswarn,losscrit
#   host3  ping         rta          rta,rtawarn,rtacrit
#   host4  c:\ space    ntdisk       total,used
#   host5  ntdisk       c:\ space    total,used
sub setuprrd {
    my ($format) = @_;
    if (! $format) { $format = 'subdir'; }
    $Config{dbseparator} = $format;
    $Config{heartbeat} = 600;
    $Config{rrddir} = gettestrrddir();
    rmtree($Config{rrddir});
    mkdir $Config{rrddir};

    my $testvar = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    my @result = createrrd(1221495632, 'host0', 'PING', $testvar);
    $testvar = ['http', ['Bps', 'GAUGE', 0] ];
    @result = createrrd(1221495632, 'host0', 'HTTP', $testvar);

    $testvar = ['http', ['Bps', 'GAUGE', 0] ];
    @result = createrrd(1221495632, 'host1', 'HTTP', $testvar);

    $testvar = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'host2', 'PING', $testvar);

    $testvar = ['loss',
                ['losspct', 'GAUGE', 0],
                ['losswarn', 'GAUGE', 5],
                ['losscrit', 'GAUGE', 10] ];
    @result = createrrd(1221495632, 'host3', 'ping', $testvar);
    $testvar = ['rta',
                ['rta', 'GAUGE', 0.01],
                ['rtawarn', 'GAUGE', 0.1],
                ['rtacrit', 'GAUGE', 0.5] ];
    @result = createrrd(1221495632, 'host3', 'ping', $testvar);

    $testvar = ['ntdisk',
                ['total', 'GAUGE', 100],
                ['used', 'GAUGE', 10] ];
    @result = createrrd(1221495632, 'host4', 'c:\\ space', $testvar);

    $testvar = ['c:\\ space',
                ['total', 'GAUGE', 500],
                ['used', 'GAUGE', 20] ];
    @result = createrrd(1221495632, 'host5', 'ntdisk', $testvar);

    return;
}

sub teardownrrd {
    rmtree(gettestrrddir());
    return;
}

sub testdebug { # Test the logger.
    open $LOG, '+>', \$log or carp "open LOG failed: $OS_ERROR";
    $Config{debug} = 1;
    debug(0, 'test message');
    ok($log, qr/02ngshared.t none test message$/);
    close $LOG or carp "close LOG failed: $OS_ERROR";
    open $LOG, '+>', \$log or carp "open LOG failed: $OS_ERROR";
    debug(2, 'test no message');
    ok($log, '');
    close $LOG or carp "close LOG failed: $OS_ERROR";
    return;
}

sub testdumper { # Test the list/hash output debugger.
    open $LOG, '+>', \$log or carp "open LOG failed: $OS_ERROR";
    my $testvar = 'test';
    dumper(0, 'test', \$testvar);
    ok($log, qr/02ngshared.t none test = .'test';$/);
    close $LOG or carp "close LOG failed: $OS_ERROR";
    open $LOG, '+>', \$log or carp "open LOG failed: $OS_ERROR";
    $testvar = ['test'];
    dumper(0, 'test', $testvar);
    ok($log, qr/02ngshared.t none test = \[\s+'test'\s+\];$/s);
    close $LOG or carp "close LOG failed: $OS_ERROR";
    open $LOG, '+>', \$log or carp "open LOG failed: $OS_ERROR";
    $testvar = {test => 1};
    dumper(0, 'test', $testvar);
    ok($log, qr/02ngshared.t none test = \{\s+'test' => 1\s+\};$/s);
    close $LOG or carp "close LOG failed: $OS_ERROR";
    open $LOG, '+>', \$log or carp "open LOG failed: $OS_ERROR";
    dumper(2, 'test', $testvar);
    ok($log, '');
    close $LOG or carp "close LOG failed: $OS_ERROR";
    $Config{debug} = 0;
    return;
}

sub testgetdebug {
    # missing app (programming mistake)
    $Config{debug} = -1;
    getdebug();
    ok($Config{debug}, 5);
 
    $Config{debug} = -1;
    getdebug('test', '', '');
    ok($Config{debug}, -1);  # not configured, so no change

    # just program tests
    $Config{debug_test} = 1;
    getdebug('test', '', '');
    ok($Config{debug}, 1);   # configured, so change
    $Config{debug} = -1;
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);   # _host and _service not set, so change
    $Config{debug} = -1;

    # just program and hostname tests
    $Config{debug_test_host} = 'testbox';
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);   # _host set to same hostname, so change
    $Config{debug} = -1;
    getdebug('test', 'testing', 'ping');
    ok($Config{debug}, 0);   # _host set to different hostname, so no logging
    $Config{debug} = -1;

    # program, hostname and service tests
    $Config{debug_test_service} = 'ping';
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);   # _host and _service same, so change
    $Config{debug} = -1;
    getdebug('test', 'testbox', 'smtp');
    ok($Config{debug}, 0);   # _host same, but _service not, so no logging
    $Config{debug} = -1;
    getdebug('test', 'testing', 'ping');
    ok($Config{debug}, 0);   # _service same, but _host not, so no logging
    $Config{debug} = -1;
    getdebug('test', 'testing', 'smtp');
    ok($Config{debug}, 0);   # neither _host or _service not, so no logging
    $Config{debug} = -1;

    # just program and service tests
    delete $Config{debug_test_host};
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);   # _service same, so change
    $Config{debug} = -1;
    getdebug('test', 'testbox', 'smtp');
    ok($Config{debug}, 0);   # _service not, so no logging

    # clean up
    $Config{debug} = 0;
    return;
}

sub testformatelapsedtime {
    my $s = gettimestamp();
    my $result = formatelapsedtime($s, $s+3_000_000);
    ok($result, '00:00:03.000');
    $result = formatelapsedtime($s, $s+60_010_000);
    ok($result, '00:01:00.010');
    $result = formatelapsedtime($s, $s+36_610_000_000);
    ok($result, '10:10:10.000');
    $result = formatelapsedtime($s, $s+7_260_100_000);
    ok($result, '02:01:00.100');
    $result = formatelapsedtime($s, $s+1_000);
    ok($result, '00:00:00.001');
    $result = formatelapsedtime($s, $s+10);
    ok($result, '00:00:00.000');
    return;
}

sub testhtmlerror {
## no critic (ProhibitTwoArgOpen)
## no critic (ProhibitBarewordFileHandles)
## no critic (ProhibitInterpolationOfLiterals)

    open SAVEOUT, ">&STDOUT" or carp "open SAVEOUT failed: $OS_ERROR";
    my $fn = $curdir . q(/) . 'error.html';
    open STDOUT, '>', $fn or carp "open $fn failed: $OS_ERROR";
    htmlerror('test');
    close STDOUT or carp "close STDOUT failed: $OS_ERROR";
    open STDOUT, ">&SAVEOUT" or carp "open STDOUT failed: $OS_ERROR";
    close SAVEOUT or carp "close SAVEOUT failed: $OS_ERROR";
    my $result = readtestfile($fn);
    ok($result, "Content-Type: text/html; charset=ISO-8859-1\r
\r
<!DOCTYPE html
\tPUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"
\t \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en-US\" xml:lang=\"en-US\">
<head>
<title>NagiosGraph Error</title>
<style type=\"text/css\">.error {font-family: sans-serif; font-size: 0.8em; padding: 0.5em; background-color: #fff6f3; border: solid 1px #cc3333; margin-bottom: 1.5em;}</style>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=iso-8859-1\" />
</head>
<body id=\"nagiosgraph\">
<div class=\"error\">test</div>

</body>
</html>");
    unlink $fn;
    return;
}

sub testimgerror {
## no critic (ProhibitTwoArgOpen)
## no critic (ProhibitBarewordFileHandles)
## no critic (ProhibitInterpolationOfLiterals)

    my $cgi = new CGI;
    my $fn = $curdir . q(/) . 'error.png';

    my $havegd = 0;
    my $rval = eval { require GD; };
    if (defined $rval && $rval == 1) {
        $havegd = 1;
    }

    open SAVEOUT, ">&STDOUT" or carp "open SAVEOUT failed: $OS_ERROR";
    open STDOUT, '>', $fn or carp "open $fn failed: $OS_ERROR";
    imgerror($cgi);
    close STDOUT or carp "close $fn failed: $OS_ERROR";
    open STDOUT, ">&SAVEOUT" or carp "open STDOUT failed: $OS_ERROR";
    close SAVEOUT or carp "close SAVEOUT failed: $OS_ERROR";
    my $result = readtestfile($fn);
    ok($result, "Content-Type: image/png\r\n\r\n\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\0\5\0\0\0\5\b\6\0\0\0\x8Do&\xE5\0\0\0!tEXtSoftware\0GraphicConverter (Intel)w\x87\xFA\31\0\0\0\31IDATx\x9Cb\xF8\xFF\xFF?\3:\xC6\20\xA0\x82 \0\0\0\xFF\xFF\3\0x\xC3J\xB6\x9F\xEB2\35\0\0\0\0IEND\xAEB`\x82");
    unlink $fn;

    open SAVEOUT, ">&STDOUT" or carp "open SAVEOUT failed: $OS_ERROR";
    open STDOUT, '>', $fn or carp "open STDOUT failed: $OS_ERROR";
    imgerror($cgi, 'test');
    close STDOUT or carp "close STDOUT failed: $OS_ERROR";
    open STDOUT, ">&SAVEOUT" or carp "open STDOUT failed: $OS_ERROR";
    close SAVEOUT or carp "close SAVEOUT failed: $OS_ERROR";
    $result = readtestfile($fn);

    if ($havegd) {
        ok($result, "Content-Type: image/png\r\n\r\n\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\2`\0\0\0\27\1\3\0\0\0\x96\35a\xC3\0\0\0\6PLTE\xFF\xFF\xFF\xFF\24\24\xDF.\xE4\xBB\0\0\0\1tRNS\0@\xE6\xD8f\0\0\0>IDAT8\x8Dc`\30\5\xA3\0;`a`\34\xA4\x86\xF1\xCB\24\37\xA0\x9Aa,J\x9DT3\x8B\x81\xC5.\x91\x8A\x86)\bR\xD1\xB0\5\x9D\nT3\x8CY\xA6\xE0\0\xD5\f\e\5\xA3\x80\16\0\0\4Q\5\x8C\xE7\37\xF6\\\0\0\0\0IEND\xAEB`\x82");
    } else {
        ok($result, "Content-Type: image/png\r\n\r\n\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\0\5\0\0\0\5\b\6\0\0\0\x8Do&\xE5\0\0\0!tEXtSoftware\0GraphicConverter (Intel)w\x87\xFA\31\0\0\0\31IDATx\x9Cb\xF8\xFF\xFF?\3:\xC6\20\xA0\x82 \0\0\0\xFF\xFF\3\0x\xC3J\xB6\x9F\xEB2\35\0\0\0\0IEND\xAEB`\x82");
    }

    unlink $fn;
    return;
}

sub testgetimg {
    my $havegd = 0;
    my $rval = eval { require GD; };
    if (defined $rval && $rval == 1) {
        $havegd = 1;
    }

    if ($havegd) {
        ok(getimg('test'), "\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\2`\0\0\0\27\1\3\0\0\0\x96\35a\xC3\0\0\0\6PLTE\xFF\xFF\xFF\xFF\24\24\xDF.\xE4\xBB\0\0\0\1tRNS\0@\xE6\xD8f\0\0\0>IDAT8\x8Dc`\30\5\xA3\0;`a`\34\xA4\x86\xF1\xCB\24\37\xA0\x9Aa,J\x9DT3\x8B\x81\xC5.\x91\x8A\x86)\bR\xD1\xB0\5\x9D\nT3\x8CY\xA6\xE0\0\xD5\f\e\5\xA3\x80\16\0\0\4Q\5\x8C\xE7\37\xF6\\\0\0\0\0IEND\xAEB`\x82");
    } else {
        ok(getimg('test'), "\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\0\5\0\0\0\5\b\6\0\0\0\x8Do&\xE5\0\0\0!tEXtSoftware\0GraphicConverter (Intel)w\x87\xFA\31\0\0\0\31IDATx\x9Cb\xF8\xFF\xFF?\3:\xC6\20\xA0\x82 \0\0\0\xFF\xFF\3\0x\xC3J\xB6\x9F\xEB2\35\0\0\0\0IEND\xAEB`\x82");
    }
    return;
}

# ensure that asking about host data does not create host directory
sub testdircreation {
    $Config{rrddir} = $curdir;
    $Config{dbseparator} = 'subdir';
    my $host = 'xxx';
    my $service = 'yyy';
    my ($d,$f) = mkfilename($host,$service);
    my $dir = $curdir . q(/) . $host;
    ok(! -d $dir);
    rmdir $dir if -d $dir;
    return;
}

sub testmkfilename { # Test getting the file and directory for a database.
    # Make rrddir where we run from
    $Config{rrddir} = $curdir;

    $Config{dbseparator} = '';
    my @result = mkfilename();
    ok($result[0], 'BOGUSDIR');
    ok($result[1], 'BOGUSFILE');
    @result = mkfilename('host');
    ok($result[0], 'BOGUSDIR');
    ok($result[1], 'BOGUSFILE');
    @result = mkfilename('testbox', 'Partition: /');
    ok($result[0], $curdir);
    ok($result[1], 'testbox_Partition%3A%20%2F_');
    @result = mkfilename('testbox', 'Partition: /', 'diskgb');
    ok($result[0], $curdir);
    ok($result[1], 'testbox_Partition%3A%20%2F_diskgb.rrd');

    $Config{dbseparator} = 'subdir';
    @result = mkfilename('testbox', 'Partition: /');
    ok($result[0], $curdir . '/testbox');
    ok($result[1], 'Partition%3A%20%2F___');
    ok(! -d $result[0]);
    rmdir $result[0] if -d $result[0];
    @result = mkfilename('testbox', 'Partition: /', 'diskgb');
    ok($result[0], $curdir . '/testbox');
    ok($result[1], 'Partition%3A%20%2F___diskgb.rrd');
    ok(! -d $result[0]);
    rmdir $result[0] if -d $result[0];
    return;
}

# With 16 generated colors, the default rainbow and one custom.
sub testhashcolor {
    my @testdata = ('FF0333', '3300CC', '990033', 'FF03CC', '990333', 'CC00CC', '000099', '6603CC');
    foreach my $ii (0..7) {
        my $result = hashcolor('Current Load', $ii + 1);
        ok($result, $testdata[$ii - 1]);
    }
    @testdata = ('CC0300', 'FF0399', '990000', '330099', '990300', '660399', '990000', 'CC0099');
    foreach my $ii (1..8) {
        my $result = hashcolor('PLW', $ii);
        ok($result, $testdata[$ii - 1]);
    }
    $Config{colors} = ['123', 'ABC'];
    @testdata = ('123', 'ABC', '123');
    foreach my $ii (0..2) {
        my $result = hashcolor('test', 9);
        ok($result, $testdata[$ii]);
    }
    undef %Config;
    $Config{colorscheme} = 2;
    ok(hashcolor('x'), '009900');
    return;
}

sub testlisttodict { # Split a string separated by a configured value into hash
#    setupdebug(5, 'testlisttodict.log');

    $Config{testsep} = ',';
    $Config{test} = 'Current Load,PLW,Procs: total,User Count';
    my $testvar = listtodict('test');
    foreach my $ii ('Current Load','PLW','Procs: total','User Count') {
        ok($testvar->{$ii}, 1);
    }

#    teardowndebug();
    return;
}

sub teststr2list {
    my $val = str2list('H,S,D=10;*,*=50');
    ok(Dumper($val), "\$VAR1 = [
          'H,S,D=10',
          '*,*=50'
        ];\n");
    # reverse the order
    $val = str2list('*,*=50;H,S,D=10');
    ok(Dumper($val), "\$VAR1 = [
          '*,*=50',
          'H,S,D=10'
        ];\n");

    my $str = "\$VAR1 = [
          '*,*=50',
          'H,S,D=10'
        ];\n";

    # trailing delimiter
    $val = str2list('*,*=50;H,S,D=10;');
    ok(Dumper($val), $str);
    # trailing delimiters
    $val = str2list('*,*=50;H,S,D=10;;');
    ok(Dumper($val), $str);
    # leading delimiters
    $val = str2list(';;;*,*=50;H,S,D=10');
    ok(Dumper($val), $str);

    # check stripping of spaces
    $val = str2list('*,*=50;H,S,D=10  ');
    ok(Dumper($val), $str);
    $val = str2list('   *,*=50;H,S,D=10  ');
    ok(Dumper($val), $str);
    $val = str2list('   *,*=50; H,S,D=10  ');
    ok(Dumper($val), $str);
    $val = str2list('*,*=50     ; H,S,D=10  ');
    ok(Dumper($val), $str);
    return;
}

sub testarrayorstring {
    my %opts;
    $opts{a} = 'aval';
    $opts{array} = ['a','b','c'];
    ok(arrayorstring(\%opts, 'a'), '&a=aval');
    ok(arrayorstring(\%opts, 'array'), '&array=a&array=b&array=c');
    return;
}

sub testcheckdirempty { # Test with an empty directory, then one with a file.
    mkdir 'checkdir', 0770;
    ok(checkdirempty('checkdir'), 1);
    open my $TMP, '>', 'checkdir/tmp' or carp "open TMP failed: $OS_ERROR";
    print ${TMP} "test\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close TMP failed: $OS_ERROR";
    ok(checkdirempty('checkdir'), 0);
    unlink 'checkdir/tmp';
    rmdir 'checkdir';
    return;
}

sub testhsddmatch {
    ok(hsddmatch('XX', 'h,s,db,ds', 'DS', 'h', 's', 'db', 'ds'), 1);
    ok(hsddmatch('XX', ',s,db,ds', 'DS', 'h', 's', 'db', 'ds'), 0);
    ok(hsddmatch('XX', ',,db,ds', 'DS', 'h', 's', 'db', 'ds'), 0);
    ok(hsddmatch('XX', ',,,ds', 'DS', 'h', 's', 'db', 'ds'), 0);

    ok(hsddmatch('XX', '.*,.*,.*,ds', 'DS', 'h', 's', 'db', 'ds'), 1);

    ok(hsddmatch('XX', '.*.com,.*,.*,ds', 'DS', 'h.com', 's', 'db', 'ds'), 1);
    ok(hsddmatch('XX', '.*.com,.*,.*,ds', 'DS', 'h.edu', 's', 'db', 'ds'), 0);

    ok(hsddmatch('XX', 'h,s,db,ds', 'DS', 'h', 's', 'db', 'ds'), 1);
    ok(hsddmatch('XX', 'h,s,db,ds', 'DS', 'H', 's', 'db', 'ds'), 0);
    ok(hsddmatch('XX', 'h,s,db', 'S', 'h', 's', 'db'), 1);
    ok(hsddmatch('XX', 'h,s,db', 'S', 'H', 's', 'db'), 0);
    return;
}

sub testgethsdd {
    # datasource priority
    $Config{hsd} = 'h,s,db,ds';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsdd('DS', 'hsd', '0', 'h', 's', 'db', 'ds'), 1);
    ok(gethsdd('DS', 'hsd', '0', 'H', 's', 'db', 'ds'), 0);

    # pattern too long for datasource priority
    $Config{hsd} = 'h,s,db,ds,LINE,COLOR';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsdd('DS', 'hsd', '0', 'h', 's', 'db', 'ds'), 0);

    # service priority
    $Config{hsd} = 'h,s,db';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsdd('S', 'hsd', '0', 'h', 's', 'db'), 1);
    ok(gethsdd('S', 'hsd', '0', 'H', 's', 'db'), 0);

    # pattern too long for service priority
    $Config{hsd} = 'h,s,db,ds';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsdd('S', 'hsd', '0', 'h', 's', 'db', 'ds'), 0);

    undef $Config{hsd};
    undef $Config{hsdlist};
    return;
}

sub testgethsddvalue {
#    setupdebug(5, 'testgethsddvalue.log');
    $Config{hsd} = 'h,s,db,ds';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsddvalue('hsd', '0', 'h', 's', 'db', 'ds'), 1);
    ok(gethsddvalue('hsd', '0', 'H', 's', 'db', 'ds'), 0);
    undef $Config{hsd};
    undef $Config{hsdlist};
#    teardowndebug();
    return;
}

sub testgethsdvalue {
    $Config{hsd} = 'h,s,db';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsdvalue('hsd', '0', 'h', 's', 'db'), '1');
    ok(gethsdvalue('hsd', '0', 'H', 's', 'db'), '0');
    ok(gethsdvalue('hsd', '0', 'ha', 's', 'db'), '0');
    ok(gethsdvalue('hsd', '0', 'ah', 's', 'db'), '0');
    $Config{hsd} = 'hh,s,db';
    $Config{hsdlist} = str2list($Config{hsd});
    ok(gethsdvalue('hsd', '0', 'hh', 's', 'db'), '1');
    ok(gethsdvalue('hsd', '0', 'h', 's', 'db'), '0');
    undef $Config{hsd};
    undef $Config{hsdlist};
    return;
}

sub testgethsdvalue2 {
    $Config{hsdlist} = str2list('host0,ping,rta=10;host5,http,bps=30');
    my $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '50');
    $Config{hsd} = 100;
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '100');
    $Config{hsdlist} = str2list('host1,ping,rta=10;host5,http,bps=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');
    $Config{hsdlist} = str2list('host1,ping,rta=10;host5,http,bps=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'loss');
    ok($x, '100');

    # test matching precedence - should be first match
    $Config{hsd} = 100;
    $Config{hsdlist} = str2list('.*,.*,.*=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,ping,.*=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,PING,.*=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '100');
    $Config{hsdlist} = str2list('host1,ping,.*=10;.*,.*,.*=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');
    $Config{hsdlist} = str2list('.*,.*,.*=30;host1,ping,.*=10');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('host1,.*,.*=10;.*,.*,.*=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');
    $Config{hsdlist} = str2list('.*,ping,.*=10;.*,.*,.*=30');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');

    # test combinations
    $Config{hsd} = 100;
    $Config{hsdlist} = str2list('.*,.*,delay=30;.*,ping,loss=10');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '100');
    $Config{hsdlist} = str2list('.*,.*,rta=30;.*,ping,loss=10');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,.*,rta=20;.*,ping,rta=10');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '20');
    $Config{hsdlist} = str2list('host1,.*,rta=30;.*,ping,RTA=10');
    $x = gethsdvalue2('hsd', 50, 'host1', 'ping', 'RTA');
    ok($x, '10');
    $Config{hsdlist} = str2list('host1,.*,rta=30;.*,ping,RTA=10');
    $x = gethsdvalue2('hsd', 50, 'host1', 'frak', 'rta');
    ok($x, '30');

    # test partial specifications

    undef $Config{hsd};
    undef $Config{hsdlist};

    # simulate what happens with the 'heartbeat' parameter
    $Config{heartbeat} = 600;
    $x = gethsdvalue2('heartbeat', 5, 'host1', 'ping', 'loss');
    ok($x, 600);
    $x = gethsdvalue2('heartbeat', 5, 'host2', 'ping', 'loss');
    ok($x, 600);
    $Config{heartbeatlist} = str2list('host1,ping,loss=20;.*,.*,.*=500');
    $x = gethsdvalue2('heartbeat', 5, 'host1', 'ping', 'loss');
    ok($x, 20);
    $x = gethsdvalue2('heartbeat', 5, 'host2', 'ping', 'loss');
    ok($x, 500);
    $Config{heartbeatlist} = str2list('host1, ping ,loss=20;.*,.*,.* =500');
    $x = gethsdvalue2('heartbeat', 5, 'host1', 'ping', 'loss');
    ok($x, 600);
    $x = gethsdvalue2('heartbeat', 5, 'host1', ' ping ', 'loss');
    ok($x, 20);
    $x = gethsdvalue2('heartbeat', 5, 'host2', 'ping', 'loss');
    ok($x, 600);
    $x = gethsdvalue2('heartbeat', 5, 'host2', 'ping', 'loss ');
    ok($x, 500);
    undef $Config{heartbeatlist};

    return;
}

sub testreadfile {
    my $fn = "$curdir/test.conf";

    writefile($fn, ('name0 = value0',
                    'name1 = x1,x2,x3',
                    '#name2 = value2',
                    '  #name2 = value2',
                    'name3 = value3 # comment',
                    'name4 = --color BACK#FFFFFF',
                    'name5=      y1,    y2,y3   ,y4'));

    my %vars;
    readfile($fn, \%vars);
    ok(scalar keys %vars, 5);
    ok($vars{name0}, 'value0');
    ok($vars{name1}, 'x1,x2,x3');
    ok($vars{name2}, undef);                    # ignore commented lines
    ok($vars{name3}, 'value3 # comment');       # do not strip comments
    ok($vars{name4}, '--color BACK#FFFFFF');
    ok($vars{name5}, 'y1,    y2,y3   ,y4');

    unlink $fn;
    return;
}

sub testinitlog {
    my $fn = "$curdir/testlog.txt";

    undef %Config;
    $Config{debug} = 5;
    initlog('test');
    debug(DBDEB, 'test message');
    close $LOG or carp "close LOG failed: $OS_ERROR";

    undef %Config;
    $Config{debug} = 5;
    $Config{logfile} = $fn;
    initlog('test');
    debug(DBDEB, 'test message');
    close $LOG or carp "close LOG failed: $OS_ERROR";
    my $result = readtestfile($fn);
    ok($result =~ /debug test message/);
    unlink $fn;

    undef %Config;
    $Config{debug} = 5;
    initlog('test', $fn);
    debug(DBDEB, 'test message');
    close $LOG or carp "close LOG failed: $OS_ERROR";
    $result = readtestfile($fn);
    ok($result =~ /debug test message/);
    unlink $fn;

    undef %Config;
    $Config{debug} = 0;
    $Config{debug_test} = 5;
    initlog('test', $fn);
    debug(DBDEB, 'test message');
    close $LOG or carp "close LOG failed: $OS_ERROR";
    $result = readtestfile($fn);
    ok($result =~ /debug test message/);
    unlink $fn;

    undef %Config;
    $Config{debug} = 0;
    $Config{debug_foo} = 5;
    initlog('test', $fn);
    debug(DBDEB, 'test message');
#    close $LOG or carp "close LOG failed: $OS_ERROR";
    $result = readtestfile($fn);
    ok($result, '');
    unlink $fn;

    undef %Config;
    return;
}

sub testreadconfig {
#    setupdebug(5, 'testreadconfig.log');

    my $fn = "$curdir/testlog.txt";
    my $msg;

    $msg = readconfig('read');
    ok($msg, q());
    unlink $fn;

    $msg = readconfig('read', '');
    ok($msg, q());
    unlink $fn;

    $Config{testlog} = $fn;
    $msg = readconfig('read', 'testlog');
    ok($msg, q());
    unlink $fn;

    # test handling of hash/list variables

    $msg = readconfig('read', 'testlog');
    ok($msg, q());
    ok($Config{rrdopts}, undef);
    ok(Dumper(\$Config{rrdoptshash}), "\$VAR1 = \\{
            'global' => ''
          };\n");
    ok($Config{heartbeats}, undef);
    ok(Dumper(\$Config{heartbeatlist}), "\$VAR1 = \\undef;\n");
    ok($Config{stepsizes}, undef);
    ok(Dumper(\$Config{stepsizelist}), "\$VAR1 = \\undef;\n");
    ok($Config{resolutions}, undef);
    ok(Dumper(\$Config{resolutionlist}), "\$VAR1 = \\undef;\n");
    ok($Config{steps}, undef);
    ok(Dumper(\$Config{steplist}), "\$VAR1 = \\undef;\n");
    ok($Config{xffs}, undef);
    ok(Dumper(\$Config{xfflist}), "\$VAR1 = \\undef;\n");
    unlink $fn;

    $Config{rrdopts} = '--flymetothemoon';
    $Config{heartbeats} = 'host1,svc1,db1=100;host2,svc2,db2=200';
    $Config{stepsizes} = 'host1,svc1,db1=30;host2,svc2,db2=50';
    $Config{resolutions} = 'host1,svc1,db1=1 1 1 1;host2,svc2,db2=2 2 2 2';
    $Config{steps} = 'host1,svc1,db1=1 1 1 1;host2,svc2,db2=2 2 2 2';
    $Config{xffs} = 'host1,svc1,db1=1;host2,svc2,db2=2';
    $msg = readconfig('read', 'testlog');
    ok($msg, q());
    ok($Config{rrdopts}, '--flymetothemoon');
    ok(Dumper(\$Config{rrdoptshash}), "\$VAR1 = \\{
            'global' => '--flymetothemoon'
          };\n");
    ok($Config{heartbeats}, 'host1,svc1,db1=100;host2,svc2,db2=200');
    ok(Dumper(\$Config{heartbeatlist}), "\$VAR1 = \\[
            'host1,svc1,db1=100',
            'host2,svc2,db2=200'
          ];\n");
    ok($Config{stepsizes}, 'host1,svc1,db1=30;host2,svc2,db2=50');
    ok(Dumper(\$Config{stepsizelist}), "\$VAR1 = \\[
            'host1,svc1,db1=30',
            'host2,svc2,db2=50'
          ];\n");
    ok($Config{resolutions}, 'host1,svc1,db1=1 1 1 1;host2,svc2,db2=2 2 2 2');
    ok(Dumper(\$Config{resolutionlist}), "\$VAR1 = \\[
            'host1,svc1,db1=1 1 1 1',
            'host2,svc2,db2=2 2 2 2'
          ];\n");
    ok($Config{steps}, 'host1,svc1,db1=1 1 1 1;host2,svc2,db2=2 2 2 2');
    ok(Dumper(\$Config{steplist}), "\$VAR1 = \\[
            'host1,svc1,db1=1 1 1 1',
            'host2,svc2,db2=2 2 2 2'
          ];\n");
    ok($Config{xffs}, 'host1,svc1,db1=1;host2,svc2,db2=2');
    ok(Dumper(\$Config{xfflist}), "\$VAR1 = \\[
            'host1,svc1,db1=1',
            'host2,svc2,db2=2'
          ];\n");
    unlink $fn;

#    teardowndebug();
    return;
}

sub testgetparams {
    my ($cgi, $params) = getparams();
    ok(Dumper($cgi), "\$VAR1 = bless( {
                 '.parameters' => [],
                 'use_tempfile' => 1,
                 '.charset' => 'ISO-8859-1',
                 '.fieldnames' => {},
                 'param' => {},
                 'escape' => 0
               }, 'CGI' );\n");
    ok(Dumper($params), "\$VAR1 = {
          'geom' => '',
          'db' => [],
          'graphonly' => '',
          'showtitle' => '',
          'showdesc' => '',
          'group' => '',
          'fixedscale' => '',
          'expand_period' => '',
          'offset' => 0,
          'expand_controls' => '',
          'rrdopts' => '',
          'period' => '',
          'hidelegend' => '',
          'service' => '',
          'host' => '',
          'showgraphtitle' => '',
          'label' => []
        };\n");
    return;
}

sub testdbfilelist { # Check getting a list of rrd files
#    setupdebug(5, 'testdbfilelist.log');

    $Config{rrddir} = $curdir;
    $Config{dbseparator} = '';
    my $result = dbfilelist('testbox', 'Partition: /');
    ok(@{$result}, 0);
    my $file = "$curdir/testbox_Partition%3A%20%2F_test.rrd";
    writefile($file, ('test'));
    my @result = dbfilelist('testbox', 'Partition: /');
    ok(@result, 1);
    unlink $file;

#    teardowndebug();
    return;
}

sub testgetdataitems {
    setuprrd();
    my $rrddir = gettestrrddir();
    my $fn = $rrddir . q(/) . 'host0/HTTP___http.rrd';
    my @rval = getdataitems($fn);
    ok(Dumper(\@rval), "\$VAR1 = [
          'Bps'
        ];\n");
    $fn = $rrddir . q(/) . 'host2/PING___ping.rrd';
    @rval = getdataitems($fn);
    ok(Dumper(\@rval), "\$VAR1 = [
          'rta',
          'losspct'
        ];\n");
    teardownrrd();
    return;
}

# FIXME: bad use of result variable here
sub testgraphinfo {
    $Config{rrddir} = $curdir;

    $Config{dbseparator} = '';
    my $testvar = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    $Config{hostservvar} = 'testbox,procs,users';
    $Config{hostservvarsep} = ';';
    $Config{hostservvar} = listtodict('hostservvar');
    ok($Config{hostservvar}->{testbox}->{procs}->{users}, 1);
    my @result = createrrd(1221495632, 'testbox', 'procs', $testvar);
    ok($result[0]->[1], 'testbox_procsusers_procs.rrd');
    ok(-f $curdir . '/testbox_procsusers_procs.rrd');
    ok(-f $curdir . '/testbox_procs_procs.rrd');

    my $result = graphinfo('testbox', 'procs', ['procs']);
    my $file = $curdir . '/testbox_procs_procs.rrd';
    skip(! -f $file, $result->[0]->{file}, 'testbox_procs_procs.rrd');
    skip(! -f $file, $result->[0]->{line}->{uwarn}, 1);
    unlink $file if -f $file;
    $file = $curdir . '/testbox_procs_procs.rrd';
    unlink $file if -f $file;
    $file = $curdir . '/testbox_procsusers_procs.rrd';
    unlink $file if -f $file;

    # create default data file
    $Config{dbseparator} = 'subdir';
    $testvar = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $testvar);
    ok($result[0]->[0], 'PING___ping.rrd');
    ok($result[1]->[0]->[0], 0);
    ok($result[1]->[0]->[1], 1);

    $result = graphinfo('testbox', 'PING', ['ping']);
    $file = $curdir . '/testbox/PING___ping.rrd';
    skip(! -f $file, $result->[0]->{file}, 'testbox/PING___ping.rrd');
    skip(! -f $file, $result->[0]->{line}->{rta}, 1);
    return;
}

sub testgetlineattr {
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
    $Config{lineformat} = 'warn=LINE1,D0D050;crit=LINE2,D05050;total=AREA,dddddd88';
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

    # test various combinations and permutations
    $Config{lineformat} = 'warn=LINE1,D0D050;crit=D05050,LINE2;total=STACK,AREA,dddddd88';
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

    # test for database,datasource formatting
    $Config{lineformat} = 'warn=LINE1,D0D050;total,data=STACK,AREA,dddddd88;fleece,data=LINE3,ffffff';
    $Config{lineformatlist} = str2list($Config{lineformat});
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'total', 'data');
    ok($linestyle, 'AREA');
    ok($linecolor, 'dddddd88');
    ok($stack, 1);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'fleece', 'data');
    ok($linestyle, 'LINE3');
    ok($linecolor, 'ffffff');
    ok($stack, 0);

    # test for database,datasource formatting (overlapping definition case)
    $Config{lineformat} = 'warn=LINE1,D0D050;total,data=STACK,AREA,dddddd88;fleece,data=LINE3,ffffff;data=STACK,TICK,222222';
    $Config{lineformatlist} = str2list($Config{lineformat});
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'total', 'data');
    ok($linestyle, 'AREA');
    ok($linecolor, 'dddddd88');
    ok($stack, 1);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'fleece', 'data');
    ok($linestyle, 'LINE3');
    ok($linecolor, 'ffffff');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'data');
    ok($linestyle, 'TICK');
    ok($linecolor, '222222');
    ok($stack, 1);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'foobar', 'data');
    ok($linestyle, 'TICK');
    ok($linecolor, '222222');
    ok($stack, 1);

    # test for database,datasource formatting (reverse overlapping case)
    $Config{lineformat} = 'data=STACK,TICK,222222;warn=LINE1,D0D050;total,data=STACK,AREA,dddddd88;fleece,data=LINE3,ffffff';
    $Config{lineformatlist} = str2list($Config{lineformat});
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'total', 'data');
    ok($linestyle, 'TICK');
    ok($linecolor, '222222');
    ok($stack, 1);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'fleece', 'data');
    ok($linestyle, 'TICK');
    ok($linecolor, '222222');
    ok($stack, 1);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'database', 'data');
    ok($linestyle, 'TICK');
    ok($linecolor, '222222');
    ok($stack, 1);
    ($linestyle, $linecolor, $stack) =
        getlineattr('host', 'service', 'foobar', 'data');
    ok($linestyle, 'TICK');
    ok($linecolor, '222222');
    ok($stack, 1);
    return;
}

# return a set of parameters for testing rrdline
sub getrrdlineparams {
    my %params = qw(host host0 service PING);
    return %params;
}

sub testrrdline {
    undef %Config;
    setuprrd();
    my $rrddir = gettestrrddir();

    # set up the bare minimum, default configuration options
    $Config{colorscheme} = 1;
    $Config{plotas} = 'LINE2';

## no critic (ProhibitInterpolationOfLiterals)
    # these are common to many results
    my $RRDLINES0 = "'-',
          '-a',
          'PNG',
          '-s',
          'now-118800',
          '-e',
          'now-0',";

    # test a minimal invocation with no data for the host
    my %params = qw(host host30 service ping);
    my ($ds,$err) = rrdline(\%params);
    ok($err, 'No data available: host=host30 service=ping');
    ok(Dumper($ds), "\$VAR1 = [];\n");

    # host and service but no data match
    %params = qw(host host30 service PING);
    $params{db} = [qw(foobar)];
    ($ds,$err) = rrdline(\%params);
    ok($err, 'No data available: host=host30 service=PING db=foobar');
    ok(Dumper($ds), "\$VAR1 = [];\n");

    # minimal invocation when data exist for the host
    %params = getrrdlineparams();
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_losspct=$rrddir/host0/PING___ping.rrd:losspct:AVERAGE',
          'LINE2:ping_losspct#9900FF:ping,losspct',
          'GPRINT:ping_losspct:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_losspct:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_losspct:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_losspct:LAST:Cur\\\\:%7.2lf%s\\\\n',
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta    ',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100
        ];\n");

    # specify a bogus data set
    %params = getrrdlineparams();
    $params{db} = ['rta'];
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [];\n");

    # specify a valid data source
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100
        ];\n");

    # test geometry
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $params{geom} = '100x100';
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          100,
          '-h',
          100
        ];\n");

    # test the period
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $params{geom} = '100x100';
    $params{period} = 'week';
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          '-',
          '-a',
          'PNG',
          '-s',
          'now-777600',
          '-e',
          'now-0',
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s\\\\n',
          '-w',
          100,
          '-h',
          100
        ];\n");

    # test fixedscale
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $params{fixedscale} = 1;
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf\\\\n',
          '-w',
          600,
          '-h',
          100,
          '-X',
          '0'
        ];\n");

    # these bits are the same for the next few tests
    my $RRDLINES1 = "'-',
          '-a',
          'PNG',
          '-s',
          'now-118800',
          '-e',
          'now-0',
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100,";

    # test altautoscale
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $Config{altautoscale}{PING} = 1;
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES1
          '-A'
        ];\n");
    undef $Config{altautoscale};

    # test altautoscalemin
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $Config{altautoscalemin}{PING} = 1;
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES1
          '-J'
        ];\n");
    undef $Config{altautoscalemin};

    # test altautoscalemax
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $Config{altautoscalemax}{PING} = 1;
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES1
          '-M'
        ];\n");
    undef $Config{altautoscalemax};

    # test nogridfit
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $Config{nogridfit}{PING} = 1;
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES1
          '-N'
        ];\n");
    undef $Config{nogridfit};

    # test nogridfit
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $Config{logarithmic}{PING} = 1;
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES1
          '-o'
        ];\n");
    undef $Config{logarithmic};

    # test negate
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $Config{negate} = 'rta';
    $Config{negatelist} = str2list($Config{negate});
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'CDEF:ping_rta_neg=ping_rta,-1,*',
          'LINE2:ping_rta_neg#CC03CC:ping,rta',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100
        ];\n");
    undef $Config{negate};
    undef $Config{negatelist};

    # test withminimums and withmaximums

    $Config{withmaximums} = 'PING';
    $Config{withmaximums} = listtodict('withmaximums', q(,));
    $Config{withminimums} = 'PING';
    $Config{withminimums} = listtodict('withminimums', q(,));
    %params = getrrdlineparams();
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_losspct=$rrddir/host0/PING___ping.rrd:losspct:AVERAGE',
          'LINE2:ping_losspct#9900FF:ping,losspct',
          'GPRINT:ping_losspct:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_losspct:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_losspct:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_losspct:LAST:Cur\\\\:%7.2lf%s\\\\n',
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:ping,rta    ',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100
        ];\n");
    undef $Config{withminimums};
    undef $Config{withmaximums};

    # test labels
    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $params{label} = ['ping,rta:labela', 'rta:labelb'];
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:labela',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100
        ];\n");

    %params = getrrdlineparams();
    $params{db} = ['ping,rta'];
    $params{label} = ['ping,rta:this label has : a colon in it'];
    ($ds,$err) = rrdline(\%params);
    ok(Dumper($ds), "\$VAR1 = [
          $RRDLINES0
          'DEF:ping_rta=$rrddir/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:ping_rta#CC03CC:this label has \\\\: a colon in it',
          'GPRINT:ping_rta:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:ping_rta:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:ping_rta:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:ping_rta:LAST:Cur\\\\:%7.2lf%s\\\\n',
          '-w',
          600,
          '-h',
          100
        ];\n");

#FIXME: test rrdopts

    teardownrrd();
    undef %Config;
    return;
}

sub testgetserverlist {
    my $allhosts = "\$VAR1 = {
  'host' => [
    'host0',
    'host1',
    'host2',
    'host3',
    'host4',
    'host5'
  ],
  'hostserv' => {
    'host0' => {
      'HTTP' => [
        [
          'http',
          'Bps'
        ]
      ],
      'PING' => [
        [
          'ping',
          'rta',
          'losspct'
        ]
      ]
    },
    'host1' => {
      'HTTP' => [
        [
          'http',
          'Bps'
        ]
      ]
    },
    'host2' => {
      'PING' => [
        [
          'ping',
          'rta',
          'losspct'
        ]
      ]
    },
    'host3' => {
      'ping' => [
        [
          'loss',
          'losscrit',
          'losspct',
          'losswarn'
        ],
        [
          'rta',
          'rtacrit',
          'rta',
          'rtawarn'
        ]
      ]
    },
    'host4' => {
      'c:\\\\ space' => [
        [
          'ntdisk',
          'total',
          'used'
        ]
      ]
    },
    'host5' => {
      'ntdisk' => [
        [
          'c:\\\\ space',
          'total',
          'used'
        ]
      ]
    }
  }
};\n";

    my $somehosts = "\$VAR1 = {
  'host' => [
    'host0',
    'host1',
    'host2',
    'host3',
    'host4',
    'host5'
  ],
  'hostserv' => {
    'host0' => {
      'HTTP' => [
        [
          'http',
          'Bps'
        ]
      ]
    },
    'host1' => {
      'HTTP' => [
        [
          'http',
          'Bps'
        ]
      ]
    },
    'host3' => {
      'ping' => [
        [
          'loss',
          'losscrit',
          'losspct',
          'losswarn'
        ],
        [
          'rta',
          'rtacrit',
          'rta',
          'rtawarn'
        ]
      ]
    },
    'host4' => {
      'c:\\\\ space' => [
        [
          'ntdisk',
          'total',
          'used'
        ]
      ]
    },
    'host5' => {
      'ntdisk' => [
        [
          'c:\\\\ space',
          'total',
          'used'
        ]
      ]
    }
  }
};\n";

    setuprrd();
    setuphsdata();
    my $rrddir = gettestrrddir();

    my %result = getserverlist();
    my $dd = Data::Dumper->new([\%result]);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    ok($dd->Dump, $allhosts);

    %result = getserverlist('');
    $dd = Data::Dumper->new([\%result]);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    ok($dd->Dump, $allhosts);

    $authz{default_host_access}{default_service_access} = 0;
    %result = getserverlist('joeblow');
    $dd = Data::Dumper->new([\%result]);
    $dd->Indent(1);
    ok($dd->Dump, "\$VAR1 = {\n  'hostserv' => {},\n  'host' => []\n};\n");

    $authz{default_host_access}{default_service_access} = 1;
    $authz{default_host_access}{PING} = 0;
    %result = getserverlist('joeblow');
    $dd = Data::Dumper->new([\%result]);
    $dd->Indent(1);
    $dd->Sortkeys(1);
    ok($dd->Dump, $somehosts);

    undef %authz;
    teardownrrd();
    teardownhsdata();
    return;
}

sub testprintmenudatascript {
    setuprrd();
    setuphsdata();

    $Config{userdb} = '';
    my $rrddir = gettestrrddir();
    my %result = getserverlist('');
    my(@servers) = @{$result{host}};
    my(%servers) = %{$result{hostserv}};

    # when no javascript, print nothing
    undef $Config{javascript};
    my $result = printmenudatascript(\@servers, \%servers);
    ok($result, '');

    # when we have javascript, we should have menudata
    $Config{javascript} = 'foo';
    $result = printmenudatascript(\@servers, \%servers);
    ok($result, '<script type="text/javascript">
menudata = new Array();
menudata[0] = ["host0"
 ,["HTTP",["http","Bps"]]
 ,["PING",["ping","losspct","rta"]]
];
menudata[1] = ["host1"
 ,["HTTP",["http","Bps"]]
];
menudata[2] = ["host2"
 ,["PING",["ping","losspct","rta"]]
];
menudata[3] = ["host3"
 ,["ping",["loss","losscrit","losspct","losswarn"],["rta","rta","rtacrit","rtawarn"]]
];
menudata[4] = ["host4"
 ,["c:\\\\ space",["ntdisk","total","used"]]
];
menudata[5] = ["host5"
 ,["ntdisk",["c:\\\\ space","total","used"]]
];
</script>
');

    teardownrrd();
    teardownhsdata();
    return;
}

sub testgraphsizes {
#    setupdebug(5, 'testgraphsizes.log');

    my @result = graphsizes(''); # defaults
    ok($result[0][0], 'day');
    ok($result[1][2], 604800);
    @result = graphsizes('year month quarter'); # comes back in length order
    ok($result[0][0], 'month');
    ok($result[1][2], 7776000);
    @result = graphsizes('test junk week'); # only returns week
    ok(@result, 1);

#    teardowndebug();
    return;
}

sub testreadperfdata {
    my @testdata =
        ('1221495633||testbox||HTTP||CRITICAL - Socket timeout after 10 seconds||',
         '1221495690||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||losspct: 0%, rta: 37.06'
         );
    my $fn = $curdir . '/perfdata.log';

    # a test without data
    writefile($fn);
    my @result = readperfdata($fn);
    ok(@result, 0);

    # a test with data
    writefile($fn, @testdata);
    @result = readperfdata($fn);
    chomp $result[0];
    ok($result[0], $testdata[0]);
    chomp $result[1];
    ok($result[1], $testdata[1]);
    unlink $fn;
    return;
}

sub testgetrras {
    my $xff = 0.5;
    my @steps = (1, 6, 24, 288);
    my @rows = (1, 2, 3, 4);

    undef $Config{maximums};
    undef $Config{maximumslist};
    undef $Config{minimums};
    undef $Config{minimumslist};
    undef $Config{lasts};
    undef $Config{lastslist};

    # test fully-qualified formatting

    $Config{maximums} = 'host1,Current Load,data;host2,Current Users,data;host3,Total Processes,data;host1,PLW,critical';
    $Config{maximumslist} = str2list($Config{maximums});
    my @result = main::getrras('host1', 'Current Load', 'data',
                               $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:MAX:0.5:1:1',
          'RRA:MAX:0.5:6:2',
          'RRA:MAX:0.5:24:3',
          'RRA:MAX:0.5:288:4'
        ];\n");

    # test single fully-qualified

    $Config{minimums} = 'host1,APCUPSD,data;';
    $Config{minimumslist} = str2list($Config{minimums});
    @result = main::getrras('host1', 'APCUPSD', 'data',
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:MIN:0.5:1:1',
          'RRA:MIN:0.5:6:2',
          'RRA:MIN:0.5:24:3',
          'RRA:MIN:0.5:288:4'
        ];\n");
    @result = main::getrras('host1', 'APCUPSD', 'critical',
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:AVERAGE:0.5:1:1',
          'RRA:AVERAGE:0.5:6:2',
          'RRA:AVERAGE:0.5:24:3',
          'RRA:AVERAGE:0.5:288:4'
        ];\n");
    @result = main::getrras('host10', 'APCUPSD', 'data',
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:AVERAGE:0.5:1:1',
          'RRA:AVERAGE:0.5:6:2',
          'RRA:AVERAGE:0.5:24:3',
          'RRA:AVERAGE:0.5:288:4'
        ];\n");

    # test mix of fully qualified and not

    $Config{lasts} = 'host1,sunrise,data;sunset;moonshine,data';
    $Config{lastslist} = str2list($Config{lasts});
    @result = main::getrras('host1', 'sunset', 'data',
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:LAST:0.5:1:1',
          'RRA:LAST:0.5:6:2',
          'RRA:LAST:0.5:24:3',
          'RRA:LAST:0.5:288:4'
        ];\n");
    @result = main::getrras('host1', 'moonshine', 'data',
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:LAST:0.5:1:1',
          'RRA:LAST:0.5:6:2',
          'RRA:LAST:0.5:24:3',
          'RRA:LAST:0.5:288:4'
        ];\n");

    # default to average when no match

    @result = main::getrras('host1', 'other value', 'data',
                            $xff, \@rows, \@steps);
    ok(Dumper(\@result), "\$VAR1 = [
          'RRA:AVERAGE:0.5:1:1',
          'RRA:AVERAGE:0.5:6:2',
          'RRA:AVERAGE:0.5:24:3',
          'RRA:AVERAGE:0.5:288:4'
        ];\n");

    return;
}

sub testcheckdatasources {
#    setupdebug(5, 'testcheckdatasources.log');

    my $result = checkdatasources([0], 'test', [0]);
    ok($result, 1);
    $result = checkdatasources([0,1,2], 'test', [0, 1]);
    ok($result, 1);
    $result = checkdatasources([0,1,2], 'test', [0]);
    ok($result, 0);

#    teardowndebug();
    return;
}

# FIXME: refactor createrrd to return stuff that is then passed to the RRDs
#  method.  this will make testing much easier and the code more obvious.
# FIXME: the hostservar naming convention is awful, but we must respect it
#  in order to maintain backward compatibility
# beware! createrrd modifies the contents of $s
sub testcreaterrd {
#    setupdebug(5, 'testcreaterrd.log');

    my $rrddir = gettestrrddir();
    $Config{rrddir} = $rrddir;
    my $s;
    my @result;
    my $fn;

    # test the old directory structure
    $Config{dbseparator} = '';
    $fn = 'testbox_PING_ping.rrd';

    # single data file
    undef $Config{hostservvar};
    undef $Config{withminimums};
    undef $Config{withmaximums};
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    ok($result[0]->[0], $fn);
    ok(-f "${rrddir}/$fn");
    ok(! -f "${rrddir}/${fn}_min");
    ok(! -f "${rrddir}/${fn}_max");
    rmtree($rrddir);

    # add minimums
    $Config{withminimums} = 'PING';
    $Config{withminimums} = listtodict('withminimums', q(,));
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    ok($result[0]->[0], $fn);
    ok(-f "${rrddir}/$fn");
    ok(-f "${rrddir}/${fn}_min");
    ok(! -f "${rrddir}/${fn}_max");
    rmtree($rrddir);

    # add maximums
    $Config{withmaximums} = 'PING';
    $Config{withmaximums} = listtodict('withmaximums', q(,));
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    ok($result[0]->[0], $fn);
    ok(-f "${rrddir}/$fn");
    ok(-f "${rrddir}/${fn}_min");
    ok(-f "${rrddir}/${fn}_max");
    rmtree($rrddir);

    # test hostservvar
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    $Config{hostservvar} = 'testbox,procs,users';
    $Config{hostservvarsep} = ';';
    $Config{hostservvar} = listtodict('hostservvar');
    ok($Config{hostservvar}->{testbox}->{procs}->{users}, 1);
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok($result[0]->[1], 'testbox_procsusers_procs.rrd');
    ok(-f $rrddir . '/testbox_procsusers_procs.rrd');
    ok(-f $rrddir . '/testbox_procs_procs.rrd');
    rmtree($rrddir);

    # test the new directory structure
    $Config{dbseparator} = 'subdir';
    $fn = 'PING___ping.rrd';

    # single data file
    undef $Config{hostservvar};
    undef $Config{withminimums};
    undef $Config{withmaximums};
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    ok($result[0]->[0], $fn);
    ok($result[1]->[0]->[0], 0);
    ok($result[1]->[0]->[1], 1);
    ok(-f "${rrddir}/testbox/$fn");
    ok(! -f "${rrddir}/testbox/${fn}_min");
    ok(! -f "${rrddir}/testbox/${fn}_max");
    rmtree($rrddir);

    # add minimums
    $Config{withminimums} = 'PING';
    $Config{withminimums} = listtodict('withminimums', q(,));
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    ok($result[0]->[0], $fn);
    ok($result[1]->[0]->[0], 0);
    ok($result[1]->[0]->[1], 1);
    ok(-f "${rrddir}/testbox/$fn");
    ok(-f "${rrddir}/testbox/${fn}_min");
    ok(! -f "${rrddir}/testbox/${fn}_max");
    rmtree($rrddir);

    # add maximums
    $Config{withmaximums} = 'PING';
    $Config{withmaximums} = listtodict('withmaximums', q(,));
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    ok($result[0]->[0], $fn);
    ok($result[1]->[0]->[0], 0);
    ok($result[1]->[0]->[1], 1);
    ok(-f "${rrddir}/testbox/$fn");
    ok(-f "${rrddir}/testbox/${fn}_min");
    ok(-f "${rrddir}/testbox/${fn}_max");
    rmtree($rrddir);

    # test hostservvar
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    $Config{hostservvar} = 'testbox,procs,users';
    $Config{hostservvarsep} = ';';
    $Config{hostservvar} = listtodict('hostservvar');
    ok($Config{hostservvar}->{testbox}->{procs}->{users}, 1);
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok($result[0]->[1], 'procsusers___procs.rrd');
    ok(-f $rrddir . '/testbox/procsusers___procs.rrd');
    ok(-f $rrddir . '/testbox/procs___procs.rrd');
    rmtree($rrddir);

#    teardowndebug();
    return;
}

sub testrrdupdate {
    my $rrddir = gettestrrddir();
    $Config{rrddir} = $rrddir;
    mkdir $Config{rrddir};

    my (@result, $s, $fn, $f, $ts1, $ts2);

    # test the old directory structure
    $Config{dbseparator} = '';
    $fn = 'testbox_PING_ping.rrd';

    # single data file
    undef $Config{withminimums};
    undef $Config{withmaximums};
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    $f = "${rrddir}/${fn}";
    $ts1 = (stat $f)[9];
    sleep 2;
    $s = [ ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    rrdupdate($result[0]->[0], 1221495635,
              'testbox', 'PING', $result[1]->[0], $s);
    $ts2 = (stat $f)[9];
    ok(-f $f);
    ok($ts2 > $ts1);
    rmtree($rrddir);

    # test the new directory structure
    $Config{dbseparator} = 'subdir';
    $fn = 'PING___ping.rrd';

    # single data file
    undef $Config{withminimums};
    undef $Config{withmaximums};
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING', $s);
    $f = "${rrddir}/testbox/${fn}";
    $ts1 = (stat $f)[9];
    sleep 2;
    $s = [ ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    rrdupdate($result[0]->[0], 1221495635,
              'testbox', 'PING', $result[1]->[0], $s);
    $ts2 = (stat $f)[9];
    ok(-f $f);
    ok($ts2 > $ts1);
    rmtree($rrddir);

    # test regression for handling of services with underscore in the name
    # https://sourceforge.net/projects/nagiosgraph/forums/forum/394748/topic/4043301

#    setupdebug(5, 'testrrdupdate.log');

    $fn = 'PING_MAX___ping.rrd';
    $Config{withminimums} = 'PING';
    $Config{withminimums} = listtodict('withminimums', q(,));
    $Config{withmaximums} = 'PING';
    $Config{withmaximums} = listtodict('withmaximums', q(,));
    mkdir $Config{rrddir};
    $s = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd(1221495632, 'testbox', 'PING_MAX', $s);
    $f = "${rrddir}/testbox/${fn}";
    ok(-f $f);
    ok(! -f "{$f}_min");
    ok(! -f "{$f}_max");
    $s = [ ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    rrdupdate($result[0]->[0], 1221495635,
              'testbox', 'PING_MAX', $result[1]->[0], $s);
    rmtree($rrddir);

#    teardowndebug();
    return;
}

sub testcheckdsname {
    ok(checkdsname('ping'), 0);
    ok(checkdsname('ping0'), 0);
    ok(checkdsname('0ping'), 0);
    ok(checkdsname('ping and pong'), 1);
    ok(checkdsname('abcdefghijklmnopqrstuvwxyz'), 1);
    ok(checkdsname('0123456789012345678'), 0);
    ok(checkdsname('012345678901234567890'), 1);

    # according to rrdtool documentation, hyphens should not be allowed in ds
    # names.  it looks like it *is* possible to create an rrd file with with
    # hyphenated ds names.  so we permit it as well (fwiw, cacti documentation
    # indicates that hyphens are ok).
    ok(checkdsname('a-b'), 0);
    return;
}

sub testmkvname {
    ok(mkvname('ping','loss'), 'ping_loss');
    ok(mkvname('ping','loss%20pct'), 'ping_loss_20pct');
    ok(mkvname('0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789','abcdefghijklmnopqrstuvwxyz'), '0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789_abcd');
    ok(mkvname('a-b','r_s,'), 'a-b_r_s_');
    return;
}

sub testgetrules {
#    setupdebug(5, 'testgetrules.log');

    undef &evalrules; ## no critic (ProhibitAmpersandSigils)
    getrules("$curdir/../etc/map");
    ok($log, '');
    ok(*evalrules);

#    teardowndebug();
    return;
}

sub testprocessdata { # depends on testcreaterdd and testgetrules
#    setupdebug(5, 'testprocessdata.log');

    my $FILE;
    my $rrdfile = $curdir . '/testbox/PING___pingloss.rrd';
    rmtree($curdir . '/testbox');

    my $fn1 = $curdir . '/map-ping-output';
    my $fn2 = $curdir . '/map-ping-perfdata';

    # map rule to grab stuff from ping output
    open $FILE, '>', $fn1 or carp "open $fn1 failed: $OS_ERROR";
    print ${FILE} <<"EOB" or carp "print failed: $OS_ERROR";
/output:PING.*?(\\d+)%.+?([.\\d]+)\\sms/
and push \@s, [ 'pingloss',
               [ 'losspct', GAUGE, \$1 ]]
and push \@s, [ 'pingrta',
               [ 'rta', GAUGE, \$2/1000 ]];
EOB
    close $FILE or carp "close $fn1 failed: $OS_ERROR";

    # map rule to grab stuff from ping perfdata
    open $FILE, '>', $fn2 or carp "open $fn2 failed: $OS_ERROR";
    print ${FILE} <<"EOB" or carp "print failed: $OS_ERROR";
/perfdata:rta=([.\\d]+)ms;([.\\d]+);([.\\d]+);([.\\d]+)\\s+losspct=([.\\d]+)%;([.\\d]+);([.\\d]+);([.\\d]+)/
and push \@s, [ 'pingloss',
               [ 'losspct', GAUGE, \$5 ]]
and push \@s, [ 'pingrta',
               [ 'rta', GAUGE, \$1/1000 ]];
EOB
    close $FILE or carp "close $fn2 failed: $OS_ERROR";

    undef &evalrules; ## no critic (ProhibitAmpersandSigils)
    getrules($fn1);

    my @perfline = ('1221495636||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||rta=37.06ms;50;100;0 losspct=0%;2;10;0');
    processdata(@perfline);
    ok(-f $rrdfile);
    rmtree($curdir . '/testbox');

    # missing timestamp
    @perfline = ('||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||rta=37.06ms;50;100;0 losspct=0%;2;10;0');
    processdata(@perfline);
    ok(! -f $rrdfile);
    rmtree($curdir . '/testbox');

    # missing host
    @perfline = ('1221495636||||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||rta=37.06ms;50;100;0 losspct=0%;2;10;0');
    processdata(@perfline);
    ok(! -f $rrdfile);
    rmtree($curdir . '/testbox');

    # missing service
    @perfline = ('1221495636||testbox||||PING OK - Packet loss = 0%, RTA = 37.06 ms ||rta=37.06ms;50;100;0 losspct=0%;2;10;0');
    processdata(@perfline);
    ok(! -f $rrdfile);
    rmtree($curdir . '/testbox');

    # missing output, parsing on output
    @perfline = ('1221495636||testbox||PING||||rta=37.06ms;50;100;0 losspct=0%;2;10;0');
    processdata(@perfline);
    ok(! -f $rrdfile);
    rmtree($curdir . '/testbox');

    # missing perfdata, parsing on output
    @perfline = ('1221495636||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||');
    processdata(@perfline);
    ok(-f $rrdfile);
    rmtree($curdir . '/testbox');

    # match perfdata now rather than output
    undef &evalrules; ## no critic (ProhibitAmpersandSigils)
    getrules($fn2);

    # missing output, parsing on perfdata
    @perfline = ('1221495636||testbox||PING||||rta=37.06ms;50;100;0 losspct=0%;2;10;0');
    processdata(@perfline);
    ok(-f $rrdfile);
    rmtree($curdir . '/testbox');

    # missing perfdata, parsing on perfdata
    @perfline = ('1221495636||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||');
    processdata(@perfline);
    ok(! -f $rrdfile);
    rmtree($curdir . '/testbox');

    # no lines
    my @nolines;
    processdata(@nolines);
    ok(! -f $rrdfile);
    rmtree($curdir . '/testbox');

#    teardowndebug();

    undef &evalrules; ## no critic (ProhibitAmpersandSigils)
    unlink $fn1;
    unlink $fn2;
    return;
}

# test for the primary string literals.  do not test for error strings.
sub testi18n {
    undef %i18n;

    ok(_('Day'), 'Day');
    ok(_('Week'), 'Week');
    ok(_('Month'), 'Month');
    ok(_('Quarter'), 'Quarter');
    ok(_('Year'), 'Year');

    ok(_('as of'), 'as of');
    ok(_('Clear'), 'Clear');
    ok(_('Created by'), 'Created by');
    ok(_('Data for group'), 'Data for group');
    ok(_('Data for host'), 'Data for host');
    ok(_('Data for service'), 'Data for service');
    ok(_('Data Sets:'), 'Data Sets:');
    ok(_('End Date:'), 'End Date:');
    ok(_('Enter names separated by spaces'), 'Enter names separated by spaces');
    ok(_('Graph of'), 'Graph of');
    ok(_('Group:'), 'Group:');
    ok(_('Host:'), 'Host:');
    ok(_('Periods:'), 'Periods:');
    ok(_('on'), 'on');
    ok(_('service'), 'service');
    ok(_('Service:'), 'Service:');
    ok(_('Show Colors'), 'Show Colors');
    ok(_('Size:'), 'Size:');
    ok(_('Update Graphs'), 'Update Graphs');

    undef %i18n;
    $ENV{HTTP_ACCEPT_LANGUAGE} = '';
    my $errstr = readi18nfile();
    ok($errstr, 'Cannot determine language');

    $errstr = readi18nfile('bogus');
    ok($errstr, "No translations for 'bogus' ($curdir/../etc/nagiosgraph_bogus.conf)");

    $errstr = readi18nfile('en');
    ok($errstr, '');

    undef %i18n;
    $ENV{HTTP_ACCEPT_LANGUAGE} = 'es-mx,es';
    $errstr = readi18nfile();
    ok($errstr, '');
    ok(_('Day'), 'Diario');

    undef %i18n;
    $ENV{HTTP_ACCEPT_LANGUAGE} = 'es_mx,es';
    $errstr = readi18nfile();
    ok($errstr, '');
    ok(_('Day'), 'Diario');

    undef %i18n;
    $Config{language} = 'es';
    $errstr = readi18nfile();
    ok($errstr, '');
    ok(_('Day'), 'Diario');
    ok(_('Week'), 'Semanal');
    ok(_('Month'), 'Mensual');
    ok(_('Quarter'), 'Trimestral');
    ok(_('Year'), 'Anual');

    undef %i18n;
    $Config{language} = 'fr';
    $errstr = readi18nfile();
    ok($errstr, '');
    ok(_('Day'), 'Jour');
    ok(_('Week'), 'Semaine');
    ok(_('Month'), 'Mois');
    ok(_('Quarter'), 'Trimestre');
    ok(_('Year'), 'Ann&#233;e');

    undef %i18n;
    $Config{language} = 'de';
    $errstr = readi18nfile();
    ok($errstr, '');
    ok(_('Day'), 'Tag');
    ok(_('Week'), 'Woche');
    ok(_('Month'), 'Monat');
    ok(_('Quarter'), 'Quartal');
    ok(_('Year'), 'Jahr');

    undef %i18n;
    undef $Config{language};
    return;
}

sub testprinti18nscript {
    undef $Config{javascript};
    my $result = printi18nscript();
    ok($result, '');

    $Config{javascript} = 'foo';
    $result = printi18nscript();
    ok($result, '<script type="text/javascript">
var i18n = {
  "Jan": \'Jan\',
  "Feb": \'Feb\',
  "Mar": \'Mar\',
  "Apr": \'Apr\',
  "May": \'May\',
  "Jun": \'Jun\',
  "Jul": \'Jul\',
  "Aug": \'Aug\',
  "Sep": \'Sep\',
  "Oct": \'Oct\',
  "Nov": \'Nov\',
  "Dec": \'Dec\',
  "Mon": \'Mon\',
  "Tue": \'Tue\',
  "Wed": \'Wed\',
  "Thu": \'Thu\',
  "Fri": \'Fri\',
  "Sat": \'Sat\',
  "Sun": \'Sun\',
  "OK": \'OK\',
  "Now": \'Now\',
  "Cancel": \'Cancel\',
  "now": \'now\',
  "graph data": \'graph data\',
};
</script>
');

    $Config{language} = 'es';
    undef %i18n;
    $Config{language} = 'es';
    my $errstr = readi18nfile();
    ok($errstr, '');
    $result = printi18nscript();
    ok($result, '<script type="text/javascript">
var i18n = {
  "Jan": \'Enero\',
  "Feb": \'Febrero\',
  "Mar": \'Marzo\',
  "Apr": \'Abril\',
  "May": \'Mai\',
  "Jun": \'Junio\',
  "Jul": \'Julio\',
  "Aug": \'Augosto\',
  "Sep": \'Septiembre\',
  "Oct": \'Octubre\',
  "Nov": \'Noviembre\',
  "Dec": \'Diciembre\',
  "Mon": \'Lun\',
  "Tue": \'Mar\',
  "Wed": \'Mie\',
  "Thu": \'Jue\',
  "Fri": \'Vie\',
  "Sat": \'Sab\',
  "Sun": \'Dom\',
  "OK": \'OK\',
  "Now": \'Ahora\',
  "Cancel": \'Cancelar\',
  "now": \'now\',
  "graph data": \'datos del gr&#241;fico\',
};
</script>
');

    undef %i18n;
    undef $Config{language};
    return;
}

sub testinitperiods {
#    setupdebug(5, 'testinitperiods.log');

    # ensure we get values from opts
    my %opts = ('period', 'day week month', 'expand_period', 'month year');
    my ($x,$y) = initperiods('both', \%opts);
    ok($x, 'day,week,month');
    ok($y, 'month,year');
    %opts = ('period', 'day week', 'expand_period', 'day month');
    ($x,$y) = initperiods('all', \%opts);
    ok($x, 'day,week');
    ok($y, 'day,month');
    ($x,$y) = initperiods('host', \%opts);
    ok($x, 'day,week');
    ok($y, 'day,month');
    ($x,$y) = initperiods('service', \%opts);
    ok($x, 'day,week');
    ok($y, 'day,month');
    ($x,$y) = initperiods('group', \%opts);
    ok($x, 'day,week');
    ok($y, 'day,month');

    # ensure we get values from config
    $Config{timeall} = 'month,year';
    $Config{expand_timeall} = 'day';
    %opts = ('period', '', 'expand_period', '');
    ($x,$y) = initperiods('all', \%opts);
    ok($x, 'month,year');
    ok($y, 'day');

    # ensure values from opts override those from config
    $Config{timeall} = 'month,year';
    $Config{expand_timeall} = 'day';
    %opts = ('period', 'day', 'expand_period', 'month');
    ($x,$y) = initperiods('all', \%opts);
    ok($x, 'day');
    ok($y, 'month');

#    teardowndebug();
    return;
}

sub testparsedb {
#    setupdebug(5, 'testparsedb.log');

    # single data source
    my $str = '&db=ping,rta';
    my ($db, $dblabel) = parsedb($str);
    ok(Dumper($db), "\$VAR1 = [
          'ping,rta'
        ];\n");

    # two data sources
    $str = '&db=ping,rta&db=ping,loss';
    ($db, $dblabel) = parsedb($str);
    ok(Dumper($db), "\$VAR1 = [
          'ping,rta',
          'ping,loss'
        ];\n");

    # multiple data sources in db,ds pairs
    $str = '&db=ping,rta&db=ping,loss&db=ping,crit&db=ping,warn';
    ($db, $dblabel) = parsedb($str);
    ok(Dumper($db), "\$VAR1 = [
          'ping,rta',
          'ping,loss',
          'ping,crit',
          'ping,warn'
        ];\n");

    # multiple data sources in single list
    $str = '&db=ping,rta&db=loss,losspct,losswarn,losscrit';
    ($db, $dblabel) = parsedb($str);
    ok(Dumper($db), "\$VAR1 = [
          'ping,rta',
          'loss,losspct,losswarn,losscrit'
        ];\n");

    # multiple data sources with labels
    $str = '&db=ping,rta&db=ping,loss&label=LOSS&db=ping,crit&db=ping,warn&label=WARN';
    ($db, $dblabel) = parsedb($str);
    ok(Dumper($db), "\$VAR1 = [
          'ping,rta',
          'ping,loss',
          'ping,crit',
          'ping,warn'
        ];\n");
    ok(Dumper($dblabel), "\$VAR1 = {
          'ping,warn' => 'WARN',
          'ping,loss' => 'LOSS'
        };\n");

#    teardowndebug();
    return;
}

# ensure that we unescape properly anything that is thrown at us
sub testcleanline {
    my $ostr = cleanline('&db=ping,rta&label=Real+Time Astronaut');
    ok($ostr, '&db=ping,rta&label=Real Time Astronaut');

    $ostr = cleanline('&db=ping,rta&label=Real%20Time%20Astronaut');
    ok($ostr, '&db=ping,rta&label=Real Time Astronaut');
    return;
}

sub testgetcfgfn {
    my $fn = getcfgfn('/home/file.txt');
    ok($fn, '/home/file.txt');
    $fn = getcfgfn('file.txt');
    ok($fn, "$curdir/../etc/file.txt");
    return;
}

sub testreadhostdb {
    setuprrd();
    setupauthhosts();

    # scan when no file defined
    undef $Config{hostdb};
    my $result = readhostdb('host0');
    ok(@{$result}, 2);
    $Config{hostdb} = '';
    $result = readhostdb('host0');
    ok(@{$result}, 2);

    my $fn = "$curdir/db.conf";
    my $rrddir = gettestrrddir();
    $Config{hostdb} = $fn;

    # nothing when nothing in file
    writefile($fn);
    $result = readhostdb();
    ok(@{$result}, 0);

    # nothing when bogus file contents
    writefile($fn, ('servicio=7up'));
    $result = readhostdb();
    ok(@{$result}, 0);

    # specify ping service with ping db
    writefile($fn, ('#this is a comment',
                    'service=PING&db=ping'));

    # degenerate cases should return nothing
    $result = readhostdb();
    ok(@{$result}, 0);
    $result = readhostdb('');
    ok(@{$result}, 0);
    $result = readhostdb('-');
    ok(@{$result}, 0);
    $result = readhostdb('bogus');
    ok(@{$result}, 0);

    # this host should not match anything
    $result = readhostdb('host1');
    ok(@{$result}, 0);

    # this host should match only ping, not http
    $result = readhostdb('host0');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host0'
          }
        ];\n");

    # bogus lines should be ignored
    writefile($fn, ('  service=ping&db=rta',
                    'service=PING&db=ping',
                    ' host=host1'));
    $result = readhostdb('host3');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'rta'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          }
        ];\n");

    # empty db spec should be filled in
    writefile($fn, ('service=PING'));
    $result = readhostdb('host0');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [],
            'db_label' => [],
            'service' => 'PING',
            'host' => 'host0'
          }
        ];\n");
    $result = readhostdb('host3');
    ok(@{$result}, 0);
    ok(Dumper($result), "\$VAR1 = [];\n");

    # now add more data sets, all for ping service
    writefile($fn, ('service=ping&db=rta',
                    'service=ping&db=loss',
                    'service=PING&db=ping',
                    'service=PING&db=ping,rta',
                    'service=PING&db=ping,losspct'));

    # this should pick up three different pings
    $result = readhostdb('host2');
    ok(@{$result}, 3);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          },
          {
            'db' => [
                      'ping,rta'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          },
          {
            'db' => [
                      'ping,losspct'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          }
        ];\n");

    $result = readhostdb('host3');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'rta'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          },
          {
            'db' => [
                      'loss'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          }
        ];\n");


    # valid service, bogus data source
    writefile($fn, ('service=PING&db=foo'));

    # this host should not match anything
    $result = readhostdb('host2');
    ok(@{$result}, 0);


    # test multiple data sources per line
    writefile($fn, ('service=ping&db=rta&db=loss',
                    'service=PING&db=ping,losspct&db=ping,rta'));
    $result = readhostdb('host2');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping,losspct',
                      'ping,rta'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          }
        ];\n");
    $result = readhostdb('host3');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'rta',
                      'loss'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          }
        ];\n");


    # test database versus data source
    writefile($fn, ('service=PING&db=ping'));
    $result = readhostdb('host2');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          }
        ];\n");
    writefile($fn, ('service=PING&db=ping,rta'));
    $result = readhostdb('host2');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping,rta'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          }
        ];\n");
    writefile($fn, ('service=PING&db=rta'));
    $result = readhostdb('host2');
    ok(@{$result}, 0);
    ok(Dumper($result), "\$VAR1 = [];\n");
    # bogus data source should result in no match
    writefile($fn, ('service=PING&db=ping,bogus'));
    $result = readhostdb('host2');
    ok(@{$result}, 0);
    ok(Dumper($result), "\$VAR1 = [];\n");


    # test multiple data sets alternative syntax
    writefile($fn, ('service=ping&db=loss,losspct,losswarn&db=rta,rtawarn,rtacrit'));
    $result = readhostdb('host3');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'loss,losspct,losswarn',
                      'rta,rtawarn,rtacrit'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          }
        ];\n");


    # test service labels parsing
    writefile($fn, ('service=ping&label=PING&db=rta&db=loss',
                    'service=PING&label=PINGIT&db=ping,losspct&db=ping,rta'));
    $result = readhostdb('host2');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'service_label' => 'PINGIT',
            'db' => [
                      'ping,losspct',
                      'ping,rta'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          }
        ];\n");
    $result = readhostdb('host3');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'service_label' => 'PING',
            'db' => [
                      'rta',
                      'loss'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          }
        ];\n");


    # test data source labels parsing
    writefile($fn, ('service=PING&db=ping&label=Ping Loss Percentage'));
    $result = readhostdb('host0');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping'
                    ],
            'db_label' => {
                            'ping' => 'Ping Loss Percentage'
                          },
            'service' => 'PING',
            'host' => 'host0'
          }
        ];\n");
    writefile($fn, ('service=PING&db=ping,losspct&label=Ping Loss Percentage'));
    $result = readhostdb('host0');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping,losspct'
                    ],
            'db_label' => {
                            'ping,losspct' => 'Ping Loss Percentage'
                          },
            'service' => 'PING',
            'host' => 'host0'
          }
        ];\n");


    # test multiple data sets
    writefile($fn, ('service=PING&db=ping,losspct&label=LP&db=ping,rta&label=RTA'));
    $result = readhostdb('host0');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'db' => [
                      'ping,losspct',
                      'ping,rta'
                    ],
            'db_label' => {
                            'ping,rta' => 'RTA',
                            'ping,losspct' => 'LP'
                          },
            'service' => 'PING',
            'host' => 'host0'
          }
        ];\n");

    unlink $fn;
    teardownrrd();
    teardownauthhosts();
    return;
}

sub testreadservdb {
    setuprrd();
    setupauthhosts();

    # scan when no file defined
    undef $Config{servdb};
    my $result = readservdb('HTTP');
    ok(@{$result}, 2);
    $Config{servdb} = '';
    $result = readservdb('HTTP');
    ok(@{$result}, 2);

    my $fn = "$curdir/db.conf";
    $Config{servdb} = $fn;

    # when nothing in file, use defaults

    writefile($fn, (''));

    $result = readservdb('PING');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host2'
        ];\n");
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");
    $result = readservdb('bogus');
    ok(@{$result}, 0);

    # bogus lines should be ignored
    writefile($fn, ('  host=host0',
                    'service=service1',
                    ' host=  host1'));
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");

    writefile($fn, ('#this is a comment',
                    'host=host0',
                    'host=host1',
                    'host=host2',
                    'host=host3',
                    'host=host4',
                    'host=host5'));

    # degenerate cases should return nothing

    $result = readservdb();
    ok(@{$result}, 0);
    $result = readservdb('');
    ok(@{$result}, 0);
    $result = readservdb('-');
    ok(@{$result}, 0);
    $result = readservdb('bogus');
    ok(@{$result}, 0);

    # check valid services

    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");
    $result = readservdb('PING');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host2'
        ];\n");
    $result = readservdb('ping');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          'host3'
        ];\n");

    # check database/source specialization

    $result = readservdb('ping', ['loss']);
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          'host3'
        ];\n");
    $result = readservdb('ping', ['loss,losspct']);
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          'host3'
        ];\n");
    $result = readservdb('ping', ['loss,losspct','loss,losswarn']);
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          'host3'
        ];\n");
    $result = readservdb('ping', ['loss,losspct','loss,bogus']);
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          'host3'
        ];\n");
    $result = readservdb('ping', ['loss,bogus']);
    ok(@{$result}, 0);
    $result = readservdb('ping', ['bogus']);
    ok(@{$result}, 0);
    ok(Dumper($result), "\$VAR1 = [];\n");

    # verify the order of hosts

    writefile($fn, ('host=host0,host1'));
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");
    writefile($fn, ('host=host1,host0'));
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host1',
          'host0'
        ];\n");

    # verify specialized requests

    writefile($fn, ('host=host0,host1'));
    $result = readservdb('HTTP', ['http']);
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");
    $result = readservdb('HTTP', ['http,Bps']);
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");
    $result = readservdb('HTTP', ['bogus']);
    ok(@{$result}, 0);
    $result = readservdb('HTTP', ['http,bogus']);
    ok(@{$result}, 0);

    unlink $fn;
    teardownrrd();
    teardownauthhosts();
    return;
}

sub testreadgroupdb {
    setuprrd();
    setupauthhosts();

    my $fn = "$curdir/db.conf";
    my $rrddir = gettestrrddir();
    $Config{groupdb} = $fn;

    # nothing when nothing in file
    writefile($fn, (''));
    my ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 0);

    # skip bogus lines
    writefile($fn, ('#this is a comment',
                    'backup',
                    'backup=host',
                    'PING='));
    ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 0);

    # test scan for defaults
    writefile($fn, ('#this is a comment',
                    'PING=host0,PING',
                    'PING=host2,PING&db=ping,losspct',
                    'PING=host3,PING'));
    ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 1);
    ok(Dumper($infos), "\$VAR1 = [
          {
            'db' => [],
            'db_label' => [],
            'service' => 'PING',
            'host' => 'host0'
          },
          {
            'db' => [
                      'ping,losspct'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host2'
          }
        ];\n");

    writefile($fn, ('#this is a comment',
                    'PING=host1,PING&db=ping,rta',
                    'PING=host1,PING&db=ping,losspct',
                    'PING=host2,PING&db=ping,losspct',
                    'PING=host3,PING&db=ping,losspct',
                    'PING=host4,PING&db=ping,rta',
                    'PING=host4,PING&db=ping,losspct',
                    'PING=host5,PING&db=ping,losspct',
                    'Web Servers=host0,PING&db=ping,losspct',
                    'Web Servers=host0,HTTP&db=http',
                    'Web Servers=host1,PING&db=ping,losspct',
                    'Web Servers=host1,HTTP&db=http',
                    'Web Servers=host5,PING&db=ping,losspct',
                    'Web Servers=host5,HTTP&db=http'));

    ($names,$infos) = readgroupdb();
    ok(@{$names}, 2);
    ok(Dumper($names), "\$VAR1 = [
          'PING',
          'Web Servers'
        ];\n");

    # degenerate cases should return nothing

    ($names,$infos) = readgroupdb();
    ok(@{$infos}, 0);
    ($names,$infos) = readgroupdb('');
    ok(@{$infos}, 0);
    ($names,$infos) = readgroupdb('-');
    ok(@{$infos}, 0);
    ($names,$infos) = readgroupdb('bogus');
    ok(@{$infos}, 0);

    # normal use case

    ($names,$infos) = readgroupdb('Web Servers');
    ok(@{$infos}, 3);
    ok(Dumper($infos), "\$VAR1 = [
          {
            'db' => [
                      'ping,losspct'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host0'
          },
          {
            'db' => [
                      'http'
                    ],
            'db_label' => {},
            'service' => 'HTTP',
            'host' => 'host0'
          },
          {
            'db' => [
                      'http'
                    ],
            'db_label' => {},
            'service' => 'HTTP',
            'host' => 'host1'
          }
        ];\n");

    # test multiple data sources from multiple databases

    writefile($fn, ('PING=host3,ping&db=loss,losspct,losscrit,losswarn&db=rta,rtacrit'));
    ($names,$infos) = readgroupdb('PING');
    ok(@{$infos}, 1);
    ok(Dumper($infos), "\$VAR1 = [
          {
            'db' => [
                      'loss,losspct,losscrit,losswarn',
                      'rta,rtacrit'
                    ],
            'db_label' => {},
            'service' => 'ping',
            'host' => 'host3'
          }
        ];\n");

    # test service and data labels

    writefile($fn, ('PING=host0,PING&label=PING RTA&db=ping,rta',
                    'PING=host0,PING&db=ping,losspct&label=LOSSY'));

    ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 1);
    ok(Dumper($names), "\$VAR1 = [
          'PING'
        ];\n");
    ok(Dumper($infos), "\$VAR1 = [
          {
            'service_label' => 'PING RTA',
            'db' => [
                      'ping,rta'
                    ],
            'db_label' => {},
            'service' => 'PING',
            'host' => 'host0'
          },
          {
            'db' => [
                      'ping,losspct'
                    ],
            'db_label' => {
                            'ping,losspct' => 'LOSSY'
                          },
            'service' => 'PING',
            'host' => 'host0'
          }
        ];\n");

    unlink $fn;
    teardownrrd();
    teardownauthhosts();
    return;
}

sub testreaddatasetdb {
    setuprrd();

    # nothing when no file defined
    undef $Config{datasetdb};
    my $result = readdatasetdb();
    ok(keys %{$result}, 0);

    $Config{datasetdb} = '';
    $result = readdatasetdb();
    ok(keys %{$result}, 0);

    my $fn = "$curdir/db.conf";
    $Config{datasetdb} = $fn;

    # nothing when nothing in file
    writefile($fn, (''));
    $result = readdatasetdb();
    ok(keys %{$result}, 0);

    # bogus lines should be ignored
    writefile($fn, ('service=',
                    '  service = ping&db=rta',
                    'host'));
    $result = readdatasetdb();
    ok(keys %{$result}, 1);

    writefile($fn, ('#this is a comment',
                    'service=PING&db=ping,rta',
                    'service=net&db=bytes-received&db=bytes-transmitted'));
    $result = readdatasetdb();
    ok(keys %{$result}, 2);
    ok(Dumper($result), "\$VAR1 = {
          'PING' => [
                      'ping,rta'
                    ],
          'net' => [
                     'bytes-received',
                     'bytes-transmitted'
                   ]
        };\n");

    writefile($fn, ('service=PING&db=ping,rta',
                    'service=PING&db=ping,loss'));

    # if multiple definitions, use the last one
    $result = readdatasetdb();
    ok(keys %{$result}, 1);
    ok(Dumper($result), "\$VAR1 = {
          'PING' => [
                      'ping,loss'
                    ]
        };\n");

    unlink $fn;
    teardownrrd();
    return;
}

sub testreadrrdoptsfile {
    # do nothing if file not defined
    undef $Config{rrdoptsfile};
    my $errstr = readrrdoptsfile();
    ok($errstr, '');

    my $fn = "$curdir/db.conf";
    $Config{rrdoptsfile} = $fn;

    undef $Config{rrdoptshash};
    $Config{rrdoptshash}{global} = q();
    $errstr = readrrdoptsfile();
    ok($errstr, "cannot open $fn: No such file or directory");
    ok(Dumper($Config{rrdoptshash}), "\$VAR1 = {
          'global' => ''
        };\n");

    writefile($fn, ('ping=-u 1 -l 0',
                    'ntp=-A'));

    undef $Config{rrdoptshash};
    $Config{rrdoptshash}{global} = q();
    $errstr = readrrdoptsfile();
    ok($errstr, '');
    ok(Dumper($Config{rrdoptshash}), "\$VAR1 = {
          'ntp' => '-A',
          'ping' => '-u 1 -l 0',
          'global' => ''
        };\n");

    undef $Config{rrdoptshash};
    unlink $fn;
    return;
}

sub testreadlabelsfile {
    undef %Labels;
    my $errstr = readlabelsfile();
    ok($errstr, '');

    my $fn = "$curdir/db.conf";
    $Config{labelfile} = $fn;

    undef %Labels;
    $errstr = readlabelsfile();
    ok($errstr, "cannot open $fn: No such file or directory");
    ok(Dumper(\%Labels), "\$VAR1 = {};\n");

    writefile($fn, ('ping=PING'));

    undef %Labels;
    $errstr = readlabelsfile();
    ok($errstr, '');
    ok(Dumper(\%Labels), "\$VAR1 = {
          'ping' => 'PING'
        };\n");

    unlink $fn;
    return;
}

# build hash from rrd files in a single directory
sub testscandirectory {
    my $TMP;
    my $rrddir = 'testrrddir';
    mkdir $rrddir, 0755;

    undef %hsdata;
    $_ = '..';
    scandirectory();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = $rrddir;
    mkdir $_, 0755;
    scandirectory();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = $rrddir . '/test1.rrd';
    open $TMP, '>', $_ or carp "open failed: $OS_ERROR";
    print ${TMP} "test1\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close failed: $OS_ERROR";
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {};\n");
    $_ = $rrddir . '/host0_ping_rta.rrd';
    open $TMP, '>', $_ or carp "open failed: $OS_ERROR";
    print ${TMP} "test1\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close failed: $OS_ERROR";
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {
          'testrrddir/host0' => {
                                  'ping' => [
                                              'rta'
                                            ]
                                }
        };\n");
    $_ = $rrddir . '/host1_ping_rta.rrd';
    open $TMP, '>', $_ or carp "open failed: $OS_ERROR";
    print ${TMP} "test1\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close failed: $OS_ERROR";
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {
          'testrrddir/host1' => {
                                  'ping' => [
                                              'rta'
                                            ]
                                },
          'testrrddir/host0' => {
                                  'ping' => [
                                              'rta'
                                            ]
                                }
        };\n");

    undef %hsdata;
    $_ = $rrddir . '/host0_ping_Round%20Trip%20Average.rrd';
    open $TMP, '>', $_ or carp "open failed: $OS_ERROR";
    print ${TMP} "test1\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close failed: $OS_ERROR";
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {
          'testrrddir/host0' => {
                                  'ping' => [
                                              'Round Trip Average'
                                            ]
                                }
        };\n");

    undef %hsdata;
    rmtree($rrddir);
    return;
}

# build hash from rrd files in a directory hierarchy
sub testscanhierarchy {
    my $TMP;
    undef %hsdata;
    $_ = '..';
    scanhierarchy();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = 'test';
    mkdir $_, 0755;
    scanhierarchy();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = 'test/test1';
    open $TMP, '>', $_ or carp "open failed: $OS_ERROR";
    print ${TMP} "test1\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close failed: $OS_ERROR";
    scanhierarchy();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = 'test';
    scanhierarchy();
    ok(Dumper($hsdata{$_}), "\$VAR1 = {};\n");
    $_ = 'test/test1.rrd';
    open $TMP, '>', $_ or carp "open failed: $OS_ERROR";
    print ${TMP} "test1\n" or carp "print failed: $OS_ERROR";
    close $TMP or carp "close failed: $OS_ERROR";
    $File::Find::dir = $curdir;
    scanhierarchy();
    ok($hsdata{$curdir}{'test/test1.rrd'}[0], undef);
    unlink 'test/test1';
    unlink 'test/test1.rrd';
    rmdir 'test';
    undef %hsdata;
    return;
}

# ensure that scanning host/service data works.  do it with both subdir and
# old style configurations.
sub testscanhsdata {
    setuprrd('subdir');
    undef %hsdata;
    scanhsdata();
    ok(printdata(\%hsdata), "\$VAR1 = {
  'host0' => {
    'HTTP' => [
      'http'
    ],
    'PING' => [
      'ping'
    ]
  },
  'host1' => {
    'HTTP' => [
      'http'
    ]
  },
  'host2' => {
    'PING' => [
      'ping'
    ]
  },
  'host3' => {
    'ping' => [
      'loss',
      'rta'
    ]
  },
  'host4' => {
    'c:\\\\ space' => [
      'ntdisk'
    ]
  },
  'host5' => {
    'ntdisk' => [
      'c:\\\\ space'
    ]
  }
};\n");
    undef %hsdata;
    teardownrrd();

    setuprrd('_');
    undef %hsdata;
    scanhsdata();
    ok(printdata(\%hsdata), "\$VAR1 = {
  'host0' => {
    'HTTP' => [
      'http'
    ],
    'PING' => [
      'ping'
    ]
  },
  'host1' => {
    'HTTP' => [
      'http'
    ]
  },
  'host2' => {
    'PING' => [
      'ping'
    ]
  },
  'host3' => {
    'ping' => [
      'rta',
      'loss'
    ]
  },
  'host4' => {
    'c:\\\\ space' => [
      'ntdisk'
    ]
  },
  'host5' => {
    'ntdisk' => [
      'c:\\\\ space'
    ]
  }
};\n");
    undef %hsdata;
    teardownrrd();
    return;
}

sub testgetstyle {
    $Config{stylesheet} = 'sheet.css';
    my @style = getstyle();
    ok(Dumper(\@style), "\$VAR1 = [
          '-style',
          {
            '-src' => 'sheet.css'
          }
        ];\n");
    undef $Config{stylesheet};
    @style = getstyle();
    ok(Dumper(\@style), "\$VAR1 = [];\n");
    return;
}

sub testgetrefresh {
    $Config{refresh} = 500;
    my @refresh = getrefresh();
    ok(Dumper(\@refresh), "\$VAR1 = [
          '-http_equiv',
          'Refresh',
          '-content',
          '500'
        ];\n");
    undef $Config{refresh};
    @refresh = getrefresh();
    ok(Dumper(\@refresh), "\$VAR1 = [];\n");
    return;
}

sub testgetperiodctrls {
    undef %Config;
    $Config{timeformat_day} = '%H:%M %e %b';
    my $cgi = new CGI;
    my $offset = 86_400;
    my @period = ('day', 118_800, 86_400);
    my $now = 1267333859; # Sun Feb 28 00:10:59 2010
    my ($p,$c,$n) = getperiodctrls($cgi, $offset, \@period, $now);
    ok($p, '<a href="&amp;offset=172800"><</a>');
    ok($c, '15:10 25 Feb - 00:10 27 Feb');
    ok($n, '<a href="&amp;offset=0">></a>');
    return;
}

sub testgetperiodlabel {
    undef %Config;
    $Config{timeformat_day} = '%H:%M %e %b';
    $Config{timeformat_week} = '%e %b';
    $Config{timeformat_month} = 'week %U';
    $Config{timeformat_quarter} = 'week %U';
    $Config{timeformat_year} = '%b %Y';

    my $n = 1267333859; # Sun Feb 28 00:10:59 2010
    my $o = 86_400;
    my $p = 118_800;
    my $s = getperiodlabel($n, $o, $p, 'day');
    ok($s, '15:10 25 Feb - 00:10 27 Feb');
    $s = getperiodlabel($n, $o, $p, 'week');
    ok($s, '25 Feb - 27 Feb');
    $s = getperiodlabel($n, $o, $p, 'month');
    ok($s, 'week 08 - week 08');
    $s = getperiodlabel($n, $o, $p, 'quarter');
    ok($s, 'week 08 - week 08');
    $s = getperiodlabel($n, $o, $p, 'year');
    ok($s, 'Feb 2010 - Feb 2010');

    $o = 172_800;
    $s = getperiodlabel($n, $o, $p, 'day');
    ok($s, '15:10 24 Feb - 00:10 26 Feb');
    $o = 86_400;
    $p = 8_467_200;
    $s = getperiodlabel($n, $o, $p, 'day');
    ok($s, '00:10 21 Nov - 00:10 27 Feb');
    return;
}

sub testformattime {
    my $t = 1267333859; # Sun Feb 28 00:10:59 2010
    $Config{timeformat_day} = '%H:%M %e %b';
    my $s = formattime($t, 'timeformat_day');
    ok($s, '00:10 28 Feb');
    $s = formattime($t, 'bogus');
    ok($s, 'Sun Feb 28 00:10:59 2010');
    return;
}

sub testcheckrrddir {
    my $isroot = $ENV{LOGNAME} eq 'root' ? 1 : 0;
    my $cwd = $curdir;
    my $gp = $cwd . '/gp';
    my $p = $gp . '/p';
    my $rrd = $p . '/rrd';

    $Config{rrddir} = $rrd;

    rmtree($gp);
    my $msg = checkrrddir('write');
    ok($msg, '');

    rmtree($gp);
    mkdir $gp, 0770;
    $msg = checkrrddir('write');
    ok($msg, '');

    rmtree($gp);
    mkdir $gp, 0550;
    $msg = checkrrddir('write');
    if ($isroot) {
        ok($msg, '');
    } else {
        ok($msg, "Cannot create rrd directory $cwd/gp/p/rrd: No such file or directory");
    }

    rmtree($gp);
    mkdir $gp, 0550;
    mkdir $p, 0770;
    $msg = checkrrddir('write');
    if ($isroot) {
        ok($msg, '');
    } else {
        ok($msg, "Cannot create rrd directory $cwd/gp/p/rrd: No such file or directory");
    }

    rmtree($gp);
    mkdir $gp, 0770;
    mkdir $p, 0550;
    $msg = checkrrddir('write');
    if ($isroot) {
        ok($msg, '');
    } else {
        ok($msg, "Cannot create rrd directory $cwd/gp/p/rrd: Permission denied");
    }

    rmtree($gp);
    $msg = checkrrddir('read');
    ok($msg, "Cannot read rrd directory $cwd/gp/p/rrd");

    mkdir $gp, 0770;
    mkdir $p, 0770;
    $msg = checkrrddir('read');
    ok($msg, "Cannot read rrd directory $cwd/gp/p/rrd");

    mkdir $gp, 0770;
    mkdir $p, 0770;
    mkdir $rrd, 0770;
    $msg = checkrrddir('read');
    ok($msg, "No data in rrd directory $cwd/gp/p/rrd");

    my $fn = $rrd . '/file.rrd';
    writefile($fn, (''));

    $msg = checkrrddir('read');
    ok($msg, '');

    rmtree($gp);
    return;
}

sub testgetlabel {
    ok(getlabel('foo'), 'foo');
    $Labels{foo} = 'bar';
    ok(getlabel('foo'), 'bar');
    undef $Labels{foo};
    return;
}

# test fallback behavior when getting labels for data
sub testgetdatalabel {
    undef %Labels;
    $Labels{'ping,loss'} = 'PING Loss';
    ok(getdatalabel('ping'), 'ping');
    ok(getdatalabel('loss'), 'loss');
    ok(getdatalabel('ping,loss'), 'PING Loss');

    undef %Labels;
    $Labels{'loss'} = 'PING Loss';
    ok(getdatalabel('ping'), 'ping');
    ok(getdatalabel('loss'), 'PING Loss');
    ok(getdatalabel('ping,loss'), 'PING Loss');

    undef %Labels;
    $Labels{'loss'} = 'Loss';
    $Labels{'ping'} = 'PING';
    $Labels{'ping,loss'} = 'PING Loss';
    ok(getdatalabel('ping'), 'PING');
    ok(getdatalabel('loss'), 'Loss');
    ok(getdatalabel('ping,loss'), 'PING Loss');

    undef %Labels;
    return;
}

sub testbuildurl {
    ok(buildurl('host0', ''), '');
    ok(buildurl('', 'ping'), '');
    ok(buildurl('', ''), '');

    my %opts;
    ok(buildurl('host0', 'ping', \%opts),
       'host=host0&service=ping');

    $opts{db} = '';
    ok(buildurl('host0', 'ping', \%opts),
       'host=host0&service=ping');
    undef $opts{db};

    $opts{db} = 'loss,losspct';
    ok(buildurl('host0', 'ping', \%opts),
       'host=host0&service=ping&db=loss,losspct');
    undef $opts{db};

    $opts{db} = ['loss,losspct', 'rta,rta'];
    ok(buildurl('host0', 'ping', \%opts),
       'host=host0&service=ping&db=loss,losspct&db=rta,rta');
    undef $opts{db};

    $opts{geom} = '100x100';
    ok(buildurl('host0', 'ping', \%opts),
       'host=host0&service=ping&geom=100x100');
    undef $opts{geom};
    return;
}

sub testcfgparams {
    undef %Config;
    my %dst;
    my %src;

    $src{expand_controls} = '';
    $src{fixedscale} = '';
    $src{showgraphtitle} = '';
    $src{showtitle} = '';
    $src{showdesc} = '';
    $src{hidelegend} = '';
    $src{graphonly} = '';
    $src{period} = '';
    $src{expand_period} = '';
    $src{geom} = '';
    $src{offset} = '';
    cfgparams(\%dst, \%src);
    ok(Dumper(\%dst), "\$VAR1 = {
          'showgraphtitle' => 0,
          'expand_controls' => 0,
          'fixedscale' => 0,
          'graphonly' => 0,
          'hidelegend' => 0,
          'showtitle' => 0,
          'showdesc' => 0,
          'offset' => 0
        };\n");

    $Config{expand_controls} = 'true';
    $Config{fixedscale} = 'true';
    $Config{showgraphtitle} = 'true';
    $Config{showtitle} = 'true';
    $Config{showdesc} = 'true';
    $Config{hidelegend} = 'true';
    $Config{graphonly} = 'true';
    cfgparams(\%dst, \%src);
    ok(Dumper(\%dst), "\$VAR1 = {
          'showgraphtitle' => 1,
          'expand_controls' => 1,
          'fixedscale' => 1,
          'graphonly' => 1,
          'hidelegend' => 1,
          'showtitle' => 1,
          'showdesc' => 1,
          'offset' => 0
        };\n");

    $src{expand_controls} = 'true';
    $src{fixedscale} = 'true';
    $src{showgraphtitle} = 'true';
    $src{showtitle} = 'true';
    $src{showdesc} = 'true';
    $src{hidelegend} = 'true';
    $src{graphonly} = 'true';
    $src{period} = 'day';
    $src{expand_period} = 'day';
    $src{geom} = '100x100';
    $src{offset} = '1';
    cfgparams(\%dst, \%src);
    ok(Dumper(\%dst), "\$VAR1 = {
          'expand_controls' => 'true',
          'geom' => '100x100',
          'period' => 'day',
          'graphonly' => 'true',
          'hidelegend' => 'true',
          'showtitle' => 'true',
          'showdesc' => 'true',
          'showgraphtitle' => 'true',
          'fixedscale' => 'true',
          'expand_period' => 'day',
          'offset' => '1'
        };\n");

    undef %Config;
    return;
}

sub testsetlabels {
    $Config{colorscheme} = 2;
    $Config{plotas} = 'LINE1';

    undef $Config{minimums};
    undef $Config{minimumslist};
    undef $Config{maximums};
    undef $Config{maximumslist};
    undef $Config{lasts};
    undef $Config{lastslist};
    undef $Config{stack};
    undef $Config{stacklist};
    my @result = setlabels('host', 'serv', 'db', 'ds', 'file', 'label', 20);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds=file:ds:AVERAGE',
          'LINE1:db_ds#990033:label               '
        ];\n");

    $Config{stack} = 'ds';
    $Config{stacklist} = str2list($Config{stack});
    @result = setlabels('host', 'serv', 'db', 'ds', 'file', 'label', 20);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds=file:ds:AVERAGE',
          'LINE1:db_ds#990033:label               :STACK'
        ];\n");

    undef $Config{stack};
    undef $Config{stacklist};
    $Config{maximums} = 'serv';
    $Config{maximumslist} = str2list($Config{maximums});
    @result = setlabels('host', 'serv', 'db', 'ds', 'file', 'label', 20);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds=file:ds:MAX',
          'CDEF:ceildb_ds=db_ds,CEIL',
          'LINE1:db_ds#990033:label               '
        ];\n");

    undef $Config{maximums};
    undef $Config{maximumslist};
    $Config{minimums} = 'serv';
    $Config{minimumslist} = str2list($Config{minimums});
    @result = setlabels('host', 'serv', 'db', 'ds', 'file', 'label', 20);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds=file:ds:MIN',
          'CDEF:floordb_ds=db_ds,FLOOR',
          'LINE1:db_ds#990033:label               '
        ];\n");

    undef $Config{minimums};
    undef $Config{minimumslist};
    $Config{lasts} = 'serv';
    $Config{lastslist} = str2list($Config{lasts});
    undef $Config{stack};
    @result = setlabels('host', 'serv', 'db', 'ds', 'file', 'label', 20);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds=file:ds:LAST',
          'LINE1:db_ds#990033:label               '
        ];\n");

    # if defined for all of them, then max is used because we look for it first

    $Config{minimums} = 'serv';
    $Config{minimumslist} = str2list($Config{minimums});
    $Config{maximums} = 'serv';
    $Config{maximumslist} = str2list($Config{maximums});
    $Config{lasts} = 'serv';
    $Config{lastslist} = str2list($Config{lasts});
    $Config{stack} = 'ds';
    $Config{stacklist} = str2list($Config{stack});
    @result = setlabels('host', 'serv', 'db', 'ds', 'file', 'label', 20);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds=file:ds:MAX',
          'CDEF:ceildb_ds=db_ds,CEIL',
          'LINE1:db_ds#990033:label               :STACK'
        ];\n");

    undef %Config;
    return;
}

sub testsetdata {
    undef $Config{withminimums};
    undef $Config{withmaximums};

    my @result = setdata('serv', 'db', 'ds', 'file', 1_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'GPRINT:db_ds:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:db_ds:MIN:Min\\\\:%7.2lf%s',
          'GPRINT:db_ds:LAST:Cur\\\\:%7.2lf%s\\\\n'
        ];\n");

    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'GPRINT:db_ds:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:db_ds:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");

    @result = setdata('serv', 'db', 'ds', 'file', 1_000, '%7.2lf');
    ok(Dumper(\@result), "\$VAR1 = [
          'GPRINT:db_ds:MAX:Max\\\\:%7.2lf',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf',
          'GPRINT:db_ds:MIN:Min\\\\:%7.2lf',
          'GPRINT:db_ds:LAST:Cur\\\\:%7.2lf\\\\n'
        ];\n");

    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000, '%7.2lf');
    ok(Dumper(\@result), "\$VAR1 = [
          'GPRINT:db_ds:MAX:Max\\\\:%7.2lf',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf',
          'GPRINT:db_ds:MIN:Min\\\\:%7.2lf\\\\n'
        ];\n");

    $Config{withminimums} =  'serv';
    listtodict('withminimums', q(,));
    undef $Config{withmaximums};
    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds_min=file_min:ds:MIN',
          'LINE1:db_ds_min#BBBBBB:minimum',
          'GPRINT:db_ds:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'CDEF:db_ds_minif=db_ds_min,UN',
          'CDEF:db_ds_mini=db_ds_minif,db_ds,db_ds_min,IF',
          'GPRINT:db_ds_mini:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");

    undef $Config{withminimums};
    $Config{withmaximums} =  'serv';
    listtodict('withmaximums', q(,));
    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds_max=file_max:ds:MAX',
          'LINE1:db_ds_max#888888:maximum',
          'CDEF:db_ds_maxif=db_ds_max,UN',
          'CDEF:db_ds_maxi=db_ds_maxif,db_ds,db_ds_max,IF',
          'GPRINT:db_ds_maxi:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'GPRINT:db_ds:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");

    $Config{withminimums} =  'serv';
    listtodict('withminimums', q(,));
    $Config{withmaximums} =  'serv';
    listtodict('withmaximums', q(,));
    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds_max=file_max:ds:MAX',
          'LINE1:db_ds_max#888888:maximum',
          'DEF:db_ds_min=file_min:ds:MIN',
          'LINE1:db_ds_min#BBBBBB:minimum',
          'CDEF:db_ds_maxif=db_ds_max,UN',
          'CDEF:db_ds_maxi=db_ds_maxif,db_ds,db_ds_max,IF',
          'GPRINT:db_ds_maxi:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'CDEF:db_ds_minif=db_ds_min,UN',
          'CDEF:db_ds_mini=db_ds_minif,db_ds,db_ds_min,IF',
          'GPRINT:db_ds_mini:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");

    $Config{colormin} = '111111';
    undef $Config{colormax};
    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds_max=file_max:ds:MAX',
          'LINE1:db_ds_max#888888:maximum',
          'DEF:db_ds_min=file_min:ds:MIN',
          'LINE1:db_ds_min#111111:minimum',
          'CDEF:db_ds_maxif=db_ds_max,UN',
          'CDEF:db_ds_maxi=db_ds_maxif,db_ds,db_ds_max,IF',
          'GPRINT:db_ds_maxi:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'CDEF:db_ds_minif=db_ds_min,UN',
          'CDEF:db_ds_mini=db_ds_minif,db_ds,db_ds_min,IF',
          'GPRINT:db_ds_mini:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");

    undef $Config{colormin};
    $Config{colormax} = 'eeeeee';
    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds_max=file_max:ds:MAX',
          'LINE1:db_ds_max#eeeeee:maximum',
          'DEF:db_ds_min=file_min:ds:MIN',
          'LINE1:db_ds_min#BBBBBB:minimum',
          'CDEF:db_ds_maxif=db_ds_max,UN',
          'CDEF:db_ds_maxi=db_ds_maxif,db_ds,db_ds_max,IF',
          'GPRINT:db_ds_maxi:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'CDEF:db_ds_minif=db_ds_min,UN',
          'CDEF:db_ds_mini=db_ds_minif,db_ds,db_ds_min,IF',
          'GPRINT:db_ds_mini:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");

    $Config{colormin} = '111111';
    $Config{colormax} = 'eeeeee';
    @result = setdata('serv', 'db', 'ds', 'file', 1_000_000);
    ok(Dumper(\@result), "\$VAR1 = [
          'DEF:db_ds_max=file_max:ds:MAX',
          'LINE1:db_ds_max#eeeeee:maximum',
          'DEF:db_ds_min=file_min:ds:MIN',
          'LINE1:db_ds_min#111111:minimum',
          'CDEF:db_ds_maxif=db_ds_max,UN',
          'CDEF:db_ds_maxi=db_ds_maxif,db_ds,db_ds_max,IF',
          'GPRINT:db_ds_maxi:MAX:Max\\\\:%7.2lf%s',
          'GPRINT:db_ds:AVERAGE:Avg\\\\:%7.2lf%s',
          'CDEF:db_ds_minif=db_ds_min,UN',
          'CDEF:db_ds_mini=db_ds_minif,db_ds,db_ds_min,IF',
          'GPRINT:db_ds_mini:MIN:Min\\\\:%7.2lf%s\\\\n'
        ];\n");
    return;
}

sub testheartbeat {
    my $logfn = 'testheartbeat.log';
#    setupdebug(5, $logfn);

    my $rrddir = gettestrrddir();
    my $s;
    my @result;
    my $fn = $rrddir . '/testbox/procs___procs.rrd';
    my $info;
    my $cfgfn = 'testheartbeat.cfg';

    writefile($cfgfn, ('testlog=' . $logfn,
                       'rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '1000');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats =testbox,x,y=100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '1000');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats =testbox,procs,procs=100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '100');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats =testbox,procs,.*=100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '100');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats =testbox,.*,procs=100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '100');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats =.*,procs,procs=100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '100');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats =.*,.*,.*=100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '100');
    rmtree($rrddir);

    writefile($cfgfn, ('rrddir=' . $rrddir,
                       'dbseparator = subdir',
                       'heartbeat = 1000',
                       'heartbeats = .*,.*,.* =100'));
    readconfig('read', 'testlog', $cfgfn);
    $s = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    mkdir $Config{rrddir};
    @result = createrrd(1221495632, 'testbox', 'procs', $s);
    ok(-f $fn);
    $info = RRDs::info $fn;
    ok($info->{'ds[users].minimal_heartbeat'}, '1000');
    rmtree($rrddir);

    unlink $cfgfn;
    teardowndebug();
    return;
}


setup();
testdebug();
testdumper();
testgetdebug();
testformatelapsedtime();
testhtmlerror();
testimgerror();
testgetimg();
testdircreation();
testmkfilename();
testhashcolor();
testlisttodict();
teststr2list();
testarrayorstring();
testcheckdirempty();
testhsddmatch();
testgethsdd();
testgethsddvalue();
testgethsdvalue();
testgethsdvalue2();
testreadfile();
testinitlog();
testreadconfig();
testdbfilelist();
testgetdataitems();
testgetserverlist();
testprintmenudatascript();
testgraphsizes();
testreadperfdata();
testgetrras();
testcheckdatasources();
testcheckdsname();
testmkvname();
testcreaterrd();
testrrdupdate();
testgetrules();
testgetlineattr();
testrrdline();
testgraphinfo();
testprocessdata();
testinitperiods();
testparsedb();
testcleanline();
testgetcfgfn();
testreadhostdb();
testreadservdb();
testreadgroupdb();
testreaddatasetdb();
testreadrrdoptsfile();
testreadlabelsfile();
testscandirectory();
testscanhierarchy();
testscanhsdata();
testi18n();
testprinti18nscript();
testgetstyle();
testgetrefresh();
testgetperiodctrls();
testgetperiodlabel();
testformattime();
testcheckrrddir();
testgetlabel();
testgetdatalabel();
testbuildurl();
testcfgparams();
testgetparams();
testsetlabels();
testsetdata();
testheartbeat();
