#!/usr/bin/perl

# $Id: showhost.cgi 315 2010-03-04 02:15:41Z mwall $
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2010 Matthew Wall

## no critic (InputOutput::RequireCheckedSyscalls)
## no critic (Modules::ProhibitExcessMainComplexity)
## no critic (Subroutines::ProhibitExcessComplexity)

# The configuration file and ngshared.pm must be in this directory:
use lib '/opt/nagiosgraph/etc';

use English qw(-no_match_vars);
use strict;
use warnings;

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
.listing {
  border: 1px solid #777777;
  background-color: #eeeeee;
  padding: 5px;
}
</style>
</head>
EOB

checkmodules();
checkoptmodules();
checkng();
checkrules();
checkfiles();
print '</body></html>';

exit 0;


sub checkmodules {
    my $rval;
    print '<h1>PERL modules - required</h1>';
    print '<div>';
    
    print 'Carp: ';
    $rval = eval { require Carp; };
    if (defined $rval && $rval == 1) { print Carp->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'CGI: ';
    $rval = eval { require CGI; };
    if (defined $rval && $rval == 1) { print CGI->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'Data::Dumper: ';
    $rval = eval { require Data::Dumper; };
    if (defined $rval && $rval == 1) { print Data::Dumper->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'File::Basename: ';
    $rval = eval { require File::Basename; };
    if (defined $rval && $rval == 1) { print File::Basename->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'File::Find: ';
    $rval = eval { require File::Find; };
    if (defined $rval && $rval == 1) { print File::Find->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'MIME::Base64: ';
    $rval = eval { require MIME::Base64; };
    if (defined $rval && $rval == 1) { print MIME::Base64->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'POSIX: ';
    $rval = eval { require POSIX; };
    if (defined $rval && $rval == 1) { print POSIX->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'RRDs: ';
    $rval = eval { require RRDs; };
    if (defined $rval && $rval == 1) { print RRDs->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print 'Time::HiRes: ';
    $rval = eval { require Time::HiRes; };
    if (defined $rval && $rval == 1) { print Time::HiRes->VERSION; }
    else { print 'not installed'; }
    print '<br>';

    print '</div>';
    return;
}

sub checkoptmodules {
    my $rval;
    print '<h1>PERL modules - optional</h1>';
    print '<div>';
    
    print 'GD: ';
    $rval = eval { require GD; };
    if (defined $rval && $rval == 1) { print GD->VERSION; }
    else { print 'not installed'; }
    print '<br>';
    
    print '</div>';
    return;
}

sub checkng {
    my $rval;
    print '<h1>nagiosgraph</h1>';
    print '<div>';
    print 'ngshared: ';
    $rval = eval { require ngshared; };
    if (defined $rval && $rval == 1) { print 'ok<br>'; }
    else {
        print 'cannot load ngshared.pm<br>';
        print 'not found in any of these locations:<br>';
        for my $ii (@INC) {
            print $ii . '<br>';
        }
        print '</div>';
        print '</body></html>';
        exit 0;
    }

# i would prefer to do this with require rather than use, but no joy...
    use ngshared;
#ngshared->import(qw($VERSION %Config));
    
    if (! $VERSION) {
        print 'cannot initialize ngshared.pm<br>';
        print '</div>';
        print '</body></html>';
        exit 0;
    }
    print 'version: ' . $VERSION . '<br>';
    
    print 'nagiosgraph.conf: ';
    my $errmsg = readconfig('showconfig', 'cgilogfile');
    if ($errmsg eq q()) {
        print 'ok<br>';
    } else {
        print 'cannot read nagiosgraph configuration file:<br>';
        print $errmsg . '<br>';
        print '</div>';
        print '</body></html>';
        exit 0;
    }

    print '</div>';
    return;
}

sub checkrules {
    print '<div>';
    print 'map rules: ';
    if ($Config{mapfile}) {
        my $errmsg = getrules($Config{mapfile});
        print $errmsg eq q() ? 'ok' : $errmsg;
    } else {
        print 'map rule file is not defined';
    }
    print '</div>';
    
    print '<h2>base configuration</h2>';
    print '<div>';
    print "<pre class='listing'>\n";
    foreach my $n (sort keys %Config) {
        print $n . q(=);
        if (ref($Config{$n}) eq 'ARRAY') {
            print "\n";
            for my $ii (@{$Config{$n}}) {
                print q(  ) . $ii . "\n";
            }
        } elsif (ref($Config{$n}) eq 'HASH') {
            print "\n";
            my %hash = %{$Config{$n}};
            for my $ii (sort keys %hash) {
                print q(  ) . $ii . q(=) . $hash{$ii} . "\n";
            }
        } else {
            print $Config{$n} . "\n";
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

sub dumpfile {
    my ($key, $desc) = @_;
    print '<div>';
    if ($Config{$key}) {
        my $fn = getcfgfn($Config{$key});
        print '<h2>' . $desc . '</h2>';
        print '<p>' . $fn . '</p>';
        print '<pre class="listing">';
        if (open my $FH, '<', $fn) {
            while (<$FH>) {
                print $_;
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



__END__

=head1 NAME

showconfig.cgi - Show nagiosgraph configuration

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It generates
a page of HTML that displays the nagiosgraph configuration.

=head1 USAGE

B<showconfig.cgi>

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

=head1 DEPENDENCIES

=head1 INSTALLATION

Copy B<ngshared.pm> and B<nagiosgraph.conf> to a
configuration directory such as /etc/nagiosgraph.

Copy this file to a CGI script directory on a web server and ensure that
it is executable by the web server.  Modify the B<use lib> line to point
to the configuration directory.

Edit B<nagiosgraph.conf> as needed.

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

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
