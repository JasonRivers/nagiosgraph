#!/usr/bin/perl

# File:    $Id: insert.pl,v 1.15 2005/10/06 00:24:54 sauber Exp $
# Author:  (c) Soren Dossing, 2004
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;
use RRDs;

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
      /^(\w+)\s*=\s*(.*?)\s*$/ and do {
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
    $ds = "$Config{rrddir}/$f --start $start";
    for ( @$labels ) {
      ($v,$t) = ($_->[0],$_->[1]);
      my $u = $t eq 'DERIVE' ? '0' : 'U' ;
      $ds .= " DS:$v:$t:$Config{heartbeat}:$u:U";
    }
    $ds .= " RRA:AVERAGE:0.5:1:600";
    $ds .= " RRA:AVERAGE:0.5:6:700";
    $ds .= " RRA:AVERAGE:0.5:24:775";
    $ds .= " RRA:AVERAGE:0.5:288:797";

    my @ds = split /\s+/, $ds;
    debug(4, "INSERT RRDs::create $ds");
    RRDs::create(@ds);
    debug(2, "INSERT RRDs::create ERR " . RRDs::error) if RRDs::error;
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
  debug(4, "INSERT RRDs::update ". join ' ', @ds);
  RRDs::update(@ds);
  debug(2, "INSERT RRDs::update ERR " . RRDs::error) if RRDs::error;
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
    undef $@;
    eval $rules;
    debug(2, "Map eval error: $@") if $@;
  use strict "subs";
  debug(3, 'INSERT perfdata not recognized') unless @s;
  return \@s;
}

### Main loop
#  - Read config and input
#  - Update rrd files
#  - Create them first if necesary.

readconfig();
debug(4, 'INSERT nagiosgraph spawned');
my @inputlines;
if ( $ARGV[0] ) {
  @inputlines = $ARGV[0];
} elsif ( defined $Config{perflog} ) {
  open PERFLOG, $Config{perflog};
    @inputlines = <PERFLOG>;
  close PERFLOG
} else {
  debug(1, 'INSERT No inputdata. Exiting.');
  exit 1;
}
for my $l ( @inputlines ) {
  my %P = parseinput($l);
  dumpperfdata(%P);
  my $S = parseperfdata(%P);
  for my $s ( @$S ) {
    my $rrd = createrrd($P{hostname}, $P{servicedescr}, $P{lastcheck}-1, $s);
    rrdupdate($rrd, $P{lastcheck}, $s);
  }
}
