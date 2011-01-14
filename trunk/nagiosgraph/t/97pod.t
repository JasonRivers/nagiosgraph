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

my $rc = eval 'use Test::Pod 1.00;';
plan skip_all => 'Test::Pod 1.00 required for testing POD' if $@;

all_pod_files_ok(qw(install.pl
                    cgi/show.cgi
                    cgi/showconfig.cgi
                    cgi/showgraph.cgi
                    cgi/showgroup.cgi
                    cgi/showhost.cgi
                    cgi/showservice.cgi
                    cgi/testcolor.cgi
                    etc/ngshared.pm
                    lib/insert.pl
                    utils/testentry.pl
                    utils/upgrade.pl));
