#!/usr/bin/perl

# File:    $Id: show.cgi,v 1.34 2006/10/28 10:24:56 vanidoso Exp $
# Author:  (c) Soren Dossing, 2005
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

use strict;
use RRDs;
use CGI qw/:standard/;
use Fcntl ':flock';


# Configuration
my $configfile = '/usr/local/etc/nagiosgraph/nagiosgraph.conf';

# Main program - change nothing below

# Expect host, service and db input
my $host = param('host') if param('host');
my $service = param('service') if param('service');
my @db = param('db') if param('db');
my $graph = param('graph') if param('graph');
my $geom = param('geom') if param('geom');
my $rrdopts = param('rrdopts') if param('rrdopts');
my $fixedscale = defined(param('fixedscale')) ? 1 : 0; 

my %Config;

# Read in configuration data
#
sub readconfig {
  # If config file not found die gracefully
  unless ( -r $configfile ) {
    my $msg = "Config file not found or not readable";
    HTMLerror($msg);
    return undef;
  }

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

   # Make sure log file can be written to
  unless ( -w $Config{logfile} ) {
    my $msg = "Log file $Config{logfile} not writable";
    HTMLerror($msg);
    return undef;
  }

  # Make sure rrddir is readable
  unless ( -r $Config{rrddir} ) {
    my $msg = "rrd dir $Config{rrddir} not readable";
    HTMLerror($msg);
    debug (2, "Config $msg");
    return undef;
  }

  # Configuration is sane enough, open logfile if debug is set
   if ($Config{debug} > 0) {
  open LOG, ">>$Config{logfile}" or (HTMLerror("Log: $Config{logfile} failed to open!") && return undef);
   }

  return 1;
}

sub HTMLerror {
    my $msg = join(" ", @_);
    # It might be an error but it doesn't have to look as one
    my $errstyle=<<ERR;
    div.error {
        border: solid 1px #cc3333;
        background-color: #fff6f3;
        padding: 0.75em;
        }
ERR
    print header(-type => "text/html", -expires => 0);
    print start_html(-id=>"nagiosgraph",-title=>'NagiosGraph Error Page');
    print '<STYLE TYPE="text/css">' . $errstyle . '</STYLE>';
    print div({-class => "error"}, "Nagiosgraph has detected an error in the configuration file: $configfile", br(),
              $msg);
    print end_html();
}
# Write debug information to log file
#
sub debug {
  my($l, $text) = @_;
  if ( $l <= $Config{debug} ) {
    $l = qw(none critical error warn info debug)[$l];
    # Get a lock on the LOG file (blocking call)
    flock(LOG,LOCK_EX);
      print LOG scalar localtime . ' $RCSfile: show.cgi,v $ $Revision: 1.34 $ '."$l - $text\n";
    flock(LOG,LOCK_UN);
  }
}

# URL encode a string
#
sub urlencode {
  $_[0] =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
  return $_[0];
}

sub urldecode {
  $_[0] =~ s/%([0-9A-F]{2})/chr(hex($1))/eg;
  return $_[0];
}

# Get list of matching rrd files
#
sub dbfilelist {
  my($host,$service) = @_;
  my $hs = urlencode "${host}_${service}";
  my @rrd;
  opendir DH, $Config{rrddir};
    @rrd = grep s/^${hs}_(.+)\.rrd$/$1/, readdir DH;
  closedir DH;
  return @rrd;
}

sub getgraphlist{
  # Builds a hash for available servers/services to graph
  my %servers;
  opendir RRDF, $Config{rrddir};
  my @rrdfiles = grep /.rrd$/ , readdir RRDF;
  # Iterate through all the .rrd files in the directory
  for my $f ( @rrdfiles ) {
    # Get the host and service name. Assumes _ separator (not in host/svc name!!)
    my($host, $svc) = split(/_/, $f, 3);
    $servers{$host}{'NAME'} = (urldecode($host));
    push @{$servers{$host}{'SERVICES'}}, urldecode($svc);
  }
  return %servers;

}

sub servmenu{
  # Create server menu and associated service submenu skel
  # Selecting a new server shows the associated  services menu
  # Selecting a new service reloads the page with the new graphs
  my @svrlist = sort (@_);
   print start_form(-name=>'menuform'),
        "Select server: ",
        popup_menu(-name=>'servidors',
                   -value=>\@svrlist,
                   -default=>"$host",
                   -onChange=>"setOptionText(this)"),
        "Select service: ",
        popup_menu(-name=>'services',
                       -value=>["--"],
                       -onChange=>"jumpto(this)"),
        checkbox(-name=>'FixedScale',
                 -checked=>$fixedscale),
        end_form;
}

# Find graphs and values
#
sub graphinfo {
  my($host,$service,@db) = @_;
  my(@rrd,$ds,$f,$dsout,@values,$hs,%H,%R);

  $hs = urlencode "${host}_${service}";

  debug(5, '@db=' . join '&', @db);

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
    debug(4, "Specified $hs db files in $Config{rrddir}: "
           . join ', ', map { $_->{file} } @rrd);
  } else {
    @rrd = map {{ file=>$_ }}
           map { "${hs}_${_}.rrd" }
           dbfilelist($host,$service);
    debug(4, "Listing $hs db files in $Config{rrddir}: "
           . join ', ', map { $_->{file} } @rrd);
  }

  for $f ( @rrd ) {
    unless ( $f->{line} ) {
      $ds = RRDs::info "$Config{rrddir}/$f->{file}";
      debug(2, "RRDs::info ERR " . RRDs::error) if RRDs::error;
      map { $f->{line}{$_} = 1}
      grep {!$H{$_}++}
      map { /ds\[(.*)\]/; $1 }
      grep /ds\[(.*)\]/,
      keys %$ds;
    }
    debug(5, "DS $f->{file} lines: "
           . join ', ', keys %{ $f->{line} } );
  }
  return \@rrd;
}

# Choose a color for service
#
sub hashcolor {
  my$c=$Config{colorscheme};map{$c=(51*$c+ord)%(216)}split//,"$_[0]x";
  my($i,$n,$m,@h);@h=(51*int$c/36,51*int$c/6%6,51*($c%6));
  for$i(0..2){$m=$i if$h[$i]<$h[$m];$n=$i if$h[$i]>$h[$n]}
  $h[$m]=102if$h[$m]>102;$h[$n]=153if$h[$n]<153;
  $c=sprintf"%06X",$h[2]+$h[1]*256+$h[0]*16**4;
  return $c;
}

# Generate all the parameters for rrd to produce a graph
#
sub rrdline {
  my($host,$service,$geom,$rrdopts,$G,$time) = @_;
  my($g,$f,$v,$c,@ds);

  @ds = ('-', '-a', 'PNG', '--start', "-$time");
  # Identify where to pull data from and what to call it
  for $g ( @$G ) {
    $f = $g->{file};
    debug(5, "file=$f");

    # Compute the longest label length
    my $longest = (sort map(length,keys(%{ $g->{line} })))[-1];

    for $v ( sort keys %{ $g->{line} } ) {
      $c = hashcolor($v);
      debug(5, "file=$f line=$v color=$c");
      my $sv = "$v";
      my $label = sprintf("%-${longest}s", $sv);
      push @ds , "DEF:$sv=$Config{rrddir}/$f:$v:AVERAGE"
               , "LINE2:${sv}#$c:$label";
      if ($fixedscale) {
        push @ds, "GPRINT:$sv:MAX:Max\\: %6.2lf"
               , "GPRINT:$sv:AVERAGE:Avg\\: %6.2lf"
               , "GPRINT:$sv:MIN:Min\\: %6.2lf"
               , "GPRINT:$sv:LAST:Cur\\: %6.2lf\\n";
      } else {
        push @ds, "GPRINT:$sv:MAX:Max\\: %6.2lf%s"
               , "GPRINT:$sv:AVERAGE:Avg\\: %6.2lf%s"
               , "GPRINT:$sv:MIN:Min\\: %6.2lf%s"
               , "GPRINT:$sv:LAST:Cur\\: %6.2lf%s\\n";
      }
    }
  }

  # Dimensions of graph if geom is specified
  if ( $geom ) {
    my($w,$h) = split 'x', $geom;
    push @ds, '-w', $w, '-h', $h;
  }
  # Additional parameters to rrd graph, if specified
  if ( $rrdopts ) {
    push @ds, split /\s+/, $rrdopts;
  }
  if ( $fixedscale ) {
    push @ds, "-X", "0";
  }
  return @ds;
}

# Write a pretty page with various graphs
#
sub page {
  my($h,$s,$d,$o,@db) = @_;

  my $offset = 0;
  $offset = param('offset') if param('offset');
  if ( $offset <= 0 ) { $offset = 0 }

  # Reencode rrdopts
  $o = urlencode $o;
  if ( $o ) { $o = $o . " " }

  # Detect available db files
  @db = dbfilelist($h,$s) unless @db;
  debug(5, "dbfilelist @db");

  # Define graph sizes
  #   Daily   =  33h =   118800s
  #   Weekly  =   9d =   777600s
  #   Monthly =   5w =  3024000s
  #   Yearly  = 400d = 34560000s
  my @T=(['dai',118800,86400], ['week',777600,604800], ['month',3024000,2592000], ['year',34560000,31536000]);
  print h1("Nagiosgraph");
  print p("Performance data for ".strong("Host: ").tt($h).' &#183; '.strong("Service: ").tt($s));
  for my $l ( @T ) {
    my($p,$t) = ($l->[0],$l->[1]);
    print a({-id=>$p});
    print h2(ucfirst $p . "ly");
    my $url = join '&', "host=$h", "service=$s",
       "geom=$d", "rrdopts=$o", map { "db=$_" } @db;
    print a( {-href=>"?$url&offset=".($offset+$l->[2])."#".$p}, "previous"), " / ", a( {-href=>"?$url&offset=".($offset-$l->[2]."#".$p) }, "next"), "<BR>";
    if ( @db ) {
      for my $g ( @db ) {
        my $arg = join '&', "host=$h", "service=$s", "db=$g", "graph=$t",
                            "geom=$d", "rrdopts=$o";
	$arg .= "&fixedscale" if ($fixedscale);
        my @gl = split ',', $g;
        my $ds = urldecode shift @gl; 
        print div({-class => "graphs"}, img( {-src => "?$arg%2Dsnow%2D$t%2D$offset%20%2Denow%2D$offset", -alt => "Graph"} ) );
        print div({-class => "graph_description"}, cite(strong($ds).br().small(join(", ", @gl))));
      }
    } else {
      my $arg = join '&', "host=$h", "service=$s", "graph=$t",
                          "geom=$d", "rrdopts=$o";
      print div({-class => "graphs"}, img( {-src => "?$arg", -alt => "Graph"} ) );
    }
  }
}

exit unless readconfig();

# Draw a graph or a page
if ( $graph ) {
  $| = 1; # Make sure headers arrive before image data
  print header(-type => "image/png");
  # Figure out db files and line labels
  my $G = graphinfo($host,$service,@db);
  my @ds = rrdline($host,$service,$geom,$rrdopts,$G,$graph);
  debug(4, "RRDs::graph ". join ' ', @ds);
  RRDs::graph(@ds);
  debug(2, "RRDs::graph ERR " . RRDs::error) if RRDs::error;
  if (fileno(LOG)) {
     close LOG;
  }
  exit;
} else {
  my @style;
  if ($Config{stylesheet}) {
    @style = ( -style => {-src => "$Config{stylesheet}"} );
  }
# GET LIST OF SERVERS/SERVICES
  my %navmenu = getgraphlist;

  print header, start_html(-id=>"nagiosgraph", -title => "nagiosgraph: $host-$service",
    -head => meta({ -http_equiv => "Refresh", -content => "300" }),
    @style
    );
# Create Javascript Arrays for client-side menu navigation
  print '<script type="text/javascript">'. "\n";
  foreach my $system (sort keys %navmenu) {
    my $crname = $navmenu{$system}{'NAME'};
    # Javascript doesn't like "-" characters in variable names
    $crname =~s/-/_/g;
    print "var ". $crname." = new Array(\"" . join ('","', sort(@{$navmenu{$system}{'SERVICES'}})) . "\");" ;
    print "\n";
  }

  # Bulk Javascript code
my $JSCRIPT=<<END;

  //Swaps the secondary (services) menu content after a server is selected
  function setOptionText(element) {
     var server = element.options[element.selectedIndex].text;
     //Converts - in hostnames to _ for matching array name
     server = server.replace(/-/g,"_");
     var svchosen = window.document.menuform.services;
     var opciones = eval(server);
     // Adjust service dropdown menu length depending on host selected
     svchosen.length=opciones.length + 1;
     // Hosts with only 1 service couldn't fire onChange() so we add a blank entry
     svchosen.options[0].text = "--";
     for (i=0; i < opciones.length; i++){
         svchosen.options[i+1].text = opciones[i];
     }
  }

  //Once a service is selected this function loads the new page
  function jumpto(element) {
    var svr = escape (document.menuform.servidors.value);
    var svc = escape (element.options[element.selectedIndex].text);
    var newURL = location.pathname + "?host=";
    newURL += svr + "&" + "service=" + svc;
    newURL += getURLparams();
    window.location.assign ( newURL ) ;
  }

  //Auxiliary URL builder function for "jumpto" keeping the params
  function getURLparams() {
     var query=this.location.search.substring(1);
     var myParams="";
     if (query.length > 0){
       var params = query.split("&");

       for (var i=0 ; i<params.length ; i++){
           var pos = params[i].indexOf("=");
           var name = params[i].substring(0, pos);
           var value = params[i].substring(pos + 1);

           //Append params (except host & service and fixedscale)
           if ( name != "host" && name != "service" && value != "fixedscale") {
              myParams+= "&" + name + "=" + value;
           }
       }

     }
     // Keep track of fixedscale parameter
     if ( document.menuform.FixedScale.checked) {
        myParams+= "&" + "fixedscale";
     }
     return (myParams);
   }

  //Forces the service menu to be filled with the correct entries
  //when the page loads
  function preloadSVC(name) {
      var notfound = true;
      var i = 0;
      while (notfound && i < document.menuform.servidors.length) {
          if (document.menuform.servidors.options[i].text == name) {
             notfound = false;
             document.menuform.servidors.selectedIndex = i;
          }
          i++;
      }
      setOptionText(document.menuform.servidors);
  }

END
  print $JSCRIPT;
  print '</script>'."\n";

  # CREATE SERVER MENU
  servmenu(keys %navmenu);
  # Preload selected host services
  print '<script type="text/javascript">'. "\n";
  print 'var prtHost="' . $host . '";' ;
  print 'preloadSVC(prtHost);' ;
  print '</script>'."\n";

  page($host,$service,$geom,$rrdopts,@db);
  print div({-id => "footer"}, hr(), small( "Created by ". a( {-href=>"http://nagiosgraph.sf.net/"}, "nagiosgraph"). "." ));
  print end_html();
}
if (fileno(LOG)) {
    close LOG;
}
