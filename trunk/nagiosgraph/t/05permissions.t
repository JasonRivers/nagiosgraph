#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

use strict;
use FindBin;
use Data::Dumper;
use lib "$FindBin::Bin/../etc";
use ngshared;
use Test;

BEGIN { plan tests => 112; }

sub testcheckuserlist {
    ok(checkuserlist('bill,bob,nancy'), 0);
    ok(checkuserlist('bill fred'), 1);
    ok(checkuserlist('bill*'), 0);
    ok(checkuserlist('jane.user'), 0);
    ok(checkuserlist('*.user'), 0);
    ok(checkuserlist('!bill'), 0);
}

sub testscrubuserlist {
    ok(scrubuserlist('bill,bob, nancy'), 'bill,bob,nancy');
    ok(scrubuserlist(' bill  , bob, nancy'), 'bill,bob,nancy');
    ok(scrubuserlist('bill,bob fred,nancy'), 'bill,bobfred,nancy');
    ok(scrubuserlist('bob,!bill, ! nancy'), 'bob,!bill,!nancy');
}

sub testgetperms {
    $Config{debug} = 5;
    my $fn = 'matches.txt';
    open $LOG, '>', $fn;

    ok(getperms('guest', 'guest'), 1);
    ok(getperms('guest', '*'), 1);
    ok(getperms('guest', '.*'), undef);
    ok(getperms('guest', 'guestlist'), undef);
    ok(getperms('guest', 'guest*'), 1);
    ok(getperms('guest', 'guest.*'), undef);
    ok(getperms('guest', 'admin,guest'), 1);
    ok(getperms('guest', 'g*,d*'), 1);
    ok(getperms('guest', 'b*,g*'), 1);
    ok(getperms('guest', 'g*t'), 1);
    ok(getperms('guest', 'g*s'), undef);
    ok(getperms('guest', 'guests'), undef);
    ok(getperms('guest', 'g'), undef);
    ok(getperms('guest', ''), 0); # same as !*
    ok(getperms('guest', '!guest'), 0);
    ok(getperms('guest', '!*'), 0);
    ok(getperms('guest', '!gu*'), 0);
    ok(getperms('guest', '*,!guest'), 0);
    ok(getperms('guest', '!guest,*'), 1);
    ok(getperms('guest', 'bill,!guest'), 0);
    ok(getperms('guest', '!guest,bill'), 0);

    ok(getperms('jane.user', '*'), 1);
    ok(getperms('jane.user', '*.user'), 1);
    ok(getperms('jane.user', 'jane.*'), 1);
    ok(getperms('jane.user', 'jane.us*'), 1);

    ok(getperms('guest', '!!!'), undef);
    ok(getperms('guest', '*.*'), undef);

    # we check the patterns, so these should not happen.  but do it just to
    # be sure the error handling works properly.
    ok(getperms('guest', '???'), 0);

    close $LOG;
    $Config{debug} = 0;
    unlink $fn;
}

sub testhavepermission {
    # grant permission when no authz is defined
    ok(havepermission(), 1);
    ok(havepermission('', ''), 1);
    ok(havepermission('host0', ''), 1);
    ok(havepermission('', 'service0'), 1);
    ok(havepermission('host0', 'service0'), 1);

    # deny permission when default is closed to everyone
    $authz{default_host_access}{default_service_access} = 0;
    ok(havepermission(), 0);
    ok(havepermission('', ''), 0);
    ok(havepermission('host0', ''), 0);
    ok(havepermission('', 'service0'), 0);
    ok(havepermission('host0', 'service0'), 0);

    # grant permission when default is open to everyone
    $authz{default_host_access}{default_service_access} = 1;
    ok(havepermission(), 1);
    ok(havepermission('', ''), 1);
    ok(havepermission('host0', ''), 1);
    ok(havepermission('', 'service0'), 1);
    ok(havepermission('host0', 'service0'), 1);

    # now test for various configurations

    undef %authz;
    $authz{default_host_access}{default_service_access} = 0;
    $authz{host0} = {'ping' => 1, 'http' => 0};
    ok(havepermission('host0', 'ping'), 1);
    ok(havepermission('host0', 'http'), 0);
    ok(havepermission('host0', 'ntp'), 0);
    ok(havepermission('host1', 'ping'), 0);
    ok(havepermission('host1', 'http'), 0);
    ok(havepermission('host1', 'ntp'), 0);

    undef %authz;
    $authz{default_host_access}{default_service_access} = 1;
    $authz{host0} = {'ping' => 1, 'http' => 0};
    ok(havepermission('host0', 'ping'), 1);
    ok(havepermission('host0', 'http'), 0);
    ok(havepermission('host0', 'ntp'), 1);
    ok(havepermission('host1', 'ping'), 1);
    ok(havepermission('host1', 'http'), 1);
    ok(havepermission('host1', 'ntp'), 1);

    undef %authz;
    $authz{default_host_access}{default_service_access} = 0;
    $authz{default_host_access}{ping} = 1;
    ok(havepermission('host0', 'ping'), 1);
    ok(havepermission('host0', 'http'), 0);
    ok(havepermission('host0', 'ntp'), 0);
    ok(havepermission('host1', 'ping'), 1);
    ok(havepermission('host1', 'http'), 0);
    ok(havepermission('host1', 'ntp'), 0);
}

sub testloadperms {
    my $cwd = $FindBin::Bin;

    my $errmsg = loadperms('guest');
    ok($errmsg, '');

    $Config{authzmethod} = 'bogus';
    $errmsg = loadperms('guest');
    ok($errmsg, 'unknown authzmethod \'bogus\'');

    $Config{authzmethod} = 'nagios3';
    $errmsg = loadperms('guest');
    ok($errmsg, '');

    $Config{authzmethod} = 'nagiosgraph';
    $errmsg = loadperms('guest');
    ok($errmsg, 'authzfile is not defined');
    $Config{authzfile} = 'boo';
    $errmsg = loadperms('guest');
    ok($errmsg, "cannot open $cwd/../etc/boo: No such file or directory");

    undef $Config{authzmethod};
    undef $Config{authzfile};
}

sub testreadpermsfile {
    my $cwd = $FindBin::Bin;

    # no access control file defined

    undef $Config{authzfile};
    my $errmsg = readpermsfile();
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    $Config{authzfile} = '';
    $errmsg = readpermsfile();
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    # file does not exist

    $Config{authzfile} = 'foobar';
    $errmsg = readpermsfile();
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    $Config{authzfile} = 'foobar';
    $errmsg = readpermsfile('');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    $Config{authzfile} = 'foobar';
    $errmsg = readpermsfile('guest');
    ok($errmsg, "cannot open $cwd/../etc/foobar: No such file or directory");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # now read some valid files

    my $fn = "$FindBin::Bin/testaccess.conf";
    $Config{authzfile} = $fn;

    # empty file

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # deny access to everyone

    open TEST, ">$fn";
    print TEST "*=\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # grant access to everyone

    open TEST, ">$fn";
    print TEST "*=*\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # the order matters, use whatever defined last

    open TEST, ">$fn";
    print TEST "*=*\n";
    print TEST "*=\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    open TEST, ">$fn";
    print TEST "*=\n";
    print TEST "*=*\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # guest for everything, but no one else

    open TEST, ">$fn";
    print TEST "*=\n";
    print TEST "*=guest\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");
    $errmsg = readpermsfile('someone');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # guest has some access, admin has all, everyone else has none

    open TEST, ">$fn";
    print TEST "*=\n";
    print TEST "*=admin\n";
    print TEST "host0=guest\n";
    print TEST "#host1=admin\n";
    print TEST "#host2=admin\n";
    print TEST "host2,ping=guest\n";
    print TEST "host3=guest\n";
    print TEST "host3,http=!guest\n";
    print TEST "host4,*=*\n";
    print TEST "host4,*=!guest\n";
    close TEST;
    $errmsg = readpermsfile('admin');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'host4' => {
                       'default_service_access' => 1
                     },
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'host4' => {
                       'default_service_access' => 0
                     },
          'host0' => {
                       'default_service_access' => 1
                     },
          'host3' => {
                       'http' => 0,
                       'default_service_access' => 1
                     },
          'host2' => {
                       'ping' => 1
                     },
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $errmsg = readpermsfile('someone');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'host4' => {
                       'default_service_access' => 1
                     },
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # exclusion specializes wildcard

    open TEST, ">$fn";
    print TEST "*=*,!guest\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # trailing wildcard overrides previous exclusion

    open TEST, ">$fn";
    print TEST "*=!guest,*\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # granular grant

    open TEST, ">$fn";
    print TEST "*=\n";
    print TEST "*,ping=guest\n";
    close TEST;
    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'ping' => 1,
                                     'default_service_access' => 0
                                   }
        };\n");

    unlink $fn;
    undef $Config{authzfile};
    undef %authz;
}

# FIXME: test the nagios permissions
sub testreadnagiosperms {
}



testcheckuserlist();
testscrubuserlist();
testgetperms();
testhavepermission();
testloadperms();
testreadpermsfile();
testreadnagiosperms();
