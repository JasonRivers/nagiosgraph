#!/usr/bin/perl

# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2010 Matthew Wall

## no critic (InputOutput::RequireCheckedSyscalls)
## no critic (RegularExpressions)
## no critic (ProhibitPackageVars)

# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use POSIX;
use English qw(-no_match_vars);
use strict;
use warnings;

emitheader();
#checkstyles();
checkmodules();
checkng();
dumpenv();
dumpinc();
dumpngconfig();
dumpfiles();
dumpdirs();
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
    print "<h1>nagiosgraph configuration on $ENV{SERVER_NAME}</h1>\n";
    my $ts = strftime '%d %b %Y %H:%M:%S %Z', localtime time;
    print "$ts<br>\n";
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

sub dumpenv {
    print "<h2>Environment</h2>\n";
    print "<div>\n";
    print "<pre class='listing'>\n";
    foreach my $i (sort keys %ENV) {
	print "$i=$ENV{$i}\n";
    }
    print "</div>\n";
    return;
}

sub dumpinc {
    print "<h2>Include Paths</h2>\n";
    print "<div>\n";
    print "<pre class='listing'>\n";
    for my $i (@INC) {
        print $i . "\n";
    }
    print "</pre>\n";
    print "</div>\n";
    return;
}

sub printrow {
    my ($style, $func, $msg, $errmsg) = @_;
    $errmsg ||= q();
    print "<tr><td class='$style'> </td><td align='right'>$func:</td><td>$msg</td><td class='$style'>$errmsg</td></tr>\n";
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
    printrow($status, $func, $statusstr);
    return;
}

sub checkmodules {
    print '<h2>PERL modules</h2>' . "\n";
    print '<div>' . "\n";
    print '<table>' . "\n";
    print "<tr><td colspan='2'></td><td><b>required</b></td></tr>\n";
    checkmodule('Carp');
    checkmodule('CGI');
    checkmodule('Data::Dumper');
    checkmodule('File::Basename');
    checkmodule('File::Find');
    checkmodule('MIME::Base64');
    checkmodule('POSIX');
    checkmodule('RRDs');
    checkmodule('Time::HiRes');
    print "<tr><td colspan='2'></td><td><b>optional</b></td></tr>\n";
    checkmodule('GD', 1);
    checkmodule('Nagios::Config', 1);
    print '</table>' . "\n";
    print '</div>' . "\n";
    return;
}

sub checkngshared {
    my ($failures) = @_;
    my $func = 'ngshared.pm';
    my $status = 'ok';
    my $style = 'ok';
    my $errmsg = q();

    my $rval = eval { require ngshared; };
    if (! defined $rval || $rval != 1) {
        $status = 'fail';
        $style = 'critical';
        $errmsg = 'cannot load ngshared.pm<br>' .
            'not found in any of these locations:<br>' . "\n";
        for my $ii (@INC) {
            $errmsg .= $ii . '<br>' . "\n";
        }
        push @{$failures}, $errmsg;
    }

    printrow($style, $func, $status, $errmsg);
    return;
}

sub checkngversion {
    my ($failures) = @_;
    my $func = 'version';
    my $status = 'ok';
    my $style = 'ok';
    my $errmsg = q();

    if ($ngshared::VERSION) {
        $status = $ngshared::VERSION;
    } else {
        $status = 'fail';
        $style = 'critical';
        $errmsg = 'cannot initialize/import ngshared.pm';
    }
    if ($status eq 'fail') {
        push @{$failures}, $errmsg;
    }

    printrow($style, $func, $status, $errmsg);
    return;
}

sub checkngconf {
    my ($failures) = @_;
    my $func = 'nagiosgraph.conf';
    my $status = 'ok';
    my $style = 'ok';
    my $errmsg = q();

    $errmsg = ngshared::readconfig('showconfig', 'cgilogfile');
    if ($errmsg ne q()) {
        $status = 'fail';
        $style = 'critical';
        $errmsg = 'cannot read nagiosgraph configuration file:<br>' . $errmsg;
    }
    if ($status eq 'fail') {
        push @{$failures}, $errmsg;
    }

    printrow($style, $func, $status, $errmsg);
    return;
}

sub checkmaprules {
    my ($failures) = @_;
    my $func = 'map file';
    my $status = 'ok';
    my $errmsg = q();

    if ($ngshared::Config{mapfile}) {
        $errmsg = ngshared::getrules($ngshared::Config{mapfile});
        if ($errmsg ne q()) {
            $status = 'fail';
        }
    } else {
        $status = 'fail';
        $errmsg = 'map file is not defined';
    }
    my $style = $status eq 'ok' ? 'ok' : 'critical';
    if ($status eq 'fail') {
        push @{$failures}, $errmsg;
    }

    printrow($style, $func, $status, $errmsg);
    return;
}

# verifty that we have a functional nagiosgraph installation.
sub checkng {
    my $rval;
    my $status;
    my @failures;

    print '<h2>nagiosgraph</h2>' . "\n";

    print '<table>' . "\n";
    checkngshared(\@failures);
    checkngversion(\@failures);

    if (scalar @failures) {
        print '</table>' . "\n";
        emitfooter();
        exit 1;
    }

    checkngconf(\@failures);
    checkdir('rrddir', 'RRD directory', \@failures);
    checkfile('logfile', 'log file', \@failures);
    checkfile('cgilogfile', 'CGI log file', \@failures, 1);
# TODO: check for read/write access by nagios user
    checkmaprules(\@failures);
    print '</table>' . "\n";

    if (scalar @failures) {
        emitfooter();
        exit 1;
    }

    return;
}

sub dumpngconfig {
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

sub dumpfiles {
    dumpfile('mapfile','map rules');
    dumpfile('labelfile','labels');
    dumpfile('hostdb','host settings');
    dumpfile('servdb','service settings');
    dumpfile('groupdb','group settings');
    dumpfile('datasetdb','data sources');
    dumpfile('rrdoptsfile','RRD options');
    return;
}

sub dumpdirs {
    dumpdir($INC[0],'contents of config directory');
    dumpdir($ngshared::Config{'rrddir'},'contents of RRD directory');
    return;
}

sub dumpfile {
    my ($key, $desc) = @_;
    my %vars = %ngshared::Config;
    print '<h2>' . $desc . '</h2>';
    print '<div>';
    if ($vars{$key}) {
        my $fn = ngshared::getcfgfn($vars{$key});
        print '<p>' . $fn . '</p>';
        print '<pre class="listing">';
        if (open my $FH, '<', $fn) {
            while (<$FH>) {
                my $line = $_;
                next if $line =~ /^\s*\#/;
                print $line;
            }
            close $FH or print "close failed for $fn: $OS_ERROR";
        } else {
            print "cannot read $fn: $OS_ERROR";
        }
        print '</pre>';
    } else {
        print '<i>' . $key . '</i> is not defined';
    }
    print '</div>';
    return;
}

# FIXME: do the recursive listing in pure perl
sub dumpdir {
    my ($dir, $desc) = @_;
    print '<h2>' . $desc . '</h2>';
    print '<div>';
    print '<pre class="listing">' . "\n";
    print `ls -lRa $dir`; ## no critic (InputOutput::ProhibitBacktickOperators)
    print "\n" . '</pre>' . "\n";
    print '</div>';
    return;
}

sub checkdir {
    my ($key, $desc, $failures) = @_;
    my $status = 'ok';
    my $errmsg = q();
    if ($ngshared::Config{$key}) {
        my $dir = ngshared::getcfgfn($ngshared::Config{$key});
        if (-d $dir) {
            if (! -r $dir) {
                $status = 'fail';
                $errmsg = 'www user cannot read directory';
            }
        } else {
            $status = 'fail';
            $errmsg = 'directory does not exist';
        }
    } else {
        $status = 'fail';
        $errmsg = 'directory is not defined';
    }
    my $style = $status eq 'ok' ? 'ok' : 'critical';
    if ($status eq 'fail') {
        push @{$failures}, $errmsg;
    }

    printrow($style, $desc, $status, $errmsg);
    return;
}

sub checkfile {
    my ($key, $desc, $failures, $optional) = @_;
    my $status = 'ok';
    my $errmsg = q();
    if ($ngshared::Config{$key}) {
        my $fn = ngshared::getcfgfn($ngshared::Config{$key});
        if (-f $fn) {
            if (! -r $fn) {
                $status = 'fail';
                $errmsg = 'www user cannot read file';
            }
        } else {
            $status = 'fail';
            $errmsg = 'file does not exist';
        }
    } else {
        $status = 'fail';
        $errmsg = 'file is not defined';
    }
    my $style = $status eq 'ok' ? 'ok' : 'warning';
    if ($status eq 'fail' && ! $optional) {
        push @{$failures}, $errmsg;
        $style = 'critical';
    }

    printrow($style, $desc, $status, $errmsg);
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

None.

=head1 OPTIONS

None.

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

This script refers to the nagiosgraph library B<ngshared.pm> and the
nagiosgraph configuration file B<nagiosgraph.conf>.

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

None.

=head1 BUGS AND LIMITATIONS

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
