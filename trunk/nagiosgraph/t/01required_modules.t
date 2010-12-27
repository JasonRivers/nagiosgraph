#!/usr/bin/perl

use strict;
use Test::More tests => 2;

eval { require RRDs; };
ok(! $@, 'check for RRDs (required)');

SKIP: {
    eval { require GD; };
    skip 'GD is not installed', 1 if $@;
    my $img = new GD::Image(5,5);
    isa_ok($img, "GD::Image");
}
