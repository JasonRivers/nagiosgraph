#!/usr/bin/perl

# File:    $Id: insert.pl,v 1.22 2006/10/28 10:24:56 vanidoso Exp $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;
use RRDs;
use Fcntl ':flock';

# Configuration
my $configfile = '/usr/local/etc/nagiosgraph.conf';

# Main program - change nothing below

my %Config;

# Read in config file
#
sub readconfig {
  die "config file not found" unless -r $configfile;

  # Read configuration data
  open FH, $configfile;
    while (<FH>) {
      s/\s*#.*//;    # Strip comments
      /^(\w+)\s*=\s*(.*?)\s*$/ and do {
        $Config{$1} = $2;
        debug(5, "Config $1:$2");
      };
    }
  close FH;

  # If debug is set make sure we can write to the log file
  if ($Config{debug} > 0) {
     open LOG, ">>$Config{logfile}" or die "Cannot append to logfile $Config{logfile}";
  }

  # Make sure rrddir exist and is writable
  unless ( -w $Config{rrddir} ) {
    mkdir $Config{rrddir};
    die "rrd dir $Config{rrddir} not writable" unless -w $Config{rrddir};
  }
}

# Parse performance data from input
#
sub parseinput {
  my $data = shift;
  #debug(5, "perfdata: $data");
  my @d = split( /\|\|/, $data);
  return ( lastcheck    => $d[0],
           hostname     => $d[1],
           servicedescr => $d[2],
           output       => $d[3],
           perfdata     => $d[4],
         );
}

# Write debug information to log file
#
sub debug { 
  my($l, $text) = @_;
  if ( $l <= $Config{debug} ) {
    $l = qw(none critical error warn info debug)[$l];
    # Get a lock on the LOG file (blocking call)
    flock(LOG,LOCK_EX);
      print LOG scalar localtime . ' $RCSfile: insert.pl,v $ $Revision: 1.22 $ '."$l - $text\n";
    flock(LOG,LOCK_UN);  #Unlock file
  }
}

# Dump to log the files read from Nagios
#
sub dumpperfdata {
  my %P = @_;
  for ( keys %P ) {
    debug(4, "Input $_:$P{$_}");
  }
}

# URL encode a string
#
sub urlencode {
  $_[0] =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
  return $_[0];
}

# Create new rrd databases if necessary
#
sub createrrd {
  my($host,$service,$start,$labels) = @_;
  my($f,$v,$t,$ds,$db);
  my($RRA_1min, $RRA_6min, $RRA_24min, $RRA_288min);
  my(@resolution);

  if (defined $Config{resolution} ) {
    @resolution=split(/ /, $Config{resolution});
    debug(4, "resol=$resolution[0] - $resolution[1] - $resolution[2] - $resolution[3]");
  }

  if ( defined $resolution[0] ) {
    $RRA_1min = $resolution[0];
  } else {
    $RRA_1min = 600;
  }
  if ( defined $resolution[1] ) {
    $RRA_6min = $resolution[1];
  } else {
    $RRA_6min = 700;
  }
  if ( defined $resolution[2] ) {
    $RRA_24min = $resolution[2];
  } else {
    $RRA_24min = 775;
  }
  if ( defined $resolution[3] ) {
    $RRA_288min = $resolution[3];
  } else {
    $RRA_288min = 797;
  }

  $db = shift @$labels;
  $f = urlencode("${host}_${service}_${db}") . '.rrd';
  debug(5, "Checking $Config{rrddir}/$f");
  unless ( -e "$Config{rrddir}/$f" ) {
    $ds = "$Config{rrddir}/$f --start $start";
    for ( @$labels ) {
      ($v,$t) = ($_->[0],$_->[1]);
      my $u = $t eq 'DERIVE' ? '0' : 'U' ;
      $ds .= " DS:$v:$t:$Config{heartbeat}:$u:U";
    }
    $ds .= " RRA:AVERAGE:0.5:1:" . $RRA_1min;
    $ds .= " RRA:AVERAGE:0.5:6:" . $RRA_6min;
    $ds .= " RRA:AVERAGE:0.5:24:" . $RRA_24min;
    $ds .= " RRA:AVERAGE:0.5:288:" . $RRA_288min;
debug(1, "DS = $ds");

    my @ds = split /\s+/, $ds;
    debug(4, "RRDs::create $ds");
    RRDs::create(@ds);
    debug(2, "RRDs::create ERR " . RRDs::error) if RRDs::error;
  }
  return $f;
}

# Use RRDs to update rrd file
#
sub rrdupdate {
  my($file,$time,$values) = @_;
  my($ds,$c);

  $ds = "$Config{rrddir}/$file $time";
  for ( @$values ) {
    $_->[2] ||= 0;
    $ds .= ":$_->[2]";
  }

  my @ds = split /\s+/, $ds;
  debug(4, "RRDs::update ". join ' ', @ds);
  RRDs::update(@ds);
  debug(2, "RRDs::update ERR " . RRDs::error) if RRDs::error;
}

# See if we can recognize any of the data we got
#
sub parseperfdata {
  my %P = @_;

  $_="servicedescr:$P{servicedescr}\noutput:$P{output}\nperfdata:$P{perfdata}";
  evalrules($_);
}

# Check that we have some data to work on
#
sub inputdata {
  my @inputlines;
  if ( $ARGV[0] ) {
    @inputlines = $ARGV[0];
  } elsif ( defined $Config{perflog} ) {
    open PERFLOG, $Config{perflog};
      @inputlines = <PERFLOG>;
    close PERFLOG
  }

  # Quit if there are no data to process
  unless ( @inputlines ) {
    debug(4, 'No inputdata. Exiting.');
    exit 1;
  }
  return @inputlines;
}

# Process all input performance data
#
sub processdata {
  my @perfdatalines = @_;
  for my $l ( @perfdatalines ) {
    debug(5, "processing perfdata: $l");
    my %P = parseinput($l);
    dumpperfdata(%P);
    my $S = parseperfdata(%P);
    for my $s ( @$S ) {
      my $rrd = createrrd($P{hostname}, $P{servicedescr}, $P{lastcheck}-1, $s);
      rrdupdate($rrd, $P{lastcheck}, $s);
    }
  }
}

### Main loop
#  - Read config and input
#  - Update rrd files
#  - Create them first if necesary.

readconfig();
debug(5, 'nagiosgraph spawned');
my @perfdata = inputdata();

# Read the map file and define a subroutine that parses performance data
my($rules);
undef $/;
open FH, $Config{mapfile};
  $rules = <FH>;
close FH;
$rules = '
sub evalrules {
  $_=$_[0];
  my @s;
  no strict "subs";
' . $rules . '
  use strict "subs";
  debug(3, "perfdata not recognized") unless @s;
  return \@s;
}';
undef $@;
eval $rules;
debug(2, "Map file eval error: $@") if $@;

processdata( @perfdata );
debug(5, 'nagiosgraph exited');
if (fileno(LOG)) {
    close LOG;
}

