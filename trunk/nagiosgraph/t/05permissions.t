#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

## no critic (RequireUseWarnings)
## no critic (ProhibitImplicitNewlines)
## no critic (ProhibitMagicNumbers)
## no critic (RequireBriefOpen)
## no critic (ProhibitEmptyQuotes)
## no critic (ProhibitQuotedWordLists)
## no critic (ProhibitNoisyQuotes)

use FindBin;
use Test;
use strict;

BEGIN {
## no critic (ProhibitStringyEval)
## no critic (ProhibitPunctuationVars)
    my $rc = eval "
        require RRDs; RRDs->import();
        use Carp;
        use Data::Dumper;
        use English qw(-no_match_vars);
        use lib \"$FindBin::Bin/../etc\";
        use ngshared;
    ";
    if ($@) {
        plan tests => 0;
        exit 0;
    } else {
        plan tests => 178;
    }
}

sub writefile {
    my ($fn, @data) = @_;
    open my $TEST, '>', $fn or carp "open $fn failed; $OS_ERROR";
    foreach my $line (@data) {
        print ${TEST} $line . "\n" or carp "print failed: $OS_ERROR";
    }
    close $TEST or carp "close $fn failed: $OS_ERROR";
    return;
}

sub testcheckuserlist {
    ok(checkuserlist('bill,bob,nancy'), 0);
    ok(checkuserlist('bill fred'), 1);
    ok(checkuserlist('bill*'), 0);
    ok(checkuserlist('jane.user'), 0);
    ok(checkuserlist('*.user'), 0);
    ok(checkuserlist('!bill'), 0);
    return;
}

sub testscrubuserlist {
    ok(scrubuserlist('bill,bob, nancy'), 'bill,bob,nancy');
    ok(scrubuserlist(' bill  , bob, nancy'), 'bill,bob,nancy');
    ok(scrubuserlist('bill,bob fred,nancy'), 'bill,bobfred,nancy');
    ok(scrubuserlist('bob,!bill, ! nancy'), 'bob,!bill,!nancy');
    return;
}

sub testgetperms {
    $Config{debug} = 5;
    my $fn = 'matches.txt';
    open $LOG, '>', $fn or carp "open LOG failed: $OS_ERROR";

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

    close $LOG or carp "close LOG failed: $OS_ERROR";
    $Config{debug} = 0;
    unlink $fn;
    return;
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

    return;
}

# this does the baseline testing for error messages and resulting permission.
# detailed tests for nagios and nagiosgraph configurations are done in
# separate test methods.
sub testloadperms {
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
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $Config{authzfile} = 'boo';
    $errmsg = loadperms('guest');
    ok($errmsg, 'cannot open nagios config boo: No such file or directory');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    my $fn = "$FindBin::Bin/test_cgi.cfg";
    $Config{authzfile} = $fn;

    # authentication disabled in nagios

    writefile($fn, ('use_authentication=0'));
    $errmsg = loadperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    # authentication enabled in nagios

    writefile($fn, ('use_authentication=1'));
    $errmsg = loadperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # nagiosgraph access control

    $Config{authzmethod} = 'nagiosgraph';
    undef $Config{authzfile};
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
    ok($errmsg, "cannot open access control file $FindBin::Bin/../etc/boo: No such file or directory");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    undef $Config{authzmethod};
    undef $Config{authzfile};
    unlink $fn;

    return;
}

sub testreadnagiosperms {
    my $fn = "$FindBin::Bin/test_cgi.cfg";

    writefile($fn, ('use_authentication=1',
                    'default_user_name=admin'));

    # no config file defined

    undef $Config{authzfile};
    my $errmsg = readnagiosperms('guest');
    ok($errmsg, 'authzfile is not defined');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # valid config file

    $Config{authzfile} = $fn;
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # file does not exist

    $Config{authzfile} = 'foobar';
    $errmsg = readnagiosperms('guest');
    ok($errmsg, 'cannot open nagios config foobar: No such file or directory');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    $Config{authzfile} = $fn;

    # authentication disabled

    writefile($fn, ('use_authentication=0',
                    'default_user_name=admin'));
    $errmsg = readnagiosperms('admin');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    # authentication enabled

    writefile($fn, ('use_authentication=1',
                    'default_user_name=admin'));
    $errmsg = readnagiosperms('admin');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # guest is default user

    writefile($fn, ('use_authentication=1',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('admin');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # guest has host access

    writefile($fn, ('use_authentication=1',
                    'authorized_for_all_hosts=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('use_authentication=1',
                    'authorized_for_all_hosts=bill, bob , guest , nancy'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('use_authentication=1',
                    'authorized_for_all_hosts=bill, bob , nancy'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # guest has service access

    writefile($fn, ('use_authentication=1',
                    'authorized_for_all_services=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('use_authentication=1',
                    'authorized_for_all_services=  jane, guest,bill'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('use_authentication=1',
                    'authorized_for_all_services=  jane,bill'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # check config file formatting

    writefile($fn, ('#comments should be ignored',
                    'other parameters should be ignored',
                    'default_user_name=guest',
                    '#comments should be ignored',
                    'other parameters should be ignored',
                    'use_authentication=1'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # ignore anything non 0 or 1
    writefile($fn, ('use_authentication=false',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('use_authentication=true',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('bogus_use_authentication=1',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('bogus_use_authentication=0',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    writefile($fn, ('  use_authentication=0',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    writefile($fn, ('use_authentication   =0',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    writefile($fn, ('use_authentication   =   0',
                    'default_user_name=guest'));
    $errmsg = readnagiosperms('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {};\n");

    # clean up

    undef $Config{authzfile};
    unlink $fn;

    return;
}

sub testreadpermsfile {
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
    ok($errmsg, "cannot open access control file $FindBin::Bin/../etc/foobar: No such file or directory");
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # now read some valid files

    my $fn = "$FindBin::Bin/testaccess.conf";
    $Config{authzfile} = $fn;
    writefile($fn, ("\n"));

    # no user

    $errmsg = readpermsfile();
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # empty user

    $errmsg = readpermsfile('');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # valid user but empty file

    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # bogus userlist

    writefile($fn, ('*=bill & ted'));

    $errmsg = readpermsfile('bill');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # deny access to everyone

    writefile($fn, ('*='));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # grant access to everyone

    writefile($fn, ('*=*'));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # the order matters, use whatever defined last

    writefile($fn, ('*=*', '*='));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    writefile($fn, ('*=', '*=*'));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # guest for everything, but no one else

    writefile($fn, ('*=', '*=guest'));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");
    $errmsg = readpermsfile('someone');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # guest has some access, admin has all, everyone else has none

    writefile($fn, ('*=',
                    '*=admin',
                    'host0=guest',
                    '#host1=admin',
                    '#host2=admin',
                    'host2,ping=guest',
                    'host3=guest',
                    'host3,http=!guest',
                    'host4,*=*',
                    'host4,*=!guest'));
    $errmsg = readpermsfile('admin');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'host4' => {
                       'default_service_access' => 1
                     },
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
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
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'host4' => {
                       'default_service_access' => 1
                     },
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # exclusion specializes wildcard

    writefile($fn, ('*=*,!guest'));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 0
                                   }
        };\n");

    # trailing wildcard overrides previous exclusion

    writefile($fn, ('*=!guest,*'));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'default_service_access' => 1
                                   }
        };\n");

    # granular grant

    writefile($fn, ('*=', '*,ping=guest'));
    $errmsg = readpermsfile('guest');
    ok($errmsg, '');
    ok(Dumper(\%authz), "\$VAR1 = {
          'default_host_access' => {
                                     'ping' => 1,
                                     'default_service_access' => 0
                                   }
        };\n");

    unlink $fn;
    undef $Config{authzfile};
    undef %authz;

    return;
}




testcheckuserlist();
testscrubuserlist();
testgetperms();
testhavepermission();
testloadperms();
testreadpermsfile();
testreadnagiosperms();
