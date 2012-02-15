#!/usr/bin/perl
# $Id: showhost.cgi 315 2010-03-04 02:15:41Z mwall $
# License: OSI Artistic License
# Author:  2011 (c) Matthew Wall

# FIXME: old versions of RRDs::dump (<1.2.13) do not like the file argument

## no critic (RequireCheckedSyscalls)
## no critic (ProhibitPostfixControls)

# ngshared.pm and configuration files must be in this directory:
use lib '/opt/nagiosgraph/etc';

use ngshared;
use English qw(-no_match_vars);
use IO::Handle;
use strict;
use warnings;

my @help = ('options include:', 'host=HOST', 'service=SERVICE', 'db=DATASOURCE', 'format=(info|csv|dump)');

my $errmsg = readconfig('testcolor', 'cgilogfile');
if ($errmsg ne q()) {
    htmlerror($errmsg);
    croak($errmsg);
}
my $cgi = CGI->new;
$cgi->autoEscape(0);

# get the arguments we care about
my $host = $cgi->param('host');
my $service = $cgi->param('service');
my $db = $cgi->param('db');
my $format = $cgi->param('format');
$format ||= 'info';

# do some error checking on the arguments
my @msgs;
my @fmsgs;
if (!defined $host || !defined $service || !defined $db) {
    if (! defined $host) {
        push @msgs, 'No host specified.';
    }
    if (! defined $service) {
        push @msgs, 'No service specified.';
    }
    if (! defined $db) {
        push @msgs, 'No database specified.';
    }
}
if ($format ne 'csv' && $format ne 'dump' && $format ne 'info') {
    push @msgs, "Unsupported format '$format'";
}
if (! defined $db && defined $host && defined $service) {
    my $fref = dbfilelist($host, $service);
    my @files = @$fref;
    if (scalar @files > 0) {
        push @fmsgs, "RRD files for host <b>$host</b> and service <b>$service</b> include:";
        foreach my $f (@files) {
            push @fmsgs, $f;
        }
    } else {
        push @msgs, "No RRD files for host <b>$host</b> and service <b>$service</b>";
    }
}
if (scalar @msgs > 0) {
    htmlerror( join '<br>', @msgs, '', @help, '', @fmsgs );
    exit 0;
}
if (! havepermission($host, $service)) {
    htmlerror("Permission denied for service '$service' on host '$host'");
    exit 0;
}

# lookup the RRD file that corresponds to the specified host, service, and db
my($dir, $fn) = mkfilename($host, $service, $db);
my $file = "$dir/$fn";
if ( ! -f $file ) {
    htmlerror("No data available for database '$db' from service '$service' on host '$host'");
    exit 0;
}

if ($format eq 'info') {
    my $hash = RRDs::info $file;
    my $err = RRDs::error;
    if ($err) {
        htmlerror("Error reading RRD file $file: $err");
    } elsif ($hash) {
        print $cgi->header(-type => 'text/plain');
        my %info = %{$hash};
        foreach my $key (sort keys %info) {
            print "$key = ";
            print $info{$key} if $info{$key};
            print "\n";
        }
    } else {
        htmlerror("No info available for database '$db' from service '$service' on host '$host'");
    }
} elsif ($format eq 'dump') {

# this works, but we get no error handling
    *STDOUT->autoflush();
    print $cgi->header(-type => 'text/plain');
    RRDs::dump $file;

# this captures only part of the RRDs::dump output
#    my $str = q();
#    if (open my $OLDOUT, '>&', STDOUT) {
#        close STDOUT;
#        if (open STDOUT, '>', \$str) {
#            RRDs::dump $file;
#            close STDOUT;
#            if (! open STDOUT, '>&', $OLDOUT) {
#                htmlerror("Cannot re-assign STDOUT: $!");
#                exit 1;
#            }
#        } else {
#            htmlerror("Cannot redirect STDOUT: $!");
#            exit 1;
#        }
#        close $OLDOUT;
#    } else {
#        htmlerror("Cannot duplicate STDOUT to OLDOUT: $!");
#        exit 1;
#    }

# this does not capture STDOUT
#    use IO::String;
#    my $str = q();
#    my $str_fh = IO::String->new($str);
#    my $old_fh = select($str_fh);
#    RRDs::dump $file;
#    select($old_fh);

#    my $err = RRDs::error;
#    if ($err) {
#        htmlerror("Error reading RRD file $file: $err");
#    } else {
#        print $cgi->header(-type => 'text/xml');
#        print $str;
#    }
} elsif ($format eq 'csv') {
    my ($start,$step,$names,$data) = RRDs::fetch $file, 'AVERAGE';
    my $err = RRDs::error;
    if ($err) {
        htmlerror("Error reading RRD file $file: $err");
    } else {
        print $cgi->header(-type => 'text/plain');
        print "# Host:        $host\n";
        print "# Service:     $service\n";
        print "# Database:    $db\n";
        print "# File:        $file\n";
        print '# Start:       ', scalar localtime($start), " ($start)\n";
        print "# Step size:   $step seconds\n";
        print '# DS names:    ', join (q(, ), @{$names}) . "\n";
        print '# Data points: ', $#{$data} + 1, "\n";
        print 'timestamp,seconds,', join (q(,), @{$names}) . "\n";
        for my $line (@{$data}) {
            print scalar localtime($start), ",$start";
            $start += $step;
            for my $val (@{$line}) {
                print q(,);
                print $val if $val;
            }
            print "\n";
        }
    }
}

exit 0;



__END__

=head1 NAME

export.cgi - extract data from RRD files and return it in desired format

=head1 DESCRIPTION

This is a CGI script that is designed to be run on a web server.  It extracts
data from RRD files and returns the data in various formats.

=head1 USAGE

B<export.cgi>?host=host_name&service=service_description&db=database

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=over 4

=item host=host_name

=item service=service_description

=item db=database

=item format=(info|dump|csv)

=back

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 CONFIGURATION

The B<nagiosgraph.conf> file controls the behavior of this script.

=head1 DEPENDENCIES

=over 4

=item B<ngshared.pm>

This is the nagiosgraph perl library.  It contains code used by this script.

=item B<rrdtool>

This provides the data storage and graphing system.

=item B<RRDs>

This provides the perl interface to rrdtool.

=back

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
B<ngshared.pm>
B<showgraph.cgi>
B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi>

=head1 AUTHOR

Matthew Wall, 2011

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 Matthew Wall, all rights reserved

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
