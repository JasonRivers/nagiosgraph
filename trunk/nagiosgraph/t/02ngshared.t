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

use FindBin;
use strict;
use CGI qw(:standard escape unescape);
use Data::Dumper;
use File::Find;
use File::Path qw(rmtree);
use Test;
use lib "$FindBin::Bin/../etc";
use ngshared;
my ($log, $result, @result, $testvar, @testdata, %testdata, $ii);

BEGIN { plan tests => 469; }

sub dumpdata {
    my ($log, $val, $label) = @_;
    open my $TMP, '>>', 'test.log' or die;
    if ($label) {
        my $dd = Data::Dumper->new([$val], [$label]);
        $dd->Indent(1);
        print $TMP $dd->Dump();
    }
    print $TMP $log;
    close $TMP;
}

sub printdata {
    my ($data) = @_;
    my $dd = Data::Dumper->new([$data]);
    $dd->Indent(1);
    return $dd->Dump;
}

sub readtestfile {
    my ($fn) = @_;
    my $contents = q();
    if (open FILE, '<', $fn) {
        while(<FILE>) {
            $contents .= $_;
        }
        close FILE;
    }
    return $contents;
}

sub gettestrrddir {
    return $FindBin::Bin . q(/) . 'rrd';
}

sub setupdebug {
    $Config{debug} = 5;
    open $LOG, '+>', 'test-debug.txt';
}

sub teardowndebug {
    close $LOG;
    $Config{debug} = 0;
}

sub setuphsdata {
    undef %hsdata;
    scanhsdata();
}

sub teardownhsdata {
    undef %hsdata;
}

sub setupauthhosts {
    undef %hsdata;
    scanhsdata();
    %authhosts = getserverlist('');
}

sub teardownauthhosts {
    undef %hsdata;
    undef %authhosts;
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

    my $testvar = ['ping',
                   ['losspct', 'GAUGE', 0],
                   ['rta', 'GAUGE', .006] ];
    my @result = createrrd('host0', 'PING', 1221495632, $testvar);
    $testvar = ['http',
                ['Bps', 'GAUGE', 0] ];
    @result = createrrd('host0', 'HTTP', 1221495632, $testvar);

    $testvar = ['http',
                ['Bps', 'GAUGE', 0] ];
    @result = createrrd('host1', 'HTTP', 1221495632, $testvar);

    $testvar = ['ping',
                ['losspct', 'GAUGE', 0],
                ['rta', 'GAUGE', .006] ];
    @result = createrrd('host2', 'PING', 1221495632, $testvar);

    $testvar = ['loss',
                ['losspct', 'GAUGE', 0],
                ['losswarn', 'GAUGE', 5],
                ['losscrit', 'GAUGE', 10] ];
    @result = createrrd('host3', 'ping', 1221495632, $testvar);
    $testvar = ['rta',
                ['rta', 'GAUGE', 0.01],
                ['rtawarn', 'GAUGE', 0.1],
                ['rtacrit', 'GAUGE', 0.5] ];
    @result = createrrd('host3', 'ping', 1221495632, $testvar);

    $testvar = ['ntdisk',
                ['total', 'GAUGE', 100],
                ['used', 'GAUGE', 10] ];
    @result = createrrd('host4', 'c:\\ space', 1221495632, $testvar);

    $testvar = ['c:\\ space',
                ['total', 'GAUGE', 500],
                ['used', 'GAUGE', 20] ];
    @result = createrrd('host5', 'ntdisk', 1221495632, $testvar);
}

sub teardownrrd {
    rmtree(gettestrrddir());
}

sub testdebug { # Test the logger.
	open $LOG, '+>', \$log;
	$Config{debug} = 1;
	debug(0, "test message");
	ok($log, qr/02ngshared.t none test message$/);
	close $LOG;
	open $LOG, '+>', \$log;
	debug(2, "test no message");
	ok($log, "");
	close $LOG;
}

sub testdumper { # Test the list/hash output debugger.
	open $LOG, '+>', \$log;
	$testvar = 'test';
	dumper(0, 'test', \$testvar);
	ok($log, qr/02ngshared.t none test = .'test';$/);
	close $LOG;
	open $LOG, '+>', \$log;
	$testvar = ['test'];
	dumper(0, 'test', $testvar);
	ok($log, qr/02ngshared.t none test = \[\s+'test'\s+\];$/s);
	close $LOG;
	open $LOG, '+>', \$log;
	$testvar = {test => 1};
	dumper(0, 'test', $testvar);
	ok($log, qr/02ngshared.t none test = \{\s+'test' => 1\s+\};$/s);
	close $LOG;
	open $LOG, '+>', \$log;
	dumper(2, 'test', $testvar);
	ok($log, '');
	close $LOG;
	$Config{debug} = 0;
}

sub testgetdebug {
 
    # missing app (programming mistake)
    $Config{debug} = -1;
    getdebug();
    ok($Config{debug}, 5);
 
    $Config{debug} = -1;
    getdebug('test', '', '');
    ok($Config{debug}, -1);		# not configured, so no change
   
    # just program tests
    $Config{debug_test} = 1;
    getdebug('test', '', '');
    ok($Config{debug}, 1);		# configured, so change
    $Config{debug} = -1;
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);		# _host and _service not set, so change
    $Config{debug} = -1;
    
    # just program and hostname tests
    $Config{debug_test_host} = 'testbox';
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);		# _host set to same hostname, so change
    $Config{debug} = -1;
    getdebug('test', 'testing', 'ping');
    ok($Config{debug}, -1);		# _host set to different hostname, so no change
    $Config{debug} = -1;
    
    # program, hostname and service tests
    $Config{debug_test_service} = 'ping';
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);		# _host and _service same, so change
    $Config{debug} = -1;
    getdebug('test', 'testbox', 'smtp');
    ok($Config{debug}, -1);		# _host same, but _service not, so no change
    $Config{debug} = -1;
    getdebug('test', 'testing', 'ping');
    ok($Config{debug}, -1);		# _service same, but _host not, so no change
    $Config{debug} = -1;
    getdebug('test', 'testing', 'smtp');
    ok($Config{debug}, -1);		# neither _host or _service not, so no change
    $Config{debug} = -1;
    
    # just program and service tests
    delete $Config{debug_test_host};
    getdebug('test', 'testbox', 'ping');
    ok($Config{debug}, 1);		# _service same, so change
    $Config{debug} = -1;
    getdebug('test', 'testbox', 'smtp');
    ok($Config{debug}, -1);		# _service not, so no change
    $Config{debug} = 0;
}

sub testformatelapsedtime {
    my $s = gettimestamp();
    $result = formatelapsedtime($s, $s+3_000_000);
    ok($result, "00:00:03.000");
    $result = formatelapsedtime($s, $s+60_010_000);
    ok($result, "00:01:00.010");
    $result = formatelapsedtime($s, $s+36_610_000_000);
    ok($result, "10:10:10.000");
    $result = formatelapsedtime($s, $s+7_260_100_000);
    ok($result, "02:01:00.100");
    $result = formatelapsedtime($s, $s+1_000);
    ok($result, "00:00:00.001");
    $result = formatelapsedtime($s, $s+10);
    ok($result, "00:00:00.000");
}

sub testhtmlerror {
    open SAVEOUT, ">&STDOUT";
    my $fn = $FindBin::Bin . q(/) . 'error.html';
    open STDOUT, '>', $fn;
    htmlerror('test');
    close STDOUT;
    open STDOUT, ">&SAVEOUT";
    close SAVEOUT;
    $result = readtestfile($fn);
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
}

sub testimgerror {
    my $cgi = new CGI;
    my $fn = $FindBin::Bin . q(/) . 'error.png';

    open SAVEOUT, ">&STDOUT";
    open STDOUT, '>', $fn;
    imgerror($cgi);
    close STDOUT;
    open STDOUT, ">&SAVEOUT";
    close SAVEOUT;
    $result = readtestfile($fn);
    ok($result, "Content-Type: image/png\r\n\r\n\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\0\5\0\0\0\5\b\6\0\0\0\x8Do&\xE5\0\0\0!tEXtSoftware\0GraphicConverter (Intel)w\x87\xFA\31\0\0\0\31IDATx\x9Cb\xF8\xFF\xFF?\3:\xC6\20\xA0\x82 \0\0\0\xFF\xFF\3\0x\xC3J\xB6\x9F\xEB2\35\0\0\0\0IEND\xAEB`\x82");
    unlink $fn;

    open SAVEOUT, ">&STDOUT";
    open STDOUT, '>', $fn;
    imgerror($cgi, 'test');
    close STDOUT;
    open STDOUT, ">&SAVEOUT";
    close SAVEOUT;
    $result = readtestfile($fn);
    ok($result, "Content-Type: image/png\r\n\r\n\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\2`\0\0\0\27\1\3\0\0\0\x96\35a\xC3\0\0\0\6PLTE\xFF\xFF\xFF\xFF\24\24\xDF.\xE4\xBB\0\0\0\1tRNS\0@\xE6\xD8f\0\0\0>IDAT8\x8Dc`\30\5\xA3\0;`a`\34\xA4\x86\xF1\xCB\24\37\xA0\x9Aa,J\x9DT3\x8B\x81\xC5.\x91\x8A\x86)\bR\xD1\xB0\5\x9D\nT3\x8CY\xA6\xE0\0\xD5\f\e\5\xA3\x80\16\0\0\4Q\5\x8C\xE7\37\xF6\\\0\0\0\0IEND\xAEB`\x82");
    unlink $fn;
}

sub testgetimg {
    ok(getimg('test'), "\x89PNG\r\n\32\n\0\0\0\rIHDR\0\0\2`\0\0\0\27\1\3\0\0\0\x96\35a\xC3\0\0\0\6PLTE\xFF\xFF\xFF\xFF\24\24\xDF.\xE4\xBB\0\0\0\1tRNS\0@\xE6\xD8f\0\0\0>IDAT8\x8Dc`\30\5\xA3\0;`a`\34\xA4\x86\xF1\xCB\24\37\xA0\x9Aa,J\x9DT3\x8B\x81\xC5.\x91\x8A\x86)\bR\xD1\xB0\5\x9D\nT3\x8CY\xA6\xE0\0\xD5\f\e\5\xA3\x80\16\0\0\4Q\5\x8C\xE7\37\xF6\\\0\0\0\0IEND\xAEB`\x82");
}

# ensure that asking about host data does not create host directory
sub testdircreation {
    $Config{rrddir} = $FindBin::Bin;
    $Config{dbseparator} = 'subdir';
    my $host = 'xxx';
    my $service = 'yyy';
    my ($d,$f) = mkfilename($host,$service);
    my $dir = $FindBin::Bin . q(/) . $host;
    ok(! -d $dir);
    rmdir $dir if -d $dir;
}

sub testmkfilename { # Test getting the file and directory for a database.
	# Make rrddir where we run from
	$Config{rrddir} = $FindBin::Bin;
	$Config{dbseparator} = '';
        @result = mkfilename();
        ok($result[0], 'BOGUSDIR');
        ok($result[1], 'BOGUSFILE');
        @result = mkfilename('host');
        ok($result[0], 'BOGUSDIR');
        ok($result[1], 'BOGUSFILE');
	@result = mkfilename('testbox', 'Partition: /');
	ok($result[0], $FindBin::Bin);
	ok($result[1], 'testbox_Partition%3A%20%2F_');
	@result = mkfilename('testbox', 'Partition: /', 'diskgb');
	ok($result[0], $FindBin::Bin);
	ok($result[1], 'testbox_Partition%3A%20%2F_diskgb.rrd');
	$Config{dbseparator} = 'subdir';
	@result = mkfilename('testbox', 'Partition: /');
	ok($result[0], $FindBin::Bin . '/testbox');
	ok($result[1], 'Partition%3A%20%2F___');
	@result = mkfilename('testbox', 'Partition: /', 'diskgb');
	ok($result[0], $FindBin::Bin . '/testbox');
	ok($result[1], 'Partition%3A%20%2F___diskgb.rrd');
	ok(! -d $result[0]);
	rmdir $result[0] if -d $result[0];
}

# With 16 generated colors, the default rainbow and one custom.
sub testhashcolor {
    @testdata = ('FF0333', '3300CC', '990033', 'FF03CC', '990333', 'CC00CC', '000099', '6603CC');
    for ($ii = 0; $ii < 8; $ii++) {
        $result = hashcolor('Current Load', $ii + 1);
        ok($result, $testdata[$ii - 1]);
    }
    @testdata = ('CC0300', 'FF0399', '990000', '330099', '990300', '660399', '990000', 'CC0099');
    for ($ii = 1; $ii < 9; $ii++) {
        $result = hashcolor('PLW', $ii);
        ok($result, $testdata[$ii - 1]);
    }
    $Config{colors} = ['123', 'ABC'];
    @testdata = ('123', 'ABC', '123');
    for ($ii = 0; $ii < 3; $ii++) {
        $result = hashcolor('test', 9);
        ok($result, $testdata[$ii]);
    }
    undef %Config;
    $Config{colorscheme} = 2;
    ok(hashcolor('x'), '009900');
}

sub testlisttodict { # Split a string separated by a configured value into hash.
	open $LOG, '+>', \$log;
	$Config{testsep} = ',';
	$Config{test} = 'Current Load,PLW,Procs: total,User Count';
	$testvar = listtodict('test');
	foreach $ii ('Current Load','PLW','Procs: total','User Count') {
		ok($testvar->{$ii}, 1);
	}
	close $LOG;
}

sub teststr2hash {
    my $val = str2hash('H,S,D=10;*,*=50');
    ok(Dumper($val), "\$VAR1 = {
          'H,S,D' => '10',
          '*,*' => '50'
        };\n");
}

sub teststr2list {
    my $val = str2list('H,S,D=10;*,*=50');
    ok(Dumper($val), "\$VAR1 = [
          'H,S,D=10',
          '*,*=50'
        ];\n");
}

sub testarrayorstring {
    my %opts;
    $opts{a} = 'aval';
    $opts{array} = ['a','b','c'];
    ok(arrayorstring(\%opts, 'a'), '&a=aval');
    ok(arrayorstring(\%opts, 'array'), '&array=a&array=b&array=c');
}

sub testcheckdirempty { # Test with an empty directory, then one with a file.
	mkdir 'checkdir', 0770;
	ok(checkdirempty('checkdir'), 1);
	open TMP, '>checkdir/tmp';
	print TMP "test\n";
	close TMP;
	ok(checkdirempty('checkdir'), 0);
	unlink 'checkdir/tmp';
	rmdir 'checkdir';
}

sub testreadfile {
    my $fn = "$FindBin::Bin/test.conf";

    open TEST, ">$fn";
    print TEST "name0 = value0\n";
    print TEST "name1 = x1,x2,x3\n";
    print TEST "#name2 = value2\n";
    print TEST "  #name2 = value2\n";
    print TEST "name3 = value3 # comment\n";
    print TEST "name4 = --color BACK#FFFFFF\n";
    print TEST "name5=      y1,    y2,y3   ,y4\n";
    close TEST;

    my %vars;
    readfile($fn, \%vars);
    ok(scalar keys %vars, 5);
    ok($vars{name0}, "value0");
    ok($vars{name1}, "x1,x2,x3");
    ok($vars{name2}, undef);                    # ignore commented lines
    ok($vars{name3}, "value3 # comment");       # do not strip comments
    ok($vars{name4}, "--color BACK#FFFFFF");
    ok($vars{name5}, "y1,    y2,y3   ,y4");

    unlink $fn;
}

sub testinitlog {
    my $fn = "$FindBin::Bin/testlog.txt";

    undef %Config;
    $Config{debug} = 5;
    initlog('test');
    debug(DBDEB, 'test message');
    close $LOG;

    undef %Config;
    $Config{debug} = 5;
    $Config{logfile} = $fn;
    initlog('test');
    debug(DBDEB, 'test message');
    close $LOG;
    my $result = readtestfile($fn);
    ok($result =~ /debug test message/);
    unlink $fn;

    undef %Config;
    $Config{debug} = 5;
    initlog('test', $fn);
    debug(DBDEB, 'test message');
    close $LOG;
    $result = readtestfile($fn);
    ok($result =~ /debug test message/);
    unlink $fn;

    undef %Config;
    $Config{debug} = 0;
    $Config{debug_test} = 5;
    initlog('test', $fn);
    debug(DBDEB, 'test message');
    close $LOG;
    $result = readtestfile($fn);
    ok($result =~ /debug test message/);
    unlink $fn;

    undef %Config;
    $Config{debug} = 0;
    $Config{debug_foo} = 5;
    initlog('test', $fn);
    debug(DBDEB, 'test message');
    close $LOG;
    $result = readtestfile($fn);
    ok($result, '');
    unlink $fn;

    undef %Config;
}

sub testreadconfig {
    open $LOG, '+>', \$log;
    readconfig('read');
    ok($Config{logfile}, '/var/log/nagiosgraph.log');
    ok($Config{cgilogfile}, undef);
    close $LOG;
}

sub testgetparams {
    my ($cgi, $params) = getparams();
    ok(Dumper($cgi), "\$VAR1 = bless( {
                 '.parameters' => [],
                 'use_tempfile' => 1,
                 '.charset' => 'ISO-8859-1',
                 '.fieldnames' => {},
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
}

sub testdbfilelist { # Check getting a list of rrd files
	$Config{debug} = 0;
	open $LOG, '+>', \$log;
	$Config{rrddir} = $FindBin::Bin;
	$Config{dbseparator} = '';
	$result = dbfilelist('testbox', 'Partition: /');
	ok(@{$result}, 0);
	my $file = "$FindBin::Bin/testbox_Partition%3A%20%2F_test.rrd";
	open TEST, ">$file";
	print TEST "test\n";
	close TEST;
	@result = dbfilelist('testbox', 'Partition: /');
	ok(@result, 1);
	unlink $file;
	close $LOG;
	$Config{debug} = 0;
}

sub testgetdataitems {
    setuprrd();
    my $rrddir = gettestrrddir();
    my $fn = $rrddir . q(/) . 'host0/HTTP___http.rrd';
    my @rval = getdataitems($fn);
    ok(Dumper(\@rval), "\$VAR1 = [
          'Bps'
        ];
");
    $fn = $rrddir . q(/) . 'host2/PING___ping.rrd';
    @rval = getdataitems($fn);
    ok(Dumper(\@rval), "\$VAR1 = [
          'rta',
          'losspct'
        ];
");
    teardownrrd();
}

sub testgraphinfo {
    $Config{rrddir} = $FindBin::Bin;

    $Config{dbseparator} = '';
    $testvar = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    $Config{hostservvar} = 'testbox,procs,users';
    $Config{hostservvarsep} = ';';
    $Config{hostservvar} = listtodict('hostservvar');
    ok($Config{hostservvar}->{testbox}->{procs}->{users}, 1);
    @result = createrrd('testbox', 'procs', 1221495632, $testvar);
    ok($result[0]->[1], 'testbox_procsusers_procs.rrd');
    ok(-f $FindBin::Bin . '/testbox_procsusers_procs.rrd');
    ok(-f $FindBin::Bin . '/testbox_procs_procs.rrd');

    $result = graphinfo('testbox', 'procs', ['procs']);
    my $file = $FindBin::Bin . '/testbox_procs_procs.rrd';
    skip(! -f $file, $result->[0]->{file}, 'testbox_procs_procs.rrd');
    skip(! -f $file, $result->[0]->{line}->{uwarn}, 1);
    unlink $file if -f $file;
    $file = $FindBin::Bin . '/testbox_procs_procs.rrd';
    unlink  $file if -f $file;
    $file = $FindBin::Bin . '/testbox_procsusers_procs.rrd';
    unlink  $file if -f $file;

    # create default data file
    $Config{dbseparator} = 'subdir';
    $testvar = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd('testbox', 'PING', 1221495632, $testvar);
    ok($result[0]->[0], 'PING___ping.rrd');
    ok($result[1]->[0]->[0], 0);
    ok($result[1]->[0]->[1], 1);

    $result = graphinfo('testbox', 'PING', ['ping']);
    $file = $FindBin::Bin . '/testbox/PING___ping.rrd';
    skip(! -f $file, $result->[0]->{file}, 'testbox/PING___ping.rrd');
    skip(! -f $file, $result->[0]->{line}->{rta}, 1);
}

sub testgetlineattr {
    # test individual line attribute options
    $Config{plotas} = 'LINE1';
    $Config{plotasLINE1} = {'avg5min' => 1, 'avg15min' => 1};
    $Config{plotasLINE2} = {'a' => 1};
    $Config{plotasLINE3} = {'b' => 1};
    $Config{plotasAREA} = {'ping' => 1};
    $Config{plotasTICK} = {'http' => 1};
    $Config{stack} = {'s' => 1};

    my ($linestyle, $linecolor, $stack) = getlineattr('foo');
    ok($linestyle, 'LINE1');
    ok($linecolor, '000399');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('ping');
    ok($linestyle, 'AREA');
    ok($linecolor, '990333');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('http');
    ok($linestyle, 'TICK');
    ok($linecolor, '000099');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('avg15min');
    ok($linestyle, 'LINE1');
    ok($linecolor, '6600FF');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('a');
    ok($linestyle, 'LINE2');
    ok($linecolor, 'CC00CC');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('b');
    ok($linestyle, 'LINE3');
    ok($linecolor, 'CC00FF');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('s');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'CC03CC');
    ok($stack, 1);

    # test basic lineformat behavior
    $Config{lineformat} = 'warn,LINE1,D0D050;crit,LINE2,D05050;total,AREA,dddddd88';
    listtodict('lineformat', q(;));
    ($linestyle, $linecolor, $stack) = getlineattr('warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('crit');
    ok($linestyle, 'LINE2');
    ok($linecolor, 'D05050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('total');
    ok($linestyle, 'AREA');
    ok($linecolor, 'dddddd88');
    ok($stack, 0);

    # test various combinations and permutations
    $Config{lineformat} = 'warn,LINE1,D0D050;crit,D05050,LINE2;total,STACK,AREA,dddddd88';
    listtodict('lineformat', q(;));
    ($linestyle, $linecolor, $stack) = getlineattr('warn');
    ok($linestyle, 'LINE1');
    ok($linecolor, 'D0D050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('crit');
    ok($linestyle, 'LINE2');
    ok($linecolor, 'D05050');
    ok($stack, 0);
    ($linestyle, $linecolor, $stack) = getlineattr('total');
    ok($linestyle, 'AREA');
    ok($linecolor, 'dddddd88');
    ok($stack, 1);

    $Config{plotas} = 'LINE2';
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
          600
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
          600
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
          600,";

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
    $Config{negate}{rta} = 1;
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
          600
        ];\n");
    undef $Config{negate};

    # test min/max options

    # FIXME: get make listtodict more obvious (no side effects)
    # FIXME: use 'maximums' and 'maximumshash' rather than replacing 'maximums'
    #        same for all the other stuff replaced by listtodict.
    $Config{maximums} = 'Current Load,PLW,Procs: total,Procs: zombie,User Count';
    $Config{maximums} = listtodict('maximums', q(,));
    $Config{minimums} = 'APCUPSD,Mem: free,Mem: swap';
    $Config{minimums} = listtodict('minimums', q(,));
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
          600
        ];\n");
    undef $Config{minimums};
    undef $Config{maximums};
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
          600
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
          600
        ];\n");

#FIXME: test rrdopts

    teardownrrd();
    undef %Config;
}

sub testgetserverlist {
    my $allhosts = "\$VAR1 = {
  'hostserv' => {
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
    },
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
    'host2' => {
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
    }
  },
  'host' => [
    'host0',
    'host1',
    'host2',
    'host3',
    'host4',
    'host5'
  ]
};\n";

    my $somehosts = "\$VAR1 = {
  'hostserv' => {
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
    },
    'host0' => {
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
    'host1' => {
      'HTTP' => [
        [
          'http',
          'Bps'
        ]
      ]
    }
  },
  'host' => [
    'host0',
    'host1',
    'host2',
    'host3',
    'host4',
    'host5'
  ]
};\n";

    setuprrd();
    setuphsdata();
    my $rrddir = gettestrrddir();

    my %result = getserverlist();
    my $dd = Data::Dumper->new([\%result]);
    $dd->Indent(1);
    ok($dd->Dump, $allhosts);

    %result = getserverlist('');
    $dd = Data::Dumper->new([\%result]);
    $dd->Indent(1);
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
    ok($dd->Dump, $somehosts);

    undef %authz;
    teardownrrd();
    teardownhsdata();
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
    $result = printmenudatascript(\@servers, \%servers);
    ok($result, "");

    # when we have javascript, we should have menudata
    $Config{javascript} = 'foo';
    $result = printmenudatascript(\@servers, \%servers);
    ok($result, "<script type=\"text/javascript\">
menudata = new Array();
menudata[0] = [\"host0\"
 ,[\"HTTP\",[\"http\",\"Bps\"]]
 ,[\"PING\",[\"ping\",\"losspct\",\"rta\"]]
];
menudata[1] = [\"host1\"
 ,[\"HTTP\",[\"http\",\"Bps\"]]
];
menudata[2] = [\"host2\"
 ,[\"PING\",[\"ping\",\"losspct\",\"rta\"]]
];
menudata[3] = [\"host3\"
 ,[\"ping\",[\"loss\",\"losscrit\",\"losspct\",\"losswarn\"],[\"rta\",\"rta\",\"rtacrit\",\"rtawarn\"]]
];
menudata[4] = [\"host4\"
 ,[\"c:\\\\ space\",[\"ntdisk\",\"total\",\"used\"]]
];
menudata[5] = [\"host5\"
 ,[\"ntdisk\",[\"c:\\\\ space\",\"total\",\"used\"]]
];
</script>
");

    teardownrrd();
    teardownhsdata();
}

sub testgraphsizes {
	$Config{debug} = 0;
	open $LOG, '+>', \$log;
	@result = graphsizes(''); # defaults
	ok($result[0][0], 'day');
	ok($result[1][2], 604800);
	@result = graphsizes('year month quarter'); # comes back in length order
	ok($result[0][0], 'month');
	ok($result[1][2], 7776000);
	@result = graphsizes('test junk week'); # only returns week
	ok(@result, 1);
	close $LOG;
	$Config{debug} = 0;
}

sub testreadperfdata {
    @testdata = ('1221495633||testbox||HTTP||CRITICAL - Socket timeout after 10 seconds||',
                 '1221495690||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||losspct: 0%, rta: 37.06'
                 );
    my $fn = $FindBin::Bin . '/perfdata.log';
    # a test without data
    open $LOG, ">$fn";
    close $LOG;
    @result = readperfdata($fn);
    ok(@result, 0);
    # a test with data
    open $LOG, ">$fn";
    foreach $ii (@testdata) {
        print $LOG "$ii\n";
    }
    close $LOG;
    @result = readperfdata($fn);
    chomp $result[0];
    ok($result[0], $testdata[0]);
    chomp $result[1];
    ok($result[1], $testdata[1]);
    unlink $fn;
}

sub testgetrras {
	@testdata = (1, 2, 3, 4);
	# $Config{maximums}
	@result = main::getrras('Current Load', \@testdata);
	ok(Dumper(\@result), "\$VAR1 = [
          'RRA:MAX:0.5:1:1',
          'RRA:MAX:0.5:6:2',
          'RRA:MAX:0.5:24:3',
          'RRA:MAX:0.5:288:4'
        ];\n");
	# $Config{minimums}
	@result = main::getrras('APCUPSD', \@testdata);
	ok(Dumper(\@result), "\$VAR1 = [
          'RRA:MIN:0.5:1:1',
          'RRA:MIN:0.5:6:2',
          'RRA:MIN:0.5:24:3',
          'RRA:MIN:0.5:288:4'
        ];\n");
	# default
	@result = main::getrras('other value', \@testdata);
	ok(Dumper(\@result), "\$VAR1 = [
          'RRA:AVERAGE:0.5:1:1',
          'RRA:AVERAGE:0.5:6:2',
          'RRA:AVERAGE:0.5:24:3',
          'RRA:AVERAGE:0.5:288:4'
        ];\n");
}

sub testcheckdatasources {
	$Config{debug} = 0;
	open $LOG, '+>', \$log;
	$result = checkdatasources([0], 'test', [0], 'junk');
	ok($result, 1);
	$result = checkdatasources([0,1,2], 'test', [0, 1], 'junk');
	ok($result, 1);
	$result = checkdatasources([0,1,2], 'test', [0], 'junk');
	ok($result, 0);
	close $LOG;
	$Config{debug} = 0;
}

sub testcreaterrd {
    $Config{debug} = 0;
    open $LOG, '+>', \$log;
    $Config{rrddir} = $FindBin::Bin;
    # test creation of a separate file for specific data
    $Config{dbseparator} = '';
    $testvar = ['procs', ['users', 'GAUGE', 1], ['uwarn', 'GAUGE', 5] ];
    $Config{hostservvar} = 'testbox,procs,users';
    $Config{hostservvarsep} = ';';
    $Config{hostservvar} = listtodict('hostservvar');
    ok($Config{hostservvar}->{testbox}->{procs}->{users}, 1);
    @result = createrrd('testbox', 'procs', 1221495632, $testvar);
    ok($result[0]->[1], 'testbox_procsusers_procs.rrd');
    ok(-f $FindBin::Bin . '/testbox_procsusers_procs.rrd');
    ok(-f $FindBin::Bin . '/testbox_procs_procs.rrd');
    # test creation of a default data file
    $Config{dbseparator} = 'subdir';
    $testvar = ['ping', ['losspct', 'GAUGE', 0], ['rta', 'GAUGE', .006] ];
    @result = createrrd('testbox', 'PING', 1221495632, $testvar);
    ok($result[0]->[0], 'PING___ping.rrd');
    ok($result[1]->[0]->[0], 0);
    ok($result[1]->[0]->[1], 1);
    close $LOG;
    $Config{debug} = 0;
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
}

sub testmkvname {
    ok(mkvname('ping','loss'), 'ping_loss');
    ok(mkvname('ping','loss%20pct'), 'ping_loss_20pct');
    ok(mkvname('0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789','abcdefghijklmnopqrstuvwxyz'), '0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789_abcd');
    ok(mkvname('a-b','r_s,'), 'a-b_r_s_');
}

sub testrrdupdate { # depends on testcreaterrd making a file
	$Config{debug} = 0;
	open $LOG, '+>', \$log;
#	dumpdata($log, \@result, 'result');
	rrdupdate($result[0]->[0], 1221495635, $testvar, 'testbox', $result[1]->[0]);
	skip(! -f $FindBin::Bin . '/testbox/PING___ping.rrd', $log, "");
	close $LOG;
#	dumpdata($log, \@result, 'result');
	$Config{debug} = 0;
}

sub testgetrules {
	$Config{debug} = 0;
	open $LOG, '+>', \$log;
	getrules("$FindBin::Bin/../etc/map");
	ok($log, "");
	ok(*evalrules);
	close $LOG;
}

sub testprocessdata { # depends on testcreaterdd and testgetrules
	$Config{debug} = 0;
	open $LOG, '+>', \$log;
	my @perfdata = ('1221495636||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||losspct: 0%, rta: 37.06');
	processdata(@perfdata);
	skip(! -f $FindBin::Bin . '/testbox/PING___ping.rrd', $log, "");
	close $LOG;
	system 'rm -rf ' . $FindBin::Bin . '/testbox';
	unlink $FindBin::Bin . '/testbox_procs_procs.rrd';
    unlink $FindBin::Bin . '/testbox_procsusers_procs.rrd';
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

    my $cwd = $FindBin::Bin;

    undef %i18n;
    $ENV{HTTP_ACCEPT_LANGUAGE} = '';
    my $errstr = readi18nfile();
    ok($errstr, 'Cannot determine language');

    $errstr = readi18nfile('bogus');
    ok($errstr, "No translations for 'bogus' ($cwd/../etc/nagiosgraph_bogus.conf)");

    $errstr = readi18nfile('en');
    ok($errstr, "");

    undef %i18n;
    $ENV{HTTP_ACCEPT_LANGUAGE} = 'es-mx,es';
    $errstr = readi18nfile();
    ok($errstr, "");
    ok(_('Day'), 'Diario');

    undef %i18n;
    $ENV{HTTP_ACCEPT_LANGUAGE} = 'es_mx,es';
    $errstr = readi18nfile();
    ok($errstr, "");
    ok(_('Day'), 'Diario');

    undef %i18n;
    $Config{language} = 'es';
    $errstr = readi18nfile();
    ok($errstr, "");
    ok(_('Day'), 'Diario');
    ok(_('Week'), 'Semanal');
    ok(_('Month'), 'Mensual');
    ok(_('Quarter'), 'Trimestral');
    ok(_('Year'), 'Anual');

    undef %i18n;
    $Config{language} = 'fr';
    $errstr = readi18nfile();
    ok($errstr, "");
    ok(_('Day'), 'Jour');
    ok(_('Week'), 'Semaine');
    ok(_('Month'), 'Mois');
    ok(_('Quarter'), 'Trimestre');
    ok(_('Year'), 'Ann&#233;e');

    undef %i18n;
    $Config{language} = 'de';
    $errstr = readi18nfile();
    ok($errstr, "");
    ok(_('Day'), 'Tag');
    ok(_('Week'), 'Woche');
    ok(_('Month'), 'Monat');
    ok(_('Quarter'), 'Quartal');
    ok(_('Year'), 'Jahr');

    undef %i18n;
    undef $Config{language};
}

sub testprinti18nscript {
    undef $Config{javascript};
    $result = printi18nscript();
    ok($result, "");

    $Config{javascript} = 'foo';
    $result = printi18nscript();
    ok($result, "<script type=\"text/javascript\">
var i18n = {
  \"Jan\": 'Jan',
  \"Feb\": 'Feb',
  \"Mar\": 'Mar',
  \"Apr\": 'Apr',
  \"May\": 'May',
  \"Jun\": 'Jun',
  \"Jul\": 'Jul',
  \"Aug\": 'Aug',
  \"Sep\": 'Sep',
  \"Oct\": 'Oct',
  \"Nov\": 'Nov',
  \"Dec\": 'Dec',
  \"Mon\": 'Mon',
  \"Tue\": 'Tue',
  \"Wed\": 'Wed',
  \"Thu\": 'Thu',
  \"Fri\": 'Fri',
  \"Sat\": 'Sat',
  \"Sun\": 'Sun',
  \"OK\": 'OK',
  \"Now\": 'Now',
  \"Cancel\": 'Cancel',
  \"now\": 'now',
  \"graph data\": 'graph data',
};
</script>
");

    $Config{language} = 'es';
    undef %i18n;
    $Config{language} = 'es';
    my $errstr = readi18nfile();
    ok($errstr, "");
    $result = printi18nscript();
    ok($result, "<script type=\"text/javascript\">
var i18n = {
  \"Jan\": 'Enero',
  \"Feb\": 'Febrero',
  \"Mar\": 'Marzo',
  \"Apr\": 'Abril',
  \"May\": 'Mai',
  \"Jun\": 'Junio',
  \"Jul\": 'Julio',
  \"Aug\": 'Augosto',
  \"Sep\": 'Septiembre',
  \"Oct\": 'Octubre',
  \"Nov\": 'Noviembre',
  \"Dec\": 'Diciembre',
  \"Mon\": 'Lun',
  \"Tue\": 'Mar',
  \"Wed\": 'Mie',
  \"Thu\": 'Jue',
  \"Fri\": 'Vie',
  \"Sat\": 'Sab',
  \"Sun\": 'Dom',
  \"OK\": 'OK',
  \"Now\": 'Ahora',
  \"Cancel\": 'Cancelar',
  \"now\": 'now',
  \"graph data\": 'datos del gr&#241;fico',
};
</script>
");

    undef %i18n;
    undef $Config{language};
}

sub testinitperiods {
    $Config{debug} = 0;
    open $LOG, '+>', \$log;

    # ensure we get values from opts
    my %opts = ('period', 'day week month', 'expand_period', 'month year');
    my ($a,$b) = initperiods('both', \%opts);
    ok($a, 'day,week,month');
    ok($b, 'month,year');
    %opts = ('period', 'day week', 'expand_period', 'day month');
    ($a,$b) = initperiods('all', \%opts);
    ok($a, 'day,week');
    ok($b, 'day,month');
    ($a,$b) = initperiods('host', \%opts);
    ok($a, 'day,week');
    ok($b, 'day,month');
    ($a,$b) = initperiods('service', \%opts);
    ok($a, 'day,week');
    ok($b, 'day,month');
    ($a,$b) = initperiods('group', \%opts);
    ok($a, 'day,week');
    ok($b, 'day,month');

    # ensure we get values from config
    $Config{timeall} = 'month,year';
    $Config{expand_timeall} = 'day';
    %opts = ('period', '', 'expand_period', '');
    ($a,$b) = initperiods('all', \%opts);
    ok($a, 'month,year');
    ok($b, 'day');

    # ensure values from opts override those from config
    $Config{timeall} = 'month,year';
    $Config{expand_timeall} = 'day';
    %opts = ('period', 'day', 'expand_period', 'month');
    ($a,$b) = initperiods('all', \%opts);
    ok($a, 'day');
    ok($b, 'month');
    
    close $LOG;
    $Config{debug} = 0;
}

sub testparsedb {
    $Config{debug} = 0;
    open $LOG, '+>', \$log;

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

    close $LOG;
    $Config{debug} = 0;
}

# ensure that we unescape properly anything that is thrown at us
sub testcleanline {
    my $ostr = cleanline('&db=ping,rta&label=Real+Time Astronaut');
    ok($ostr, '&db=ping,rta&label=Real Time Astronaut');

    $ostr = cleanline('&db=ping,rta&label=Real%20Time%20Astronaut');
    ok($ostr, '&db=ping,rta&label=Real Time Astronaut');
}

sub testgetcfgfn {
    my $cwd = $FindBin::Bin;
    my $fn = getcfgfn('/home/file.txt');
    ok($fn, "/home/file.txt");
    $fn = getcfgfn('file.txt');
    ok($fn, "$cwd/../etc/file.txt");
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

    my $fn = "$FindBin::Bin/db.conf";
    my $rrddir = gettestrrddir();
    $Config{hostdb} = $fn;

    # nothing when nothing in file
    open TEST, ">$fn";
    print TEST "\n";
    close TEST;
    $result = readhostdb();
    ok(@{$result}, 0);

    # nothing when bogus file contents
    open TEST, ">$fn";
    print TEST "servicio=7up\n";
    close TEST;
    $result = readhostdb();
    ok(@{$result}, 0);

    # specify ping service with ping db
    open TEST, ">$fn";
    print TEST "#this is a comment\n";
    print TEST "service=PING&db=ping\n";
    close TEST;

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
    open TEST, ">$fn";
    print TEST "  service=ping&db=rta\n";
    print TEST "service=PING&db=ping\n";
    print TEST " host=host1\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=ping&db=rta\n";
    print TEST "service=ping&db=loss\n";
    print TEST "service=PING&db=ping\n";
    print TEST "service=PING&db=ping,rta\n";
    print TEST "service=PING&db=ping,losspct\n";
    close TEST;

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
    open TEST, ">$fn";
    print TEST "service=PING&db=foo\n";
    close TEST;

    # this host should not match anything
    $result = readhostdb('host2');
    ok(@{$result}, 0);


    # test multiple data sources per line
    open TEST, ">$fn";
    print TEST "service=ping&db=rta&db=loss\n";
    print TEST "service=PING&db=ping,losspct&db=ping,rta\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING&db=ping\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,rta\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING&db=rta\n";
    close TEST;
    $result = readhostdb('host2');
    ok(@{$result}, 0);
    ok(Dumper($result), "\$VAR1 = [];\n");
    # bogus data source should result in no match
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,bogus\n";
    close TEST;
    $result = readhostdb('host2');
    ok(@{$result}, 0);
    ok(Dumper($result), "\$VAR1 = [];\n");

    
    # test multiple data sets alternative syntax
    open TEST, ">$fn";
    print TEST "service=ping&db=loss,losspct,losswarn&db=rta,rtawarn,rtacrit\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=ping&label=PING&db=rta&db=loss\n";
    print TEST "service=PING&label=PINGIT&db=ping,losspct&db=ping,rta\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING&db=ping&label=Ping Loss Percentage\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,losspct&label=Ping Loss Percentage\n";
    close TEST;
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
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,losspct&label=LP&db=ping,rta&label=RTA\n";
    close TEST;
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

    my $fn = "$FindBin::Bin/db.conf";
    $Config{servdb} = $fn;

    # when nothing in file, use defaults

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

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
    open TEST, ">$fn";
    print TEST "  host=host0\n";
    print TEST "service=service1\n";
    print TEST " host=  host1\n";
    close TEST;
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");

    open TEST, ">$fn";
    print TEST "#this is a comment\n";
    print TEST "host=host0\n";
    print TEST "host=host1\n";
    print TEST "host=host2\n";
    print TEST "host=host3\n";
    print TEST "host=host4\n";
    print TEST "host=host5\n";
    close TEST;

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

    open TEST, ">$fn";
    print TEST "host=host0,host1\n";
    close TEST;
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host1'
        ];\n");
    open TEST, ">$fn";
    print TEST "host=host1,host0\n";
    close TEST;
    $result = readservdb('HTTP');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host1',
          'host0'
        ];\n");

    # verify specialized requests

    open TEST, ">$fn";
    print TEST "host=host0,host1\n";
    close TEST;
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
}

sub testreadgroupdb {
    setuprrd();
    setupauthhosts();

    my $fn = "$FindBin::Bin/db.conf";
    my $rrddir = gettestrrddir();
    $Config{groupdb} = $fn;

    # nothing when nothing in file
    open TEST, ">$fn";
    print TEST "\n";
    close TEST;
    my ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 0);

    # skip bogus lines
    open TEST, ">$fn";
    print TEST "#this is a comment\n";
    print TEST "backup\n";
    print TEST "backup=host\n";
    print TEST "PING=\n";
    close TEST;
    ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 0);

    # test scan for defaults
    open TEST, ">$fn";
    print TEST "#this is a comment\n";
    print TEST "PING=host0,PING\n";
    print TEST "PING=host2,PING&db=ping,losspct\n";
    print TEST "PING=host3,PING\n";
    close TEST;
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

    open TEST, ">$fn";
    print TEST "#this is a comment\n";
    print TEST "PING=host1,PING&db=ping,rta\n";
    print TEST "PING=host1,PING&db=ping,losspct\n";
    print TEST "PING=host2,PING&db=ping,losspct\n";
    print TEST "PING=host3,PING&db=ping,losspct\n";
    print TEST "PING=host4,PING&db=ping,rta\n";
    print TEST "PING=host4,PING&db=ping,losspct\n";
    print TEST "PING=host5,PING&db=ping,losspct\n";
    print TEST "Web Servers=host0,PING&db=ping,losspct\n";
    print TEST "Web Servers=host0,HTTP&db=http\n";
    print TEST "Web Servers=host1,PING&db=ping,losspct\n";
    print TEST "Web Servers=host1,HTTP&db=http\n";
    print TEST "Web Servers=host5,PING&db=ping,losspct\n";
    print TEST "Web Servers=host5,HTTP&db=http\n";
    close TEST;

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

    open TEST, ">$fn";
    print TEST "PING=host3,ping&db=loss,losspct,losscrit,losswarn&db=rta,rtacrit\n";
    close TEST;
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

    open TEST, ">$fn";
    print TEST "PING=host0,PING&label=PING RTA&db=ping,rta\n";
    print TEST "PING=host0,PING&db=ping,losspct&label=LOSSY\n";
    close TEST;

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

    my $fn = "$FindBin::Bin/db.conf";
    $Config{datasetdb} = $fn;

    # nothing when nothing in file
    open TEST, ">$fn";
    print TEST "\n";
    close TEST;
    $result = readdatasetdb();
    ok(keys %{$result}, 0);

    # bogus lines should be ignored
    open TEST, ">$fn";
    print TEST "service=\n";
    print TEST "  service = ping&db=rta\n";
    print TEST "host\n";
    close TEST;
    $result = readdatasetdb();
    ok(keys %{$result}, 1);

    open TEST, ">$fn";
    print TEST "#this is a comment\n";
    print TEST "service=PING&db=ping,rta\n";
    print TEST "service=net&db=bytes-received&db=bytes-transmitted\n";
    close TEST;

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

    open TEST, ">$fn";
    print TEST "service=PING&db=ping,rta\n";
    print TEST "service=PING&db=ping,loss\n";
    close TEST;

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
}

sub testreadrrdoptsfile {
    # do nothing if file not defined
    undef $Config{rrdoptsfile};
    my $errstr = readrrdoptsfile();
    ok($errstr, "");

    my $fn = "$FindBin::Bin/db.conf";
    $Config{rrdoptsfile} = $fn;

    undef $Config{rrdoptshash};
    $Config{rrdoptshash}{global} = q();
    $errstr = readrrdoptsfile();
    ok($errstr, "cannot open $fn: No such file or directory");
    ok(Dumper($Config{rrdoptshash}), "\$VAR1 = {
          'global' => ''
        };
");

    open TEST, ">$fn";
    print TEST "ping=-u 1 -l 0\n";
    print TEST "ntp=-A\n";
    close TEST;

    undef $Config{rrdoptshash};
    $Config{rrdoptshash}{global} = q();
    $errstr = readrrdoptsfile();
    ok($errstr, "");
    ok(Dumper($Config{rrdoptshash}), "\$VAR1 = {
          'ntp' => '-A',
          'ping' => '-u 1 -l 0',
          'global' => ''
        };
");

    undef $Config{rrdoptshash};
    unlink $fn;
}

sub testreadlabelsfile {
    undef %Labels;
    my $errstr = readlabelsfile();
    ok($errstr, "");

    my $fn = "$FindBin::Bin/db.conf";
    $Config{labelfile} = $fn;

    undef %Labels;
    $errstr = readlabelsfile();
    ok($errstr, "cannot open $fn: No such file or directory");
    ok(Dumper(\%Labels), "\$VAR1 = {};\n");

    open TEST, ">$fn";
    print TEST "ping=PING\n";
    close TEST;

    undef %Labels;
    $errstr = readlabelsfile();
    ok($errstr, "");
    ok(Dumper(\%Labels), "\$VAR1 = {
          'ping' => 'PING'
        };
");

    unlink $fn;
}

# build hash from rrd files in a single directory
sub testscandirectory {
    my $rrddir = 'testrrddir';
    mkdir($rrddir, 0755);

    undef %hsdata;
    $_ = '..';
    scandirectory();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = $rrddir;
    mkdir($_, 0755);
    scandirectory();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = $rrddir . '/test1.rrd';
    open TMP, ">$_";
    print TMP "test1\n";
    close TMP;
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {};\n");
    $_ = $rrddir . '/host0_ping_rta.rrd';
    open TMP, ">$_";
    print TMP "test1\n";
    close TMP;
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {
          'testrrddir/host0' => {
                                  'ping' => [
                                              'rta'
                                            ]
                                }
        };
");
    $_ = $rrddir . '/host1_ping_rta.rrd';
    open TMP, ">$_";
    print TMP "test1\n";
    close TMP;
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
        };
");

    undef %hsdata;
    $_ = $rrddir . '/host0_ping_Round%20Trip%20Average.rrd';
    open TMP, ">$_";
    print TMP "test1\n";
    close TMP;
    scandirectory();
    ok(Dumper(\%hsdata), "\$VAR1 = {
          'testrrddir/host0' => {
                                  'ping' => [
                                              'Round Trip Average'
                                            ]
                                }
        };
");

    undef %hsdata;
    rmtree($rrddir);
}

# build hash from rrd files in a directory hierarchy
sub testscanhierarchy {
    undef %hsdata;
    $_ = '..';
    scanhierarchy();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = 'test';
    mkdir($_, 0755);
    scanhierarchy();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = 'test/test1';
    open TMP, ">$_";
    print TMP "test1\n";
    close TMP;
    scanhierarchy();
    ok(%hsdata, 0, 'Nothing should be set yet');
    $_ = 'test';
    scanhierarchy();
    ok(Dumper($hsdata{$_}), qr'{}');
    $_ = 'test/test1.rrd';
    open TMP, ">$_";
    print TMP "test1\n";
    close TMP;
    $File::Find::dir = $FindBin::Bin;
    scanhierarchy();
    ok($hsdata{$FindBin::Bin}{'test/test1.rrd'}[0], undef);
    unlink 'test/test1';
    unlink 'test/test1.rrd';
    rmdir 'test';
    undef %hsdata;
}

# ensure that scanning host/service data works.  do it with both subdir and
# old style configurations.
sub testscanhsdata {
    setuprrd('subdir');
    undef %hsdata;
    scanhsdata();
    ok(printdata(\%hsdata), "\$VAR1 = {
  'host4' => {
    'c:\\\\ space' => [
      'ntdisk'
    ]
  },
  'host0' => {
    'HTTP' => [
      'http'
    ],
    'PING' => [
      'ping'
    ]
  },
  'host5' => {
    'ntdisk' => [
      'c:\\\\ space'
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
  'host1' => {
    'HTTP' => [
      'http'
    ]
  }
};
");
    undef %hsdata;
    teardownrrd();

    setuprrd('_');
    undef %hsdata;
    scanhsdata();
    ok(printdata(\%hsdata), "\$VAR1 = {
  'host4' => {
    'c:\\\\ space' => [
      'ntdisk'
    ]
  },
  'host5' => {
    'ntdisk' => [
      'c:\\\\ space'
    ]
  },
  'host0' => {
    'HTTP' => [
      'http'
    ],
    'PING' => [
      'ping'
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
  'host1' => {
    'HTTP' => [
      'http'
    ]
  }
};
");
    undef %hsdata;
    teardownrrd();
}

sub testgetstyle {
    $Config{stylesheet} = 'sheet.css';
    my @style = getstyle();
    ok(Dumper(\@style), "\$VAR1 = [
          '-style',
          {
            '-src' => 'sheet.css'
          }
        ];
");
    undef $Config{stylesheet};
    @style = getstyle();
    ok(Dumper(\@style), "\$VAR1 = [];\n");
}

sub testgetrefresh {
    $Config{refresh} = 500;
    my @refresh = getrefresh();
    ok(Dumper(\@refresh), "\$VAR1 = [
          '-http_equiv',
          'Refresh',
          '-content',
          '500'
        ];
");
    undef $Config{refresh};
    @refresh = getrefresh();
    ok(Dumper(\@refresh), "\$VAR1 = [];\n");
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
    ok($s, "15:10 25 Feb - 00:10 27 Feb");
    $s = getperiodlabel($n, $o, $p, 'week');
    ok($s, "25 Feb - 27 Feb");
    $s = getperiodlabel($n, $o, $p, 'month');
    ok($s, "week 08 - week 08");
    $s = getperiodlabel($n, $o, $p, 'quarter');
    ok($s, "week 08 - week 08");
    $s = getperiodlabel($n, $o, $p, 'year');
    ok($s, "Feb 2010 - Feb 2010");

    $o = 172_800;
    $s = getperiodlabel($n, $o, $p, 'day');
    ok($s, "15:10 24 Feb - 00:10 26 Feb");
    $o = 86_400;
    $p = 8_467_200;
    $s = getperiodlabel($n, $o, $p, 'day');
    ok($s, "00:10 21 Nov - 00:10 27 Feb");
}

sub testformattime {
    my $t = 1267333859; # Sun Feb 28 00:10:59 2010
    $Config{timeformat_day} = '%H:%M %e %b';
    my $s = formattime($t, 'timeformat_day');
    ok($s, "00:10 28 Feb");
    $s = formattime($t, 'bogus');
    ok($s, "Sun Feb 28 00:10:59 2010");
}

sub testcheckrrddir {
    my $cwd = $FindBin::Bin;
    my $a = $cwd . '/parent';
    my $b = $a . '/rrd';

    $Config{rrddir} = $b;

    rmtree($a);
    mkdir $a, 0770;
    my $msg = checkrrddir('write');
    ok($msg, "");

    rmtree($a);
    mkdir $a, 0770;
    mkdir $b, 0550;
    $msg = checkrrddir('write');
    ok($msg, "");

    rmtree($a);
    $msg = checkrrddir('write');
    ok($msg, "Cannot create rrd directory: No such file or directory");

    rmtree($a);
    $msg = checkrrddir('read');
    ok($msg, "Cannot read rrd directory $cwd/parent/rrd");

    mkdir $a, 0770;
    mkdir $b, 0770;
    $msg = checkrrddir('read');
    ok($msg, "No data in rrd directory $cwd/parent/rrd");

    my $fn = $b . '/file.rrd';
    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

    $msg = checkrrddir('read');
    ok($msg, "");

    rmtree($a);
}

sub testgetlabel {
    ok(getlabel('foo'), 'foo');
    $Labels{foo} = 'bar';
    ok(getlabel('foo'), 'bar');
    undef $Labels{foo};
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
}

sub testgethsdmatch {
    $Config{hsdlist} = str2list('host0,ping=10;host5,http=30');
    my $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '50');
    $Config{hsd} = 100;
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '100');
    $Config{hsdlist} = str2list('host1,ping=10;host5,http=30');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');

    # test matching precedence - should be last match
    $Config{hsd} = 100;
    $Config{hsdlist} = str2list('.*,.*=30');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,ping=30');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,PING=30');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '100');
    $Config{hsdlist} = str2list('host1,ping=10;.*,.*=30');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,.*=30;host1,ping=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');
    $Config{hsdlist} = str2list('.*,.*=30;host1,.*=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');
    $Config{hsdlist} = str2list('.*,.*=30;.*,ping=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');

    # test database
    $Config{hsdlist} = str2list('.*,.*,delay=30;.*,ping,loss=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '100');
    $Config{hsdlist} = str2list('.*,.*,rta=30;.*,ping,loss=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');
    $Config{hsdlist} = str2list('.*,.*,rta=30;.*,ping,rta=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '10');
    $Config{hsdlist} = str2list('host1,.*,rta=30;.*,ping,RTA=10');
    $x = gethsdmatch('hsd', 50, 'host1', 'ping', 'rta');
    ok($x, '30');

    undef $Config{hsd};
    undef $Config{hsdlist};
}




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
teststr2hash();
teststr2list();
testarrayorstring();
testcheckdirempty();
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
testrrdupdate(); # must be run after createrrd
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
testgethsdmatch();
