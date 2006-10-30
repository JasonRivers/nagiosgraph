#!/usr/bin/perl
# Upgrade script for NagiosGraph, scans a directory to organize the .rrd files into
# subdirectories named after the hosts they belong to
# Changes layout from "Config(rrdir)/host_svc_db.rrd" to 
# "Config(dir)/host/svc___db.rrd" (that's 3 '_' joined)

use warnings;
use strict;

use File::Copy;

# Subroutines definition
sub askUser;
sub CheckDir;
sub SeenName;
sub AddSeen;
sub urlencode;
sub urldecode;

# Global variables definition
my $defdir="/usr/local/nagios/nagiosgraph/rrd";
my $clear=`clear`;
my $MAX = 2;
my @svrs;
my @svcs;
my @unknown;

print $clear;
print '-' x 80 . "\n";
print "NagiosGraph has changed the organization of RRD Databases in this release\n";
print "Now the rrdir parameter specifies the top-folder where a directory for each\n";
print "monitored server will be created\n";
print "This script will help you in reorganize your existing RRDs files\n";
print "It would be a good idea to run this script from the account that owns the RRD files\n";
print "If you haven't used NagiosGraph before you don't need to run this script\n";
print '-' x 80 . "\n" x 4;

# Get and validate the top-level dir
my $answer = askUser("Enter the RRD directory to process", "$defdir");
my @files = CheckDir($answer);

# We have the files
PROCESS: foreach my $fname (@files) {
  my $count=0;
  my $host;
  my $svcname;
  $count++ while $fname =~ /_/g;

  if ( $count > $MAX ) {
  # Too many _ , let's see if we can match anyway
    $host = SeenName($fname,"host");
    if (! defined($host)) {
    # No luck, ask the user for help
      $host = AddSeen($fname,"host");
    }
  }
  elsif ($count == $MAX ) {
  # Regular file with only 2 _ separators, hostname goes until the 1st _
    ($host,$svcname) = split(/_/, $fname, 3);
  }
  else {
  # This is an RRD file that doesn't follow the naming convention, record his name
    push(@unknown,$fname);
    next PROCESS;
  }

 # Prepare the new folders and filenames
 my $tgfile;
 # Strip hostname from the destination filename
 ($tgfile = $fname) =~ s/^${host}_//;
 my $tgdir = $answer . "/" . urldecode($host) ;

 # Let's check that we have only 1 "_" in our final filename
 if (! defined($svcname)) {
    my $sepnumber;
    $sepnumber++ while $tgfile=~ /_/g; 
    if ($sepnumber > 1) {
    # Houston, we have a problem
       $svcname = SeenName($tgfile, "service");
       if (! defined($svcname)) {
           $svcname = AddSeen($tgfile, "service");
       }
    }
   elsif ($sepnumber == 1) {
       ($svcname) = split(/_/, $tgfile,0);
   }
   else {
      push(@unknown,$fname);
      next PROCESS;
   }

 }
 
 # We know now the service name , ensure we can always get it
 # We triple the separator between svc and db that will be both
 # a visual clue and reduce collision chances
 my $rest;
 ($rest = $tgfile) =~ s/^${svcname}_//;
 $tgfile = $svcname . "___" . $rest;

 # Time to move on!
 chdir $answer;
 if ( -d $tgdir ) {
 # Target dir exists , move the file
   move("$fname", "$tgdir/$tgfile") or die "Cannot move $fname $! \n";
 }
 else {
   # Dirs are created without URL encoding (user-friendly)
   mkdir $tgdir or die "Cannot create $tgdir directory $! \n";
   move("$fname", "$tgdir/$tgfile") or die "Cannot move $fname $! \n";
 }

}


# Report results
print $clear;
print "Directory $answer had " . @files . " RRD Databases\n";
my $total = @files - @unknown;
print "Total files processed: $total\n";
if ( @unknown ) {
   print "Files that couldn't be processed " . @unknown . "\n";
   print (join "\n", @unknown);
   print "Please move these files to the appropiate folder manually\n";
}
print "\n" x 4;
print "IMPORTANT: Make sure that file ownership and permissions are correct!!\n";
print "NagiosGraph Upgrade Script finished!!!\n\n\n";



# Prompts the user, accepts 2 arguments , the prompt and a optional default value
# Return whatever user choose to respond
sub askUser {

  my ($prompt,$default) = @_;
  my $response;
  
  print "$prompt ";
  
  if ( $default ) {
     print "[", $default , "]: " ;
     chomp($response = <STDIN>);
     return $response ? $response : $default;
  }  
  else {
     print ": ";
     chomp($response = <STDIN>);
     return $response;
  }
}

# Make sure rrddir is readable and it holds rrd databases
# Returns a list of files or dies
sub CheckDir {
   my $dir = $_[0];

   if ( -r $dir ) {
       opendir RRDF, $dir or die "Error opening $dir\n";
       my @files = grep /.rrd$/ , readdir RRDF;
       die "No files found in $dir \n" unless (@files);
       return @files;
   } 
   else {
      die "Cannot access $dir\n";

   }

}


# Looks for a known host/svc that matches beginning of filename
# Gets a filename and the type of info (host/svc)
# Returns the hostname if found
sub SeenName{
   my $fname = $_[0];
   my $type = $_[1];
  
   if ( $type eq "host") {
      foreach my $seenh (@svrs) {
         if ($fname=~m/^${seenh}_/) {
            return($seenh);
         }
      }
   }
   elsif ($type eq "service") {
      foreach my $seens (@svcs) {
         if ($fname=~m/^${seens}_/) {
            return($seens);
         }
       }
   }
    else {
      return undef;

    }   
   
   return undef;

}

# Ask the user to enter the host/service name when we cannot determine it
# Gets a filename and the type of info we want (host/service).
# Returns the host/svc name
sub AddSeen {
    my $fname = $_[0];
    my $what = $_[1];
    my $notfound = 1;
    my $result;

    print "I cannot determine the $what name portion in the string $fname\n";
    # Keep asking the user until we get a reasonably answer
    while ($notfound) {
          $result = askUser("Enter the $what name part in this string ($fname)" );
          $notfound = 0 if ($fname=~m/^${result}_/);
    }

    # Now confirm if we must "memorize" this name for future (SeenName) checks
    print "\n From now on I will use $result as $what name on similar files\n";
    my $confirm = askUser("Is that OK? [Yes/No]", "Yes");
    if ($confirm=~/^[yY]/)  {
         push(@svrs,$result) if ($what eq "host");
         push(@svcs,$result) if ($what eq "service");
    }
					  
    return($result);

}


# URL encode/decode a string (filenames are URLEncoded)
#
sub urlencode {
  $_[0] =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
  return $_[0];
}

sub urldecode {
  $_[0] =~ s/%([0-9A-F]{2})/chr(hex($1))/eg;
  return $_[0];
}

