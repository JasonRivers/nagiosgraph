#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

use strict;
use FindBin;
use Test;

BEGIN { plan tests => 1; }

my $cgidir = $FindBin::Bin . '/../cgi';
my $result = `$cgidir/show.cgi`;
#ok($result, "");   
