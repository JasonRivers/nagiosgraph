#!/usr/bin/perl

use strict;
use Test;

BEGIN { plan tests => 1 }

print "# Checking for RRDs\n";
eval {
    require RRDs;
};
ok(! $@);
