#!/usr/bin/perl

use strict;
use Test::More tests => 2;

print "# Checking for RRDs\n";
eval { require RRDs; };
ok(! $@, "check for RRDs (required)");

print "# Checking for GD (optional)\n";
eval { require GD; };
ok(! $@, "check for GD (optional)");
