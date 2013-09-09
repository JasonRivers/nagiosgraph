#!/usr/bin/perl
# create a text index from a pod file

use strict;

my $fn = 'README.pod';
my $ofn = 'README.tmp';
my $ifn = 'README';
my @headings = `grep =head $fn`;

my $idx = q();
foreach my $h (@headings) {
    my($level,$str) = $h =~ /^=head(\d) (.*)/;
    next if $str eq 'Nagiosgraph';
    next if $str eq 'Copyright and License';
    my $pad = q();
    for(my $i=0; $i<$level; $i++) {
        $pad .= "   ";
    }
    $idx .= "$pad$str\n";
}

if (open OFILE, '>', $ofn) {
    if (open IFILE, '<', $ifn) {
        while(<IFILE>) {
            my $line = $_;
            if ($line =~ /^Principles of Operation/) {
                print OFILE "Contents\n\n";
                print OFILE $idx;
                print OFILE "\n";
            }
            print OFILE $line;
        }
        close IFILE;
    } else {
        print "cannot read $ifn: $!\n";
    }
    close OFILE;
} else {
    print "cannot write $ofn: $!\n";
}

`mv $ofn $ifn`;

exit 0;
