#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../etc";
use strict;
use CGI qw/:standard/;
use Data::Dumper;
use File::Find;
use Test;
use ngshared;
my ($result, @result, $testvar, @testdata, %testdata, $ii);

BEGIN {
    plan tests => 52;
}

# test the debug logger
open LOG, '+>', \$result;
$Config{debug} = 1;
debug(0, "test message");
ok($result, qr/02ngshared.t none - test message$/);
close LOG;
open LOG, '+>', \$result;
debug(2, "test no message");
ok($result, "");
close LOG;

# test the list/hash output debugger
open LOG, '+>', \$result;
$testvar = 'test';
dumper(0, 'test', \$testvar);
ok($result, qr/02ngshared.t none - .test = .'test';$/);
close LOG;
open LOG, '+>', \$result;
$testvar = ['test'];
dumper(0, 'test', $testvar);
ok($result, qr/02ngshared.t none - .test = \[\s+'test'\s+\];$/s);
close LOG;
open LOG, '+>', \$result;
$testvar = {test => 1};
dumper(0, 'test', $testvar);
ok($result, qr/02ngshared.t none - .test = \{\s+'test' => 1\s+\};$/s);
close LOG;
open LOG, '+>', \$result;
dumper(2, 'test', $testvar);
ok($result, '');
close LOG;
$Config{debug} = 0;

# Test encoding a URL and the decoding it
%testdata = ('http://wiki.nagiosgraph.sourceforge.net/' => 'http%3A%2F%2Fwiki%2Enagiosgraph%2Esourceforge%2Enet%2F',
	'Partition: /' => 'Partition%3A%20%2F');
foreach $ii (keys %testdata) {
	$result = urlencode($ii);
	ok($result, $testdata{$ii});
	$result = urldecode($result);
	ok($result, $ii);
}

# Make rrddir where we run from, since the 'subdir' configuration wants to
# create missing subdirectories
$Config{rrddir} = $FindBin::Bin;
$Config{dbseparator} = '';
@result = getfilename('testbox', 'Partition: /');
ok($result[0], $FindBin::Bin);
ok($result[1], 'testbox_Partition%3A%20%2F_');
@result = getfilename('testbox', 'Partition: /', 'diskgb');
ok($result[0], $FindBin::Bin);
ok($result[1], 'testbox_Partition%3A%20%2F_diskgb.rrd');
$Config{dbseparator} = 'subdir';
@result = getfilename('testbox', 'Partition: /');
ok($result[0], $FindBin::Bin . '/testbox');
ok($result[1], 'Partition%3A%20%2F___');
@result = getfilename('testbox', 'Partition: /', 'diskgb');
ok($result[0], $FindBin::Bin . '/testbox');
ok($result[1], 'Partition%3A%20%2F___diskgb.rrd');
ok(-d $result[0]);
rmdir $result[0] if -d $result[0];

# We can't really test HTMLerror, since it just prints to STDOUT.
# I tried this:
#open SAVEOUT, ">&STDOUT";
#open STDOUT, '+>', \$result;
#HTMLerror('test');
#ok($result, '');
#close STDOUT;
#open STDOUT, ">&SAVEOUT";

# Test hashcolor with 16 generated colors, the default rainbow and one custom.
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
$Config{color} = ['123', 'ABC'];
@testdata = ('123', 'ABC', '123');
for ($ii = 0; $ii < 3; $ii++) {
	$result = hashcolor('test', 9);
	ok($result, $testdata[$ii]);
}

# getgraphlist does two things, verifies directores and .rrd files
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
ok($Navmenu{$_}{NAME}, 'test');
$_ = 'test/test1.rrd';
open TMP, ">$_";
print TMP "test1\n";
close TMP;
$File::Find::dir = $FindBin::Bin;
getgraphlist();
ok(Dumper($Navmenu{$FindBin::Bin}{SERVICES}), qr"'test/test1.rrd' => \\1"); 
unlink 'test/test1';
unlink 'test/test1.rrd';
rmdir 'test';

# listtodict splits a string separated by a configured value into hash
$Config{testsep} = ',';
$Config{test} = 'Current Load,PLW,Procs: total,User Count';
$testvar = listtodict('test');
foreach $ii ('Current Load','PLW','Procs: total','User Count') {
	ok($testvar->{$ii});
}

# Test checkdir with an empty directory, then one with a file in it.
mkdir 'checkdir', 0770;
ok(checkdirempty('checkdir') == 1);
open TMP, '>checkdir/tmp';
print TMP "test\n";
close TMP;
ok(checkdirempty('checkdir') == 0);
unlink 'checkdir/tmp';
rmdir 'checkdir';

# Check the default configuration
open LOG, '+>', \$result;
readconfig('read');
ok($Config{colorscheme}, 9);
ok($Config{minimums}{'Mem: free'});
skip(-r $Config{rrddir} and checkdirempty($Config{rrddir}),
	$Config{ngshared}); # This gets sets when the default rrddir doesn't exist.
close LOG;
