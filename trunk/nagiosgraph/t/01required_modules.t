#!/usr/bin/perl

use strict;
use Test::More tests => 2;

eval { require RRDs; };
ok(! $@, 'check for RRDs (required)');

eval { require GD; };
ok(! $@, 'check for GD (optional)');
