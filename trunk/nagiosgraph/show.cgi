#!/usr/bin/perl

# File:    $Id: show.cgi,v 1.2 2004/11/12 03:01:55 sauber Exp $
# Author:  (c) Soren Dossing, 2004
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;
use CGI qw/:standard/;

# Configuration
my $configfile = '/usr/local/etc/nagiosgraph.conf';

# Main program - change nothing below

my %Config;

# Read in configuration data
#
sub readconfig {
  # Read configuration data
  open FH, $configfile;
    while (<FH>) {
      s/\s*#.*//;    # Strip comments
      /(\w+)\s*=\s*(.*)/ and do {
        $Config{$1} = $2;
        debug(5, "CGI Config $1:$2");
      };
    }
  close FH;

  # Make sure log file can be written to
  unless ( -w $Config{logfile} ) {
    my $msg = "Log file $Config{logfile} not writable";
    print "Content-type: text/html\nExpires: 0\n\n";
    print "$msg<br>\n";
    debug (2, "CGI Config $msg");
    return undef;
  }

  # Make sure rrddir is readable
  unless ( -r $Config{rrddir} ) {
    my $msg = "rrd dir $Config{rrddir} not readable";
    print "Content-type: text/html\nExpires: 0\n\n";
    print "$msg<br>\n";
    debug (2, "CGI Config $msg");
    return undef;
  }

  return 1;
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

# URL encode a string
#
sub urlencode {
  $_[0] =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
  return $_[0];
}

# Find graphs and values
#
sub graphinfo {
  my($host,$service,@db) = @_;
  my(@rrd,$ds,$f,$dsout,@values,$hs,%H,%R);

  $hs = urlencode "${host}_${service}";

  debug(5, 'CGI @db=' . join '&', @db);

  # Determine which files to read lines from
  if ( @db ) {
    my $n = 0;
    for my $d ( @db ) {
      my($db,@lines) = split ',', $d;
      $rrd[$n]{file} = $hs . urlencode("_$db") . '.rrd';
      for my $l ( @lines ) {
        my($line,$unit) = split '~', $l;
        if ( $unit ) {
          $rrd[$n]{line}{$line}{unit} = $unit if $unit;
        } else {
          $rrd[$n]{line}{$line} = 1;
        }
      }
      $n++;
    }
    debug(4, "CGI Specified $hs db files in $Config{rrddir}: "
           . join ', ', map { $_->{file} } @rrd);
  } else {
    opendir DH, $Config{rrddir};
      @rrd = map {{ file=>$_ }} grep /^$hs/, readdir DH;
    closedir DH;
    debug(4, "CGI Listing $hs db files in $Config{rrddir}: "
           . join ', ', map { $_->{file} } @rrd);
  }

  for $f ( @rrd ) {
    if ( $f->{line} ) {
    } else {
      $ds = "$Config{rrdtool} info $Config{rrddir}/$f->{file}";
      debug(4, "CGI System $ds");
      $dsout = `$ds`;
      map { $f->{line}{$_} = 1} grep {!$H{$_}++} $dsout =~ /ds\[(.*)\]/g;
    }
    debug(5, "CGI DS $f->{file} lines:"
           . join ', ', keys %{ $f->{line} } );
  }
  return \@rrd;
}

# Choose a color for service
#
sub hashcolor {
  my$c=1;map{$c=1+($c*ord)%(216)}split//,$_[0];
  my($i,$n,$m,@h);@h=(51*int$c/36,51*int$c/6%6,51*($c%6));
  for$i(0..2){$m=$i if$h[$i]<$h[$m];$n=$i if$h[$i]>$h[$n]}
  $h[$m]=102if$h[$m]>102;$h[$n]=153if$h[$n]<153;
  $c=sprintf"%06X",$h[2]+$h[1]*256+$h[0]*16**4;
  return $c;
}

# Generate all the parameters for rrd to produce a graph
#
sub rrdline {
  my($host,$service,$G,$time) = @_;
  my($g,$f,$v,$c,$ds);

  # Identify where to pull data from and what to call it
  $ds = '';
  for $g ( @$G ) {
    $f = $g->{file};
    debug(5, "CGI file=$f");
    for $v ( keys %{ $g->{line} } ) {
      $c = hashcolor($v);
      debug(5, "CGI file=$f line=$v color=$c");
      my $sv = "$v";
      $ds .= " DEF:$sv=$Config{rrddir}/$f:$v:AVERAGE";
      $ds .= " LINE2:${sv}#$c:$sv";
      $ds .= " GPRINT:$sv:MAX:'Max\\: %6.2lf%s'";
      $ds .= " GPRINT:$sv:AVERAGE:'Avg\\: %6.2lf%s'";
      $ds .= " GPRINT:$sv:MIN:'Min\\: %6.2lf%s'";
      $ds .= " GPRINT:$sv:LAST:'Cur\\: %6.2lf%s\\n'";
    }
  }

  my $rg = "$Config{rrdtool} graph - -a PNG --start -$time $ds";
  return $rg;
}

# Write a pretty page with various graphs
#
sub page {
  my($h,$s,@db) = @_;

  # Define graph sizes
  #   Daily   =  33h =   118800s
  #   Weekly  =   9d =   777600s
  #   Monthly =   5w =  3024000s
  #   Yearly  = 400d = 34560000s
  my @T=(['dai',118800], ['week',777600], ['month',3024000], ['year',34560000]);
  
  print "<h2>Nagios Graph</h2>\n";
  print "Host: $h<br>\n";
  print "Service: $s<br>\n";
  print "Lines: @db<br>\n";
  for my $l ( @T ) {
    my($p,$t) = ($l->[0],$l->[1]);
    print "<hr>\n<h4>${p}ly graph</h4><br>\n";
    if ( @db ) {
      for my $g ( @db ) {
        my $arg = join '&', "host=$h", "service=$s", "db=$g", "graph=$t";
        print "(<small>$arg</small>)<br>\n";
        print "<img src='?$arg'><br><br>\n";
      }
    } else {
      my $arg = join '&', "host=$h", "service=$s", "graph=$t";
      print "(<small>$arg</small>)<br>\n";
      print "<img src='?$arg'><br><br>\n";
    }
  }
}

exit unless readconfig();

# Expect host, service and db input
my $host = param('host') if param('host');
my $service = param('service') if param('service');
my @db = param('db') if param('db');
my $graph = param('graph') if param('graph');

# Draw a graph or a page
if ( $graph ) {
  print "Content-type: image/png\n\n";
  # Figure out db files and line labels
  my $G = graphinfo($host,$service,@db);
  my $ds = rrdline($host,$service,$G,$graph);
  debug(4, "CGI System $ds");
  print `$ds`;
  exit;
} else {
  print "Content-type: text/html\n\n";
  print "<html>\n";
  print "<head>\n";
  print "<title>Nagiosgraph $host-$service</title>\n";
  print "<META HTTP-EQUIV=\"Refresh\" CONTENT=\"300\">\n";
  print "</head>\n";
  print "<body>\n";
  page($host,$service,@db);
  print "</body>\n</html>\n";
}
