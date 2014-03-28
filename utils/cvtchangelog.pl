#!/usr/bin/perl
# convert the CHANGELOG to debian changelog format

use POSIX;
use Time::Local;
use strict;

my $user = 'nagiosgraph';
my $email = 'nagiosgraph@sourceforge.net';
my $pkgname = 'nagiosgraph';
my $ifn = 'CHANGELOG';
my $rc = 0;

if (open my $IFH, '<', $ifn) {
    my @lines;
    my $starttag = q();
    my $endtag = q();
    while(<$IFH>) {
        my $line = $_;
        next if $line =~ /^\$Id/;
        if ($line =~ /^([0-9.]+)/) {
            my $version = $1;
            my $t = time;
            if ($line =~ /(\d\d\d\d)-(\d\d)-(\d\d)/) {
                my($year,$month,$day) = ($1,$2,$3);
                $t = timelocal(0,0,0,$day,$month-1,$year);
            }
            my $ts = strftime '%a, %d %b %Y %H:%M:%S %z', localtime $t;
            $starttag = "$pkgname ($version) unstable; urgency=low";
            $endtag = "-- $user <$email>  $ts";
        } elsif ($line !~ /\S/) {
            if ($starttag ne q() && $#lines >= 0) {
                print STDOUT "$starttag\n";
                print STDOUT "\n";
                foreach my $ln (@lines) {
                    print STDOUT "$ln";
                }
                print STDOUT "\n";
                print STDOUT "$endtag\n";
                print STDOUT "\n";
                print STDOUT "\n";
                $starttag = q();
                $endtag = q();
                @lines = ();
            }
        } else {
            push @lines, $line;
        }
    }
} else {
    print "cannot read $ifn: $!\n";
    $rc = 1;
}

exit $rc;
