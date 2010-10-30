#!/usr/bin/perl

# $Id: showhost.cgi 315 2010-03-04 02:15:41Z mwall $
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2010 Matthew Wall

## no critic (InputOutput::RequireCheckedSyscalls)
## no critic (Documentation::RequirePodSections)
## no critic (RegularExpressions)
## no critic (ProhibitPackageVars)

# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use English qw(-no_match_vars);
use strict;
use warnings;

emitheader();
#checkstyles();
checkmodules();
checkoptmodules();
checkng();
checkenv();
checkinc();
checkngconfig();
checkfiles();
checkdirs();
emitfooter();

exit 0;



sub emitheader {
    print <<"EOB";
Content-Type: text/html


<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
<head>
<title>nagiosgraph: configuration</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
<style type="text/css">
body {
  color: black;
  background-color: white;
  font-family: sans-serif, serif;
  font-weight: normal;
  font-size: 9pt;
}
h1 {
  font-size: 1.3em;
  padding-top: 0.25em;
}
h2 {
  font-size: 1.2em;
  padding-top: 0;
}
td {
  font-size: 9pt;
}
.listing {
  border: 1px solid #777777;
  background-color: #eeeeee;
  padding: 5px;
}
.ok {
  border: 1px solid #777777;
  background-color: #ffffff;
  padding: 5px;
}
.warning {
  border: 1px solid #777777;
  background-color: #ffff00;
  padding: 5px;
}
.critical {
  border: 1px solid #777777;
  background-color: #f88888;
  padding: 5px;
}
</style>
</head>
<body>
EOB
    return;
}

sub emitfooter {
    print '</body></html>' . "\n";
    return;
}

sub checkstyles {
    print "<p class='listing'>a<br>b<br>c<br></p>\n";
    print "<p class='ok'>a<br>b<br>c<br></p>\n";
    print "<p class='warning'>a<br>b<br>c<br></p>\n";
    print "<p class='critical'>a<br>b<br>c<br></p>\n";
    return;
}

sub checkenv {
    print "<h1>Environment</h1>\n";
    print "<div>\n";
    print "<pre class='listing'>\n";
    foreach my $i (sort keys %ENV) {
	print "$i=$ENV{$i}\n";
    }
    print "</div>\n";
    return;
}

sub checkinc {
    print "<h1>Include Paths</h1>\n";
    print "<div>\n";
    print "<pre class='listing'>\n";
    for my $i (@INC) {
        print $i . "\n";
    }
    print "</pre>\n";
    print "</div>\n";
    return;
}

sub checkmodule {
    my ($func, $optional) = @_;
    my $statusstr = 'not installed';
    my $status = $optional ? 'warning' : 'critical';
    my $rval = eval "{ require $func; }"; ## no critic (ProhibitStringyEval)
    if (defined $rval && $rval == 1) {
        $statusstr = $func->VERSION;
        $status = 'ok';
    }
    print '<tr><td class=' . "'$status'" . '> </td><td>' . $func . ': ' . $statusstr . '</td></tr>';
    return;
}

sub checkmodules {
    my $rval;
    print '<h1>PERL modules - required</h1>' . "\n";
    print '<div>' . "\n";
    print '<table>' . "\n";
    checkmodule('Carp');
    checkmodule('CGI');
    checkmodule('Data::Dumper');
    checkmodule('File::Basename');
    checkmodule('File::Find');
    checkmodule('MIME::Base64');
    checkmodule('POSIX');
    checkmodule('RRDs');
    checkmodule('Time::HiRes');
    print '</table>' . "\n";
    print '</div>' . "\n";
    return;
}

sub checkoptmodules {
    my $rval;
    print '<h1>PERL modules - optional</h1>' . "\n";
    print '<div>' . "\n";
    print '<table>' . "\n";
    checkmodule('GD', 1);
    print '</table>' . "\n";
    print '</div>' . "\n";
    return;
}

# verifty that we have a functional nagiosgraph installation.
sub checkng {
    my $rval;
    my @failures;

    print '<h1>nagiosgraph</h1>' . "\n";
    print '<div>';

    print 'ngshared: ';
    $rval = eval { require ngshared; };
    if (defined $rval && $rval == 1) {
        print 'ok<br>';
    } else {
        print 'failed<br>';
        my $msg = 'cannot load ngshared.pm<br>' .
            'not found in any of these locations:<br>' . "\n";
        for my $ii (@INC) {
            $msg .= $ii . '<br>' . "\n";
        }
        push @failures, $msg;
    }

    print 'version: ';
    if ($ngshared::VERSION) {
        print $ngshared::VERSION . '<br>';
    } else {
        print 'failed<br>';
        push @failures, 'cannot initialize ngshared.pm';
    }

    if (scalar @failures) {
        for my $msg (@failures) {
            emitcrit($msg);
        }
        emitfooter();
        exit 1;
    }
    
    print 'nagiosgraph.conf: ';
    my $errmsg = ngshared::readconfig('showconfig', 'cgilogfile');
    if ($errmsg eq q()) {
        print 'ok<br>';
    } else {
        print 'failed<br>';
        my $msg = 'cannot read nagiosgraph configuration file:<br>' .
            $errmsg . '<br>';
        push @failures, $msg;
    }

    print 'rrd dir: ';
    if ($ngshared::Config{rrddir}) {
        my $dir = $ngshared::Config{rrddir};
        if (-d $dir) {
# FIXME: check for write access by nagios user
# FIXME: check for read access by web user
        } else {
            print 'fail<br>';
            push @failures, 'rrd directory does not exist';
        }
    } else {
        print 'not defined<br>';
        push @failures, 'rrd directory is not defined';
    }

    print 'log file: ';
    print 'ok<br>';

    print 'cgi log file: ';
    print 'ok<br>';

    print 'map rules: ';
    if ($ngshared::Config{mapfile}) {
        my $errmsg = ngshared::getrules($ngshared::Config{mapfile});
        if ($errmsg eq q()) {
            print 'ok<br>';
        } else {
            push @failures, $errmsg;
        }
    } else {
        print 'file is not defined';
        push @failures, 'map file is not defined';
    }

    print '</div>';

    if (scalar @failures) {
        for my $msg (@failures) {
            emitcrit($msg);
        }
        emitfooter();
        exit 1;
    }

    return;
}

sub checkngconfig {
    my $cfgname = $ngshared::CFGNAME;
    my $blah = $ngshared::CFGNAME; # keep perl from whining at us
    my %vars = %ngshared::Config;
    print '<h2>base configuration</h2>';
    print '<div>';
    print '<p>' . $INC[0] . q(/) . $cfgname . '</p>' . "\n";
    print "<pre class='listing'>\n";
    foreach my $n (sort keys %vars) {
        print $n . q(=);
        if (ref($vars{$n}) eq 'ARRAY') {
            print "\n";
            for my $ii (@{$vars{$n}}) {
                print q(  ) . $ii . "\n";
            }
        } elsif (ref($vars{$n}) eq 'HASH') {
            print "\n";
            my %hash = %{$vars{$n}};
            for my $ii (sort keys %hash) {
                print q(  ) . $ii . q(=) . $hash{$ii} . "\n";
            }
        } else {
            print $vars{$n} . "\n";
        }
    }
    print "</pre>\n";
    print '</div>';
    return;
}

sub checkfiles {
    dumpfile('mapfile','map rules');
    dumpfile('labelfile','labels');
    dumpfile('hostdb','host settings');
    dumpfile('servdb','service settings');
    dumpfile('groupdb','group settings');
    dumpfile('datasetdb','data sources');
    dumpfile('rrdoptsfile','RRD options');
    return;
}

sub checkdirs {
    dumpdir($INC[0],'contents of config dir');
    dumpdir($ngshared::Config{'rrddir'},'contents of RRD dir');
    return;
}

sub dumpfile {
    my ($key, $desc) = @_;
    my %vars = %ngshared::Config;
    print '<div>';
    if ($vars{$key}) {
        my $fn = ngshared::getcfgfn($vars{$key});
        print '<h2>' . $desc . '</h2>';
        print '<p>' . $fn . '</p>';
        print '<pre class="listing">';
        if (open my $FH, '<', $fn) {
            while (<$FH>) {
                my $line = $_;
                next if $line =~ /\s*\#/;
                print $line;
            }
            close $FH or print "close failed for $fn: $OS_ERROR";
        } else {
            print "cannot read $fn: $OS_ERROR";
        }
        print '</pre>';
    } else {
        print $key . ' is not defined';
    }
    print '</div>';
    return;
}

sub dumpdir {
    my ($dir, $desc) = @_;
    print '<div>';
    print '<h2>' . $desc . '</h2>';
    print '<pre class="listing">' . "\n";
    print `ls -lRa $dir`;
    print "\n" . '</pre>' . "\n";
    print '</div>';
    return;
}

sub emitcrit {
    my ($msg) = @_;
    print '<p class="critical">' . $msg . '</p>';
    return;
}



__END__

=head1 NAME

showconfig.cgi - Show nagiosgraph configuration

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It displays
the nagiosgraph configuration.

=head1 USAGE

B<showconfig.cgi>

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

=head1 DEPENDENCIES

None.

=head1 INSTALLATION

Copy B<ngshared.pm> and B<nagiosgraph.conf> to a
configuration directory such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> as needed.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

We would prefer to have run-time rather than compile-time checking of the
ngshared module so that this script would have external dependencies.

The exports for ngshared need to be cleaned up so that it is a proper module.

=head1 SEE ALSO

B<nagiosgraph.conf>
B<ngshared.pm> B<showgraph.cgi>
B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Matthew Wall, 2010.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 Matthew Wall

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
