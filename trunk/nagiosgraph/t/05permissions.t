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
use Test;
use lib "$FindBin::Bin/../etc";
use ngshared;

BEGIN { plan tests => 148; }

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

    undef %authz;
    $authz{default_host_access}{default_service_access} = 0;
    $authz{host0} = {'default_service_access' => 1, 'ping' => 0};
    ok(havepermission('host0', 'ping'), 0);
    ok(havepermission('host0', 'http'), 1);
    ok(havepermission('host1', 'ping'), 0);
}

# this does the baseline testing for error messages and resulting permission.
# detailed tests for nagios and nagiosgraph configurations are done in
# separate test methods.
sub testloadperms {
    my $cwd = $FindBin::Bin;
    undef %authz;

    my $errmsg = loadperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    $Config{authzmethod} = 'bogus';
    $errmsg = loadperms('guest');
    ok($errmsg, 'unknown authzmethod \'bogus\'');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    # nagios access control

    $Config{authzmethod} = 'nagios3';
    $errmsg = loadperms('');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $errmsg = loadperms('guest');
    ok($errmsg, 'authz_nagios_cfg is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $Config{authz_nagios_cfg} = 'boo';
    $errmsg = loadperms('guest');
    ok($errmsg, 'cannot open nagios config boo: No such file or directory');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    my $fn1 = "$FindBin::Bin/test_nagios.cfg";
    my $fn2 = "$FindBin::Bin/test_cgi.cfg";
    $Config{authz_nagios_cfg} = $fn1;

    # authentication disabled in nagios

    open TEST, ">$fn1";
    print TEST "use_authentication=0\n";
    close TEST;

    $errmsg = loadperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    open TEST, ">$fn1";
    print TEST "use_authentication=1\n";
    close TEST;

    $errmsg = loadperms('guest');
    ok($errmsg, 'authz_cgi_cfg is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    $Config{authz_cgi_cfg} = 'boo';
    $errmsg = loadperms('guest');
    ok($errmsg, 'cannot open nagios cgi config boo: No such file or directory');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    open TEST, ">$fn2";
    print TEST "\n";
    close TEST;

    $Config{authz_cgi_cfg} = $fn2;
    $errmsg = loadperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # nagiosgraph access control

    $Config{authzmethod} = 'nagiosgraph';
    $errmsg = loadperms('');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $errmsg = loadperms('guest');
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $Config{authzfile} = 'boo';
    $errmsg = loadperms('guest');
    ok($errmsg, "cannot open access control file $cwd/../etc/boo: No such file or directory");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    undef $Config{authzmethod};
    undef $Config{authzfile};
    undef $Config{authz_nagios_cfg};
    undef $Config{authz_cgi_cfg};
    unlink $fn1;
    unlink $fn2;
}

sub testreadnagiosperms {
    my $fn1 = "$FindBin::Bin/test_nagios.cfg";
    my $fn2 = "$FindBin::Bin/test_cgi.cfg";
    $Config{authz_nagios_cfg} = $fn1;
    $Config{authz_cgi_cfg} = $fn2;

    open TEST, ">$fn1";
    print TEST "#nagios config\n";
    print TEST "random junk should be ignored for the tests";
    print TEST "use_authentication=1\n";
    close TEST;

    # admin is default user

    open TEST, ">$fn2";
    print TEST "default_user_name=admin\n";
    close TEST;
    my $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # guest is default user

    open TEST, ">$fn2";
    print TEST "default_user_name=guest\n";
    close TEST;
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # guest has host access

    open TEST, ">$fn2";
    print TEST "#nagios config\n";
    print TEST "random junk should be ignored for the tests";
    print TEST "authorized_for_all_hosts=guest\n";
    close TEST;
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    open TEST, ">$fn2";
    print TEST "authorized_for_all_hosts=bill, bob , guest , nancy\n";
    close TEST;
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # guest has service access

    open TEST, ">$fn2";
    print TEST "#nagios config\n";
    print TEST "random junk should be ignored for the tests";
    print TEST "authorized_for_all_services=guest\n";
    close TEST;
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    open TEST, ">$fn2";
    print TEST "authorized_for_all_hosts=  jane, guest,bill\n";
    close TEST;
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    undef $Config{authz_nagios_cfg};
    undef $Config{authz_cgi_cfg};
    unlink $fn1;
    unlink $fn2;
}

sub testreadpermsfile {
    my $cwd = $FindBin::Bin;

    # no access control file defined

    undef $Config{authzfile};
    my $errmsg = readpermsfile('guest');
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    $Config{authzfile} = '';
    $errmsg = readpermsfile('guest');
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # file does not exist

    $Config{authzfile} = 'foobar';
    $errmsg = readpermsfile('guest');
    ok($errmsg, "cannot open access control file $cwd/../etc/foobar: No such file or directory");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # now read some valid files

    my $fn = "$FindBin::Bin/testaccess.conf";
    $Config{authzfile} = $fn;

    open TEST, ">$fn";
    print TEST "\n";
    close TEST;

    # no user

    $errmsg = readpermsfile();
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # empty user

    $errmsg = readpermsfile('');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # valid user but empty file

    $errmsg = readpermsfile('guest');
    ok($errmsg, "");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # bogus userlist

    open TEST, ">$fn";
    print TEST "*=bill & ted\n";
    close TEST;

    $errmsg = readpermsfile('bill');
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




testcheckuserlist();
testscrubuserlist();
testgetperms();
testhavepermission();
testloadperms();
testreadpermsfile();
testreadnagiosperms();
