#!/usr/bin/perl
# $Id$
#
# This script reorganizes the nagiosgraph RRD files from all files in a single
# directory to a separate directory for each host.  It changes the filenames
# and directories from:
#    RRDDIR/hostname_servicedesc_datasource.rrd
# to:
#    RRDDIR/hostname/servicedesc___datasource.rrd

use English qw(-no_match_vars);
use File::Copy;
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '2.0';

# Global variables definition
my $defdir = '/usr/local/nagios/nagiosgraph/rrd';
my $MAX = 2;
my @svrs;
my @svcs;
my @unknown;

## no critic (RequireCheckedSyscalls,ProhibitMixedCaseSubs)
print 80 x q(-). "\n"; ## no critic (ProhibitMagicNumbers)
print "NagiosGraph has changed the organization of RRD Databases in this release\n";
print "Now the rrdir parameter specifies the top-folder where a directory for each\n";
print "monitored server will be created\n";
print "This script will help you in reorganize your existing RRDs files\n";
print "It would be a good idea to run this script from the account that owns the RRD files\n";
print "If you haven't used NagiosGraph before you don't need to run this script\n";
print 80 x q(-) . "\n" x 4; ## no critic (ProhibitMagicNumbers)

# Get and validate the top-level dir
my $answer = askUser('Enter the RRD directory to process', $defdir);
my @files = CheckDir($answer);

# We have the files
PROCESS: foreach my $fname (@files) {
    my $count=0;
    my $host;
    my $svcname;
    while ($fname =~ /_/g) { $count++; } ## no critic (RegularExpressions)

    if ( $count > $MAX ) {
        # Too many _ , let's see if we can match anyway
        $host = SeenName($fname, 'host');
        if (not $host) {
            # No luck, ask the user for help
            $host = AddSeen($fname, 'host');
        }
    } elsif ($count == $MAX ) {
        # Regular file with only 2 _ separators, hostname goes until the 1st _
        ($host, $svcname) = split /_/, $fname, 3; ## no critic (RegularExpressions,ProhibitMagicNumbers)
    } else {
        # This is an RRD file that doesn't follow the naming convention, record his name
        push @unknown, $fname;
        next PROCESS;
    }

    # Prepare the new folders and filenames
    my $tgfile;
    # Strip hostname from the destination filename
    ($tgfile = $fname) =~ s/^${host}_//; ## no critic (RegularExpressions)
    my $tgdir = $answer . q(/) . urldecode($host) ;

    # Let's check that we have only 1 "_" in our final filename
    if (! defined $svcname) {
        my $sepnumber;
        while ($tgfile =~ /_/g) { $sepnumber++; }
        if ($sepnumber > 1) {
            # Houston, we have a problem
            $svcname = SeenName($tgfile, 'service');
            if (not $svcname) {
                $svcname = AddSeen($tgfile, 'service');
            }
        } elsif ($sepnumber == 1) {
            ($svcname) = split /_/, $tgfile,0;
        } else {
            push @unknown, $fname;
            next PROCESS;
        }
    }

    # We know now the service name , ensure we can always get it
    # We triple the separator between svc and db that will be both
    # a visual clue and reduce collision chances
    my $rest;
    ($rest = $tgfile) =~ s/^${svcname}_//; ## no critic (RegularExpressions)
    $tgfile = $svcname . '___' . $rest;

    # Time to move on!
    chdir $answer;
    if ( -d $tgdir ) {
        # Target dir exists , move the file
        move("$fname", "$tgdir/$tgfile") or die "Cannot move $fname $OS_ERROR \n";
    } else {
        # Dirs are created without URL encoding (user-friendly)
        mkdir $tgdir or die "Cannot create $tgdir directory $OS_ERROR \n";
        move("$fname", "$tgdir/$tgfile") or die "Cannot move $fname $OS_ERROR \n";
    }
}


# Report results
print "\nDirectory $answer had " . @files . " RRD Databases\n";
my $total = @files - @unknown;
print "Total files processed: $total\n";
if ( @unknown ) {
    print "Files that couldn't be processed " . @unknown . "\n"; ## no critic (ProhibitInterpolationOfLiterals)
    print join "\n", @unknown;
    print "Please move these files to the appropiate folder manually\n";
}
print "\n" x 4; ## no critic (ProhibitMagicNumbers)
print "IMPORTANT: Make sure that file ownership and permissions are correct!!\n";
print "NagiosGraph Upgrade Script finished!!!\n\n\n";



# Prompts the user, accepts 2 arguments , the prompt and a optional default value
# Return whatever user choose to respond
sub askUser {
    my ($prompt,$default) = @_;
    my $response;

    print "$prompt ";

    if ( $default ) {
        print '[', $default , ']: ' ;
        chomp($response = <>);
        return $response ? $response : $default;
    } else {
        print ': ';
        chomp($response = <>);
        return $response;
    }
}

# Make sure rrddir is readable and it holds rrd databases
# Returns a list of files or dies
sub CheckDir {
    my ($dir) = @_;

    if ( -r $dir ) {
        opendir RRDF, $dir or die "Error opening $dir\n";
        my @dirfiles = grep { /.rrd$/ } readdir RRDF; ## no critic (RegularExpressions)
        if (not @dirfiles) { die "No files found in $dir \n"; }
        return @dirfiles;
    } else {
        die "Cannot access $dir\n";
    }
}


# Looks for a known host/svc that matches beginning of filename
# Gets a filename and the type of info (host/svc)
# Returns the hostname if found
sub SeenName {
    my ($fname, $type) = @_;

    if ($type eq 'host') {
        foreach my $seenh (@svrs) {
            if ($fname =~ m/^${seenh}_/) { ## no critic (RegularExpressions)
                return($seenh);
            }
        }
    } elsif ($type eq 'service') {
        foreach my $seens (@svcs) {
            if ($fname =~ m/^${seens}_/) { ## no critic (RegularExpressions)
                return($seens);
            }
        }
    }
    return;
}

# Ask the user to enter the host/service name when we cannot determine it
# Gets a filename and the type of info we want (host/service).
# Returns the host/svc name
sub AddSeen {
    my ($fname, $what) = @_;
    my $notfound = 1;
    my $result;

    print "I cannot determine the $what name portion in the string $fname\n";
    # Keep asking the user until we get a reasonably answer
    while ($notfound) {
          $result = askUser("Enter the $what name part in this string ($fname)" );
          if ($fname =~ m/^${result}_/) { $notfound = 0; } ## no critic (RegularExpressions)
    }

    # Now confirm if we must "memorize" this name for future (SeenName) checks
    print "\n From now on I will use $result as $what name on similar files\n";
    my $confirm = askUser('Is that OK? [Yes/No]', 'Yes');
    if ($confirm =~ /^[yY]/) { ## no critic (RegularExpressions)
         if ($what eq 'host') { push @svrs, $result; }
         if ($what eq 'service') { push @svcs, $result; }
    }
    return($result);
}


# URL encode/decode a string (filenames are URLEncoded)
#
sub urlencode {
    my ($arg) = @_;
    $arg =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg; ## no critic (RegularExpressions)
    return $arg;
}

sub urldecode {
    my ($arg) = @_;
    $arg =~ s/%([0-9A-F]{2})/chr(hex($1))/eg; ## no critic (RegularExpressions)
    return $arg;
}

__END__

=head1 NAME

upgrade.pl - upgrade nagiosgraph database.

=head1 DESCRIPTION

=head1 USAGE

B<upgrade.pl>

=head1 CONFIGURATION

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over 4

=item B<Nagios>

This provides the data collection system.

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org, added perldoc and other changes.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2009 Andrew W. Mellon Foundation

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
