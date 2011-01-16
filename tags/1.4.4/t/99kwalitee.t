#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

## no critic (RequireUseWarnings)
## no critic (ProhibitStringyEval)
## no critic (ProhibitPunctuationVars)
## no critic (ProhibitPostfixControls)

use Test::More;
use strict;

my $rc = eval 'require Test::Kwalitee; Test::Kwalitee->import();';
plan skip_all => 'Test::Kwalitee not installed' if $@;
