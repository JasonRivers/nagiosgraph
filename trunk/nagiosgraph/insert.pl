#!/usr/bin/perl

# File:    $Id: insert.pl,v 1.5 2004/11/11 07:22:02 sauber Exp $
# Author:  (c) Soren Dossing, 2004
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;

# Configuration
my $configfile = '/usr/local/etc/nagiosgraph.conf';

# Main program - change nothing below

my %Config;

# Read in config file
#
sub readconfig {
  # Read configuration data
  open FH, $configfile;
    while (<FH>) {
      s/\s*#.*//;    # Strip comments
      /(\w+)\s*=\s*(.*)/ and do {
        $Config{$1} = $2;
        debug(5, "INSERT Config $1:$2");
      };
    }
  close FH;

  # Make sure log file can be written to
  die "Log file $Config{logfile} not writable" unless -w $Config{logfile};

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
  debug(5, "INSERT perfdata: $data");
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
    $text =~ s/(\w+)/$1 $l:/;
    open LOG, ">>$Config{logfile}";
      print LOG scalar localtime;
      print LOG " $text\n";
    close LOG;
  }
}

# Dump to log the files read from Nagios
#
sub dumpperfdata {
  my %P = @_;
  for ( keys %P ) {
    debug(4, "INSERT Input $_:$P{$_}");
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

  $db = shift @$labels;
  $f = urlencode("${host}_${service}_${db}") . '.rrd';
  debug(5, "INSERT Checking $Config{rrddir}/$f");
  unless ( -e "$Config{rrddir}/$f" ) {
    $ds = "$Config{rrdtool} create $Config{rrddir}/$f --start $start";
    for ( @$labels ) {
      ($v,$t) = ($_->[0],$_->[1]);
      my $u = $t eq 'DERIVE' ? '0' : 'U' ;
      $ds .= " DS:$v:$t:600:$u:U";
    }
    $ds .= " RRA:AVERAGE:0.5:1:600";
    $ds .= " RRA:AVERAGE:0.5:6:700";
    $ds .= " RRA:AVERAGE:0.5:24:775";
    $ds .= " RRA:AVERAGE:0.5:288:797";
    debug(4, "INSERT System $ds");
    system ($ds);
  }
  return $f;
}

# Use rrdtool to update rrd file
#
sub rrdupdate {
  my($file,$time,$values) = @_;
  my($ds,$c);

  $ds = "$Config{rrdtool} update $Config{rrddir}/$file $time";
  for ( @$values ) {
    $ds .= ":$_->[2]";
  }
  debug(4, "INSERT System $ds");
  system($ds);
}

# See if we can recognize any of the data we got
#
sub parseperfdata {
  my %P = @_;

  my($rules,@s);

  # Slurp in map regexp file
  my $slurptmp = $/;
  undef $/;
    open FH, $Config{mapfile};
      $rules = <FH>;
    close FH;
  $/ = $slurptmp;
  #debug(5, 'INSERT $rules=' . $rules);

  # Send input to map file, and let it assign something to @s;
  $_="servicedescr:$P{servicedescr}\noutput:$P{output}\nperfdata:$P{perfdata}";
  no strict "subs";
    eval $rules;
    debug(2, "Map eval error: $@") if $@;
  use strict "subs";
  debug(3, 'INSERT perfdata not recognized' unless @s;
  return \@s;
}

### Main loop
#  - Read config and input
#  - Update rrd files
#  - Create them first if necesary.

readconfig();
my %P = parseinput($ARGV[0]);
dumpperfdata(%P);
my $S = parseperfdata(%P);
for my $s ( @$S ) {
  my $rrd = createrrd($P{hostname}, $P{servicedescr}, $P{lastcheck}--, $s);
  rrdupdate($rrd, $P{lastcheck}, $s);
}
