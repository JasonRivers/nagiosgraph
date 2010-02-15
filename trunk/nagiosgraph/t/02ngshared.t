#!/usr/bin/perl
use FindBin;
use strict;
use CGI qw(:standard escape unescape);
use Data::Dumper;
use File::Find;
use Test;
use lib "$FindBin::Bin/../etc";
use ngshared;
my ($log, $result, @result, $testvar, @testdata, %testdata, $ii);

BEGIN { plan tests => 197; }

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

sub testmkfilename { # Test getting the file and directory for a database.
	# Make rrddir where we run from, since the 'subdir' configuration wants to
	# create missing subdirectories
	$Config{rrddir} = $FindBin::Bin;
	$Config{dbseparator} = '';
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
	ok(-d $result[0]);
	rmdir $result[0] if -d $result[0];
}

sub testhtmlerror { # We can't really test htmlerror, since it just prints to STDOUT.
	# I tried this:
	#open SAVEOUT, ">&STDOUT";
	#open STDOUT, '+>', \$log;
	#htmlerror('test');
	#ok($result, '');
	#close STDOUT;
	#open STDOUT, ">&SAVEOUT";
}

sub testhashcolor { # With 16 generated colors, the default rainbow and one custom.
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
    my $cwd = $FindBin::Bin;

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

sub testreadconfig { # Check the default configuration
	open $LOG, '+>', \$log;
	readconfig('read');
	ok($Config{colorscheme}, 1);
	ok($Config{minimums}{'Mem: free'});
	close $LOG;
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

sub testgetlabels {
    $result = getlabels('diskgb', 'test,junk');
    ok($result->[0], 'Disk Usage in Gigabytes');
    $result = getlabels('testing', 'tested,Mem%3A%20swap,junk');
    ok($result->[0], 'Swap Utilization');
}

sub testrrdline {
    setuprrd();

    # test a minimal invocation with no data for the host
    my %params = qw(host host30 service ping);
    my @ds = rrdline(\%params);
    ok(Dumper(\@ds), "\$VAR1 = [
          '-',
          '-a',
          'PNG',
          '-s',
          'now-118800',
          '-e',
          'now-0',
          '-w',
          600
        ];\n");

    # minimal invocation when data exist for the host
    %params = qw(host host0 service PING);
    @ds = rrdline(\%params);
    ok(Dumper(\@ds), "\$VAR1 = [
          '-',
          '-a',
          'PNG',
          '-s',
          'now-118800',
          '-e',
          'now-0',
          'DEF:losspct=/home/src/nagiosgraph/t/host0/PING___ping.rrd:losspct:AVERAGE',
          'LINE2:losspct#9900FF:losspct',
          'GPRINT:losspct:MAX:Max\\\\: %6.2lf%s',
          'GPRINT:losspct:AVERAGE:Avg\\\\: %6.2lf%s',
          'GPRINT:losspct:MIN:Min\\\\: %6.2lf%s',
          'GPRINT:losspct:LAST:Cur\\\\: %6.2lf%s\\\\n',
          'DEF:rta=/home/src/nagiosgraph/t/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:rta#CC03CC:rta    ',
          'GPRINT:rta:MAX:Max\\\\: %6.2lf%s',
          'GPRINT:rta:AVERAGE:Avg\\\\: %6.2lf%s',
          'GPRINT:rta:MIN:Min\\\\: %6.2lf%s',
          'GPRINT:rta:LAST:Cur\\\\: %6.2lf%s\\\\n',
          '-w',
          600
        ];\n");

    # specify a bogus data set
    $params{db} = ['rta'];
    @ds = rrdline(\%params);
    ok(Dumper(\@ds), "\$VAR1 = [
          '-',
          '-a',
          'PNG',
          '-s',
          'now-118800',
          '-e',
          'now-0',
          '-w',
          600
        ];\n");

    # specify a valid data set
    $params{db} = ['ping,rta'];
    @ds = rrdline(\%params);
    ok(Dumper(\@ds), "\$VAR1 = [
          '-',
          '-a',
          'PNG',
          '-s',
          'now-118800',
          '-e',
          'now-0',
          'DEF:rta=/home/src/nagiosgraph/t/host0/PING___ping.rrd:rta:AVERAGE',
          'LINE2:rta#CC03CC:rta',
          'GPRINT:rta:MAX:Max\\\\: %6.2lf%s',
          'GPRINT:rta:AVERAGE:Avg\\\\: %6.2lf%s',
          'GPRINT:rta:MIN:Min\\\\: %6.2lf%s',
          'GPRINT:rta:LAST:Cur\\\\: %6.2lf%s\\\\n',
          '-w',
          600
        ];\n");

#FIXME: test geom
#FIXME: test rrdopts
#FIXME: test altautoscale
#FIXME: test altautoscalemin
#FIXME: test altautoscalemax
#FIXME: test nogridfit
#FIXME: test logarithmic
}

sub testgetgraphlist { # Does two things: verifies directores and .rrd files.
	$_ = '..';
	getgraphlist();
	ok(%Navmenu, 0, 'Nothing should be set yet');
	$_ = 'test';
	mkdir($_, 0755);
	getgraphlist();
	ok(%Navmenu, 0, 'Nothing should be set yet');
	$_ = 'test/test1';
	open TMP, ">$_";
	print TMP "test1\n";
	close TMP;
	getgraphlist();
	ok(%Navmenu, 0, 'Nothing should be set yet');
	$_ = 'test';
	getgraphlist();
	ok(Dumper($Navmenu{$_}), qr'{}');
	$_ = 'test/test1.rrd';
	open TMP, ">$_";
	print TMP "test1\n";
	close TMP;
	$File::Find::dir = $FindBin::Bin;
	getgraphlist();
	ok($Navmenu{$FindBin::Bin}{'test/test1.rrd'}[0], undef);
	unlink 'test/test1';
	unlink 'test/test1.rrd';
	rmdir 'test';
}

sub testprintNavMenu { # printNavMenu is like htmlerror--not really testable.
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

sub testinputdata {
	@testdata = (
		'1221495633||testbox||HTTP||CRITICAL - Socket timeout after 10 seconds||',
		'1221495690||testbox||PING||PING OK - Packet loss = 0%, RTA = 37.06 ms ||losspct: 0%, rta: 37.06'
	);
	# $ARGV[0] array input test, which will only be one line of data
	$ARGV[0] = $testdata[1];
	@result = main::inputdata();
	ok(Dumper($result[0]), Dumper($testdata[1]));
	$Config{perflog} = $FindBin::Bin . '/perfdata.log';
	# a test without data
	delete $ARGV[0];
	open $LOG, ">$Config{perflog}";
	close $LOG;
	@result = main::inputdata();
	ok(@result, 0);
	# $Config{perflog} input test
	open $LOG, ">$Config{perflog}";
	foreach $ii (@testdata) {
		print $LOG "$ii\n";
	}
	close $LOG;
	@result = main::inputdata();
	chomp $result[0];
	ok($result[0], $testdata[0]);
	chomp $result[1];
	ok($result[1], $testdata[1]);
	unlink $Config{perflog};
}

sub testgetrras {
	@testdata = (1, 2, 3, 4);
	# $Config{maximums}
	@result = main::getrras('Current Load', \@testdata);
	ok(Dumper(\@result), "\$VAR1 = [\n          'RRA:MAX:0.5:1:1',\n          'RRA:MAX:0.5:6:2',\n          'RRA:MAX:0.5:24:3',\n          'RRA:MAX:0.5:288:4'\n        ];\n");
	# $Config{minimums}
	@result = main::getrras('APCUPSD', \@testdata);
	ok(Dumper(\@result), "\$VAR1 = [\n          'RRA:MIN:0.5:1:1',\n          'RRA:MIN:0.5:6:2',\n          'RRA:MIN:0.5:24:3',\n          'RRA:MIN:0.5:288:4'\n        ];\n");
	# default
	@result = main::getrras('other value', \@testdata);
	ok(Dumper(\@result), "\$VAR1 = [\n          'RRA:AVERAGE:0.5:1:1',\n          'RRA:AVERAGE:0.5:6:2',\n          'RRA:AVERAGE:0.5:24:3',\n          'RRA:AVERAGE:0.5:288:4'\n        ];\n");
}

sub testruncreate {				# runcreate tested as part of createrrd
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

sub testrunupdate {				# like runcreate, it doesn't do much
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

sub testtrans {
    $Config{debug} = 0;
    open $LOG, '+>', \$log;
    ok(trans('day'), 'Today');
    ok(trans('daily'), 'Daily');
    ok(trans('week'), 'This Week');
    ok(trans('weekly'), 'Weekly');
    ok(trans('month'), 'This Month');
    ok(trans('monthly'), 'Monthly');
    ok(trans('year'), 'This Year');
    ok(trans('yearly'), 'Yearly');
    close $LOG;
    $Config{debug} = 0;
}

sub testinitperiods {
    $Config{debug} = 0;
    open $LOG, '+>', \$log;

    # ensure we get values from opts
    my %opts = ('period', 'day week month', 'expand_period', 'month year');
    my ($a,$b) = initperiods('all', \%opts);
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
    my ($name, @db) = parsedb($str);
    ok($name, 'ping');
    ok(Dumper(\@db), "\$VAR1 = [
          'ping,rta'
        ];\n");

    # two data sources
    $str = '&db=ping,rta&db=ping,loss';
    ($name, @db) = parsedb($str);
    ok($name, 'ping');
    ok(Dumper(\@db), "\$VAR1 = [
          'ping,rta',
          'ping,loss'
        ];\n");

    # multiple data sources
    $str = '&db=ping,rta&db=ping,loss&db=ping,crit&db=ping,warn';
    ($name, @db) = parsedb($str);
    ok($name, 'ping');
    ok(Dumper(\@db), "\$VAR1 = [
          'ping,rta',
          'ping,loss',
          'ping,crit',
          'ping,warn'
        ];\n");

    close $LOG;
    $Config{debug} = 0;
}

sub testdbname {
    $Config{debug} = 0;
    open $LOG, '+>', \$log;

    # check the normal usage
    my @db = ('ping,rta', 'ping,loss');
    my $name = getdbname(@db);
    ok($name, 'ping');

    # verify behavior when datasets have different service name.
    @db = ('ping,rta', 'http,Bps');
    $name = getdbname(@db);
    ok($name, 'ping');
    
    close $LOG;
    $Config{debug} = 0;
}

# create rrd files used in the read*db tests
sub setuprrd {
    $Config{rrddir} = $FindBin::Bin;
    $Config{dbseparator} = 'subdir';

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
                ['rtapct', 'GAUGE', 0.01],
                ['rtawarn', 'GAUGE', 0.1],
                ['rtacrit', 'GAUGE', 0.5] ];
    @result = createrrd('host3', 'ping', 1221495632, $testvar);
}

sub testreadhostdb {
    setuprrd();

    my $fn = "$FindBin::Bin/db.conf";
    my $cwd = $FindBin::Bin;
    $Config{hostdb} = $fn;
    my $result;

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

    # nothing when nothing in file
    $result = readhostdb();
    ok(@{$result}, 0);

    open TEST, ">$fn";
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

    # for this host ensure we get only ping, not http
    $result = readhostdb('host0');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'filename' => '$cwd/host0/PING___ping.rrd',
            'db' => [
                      'ping'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host0'
          }
        ];\n");


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
            'filename' => '$cwd/host2/PING___ping.rrd',
            'db' => [
                      'ping'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host2'
          },
          {
            'filename' => '$cwd/host2/PING___ping.rrd',
            'db' => [
                      'ping,rta'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host2'
          },
          {
            'filename' => '$cwd/host2/PING___ping.rrd',
            'db' => [
                      'ping,losspct'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host2'
          }
        ];\n");

    $result = readhostdb('host3');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          {
            'filename' => '$cwd/host3/ping___rta.rrd',
            'db' => [
                      'rta'
                    ],
            'service' => 'ping',
            'dbname' => 'rta',
            'host' => 'host3'
          },
          {
            'filename' => '$cwd/host3/ping___loss.rrd',
            'db' => [
                      'loss'
                    ],
            'service' => 'ping',
            'dbname' => 'loss',
            'host' => 'host3'
          }
        ];\n");


    # valid service, bogus dataset
    open TEST, ">$fn";
    print TEST "service=PING&db=foo\n";
    close TEST;

    # this host should not match anything
    $result = readhostdb('host2');
    ok(@{$result}, 0);


    # test multiple datasets per line
    open TEST, ">$fn";
    print TEST "service=ping&db=rta&db=loss\n";
    print TEST "service=PING&db=ping,losspct&db=ping,rtapct\n";
    close TEST;

    $result = readhostdb('host2');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'filename' => '$cwd/host2/PING___ping.rrd',
            'db' => [
                      'ping,losspct',
                      'ping,rtapct'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host2'
          }
        ];\n");

    $result = readhostdb('host3');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'filename' => '$cwd/host3/ping___rta.rrd',
            'db' => [
                      'rta',
                      'loss'
                    ],
            'service' => 'ping',
            'dbname' => 'rta',
            'host' => 'host3'
          }
        ];\n");


    # test service labels parsing
    open TEST, ">$fn";
    print TEST "service=ping&label=PING Loss Percentage&db=loss\n";
    close TEST;

    $result = readhostdb('host3');
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          {
            'service_label' => 'PING Loss Percentage',
            'filename' => '$cwd/host3/ping___loss.rrd',
            'db' => [
                      'loss'
                    ],
            'service' => 'ping',
            'dbname' => 'loss',
            'host' => 'host3'
          }
        ];\n");


    #FIXME: do per-dataset labels

    # test dataset labels parsing
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,losspct&label=Loser\n";
    close TEST;


    # test for spaces in label names
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,rta&label=Real+Time Astronaut\n";
    print TEST "service=PING&db=ping,losspct&label=Loser\n";
    close TEST;


    # ensure that labels override those in cfg file
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,rta&label=Real+Time+Astronaut\n";
    print TEST "service=PING&db=ping,losspct&label=Loser\n";
    close TEST;


    # test labels for multiple data sets
    open TEST, ">$fn";
    print TEST "service=PING&db=ping,losspct&label=A&db=ping,rtapct&label=B\n";
    close TEST;

    unlink $fn;
}

sub testreadservdb {
    setuprrd();

    my $fn = "$FindBin::Bin/db.conf";
    $Config{servdb} = $fn;
    my $result;

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

    # nothing when nothing in file
    $result = readservdb('PING');
    ok(@{$result}, 0);

    open TEST, ">$fn";
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

    # check service/dataset pairs

    $result = readservdb('PING');
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host2'
        ];\n");

    $result = readservdb('PING', ['ping']);
    ok(@{$result}, 2);
    ok(Dumper($result), "\$VAR1 = [
          'host0',
          'host2'
        ];\n");

    $result = readservdb('ping', ['loss']);
    ok(@{$result}, 1);
    ok(Dumper($result), "\$VAR1 = [
          'host3'
        ];\n");

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

    unlink $fn;
}

sub testreadgroupdb {
    setuprrd();

    my $fn = "$FindBin::Bin/db.conf";
    my $cwd = $FindBin::Bin;
    $Config{groupdb} = $fn;
    my $names;
    my $infos;

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

    # nothing when nothing in file
    ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 0);

    open TEST, ">$fn";
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

    ($names,$infos) = readgroupdb('Web Servers');
    ok(@{$infos}, 3);
    ok(Dumper($infos), "\$VAR1 = [
          {
            'filename' => '$cwd/host0/PING___ping.rrd',
            'db' => [
                      'ping,losspct'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host0'
          },
          {
            'filename' => '$cwd/host0/HTTP___http.rrd',
            'db' => [
                      'http'
                    ],
            'service' => 'HTTP',
            'dbname' => 'http',
            'host' => 'host0'
          },
          {
            'filename' => '$cwd/host1/HTTP___http.rrd',
            'db' => [
                      'http'
                    ],
            'service' => 'HTTP',
            'dbname' => 'http',
            'host' => 'host1'
          }
        ];\n");


    # test labels
    open TEST, ">$fn";
    print TEST "PING=host0,PING&label=PING RTA&db=ping,rta\n";
    print TEST "PING=host0,PING&db=ping,losspct\n";
    close TEST;

    ($names,$infos) = readgroupdb('PING');
    ok(@{$names}, 1);
    ok(Dumper($names), "\$VAR1 = [
          'PING'
        ];\n");
    ok(Dumper($infos), "\$VAR1 = [
          {
            'service_label' => 'PING RTA',
            'filename' => '$cwd/host0/PING___ping.rrd',
            'db' => [
                      'ping,rta'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host0'
          },
          {
            'filename' => '$cwd/host0/PING___ping.rrd',
            'db' => [
                      'ping,losspct'
                    ],
            'service' => 'PING',
            'dbname' => 'ping',
            'host' => 'host0'
          }
        ];\n");

    unlink $fn;
}

sub testreaddatasetdb {
    setuprrd();

    my $fn = "$FindBin::Bin/db.conf";
    my $cwd = $FindBin::Bin;
    $Config{datasetdb} = $fn;
    my $result;

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

    # nothing when nothing in file
    $result = readdatasetdb();
    ok(keys %{$result}, 0);

    open TEST, ">$fn";
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
}

testdebug();
testdumper();
testgetdebug();
testmkfilename();
testhashcolor();
testgetgraphlist();
testlisttodict();
testcheckdirempty();
testreadfile();
testreadconfig();
testdbfilelist();
testgraphsizes();
testinputdata();
testgetrras();
testcheckdatasources();
testcreaterrd();
testrrdupdate(); # must be run after createrrd
testgetrules();
#testgetlabels();
testrrdline();
testgraphinfo();
testprocessdata();
testtrans();
testinitperiods();
testparsedb();
testdbname();
testreadhostdb();
testreadservdb();
testreadgroupdb();
testreaddatasetdb();
