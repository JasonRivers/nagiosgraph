#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Matthew Wall, 2010

use strict;
use Test::More tests => 4;
use File::Temp qw(tempfile);

eval { require RRDs; };
ok(! $@, 'check for required module RRDs');
if (! $@) {
    my ($fh,$fn) = tempfile();
    RRDs::create("$fn","-s 60",
                 "DS:temp:GAUGE:600:0:100",
                 "RRA:AVERAGE:0.5:1:576",
                 "RRA:AVERAGE:0.5:6:672",
                 "RRA:AVERAGE:0.5:24:732",
                 "RRA:AVERAGE:0.5:144:1460");
    ok(-f $fn, 'create RRD file');
    RRDs::update("$fn", "-t", "temp", "N:50");
    ok(-f $fn, 'update RRD file');
    unlink($fn);
}

SKIP: {
    eval { require GD; };
    skip 'GD is not installed', 1 if $@;
    my $img = new GD::Image(5,5);
    isa_ok($img, "GD::Image");
}
