#!/usr/bin/perl

use Test::More;

eval "use Test::Pod 1.00";

plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

all_pod_files_ok(qw(cgi/showgraph.cgi cgi/show.cgi cgi/showhost.cgi
                    cgi/showservice.cgi cgi/showgroup.cgi cgi/testcolor.cgi
                    lib/insert.pl utils/testentry.pl utils/upgrade.pl));
