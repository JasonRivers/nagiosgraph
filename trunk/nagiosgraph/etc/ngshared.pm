#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

## no critic (RegularExpressions)
## no critic (ProhibitCascadingIfElse)
## no critic (ProhibitExcessComplexity)
## no critic (ProhibitDeepNests)

use strict;
use warnings;
use Carp;
use CGI qw(escape unescape);
use Data::Dumper;
use English qw(-no_match_vars);
use Fcntl qw(:DEFAULT :flock);
use File::Find;
use File::Basename;
use RRDs;
use POSIX;

## no critic (ProhibitConstantPragma)
use constant DBCRT => 1;
use constant DBERR => 2;
use constant DBWRN => 3;
use constant DBINF => 4;
use constant DBDEB => 5;

use constant GRAPHWIDTH => 600;
use constant PROG => basename($PROGRAM_NAME);
use constant NAGIOSGRAPHURL => 'http://nagiosgraph.wiki.sourceforge.net/';
use constant ERRSTYLE => '.error { padding: 0.75em; background-color: #fff6f3; border: solid 1px #cc3333; }';
use constant ERRMSG => 'Nagiosgraph has detected an error in the configuration file: ';
use constant DBLISTROWS => 3;
use constant PERIODLISTROWS => 5;

# default geometries
use constant GEOMETRIES => '500x80,650x150,1000x200';
# default custom color palette
use constant COLORS => 'D05050,D08050,D0D050,50D050,50D0D0,5050D0,D050D0';

use vars qw(%Config %Navmenu $colorsub $VERSION %Ctrans $LOG); ## no critic (ProhibitPackageVars)
$colorsub = -1; ## no critic (ProhibitMagicNumbers)
$VERSION = '1.4.1';

my $CFGNAME = 'nagiosgraph.conf';
my @PERIODS = qw(day week month quarter year);

# Debug/logging support #######################################################
# Write information to STDERR
sub stacktrace {
    my $msg = shift;
    warn "$msg\n";
    my $max_depth = 30; ## no critic (ProhibitMagicNumbers)
    my $ii = 1;
    warn "--- Begin stack trace ---\n";
    while ((my @call_details = (caller $ii++)) && ($ii < $max_depth)) {
      warn "$call_details[1] line $call_details[2] in function $call_details[3]\n";
    }
    warn "--- End stack trace ---\n";
    return;
}

# Write debug information to log file
sub debug {
    my ($level, $text) = @_;
    if (not defined $Config{debug}) { $Config{debug} = 0; }
    return if ($level > $Config{debug});
    $level = qw(none critical error warn info debug)[$level];
    my $message = join q( ), scalar (localtime), PROG, $level, $text;
    if (not fileno $LOG) {
        stacktrace($message);
        return;
    }
    # Get a lock on the LOG file (blocking call)
    my $rval = eval {
        flock $LOG, LOCK_EX;
        print ${LOG} "$message\n" or carp("could not write to LOG: $OS_ERROR");
        flock $LOG, LOCK_UN;
        return 0;
    };
    if ($EVAL_ERROR or $rval) {
        stacktrace($message);
    }
    return;
}

# Dump to log the files read from Nagios
sub dumper {
    my ($level, $label, $vals) = @_;
    return if ($level > $Config{debug});
    my $dd = Data::Dumper->new([$vals], [$label]);
    $dd->Indent(1);
    my $out = $dd->Dump();
    chomp $out;
    debug($level, substr $out, 1);
    return;
}

sub init {
    my ($app) = @_;

    readconfig('read');
    if (defined $Config{ngshared}) {
        debug(DBCRT, $Config{ngshared});
        htmlerror($Config{ngshared});
        exit;
    }
    
    my $cgi = new CGI;  ## no critic (ProhibitIndirectSyntax)
    $cgi->autoEscape(0);
    
    my $params = getparams($cgi);
    getdebug($app, $params->{host}, $params->{service});
    
    dumper(DBDEB, 'config', \%Config);
    dumper(DBDEB, 'params', $params);

    return $cgi, $params;
}

# we must have a type (the CGI script that is being invoked).  we may or may
# not have a host and/or service.
sub getdebug {
    my ($type, $server, $service) = @_;
    if (not defined $type) {
        debug(DBWRN, 'no type defined, enabling debug');
        $Config{debug} = DBDEB;
        return;
    }

    if (not $server) { $server = q(); }
    if (not $service) { $service = q(); }
    debug(DBDEB, "getdebug($type, $server, $service)");

    # All this allows debugging one service, or one server,
    # or one service on one server, for each line of input.
    my $base = 'debug_' . $type;
    my $host = 'debug_' . $type . '_host';
    my $serv = 'debug_' . $type . '_service';
    if (defined $Config{$base}) {
        debug(DBDEB, "getdebug found $base");
        if (defined $Config{$host}) {
            debug(DBDEB, "getdebug found $host");
            if ($Config{$host} eq $server) {
                if (defined $Config{$serv}) {
                    debug(DBDEB, "getdebug found $serv with $host");
                    if ($Config{$serv} eq $service) {
                        $Config{debug} = $Config{$base};
                    }
                } else {
                    $Config{debug} = $Config{$base};
                }
            }
        } elsif (defined $Config{$serv}) {
            debug(DBDEB, "getdebug found $serv");
            if ($Config{$serv} eq $service) {
                $Config{debug} = $Config{$base};
            }
        } else {
            $Config{debug} = $Config{$base};
        }
    }
    return;
}

# HTTP support ################################################################
# get parameters from CGI
#
# these are the CGI arguments that we understand:
#
# host=host_name (from nagios configuration)
# service=service_description (from nagios configuration)
# db=dataset (may be comma-delimited or specified multiple times)
# geom=WxH
# rrdopts=
# offset=
# period=(day,week,month,quarter,year)
# graphonly
# hidelegend
# fixedscale
# showtitle
# showgraphtitle
# showdesc
# expand_controls
# expand_period=(day,week,month,quarter,year)
#
sub getparams {
    my ($cgi) = @_;
    my %rval;

    # these flags are either string or array
    for my $ii (qw(host service db group graph geom rrdopts offset period expand_period)) {
        if ($cgi->param($ii)) {
            if (ref($cgi->param($ii)) eq 'ARRAY') {
                my @rval = $cgi->param($ii);
                $rval{$ii} = \@rval;
            } elsif ($ii eq 'db') {
                $rval{$ii} = [$cgi->param($ii),];
            } else {
                $rval{$ii} = $cgi->param($ii);
            }
        } else {
            $rval{$ii} = q();
        }
    }

    # these flags are boolean.  if they exist, then consider it true.
    for my $ii (qw(expand_controls fixedscale showgraphtitle showtitle showdesc graphonly hidelegend)) {
        $rval{$ii} = q();
        for my $jj ($cgi->param()) {
            if ($jj eq $ii) {
                $rval{$ii} = 1;
                last;
            }
        }
    }

    if (not $rval{host}) { $rval{host} = q(); }
    if (not $rval{service}) { $rval{service} = q(); }
    if (not $rval{group}) { $rval{group} = q(); }
    if (not $rval{db}) {
        if ($rval{host} ne q() && $rval{host} ne q(-)
            && $rval{service} ne q() && $rval{service} ne q(-)) {
            $rval{db} = dbfilelist($rval{host}, $rval{service});
        } else {
            my @db;
            $rval{db} = \@db;
        }
    }

    if ($rval{offset}) { $rval{offset} = int $rval{offset}; }
    if (not $rval{offset} or $rval{offset} <= 0) { $rval{offset} = 0; }

    return \%rval;
}

# return two strings: period and expand_period.  each is a comma-delimited
# list of day, week, month, quarter, year.  first try to get the value from
# the parameters.  if that fails, use whatever is defined in config.
#
# CGI uses comma-delimited, old configs used space-delimited, so we deal with
# either.  we ensure the result is comma-delimited.
sub initperiods {
    my ($context, $opts) = @_;
    if ($context eq 'both') {
        $context = 'all';
    }

    my $s = $opts->{period};
    my $c = $Config{'time' . $context};
    my $p = q();
    if (defined $c && $c ne q()) { $p = $c; }
    if (defined $s && $s ne q()) { $p = $s; }
    $p =~ s/ /,/g; ## no critic (RegularExpressions)

    $s = $opts->{expand_period};
    $c = $Config{'expand_time' . $context};
    my $ep = q();
    if (defined $c && $c ne q()) { $ep = $c; }
    if (defined $s && $s ne q()) { $ep = $s; }
    $ep =~ s/ /,/g; ## no critic (RegularExpressions)

    return ($p, $ep);
}

sub getstyle {
    my @style;
    if ($Config{stylesheet}) {
        @style = (-style => {-src => "$Config{stylesheet}"});
    }
    return @style;
}

sub getrefresh {
    my ($cgi) = @_;
    my $refresh = (defined $Config{refresh})
        ? $cgi->meta({ -http_equiv => 'Refresh',
                       -content => "$Config{refresh}" })
        : q();
    return $refresh;
}

# configure parameters with something that we are sure will work.  grab values
# from the supplied default object.  if there are any gaps, use values from the
# configuration.
sub cfgparams {
    my($p, $dflt, $service) = @_;

    foreach my $ii (qw(expand_controls fixedscale showgraphtitle showtitle showdesc hidelegend graphonly)) {
        if ($dflt->{$ii} ne q()) {
            $p->{$ii} = $dflt->{$ii};
        } elsif(defined $Config{$ii}) {
            $p->{$ii} = $Config{$ii} eq 'true' ? 1 : 0;
        } else {
            $p->{$ii} = 0;
        }
    }

    if ($dflt->{period} ne q()) {
        $p->{period} = $dflt->{period};
    }
    if ($dflt->{expand_period} ne q()) {
        $p->{expand_period} = $dflt->{expand_period};
    }
    if ($dflt->{geom} ne q()) {
        $p->{geom} = $dflt->{geom};
    }
    $p->{offset} = $dflt->{offset} ne q() ? $dflt->{offset} : 0;

    if ($service) {
        $p->{rrdopts} = (defined $Config{rrdopts}{$service})
            ? $Config{rrdopts}{$service} : $dflt->{rrdopts};
    }

    return;
}

sub arrayorstring {
    my ($opts, $param) = @_;
    debug(DBDEB, "arrayorstring($opts, $param)");
    dumper(DBDEB, 'arrayorstring opts', $opts);
    my $rval = q();
    if (exists $opts->{$param} and $opts->{$param}) {
        if (ref($opts->{$param}) eq 'ARRAY') {
            for my $ii (@{$opts->{$param}}) {
                next if not defined $ii;
                $rval .= "&$param=$ii";
            }
        } else {
            $rval .= "&$param=" . $opts->{$param};
        }
    }
    return $rval;
}

sub buildurl {
    my ($host, $service, $opts) = @_;
    if (not $host or not $service) {
        debug(DBWRN, 'buildurl called without host or service');
        if ($host) { debug(DBDEB, "buildurl got host: $host"); }
        if ($service) { debug(DBDEB, "buildurl got host: $service"); }
        return q();
    }
    debug(DBDEB, "buildurl($host, $service)");
    dumper(DBDEB, 'buildurl opts', $opts);
    my $url = join q(&), 'host=' . $host, 'service=' . $service;
    $url .= arrayorstring($opts, 'db') .
            arrayorstring($opts, 'graph') .
            arrayorstring($opts, 'geom');
    if (exists $opts->{fixedscale} and $opts->{fixedscale}) {
        $url .= '&fixedscale';
    }
    $url .= arrayorstring($opts, 'rrdopts');
    debug(DBDEB, "buildurl returning $url");
    return $url;
}

# construct the filename to RRD data file.  this requires at least a valid
# host and service to work.
sub mkfilename {
    my ($host, $service, $db, $quiet) = @_;
    if (not $host or not $service) {
        debug(DBWRN, 'cannot construct filename: missing host or service');
        return 'BOGUSDIR', 'BOGUSFILE';
    }
    $db ||= q();
    $quiet ||= 0;
    if (not $quiet) { debug(DBDEB, "mkfilename($host, $service, $db)"); }
    my ($directory, $filename) = $Config{rrddir};
    if (not $quiet) { debug(DBDEB + 1, "mkfilename: dbseparator: '$Config{dbseparator}'"); }
    if ($Config{dbseparator} eq 'subdir') {
        $directory .=  q(/) . $host;
        if (not -e $directory) { # Create host specific directories
            debug(DBINF, "mkfilename: creating directory $directory");
            mkdir $directory, 0775; ## no critic (ProhibitMagicNumbers)
            if (not -w $directory) { croak "$directory not writable"; }
        }
        if ($db) {
            $filename = escape("${service}___${db}") . '.rrd';
        } else {
            $filename = escape("${service}___");
        }
    } else {
        # Build filename for traditional separation
        if ($db) {
            return $directory, escape("${host}_${service}_${db}") . '.rrd'
        } else {
            $filename = escape("${host}_${service}_");
        }
    }
    if (not $quiet) { debug(DBDEB, "mkfilename: dir=$directory file=$filename"); }
    return $directory, $filename;
}

# this is completely self-contained so that it can be called no matter what
# error we encounter.  stylesheet is hard-coded so no dependencies on anything
# external.
sub htmlerror {
    my ($msg, $bconf) = @_;
    my $cgi = new CGI; ## no critic (ProhibitIndirectSyntax)
    print $cgi->header(-type => 'text/html', -expires => 0) .
        $cgi->start_html(-id => 'nagiosgraph',
                         -title => 'NagiosGraph Error',
                         -head => $cgi->style({-type => 'text/css'},
                                              ERRSTYLE)) or
        debug(DBCRT, "could not write to STDOUT: $OS_ERROR");
    if (not $bconf) {
        print $cgi->div({-class => 'error'},
                        ERRMSG . $INC[0] . q(/) . $CFGNAME) . "\n" or
            debug(DBCRT, "could not write to STDOUT: $OS_ERROR");
    }
    print $cgi->div({-class=>'error'}, $msg) . "\n" . $cgi->end_html() or
        debug(DBCRT, "could not write to STDOUT: $OS_ERROR");
    return;
}

# Color subroutines ###########################################################
# Choose a color for service
sub hashcolor {
    my $label = shift;
    my $color = shift;
    $color ||= $Config{colorscheme};
    debug(DBDEB, "hashcolor($color)");

    # color 9 is user defined (or the default rainbow if nothing userdefined).
    if ($color == 9) { ## no critic (ProhibitMagicNumbers)
        # Wrap around, if we have more values than given colors
        $colorsub++;
        if ($colorsub >= scalar @{$Config{colors}}) { $colorsub = 0; }
        debug(DBDEB, 'hashcolor: returning color = ' . $Config{colors}[$colorsub]);
        return $Config{colors}[$colorsub];
    }

    ## no critic (ProhibitMagicNumbers)
    my ($min, $max, $rval, @rgb) = (0, 0);
    # generate a starting value
    map { $color = (51 * $color + ord) % (216) } split //, $label;
    # turn the starting value into a red, green, blue triplet
    @rgb = (51 * int($color / 36), 51 * int($color / 6) % 6, 51 * ($color % 6));
    for my $ii (0 .. 2) {
        if ($rgb[$ii] < $rgb[$min]) { $min = $ii; }
        if ($rgb[$ii] > $rgb[$max]) { $max = $ii; }
    }
    # expand the color range, if needed
    if ($rgb[$min] > 102) { $rgb[$min] = 102; }
    if ($rgb[$max] < 153) { $rgb[$max] = 153; }
    # generate the hex color value
    $color = sprintf '%06X', $rgb[0] * 16 ** 4 + $rgb[1] * 256 + $rgb[2];
    debug(DBDEB, "hashcolor: returning color = $color");
    return $color;
}

# Configuration subroutines ###################################################
# parse the min/max list into a dictionary for quick lookup
sub listtodict {
    my ($val, $sep, $commasplit) = @_;
    $sep ||= q(,);
    $commasplit ||= 0;
    debug(DBDEB, "listtodict($val, $sep, $commasplit)");
    my (%rval);
    $Config{$val} ||= q();
    if (ref $Config{$val} eq 'HASH') {
        debug(DBDEB, 'listtodict returning existing hash');
        return $Config{$val};
    }
    $Config{$val . 'sep'} ||= $sep;
    debug(DBDEB, 'listtodict splitting "' . $Config{$val} . '" on "' . $Config{$val . 'sep'} . q(")); # "
    foreach my $ii (split $Config{$val . 'sep'}, $Config{$val}) {
        if ($val eq 'hostservvar') {
            my @data = split /,/, $ii;
            dumper(DBDEB, 'listtodict hostservvar data', \@data);
            if (defined $rval{$data[0]}) {
                if (defined $rval{$data[0]}->{$data[1]}) {
                    $rval{$data[0]}->{$data[1]}->{$data[2]} = 1;
                } else {
                    $rval{$data[0]}->{$data[1]} = {$data[2] => 1};
                }
            } else {
                $rval{$data[0]} = {$data[1] => {$data[2] => 1}};
            }
        } elsif ($commasplit) {
            my @data = split /,/, $ii;
            dumper(DBDEB, 'listtodict commasplit data', \@data);
            $rval{$data[0]} = $data[1];
        } else {
            $rval{$ii} = 1;
        }
    }
    $Config{$val} = \%rval;
    dumper(DBDEB, 'listtodict rval', $Config{$val});
    return $Config{$val};
}

# Subroutine for checking that the directory with RRD file is not empty
sub checkdirempty {
    my $directory = shift;
    if (not opendir DIR, $directory) {
        debug(DBCRT, "couldn't open: $OS_ERROR");
        return 0;
    }
    my @files = readdir DIR;
    my $size = scalar @files;
    closedir DIR;
    return 0 if $size > 2;
    return 1;
}

sub readfile {
    my ($filename, $hashref, $debug) = @_;
    $debug ||= 0;
    debug(DBDEB, "readfile($filename, $debug)");
    my ($FH);
    open $FH, '<', $filename or close $FH and
        ($Config{ngshared} = "$filename not found") and
        carp $Config{ngshared};
    my ($key, $val);
    while (<$FH>) {
        s/\s*#.*//;             # Strip comments
        s/^\s+//;               # removes leading whitespace
        /^([^=]+) \s* = \s* (.*) $/x and do { # splits into key=val pairs
            $key = $1;
            $val = $2;
            $key =~ s/\s+$//;   # removes trailing whitespace
            $val =~ s/\s+$//;   # removes trailing whitespace
            $hashref->{$key} = $val;
            if ($key eq 'debug' and defined $debug) { $Config{debug} = $debug; }
            debug(DBDEB, "$filename $key:$val");
        };
    }
    close $FH or debug(DBCRT, "Error closing $INC[0]/$CFGNAME: $OS_ERROR");
    return;
}

sub checkrrddir {
    my ($rrdstate) = @_;
    if ($rrdstate eq 'write') {
        # Make sure rrddir exist and is writable
        if (not -w $Config{rrddir}) {
            mkdir $Config{rrddir} or $Config{ngshared} = $OS_ERROR;
        }
        if (not -w $Config{rrddir} and defined $Config{ngshared}) {
            $Config{ngshared} = "rrd dir $Config{rrddir} not writable";
        }
    } else {
        # Make sure rrddir is readable and not empty
        if (-r $Config{rrddir} ) {
            if (checkdirempty($Config{rrddir})) {
                $Config{ngshared} = "$Config{rrddir} is empty";
            }
            return;
        }
        $Config{ngshared} = "rrd dir $Config{rrddir} not readable";
    }
    return;
}

# Read in the config file, check the log file and rrd directory
sub readconfig {
    my ($rrdstate, $debug) = @_;
    # Read configuration data
    if ($debug) {
        open $LOG, '>&=STDERR' or carp "$OS_ERROR\n"; ## no critic (RequireBriefOpen)
        $Config{debug} = $debug;
        dumper(DBDEB, 'INC', \@INC);
        debug(DBDEB, "readconfig opening $INC[0]/$CFGNAME");
    } else {
        $debug = 1;
    }
    readfile($INC[0] . q(/) . $CFGNAME, \%Config, $debug);

    # From Craig Dunn, with modifications by Alan Brenner to use an eval, to
    # allow continuing on failure to open the file, while logging the error
    if ( defined $Config{rrdoptsfile} ) {
        $Config{rrdopts} = {};
        my $rval = eval {
            readfile($Config{rrdoptsfile}, $Config{rrdopts});
            return 0;
        };
        if ($rval or $EVAL_ERROR) { debug(DBCRT, $rval . q( ) . $EVAL_ERROR); }
    }

    foreach my $ii ('maximums', 'minimums', 'withmaximums', 'withminimums',
                    'altautoscale', 'nogridfit', 'logarithmic', 'negate',
                    'plotasLINE1', 'plotasLINE2', 'plotasLINE3',
                    'plotasAREA', 'plotasTICK') {
        listtodict($ii, q(,));
    }
    foreach my $ii ('hostservvar', 'lineformat') {
        listtodict($ii, q(;));
    }
    foreach my $ii ('altautoscalemax', 'altautoscalemin') {
        listtodict($ii, q(;), 1);
    }

    # set these only if they have not been specified in the config file
    foreach my $ii (['timeall', 'day week month'],
                    ['timehost', 'day'],
                    ['timeservice', 'day'],
                    ['expand_timeall', 'day week month'],
                    ['expand_timehost', 'day'],
                    ['expand_timeservice', 'day'],
                    ['geometries', GEOMETRIES],
                    ['colors', COLORS],) {
        if (not $Config{$ii->[0]}) { $Config{$ii->[0]} = $ii->[1]; }
    }
    $Config{colors} = [split /\s*,\s*/, $Config{colors}];

    # If debug is set make sure we can write to the log file
    if ($Config{debug} > 0) {
        if (not open $LOG, '>>', $Config{logfile}) { ## no critic (RequireBriefOpen)
            return open $LOG, '>&=STDERR' and ## no critic (RequireBriefOpen)
                $Config{ngshared} = "cannot append to $Config{logfile}";
        }
        dumper(DBDEB, 'Config', \%Config);
    }
    checkrrddir($rrdstate);
    if ($Config{dbfile}) {
        require $Config{dbfile};
        $Config{userdb} = $Config{rrddir} . '/users';
    }
    return;
}

sub parsedb {
    my ($line) = @_;
    $line =~ s/^&db=//;
    my @db = split /&db=/, $line;
    return getdbname(@db), @db;
}

sub getdbname {
    my (@db) = @_;
    my $dbname = q();
    if (@db && $db[0] =~ /(^[^,]+)/) {
        $dbname = $1;
    }
    return $dbname;
}

# Read hostdb file
#
# This returns a list of graph infos for the specified host based on the
# contents of the hostdb file.
#
# Services are defined with this format:
#
#   service=name[&db=dataset[&label=text][&db=dataset[&label=text][...]]]
#
sub readhostdb {
    my ($host) = @_;
    $host ||= q();
    if ($host eq q()) { return (); }

    debug(DBDEB, "readhostdb($host)");

    if (! defined $Config{hostdb} || $Config{hostdb} eq q()) {
        my $msg = 'no hostdb file has been specified in the configuration.';
        debug(DBDEB, $msg);
        htmlerror($msg);
        croak($msg);
    }

    my @ginfo;
    my $fn = $Config{hostdb};
    if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
        while (my $line = <$DB>) {
            chomp $line;
            debug(DBDEB, "readhostdb: $line");
            $line =~ s/\s*#.*//;
            $line =~ tr/+/ /;
            $line =~ s/^\s+//g;
            my $service = q();
            my $dbname = q();
            my @db;
            if ($line =~ s/^service\s*=\s*([^&]+)//) {
                $service = $1;
                ($dbname, @db) = parsedb($line);
            }
            next if ! $service;
            my($dir, $file) = mkfilename($host, $service, $dbname, 1);
            my $rrdfn = $dir . q(/) . $file;
            if (-f $rrdfn) {
                my %info;
                $info{host} = $host;
                $info{service} = $service;
                $info{dbname} = $dbname;
                $info{db} = \@db;
                $info{filename} = $rrdfn;
                push @ginfo, \%info;
                debug(DBDEB, "readhostdb: add host:$host service:$service");
            } else {
                debug(DBDEB, "readhostdb: skip host:$host service:$service");
            }
        }
        close $DB or debug(DBERR, "readhostdb: close failed for $fn: $OS_ERROR");
    } else {
        my $msg = "cannot open hostdb $fn: $!";
        debug(DBDEB, $msg);
        htmlerror($msg);
        croak($msg);
    }

    return \@ginfo;
}

# Read the servdb file
#
# This returns a list of hosts that have data for the specified service and db.
#
# Hosts are defined with this format:
#
#   host=name[,name1[,name2[...]]]
#
sub readservdb {
    my ($service, $dblist) = @_;
    $service ||= q();
    if ($service eq q()) { return (); }
    my $dbname = q();
    if ($dblist) { ($dbname) = getdbname(@{$dblist}); }

    debug(DBDEB, "readservdb($service, $dbname)");

    if (! defined $Config{servdb} || $Config{servdb} eq q()) {
        my $msg = 'no servdb file has been specified in the configuration.';
        debug(DBDEB, $msg);
        htmlerror($msg);
        croak($msg);
    }

    my @allhosts;
    my @ginfo;
    my $fn = $Config{servdb};
    if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
        while (my $line = <$DB>) {
            chomp $line;
            debug(DBDEB, "readservdb: $line");
            $line =~ s/\s*#.*//;
            $line =~ tr/+/ /;
            $line =~ s/^\s+//g;
            my $host = q();
            if ($line =~ s/^host\s*=\s*(.*)//) {
                $host = $1;
            }
            next if ! $host;
            push @allhosts, split /\s*,\s*/, $host;
        }
        close $DB or debug(DBERR, "readhostdb: close failed for $fn: $OS_ERROR");
    } else {
        my $msg = "cannot open servdb $fn: $!";
        debug(DBDEB, $msg);
        htmlerror($msg);
        croak($msg);
    }

    # if we have a dbname, then do a check for that for each host.  if not, 
    # then read each hosts rrd directory to see if we have a service match.
    my @hosts;
    foreach my $host (@allhosts) {
        if ($dbname ne q()) {
            my($dir, $file) = mkfilename($host, $service, $dbname, 1);
            my $rrdfn = $dir . q(/) . $file;
            if (-f $rrdfn) {
                push @hosts, $host;
            }
        } else {
            my $rrds = dbfilelist($host, $service);
            if (scalar @{$rrds} > 0) {
                push @hosts, $host;
            }
        }
    }

    dumper(DBDEB, 'readservdb: all hosts', \@allhosts);
    dumper(DBDEB, 'readservdb: validated hosts', \@hosts);
    return \@hosts;
}

# Read the groupdb file
#
# This returns a list of graph infos for the specified group and a list
# of all group names.
#
# Groups are defined with this format:
#
#   groupname=host,service[&db=dataset[&label=text][...]]
#
sub readgroupdb {
    my ($g) = @_;
    $g ||= q();
    debug(DBDEB, "readgroupdb($g)");

    if (! defined $Config{groupdb} || $Config{groupdb} eq q()) {
        my $msg = 'no groupdb file has been specified in the configuration.';
        debug(DBDEB, $msg);
        htmlerror($msg);
        croak($msg);
    }

    my $fn = $Config{groupdb};
    my %gnames;
    my @ginfo;
    if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
        while (my $line = <$DB>) {
            chomp $line;
            debug(DBDEB, "readgroupdb: $line");
            $line =~ s/\s*#.*//;
            $line =~ tr/+/ /;
            $line =~ s/^\s+//g;
            my $group = q();
            my $host = q();
            my $service = q();
            my $dbname = q();
            my @db;
            if ($line =~ s/^([^=]+)\s*=\s*([^,]+)\s*,\s*([^&]+)//) {
                $group = $1;
                $host = $2;
                $service = $3;
                ($dbname, @db) = parsedb($line);
            }
            next if ! $group || ! $host || ! $service;
            $gnames{$group} = 1;
            next if $group ne $g;
            my($dir, $file) = mkfilename($host, $service, $dbname, 1);
            my $rrdfn = $dir . q(/) . $file;
            if (-f $rrdfn) {
                my %info;
                $info{host} = $host;
                $info{service} = $service;
                $info{dbname} = $dbname;
                $info{db} = \@db;
                $info{filename} = $rrdfn;
                push @ginfo, \%info;
                debug(DBDEB, "readgroupdb: add host:$host service:$service");
            } else {
                debug(DBDEB, "readgroupdb: skip host:$host service:$service");
            }
        }
        close $DB or debug(DBERR, "readgroupdb: close failed for $fn: $OS_ERROR");
    } else {
        my $msg = "cannot open groupdb $fn: $!";
        debug(DBDEB, $msg);
        htmlerror($msg);
        croak($msg);
    }

    my @gnames = sortnaturally(keys %gnames);

    return \@gnames, \@ginfo;
}

# show.cgi subroutines here for unit testability ##############################
# Shared routines #############################################################
# Get list of matching rrd files
# unescape the filenames as we read in since they should be escaped on disk
sub dbfilelist {
    my ($host, $serv) = @_;
    debug(DBDEB, "dbfilelist($host, $serv)");
    my ($directory, $filename) = mkfilename($host, $serv);
    debug(DBDEB, "dbfilelist scanning $directory for $filename");
    my @rrd;
    if (opendir DH, $directory) {
        while (my $entry=readdir DH) {
            next if $entry =~ /^\./;
            if ($entry =~ /^${filename}(.+)\.rrd$/) {
                push @rrd, unescape($1);
            }
        }
        closedir DH or debug(DBCRT, "cannot close $directory: $OS_ERROR");
    } else {
        debug(DBWRN, "cannot open directory $directory: $!");
    }

    dumper(DBDEB, 'dbfilelist', \@rrd);
    return \@rrd;
}

# Graphing routines ###########################################################
# Return a list of the data 'lines' in an rrd file
sub getdataitems {
    my ($file) = @_;
    my ($ds,                 # return value from RRDs::info
        $ERR,                # RRDs error value
        %dupes);             # temporary hash to filter duplicate values with
    if (-f $file) {
        $ds = RRDs::info($file);
    } else {
        $ds = RRDs::info("$Config{rrddir}/$file");
    }
    $ERR = RRDs::error();
    if ($ERR) {
        debug(DBERR, 'getdataitems: RRDs::info ERR ' . $ERR);
        dumper(DBERR, 'getdataitems: ds', $ds);
    }
    return grep { ! $dupes{$_}++ }          # filters duplicate data set names
        map { /ds\[(.*)\]/ and $1 }         # returns just the data set names
            grep { /ds\[(.*)\]/ } keys %{$ds}; # gets just the data set fields
}

# Find graphs and values
sub graphinfo {
    my ($host, $service, $db) = @_;
    debug(DBDEB, "graphinfo($host, $service)");
    my ($hs,                    # host/service
        @rrd,                    # the returned list of hashes
        $ds);

    if ($Config{dbseparator} eq 'subdir') {
        $hs = $host . q(/) . escape("$service") . q(___);
    } else {
        $hs = escape("${host}_${service}") . q(_);
    }

    # Determine which files to read lines from
    dumper(DBDEB, 'graphinfo: db', $db);
    if ($db) {
        my ($nn,                # index of @rrd, for inserting entries
            $dbname,            # RRD file name, without extension
            @lines,             # entries after file name from $db
            $line,              # value split from $ll
            $unit) = (0);       # value split from $ll
        for my $dd (@{$db}) {
            ($dbname, @lines) = split /,/, $dd;
            $rrd[$nn]{file} = $hs . escape("$dbname") . '.rrd';
            for my $ll (@lines) {
                ($line, $unit) = split /~/, $ll;
                if ($unit) {
                    $rrd[$nn]{line}{$line}{unit} = $unit;
                } else {
                    $rrd[$nn]{line}{$line} = 1;
                }
            }
            $nn++;
        }
        debug(DBINF, "graphinfo: Specified $hs db files in $Config{rrddir}: "
                     . join ', ', map { $_->{file} } @rrd);
    } else {
        @rrd = map {{ file=>$_ }}
                     map { "${hs}${_}.rrd" }
                     @{dbfilelist($host, $service)};
        debug(DBINF, "graphinfo: Listing $hs db files in $Config{rrddir}: "
                     . join ', ', map { $_->{file} } @rrd);
    }

    foreach my $rrd ( @rrd ) {
        if (not $rrd->{line}) {
            foreach my $ii (getdataitems($rrd->{file})) {
                $rrd->{line}{$ii} = 1;
            }
        }
        debug(DBDEB, "graphinfo: DS $rrd->{file} lines: "
                     . join ', ', keys %{$rrd->{line}});
    }
    dumper(DBDEB, 'graphinfo: rrd', \@rrd);
    return \@rrd;
}

sub setlabels { ## no critic (ProhibitManyArgs)
    my ($dataset, $longest, $color, $serv, $file, $ds) = @_;
    my $label = sprintf "%-${longest}s", $dataset;
    debug(DBDEB, "setlabels($label)");
    my $linestyle = $Config{plotas};
    foreach my $ii (qw(LINE1 LINE2 LINE3 AREA TICK)) {
        if (defined $Config{'plotas' . $ii}->{$dataset}) {
            $linestyle = $ii;
            last;
        }
    }
    if (defined $Config{lineformat}) {
        dumper(DBDEB, 'lineformat', \%{$Config{lineformat}});
        foreach my $tuple (keys %{$Config{lineformat}}) {
            if ($tuple =~ /^$dataset,/) {
                my @values = split /,/, $tuple;
                foreach my $value (@values) {
                    if ($value eq 'LINE1' || $value eq 'LINE2' ||
                        $value eq 'LINE3' || $value eq 'AREA' ||
                        $value eq 'TICK') {
                        $linestyle = $value;
                    } elsif ($value =~ /[0-9a-f][0-9a-f][0-9a-f]+/) {
                        $color = $value;
                    }
                }
            }
        }
    }
    if (defined $Config{maximums}->{$serv}) {
        push @{$ds}, "DEF:$dataset=$file:$dataset:MAX"
                , "CDEF:ceil$dataset=$dataset,CEIL"
                , "$linestyle:${dataset}#$color:$label";
    } elsif (defined $Config{minimums}->{$serv}) {
        push @{$ds}, "DEF:$dataset=$file:$dataset:MIN"
                , "CDEF:floor$dataset=$dataset,FLOOR"
                , "$linestyle:${dataset}#$color:$label";
    } else {
        push @{$ds}, "DEF:${dataset}=$file:$dataset:AVERAGE";
        if (defined $Config{negate}->{$dataset}) {
            push @{$ds}, "CDEF:${dataset}_neg=${dataset},-1,*";
            push @{$ds}, "$linestyle:${dataset}_neg#$color:$label";
        } else {
            push @{$ds}, "$linestyle:${dataset}#$color:$label";
        }
    }
    return;
}

sub setdata { ## no critic (ProhibitManyArgs)
    my ($dataset, $fixedscale, $time, $serv, $file, $ds) = @_;
    debug(DBDEB, "setdata($dataset, $time, $serv, $file)");
    my $format = '%6.2lf%s';
    if ($fixedscale) { $format = '%6.2lf'; }
    debug(DBDEB, "setdata($format)");
    if ($time > 120_000) { ## no critic (ProhibitMagicNumbers) long enough to start getting summation
        if (defined $Config{withmaximums}->{$serv}) {
            my $maxcolor = '888888'; #$color;
            push @{$ds}, "DEF:${dataset}_max=${file}_max:$dataset:MAX"
                    , "LINE1:${dataset}_max#${maxcolor}:maximum";
        }
        if (defined $Config{withminimums}->{$serv}) {
            my $mincolor = 'BBBBBB'; #color;
            push @{$ds}, "DEF:${dataset}_min=${file}_min:$dataset:MIN"
                    , "LINE1:${dataset}_min#${mincolor}:minimum";
        }
        if (defined $Config{withmaximums}->{$serv}) {
            push @{$ds}, "CDEF:${dataset}_maxif=${dataset}_max,UN",
                    , "CDEF:${dataset}_maxi=${dataset}_maxif,${dataset},${dataset}_max,IF"
                    , "GPRINT:${dataset}_maxi:MAX:Max\\: $format";
        } else {
            push @{$ds}, "GPRINT:$dataset:MAX:Max\\: $format";
        }
        push @{$ds}, "GPRINT:$dataset:AVERAGE:Avg\\: $format";
        if (defined $Config{withminimums}->{$serv}) {
            push @{$ds}, "CDEF:${dataset}_minif=${dataset}_min,UN",
                    , "CDEF:${dataset}_mini=${dataset}_minif,${dataset},${dataset}_min,IF"
                    , "GPRINT:${dataset}_mini:MIN:Min\\: $format\\n"
        } else {
            push @{$ds}, "GPRINT:$dataset:MIN:Min\\: $format\\n"
        }
    } else {
        push @{$ds}, "GPRINT:$dataset:MAX:Max\\: $format"
                , "GPRINT:$dataset:AVERAGE:Avg\\: $format"
                , "GPRINT:$dataset:MIN:Min\\: $format"
                , "GPRINT:$dataset:LAST:Cur\\: ${format}\\n";
    }
    return;
}

# Generate all the parameters for rrd to produce a graph
sub rrdline {
    my ($params) = @_;
    dumper(DBDEB, 'rrdline params', $params);
    my ($graphinfo) = graphinfo($params->{host}, $params->{service}, $params->{db});
    my ($file,                  # current rrd data file
        $color,                 # return value from hashcolor()
        $duration,              # how long the graph covers
        @ds);                   # array of strings for use as the command line
    my $directory = $Config{rrddir};

    if ($params->{rrdopts} and $params->{rrdopts} =~ m/snow.(\d+)/) {
        $duration = $1;
    } else {
        $duration = 118_800; ## no critic (ProhibitMagicNumbers)
    }
    @ds = (q(-), q(-a), 'PNG', '--start', "-$params->{offset}");
    # Identify where to pull data from and what to call it
    for my $ii (@{$graphinfo}) {
        $file = $ii->{file};
        dumper(DBDEB, 'rrdline: this graphinfo entry', $ii);

        # Compute the longest label length
        my $longest = (sort map { length } keys %{$ii->{line}})[-1]; ## no critic (ProhibitMagicNumbers)

        for my $dataset (sortnaturally(keys %{$ii->{line}})) {
            $color = hashcolor($dataset);
            debug(DBDEB, "rrdline: file=$file dataset=$dataset color=$color");
            my ($serv, $pos) = ($params->{service}, length($params->{service}) - length $dataset);
            if (substr($params->{service}, $pos) eq $dataset) {
                $serv = substr $params->{service}, 0, $pos;
            }
            setlabels($dataset, $longest, $color, $serv, "$directory/$file", \@ds);
            setdata($dataset, $params->{fixedscale}, $duration, $serv, "$directory/$file", \@ds);
        }
    }

    # Dimensions of graph if geom is specified
    if ($params->{geom} && $params->{geom} ne 'default') {
        my ($w, $h) = split /x/, $params->{geom};
        push @ds, '-w', $w, '-h', $h;
    } else {
        push @ds, '-w', GRAPHWIDTH; # just make the graph wider than default
    }
    # Additional parameters to rrd graph, if specified
    if ($params->{rrdopts}) {
        my $opt = q();
        foreach my $ii (split /\s+/, $params->{rrdopts}) {
            if (substr($ii, 0, 1) eq q(-)) {
                $opt = $ii;
                push @ds, $opt;
            } else {
                if ($ds[-1] eq $opt) {
                    push @ds, $ii;
                } else {
                    $ds[-1] .= " $ii";
                }
            }
        }
    }
    if ($params->{fixedscale}) { push @ds, '-X', '0'; }
    foreach my $ii (['altautoscale', '-A'], ['altautoscalemin', '-J'],
                    ['altautoscalemax', '-M'], ['nogridfit', '-N'],
                    ['logarithmic', '-o']) {
        addopt($ii->[0], $params->{service}, $params->{rrdopts}, $ii->[1], \@ds);
    }
    debug(DBDEB, 'rrdline: returning ' . join q( ), @ds);
    return @ds;
}

sub addopt {
    my ($conf, $service, $rrdopts, $rrdopt, $ds) = @_;
    ## no critic (ProhibitMagicNumbers)
    if (defined $Config{$conf} and
        exists $Config{$conf}{$service} and
        index($rrdopts, $rrdopt) == -1) {
            push @{$ds}, $rrdopt;
    }
    return;
}

# Server/service menu routines ################################################
# Assumes subdir as separator
sub getgraphlist {
    # Builds a hash for available servers/services to graph
    my $current = $_;
    my $extension = '.rrd';
    my $rrdlen = 0 - length $extension;
    if (-d $current and substr($current, 0, 1) ne q(.)) { # Directories are for hostnames
        if (not checkdirempty($current)) { %{$Navmenu{$current}} = (); }
    } elsif (-f $current && substr($current, $rrdlen) eq $extension) { # Files are for services
        my ($host, $service, $dataset);
        $dataset = $File::Find::dir; # this stops the only used once message
        ($host = $File::Find::dir) =~ s|^$Config{rrddir}/||;
        # We got the server to associate with and now
        # we get the service name by splitting on separator
        ($service, $dataset) = split /___/, $current;
        if ($dataset) { $dataset = substr $dataset, 0, $rrdlen; }
        #debug(DBDEB, "getgraphlist: service = $service, dataset = $dataset");
        if (not exists $Navmenu{$host}{unescape($service)}) {
            @{$Navmenu{$host}{unescape($service)}} = (unescape($dataset));
        } else {
            push @{$Navmenu{$host}{unescape($service)}}, unescape($dataset);
        }
    }
    return;
}

# If configured, check to see if this user is allowed to see this host.
sub checkperms {
    my ($host, $user, $authz) = @_;
    if (not $Config{userdb}) { return 1; } # not configured = yes
    my $untie = 1;
    if ($authz) {
        $untie = 0;
    } else {
        tie %{$authz}, $Config{dbfile}, $Config{userdb}, O_RDONLY or return; ## no critic (ProhibitTies)
    }
    if ($authz->{$host} and $authz->{$host}{$user}) {
        if ($untie) { untie %{$authz}; }
        return 1;
    }
    if ($untie) { untie %{$authz}; }
    return 0;
}

sub printjavascript {
    my ($servers, $lookup) = @_;
    my $rval = "<script type=\"text/javascript\">\nmenudata = new Array();\n";
    my (@services,              # list of services on a server
        $com1, $com2);          # booleans for whether or a comma gets printed

    # Create Javascript Arrays for client-side menu navigation
    for my $ii (0 .. @{$servers} - 1) {
        $rval .= "menudata[$ii] = [\"$servers->[$ii]\", \n";
        @services = sortnaturally(keys %{$Navmenu{$servers->[$ii]}});
        #dumper(DBDEB, 'printjavascript: keys', \@services);
        $com1 = 0;
        foreach my $jj (@services) {
            if ($com1) {
                $rval .= q( ,);
            } else {
                $rval .= q(  );
            }
            $rval .= "[\"$jj\",";
            $com2 = 0;
            foreach my $kk (@{$lookup->{$servers->[$ii]}{$jj}}) {
                if ($com2) {
                    $rval .= q(,);
                }
                $rval .= '["' . join('","', @{$kk}) . '"]';
                $com2 = 1;
            }
            $rval .= "]\n";
            $com1 = 1;
        }
        $rval .= "];\n";
    }
    return $rval . "</script>\n<script type=\"text/javascript\" src=\"" .
        $Config{javascript} . "\"></script>\n";
}

sub getserverlist {
    my ($userid) = @_;
    debug(DBDEB, "getserverlist($userid)");
    my (@hosts,               # host list in order
        %hostserv,            # hash of hosts -> list of services
        @services,            # list of services on a host
        @dataitems);          # list of values in the current data set

    # Verify the connected user is allowed to see this host.
    if ($Config{userdb} and $userid) {
        my %authz;
        tie %authz, $Config{dbfile}, $Config{userdb}, O_RDONLY or return; ## no critic (ProhibitTies)
        foreach my $ii (sortnaturally(keys %Navmenu)) {
            if (checkperms($ii, $userid, \%authz)) { push @hosts, $ii; }
        }
        untie %authz;
    } else {
        @hosts = sortnaturally(keys %Navmenu);
    }

    foreach my $ii (@hosts) {
        @services = sortnaturally(keys %{$Navmenu{$ii}});
        foreach my $jj (@services) {
            foreach my $kk (@{$Navmenu{$ii}{$jj}}) {
                @dataitems = getdataitems(join q(/), mkfilename($ii, $jj, $kk, 1));
                if (not exists $hostserv{$ii}) {
                    $hostserv{$ii} = {};
                }
                if (not exists $hostserv{$ii}{$jj}) {
                    $hostserv{$ii}{$jj} = [];
                }
                push @{$hostserv{$ii}{$jj}}, [$kk, @dataitems];
            }
        }
    }
    #dumper(DBDEB, 'hosts', \@hosts);
    #dumper(DBDEB, 'hosts-services', \%hostserv);
    return ( host => [@hosts], hostserv => \%hostserv );
}

# emit the javascript that configures the web page.  this has to be at the
# end of the web page so that all elements have a chance to be instantiated
# before the javascript is invoked.
sub printscript {
    my ($host, $service, $expanded_periods) = @_;
    return "<script type=\"text/javascript\">cfgMenus(\'$host\',\'$service\',\'$expanded_periods\');</script>\n";
}

# there are 4 contexts: show, showhost, showservice, showgroup.
#   show displays both host and service menus.
#   showhost displays the host menu.
#   showservice displays the service menu.
#   showgroup displays the groups menu.
#
# primary controls consist of the host/service/group menus and the
# update button.  secondary controls are all the others.
#
# the host and group contexts do not require javascript updates when the
# menus change, since there are no dependencies in those contexts.
sub printcontrols {
    my ($cgi, $opts) = @_;

    my $context = $opts->{call};

    # FIXME: prolly not necessary since we fabricate the submit in javascript.
    my %script = qw(both show.cgi host showhost.cgi service showservice.cgi group showgroup.cgi);
    my $action = $Config{nagiosgraphcgiurl} . q(/) . $script{$context};

    # preface the geometry list with a default entry no matter what
    my @geom = ('default', split /,/, $Config{geometries});

    my $menustr = q();
    if ($context eq 'both') {
        my $host = $opts->{host};
        my $service = $opts->{service};
        $menustr = $cgi->span({-class => 'selector'},
                              trans('selecthost') . q( ) .
                              $cgi->popup_menu(-name => 'servidors',
                                               -onChange => 'hostChange()',
                                               -values => [$host],
                                               -default => $host)) . "\n";
        $menustr .= $cgi->span({-class => 'selector'},
                               trans('selectserv') . q( ) .
                               $cgi->popup_menu(-name => 'services',
                                                -onChange => 'serviceChange()',
                                                -values => [$service],
                                                -default => $service));
    } elsif ($context eq 'host') {
        my $host = $opts->{host};
        $menustr = $cgi->span({-class => 'selector'},
                              trans('selecthost') . q( ) .
                              $cgi->popup_menu(-name => 'servidors',
                                               -values => [$host],
                                               -default => $host));
    } elsif ($context eq 'service') {
        my $service = $opts->{service};
        $menustr = $cgi->span({-class => 'selector'},
                              trans('selectserv') . q( ) .
                              $cgi->popup_menu(-name => 'services',
                                               -onChange => 'serviceChange()',
                                               -values => [$service],
                                               -default => $service));
    } elsif ($context eq 'group') {
        my $group = $opts->{group};
        my @groups = (q(-), @{$opts->{grouplist}});
        $menustr = $cgi->span({-class => 'selector'},
                              trans('selectgroup') . q( ) .
                              $cgi->popup_menu(-name => 'groups',
                                               -values => [@groups],
                                               -default => $group));
    }

    return $cgi->
        div({-class => 'controls'}, "\n" .
            $cgi->start_form(-method => 'GET',
                             -action => $action,
                             -name => 'menuform') . "\n",
            $cgi->div({-class => 'primary_controls'},
                      $menustr . "\n",
                      $cgi->span({-class => 'executor'},
                                 $cgi->button(-name => 'go',
                                              -label => trans('submit'),
                                              -onClick => 'jumpto()')
                                 ) . "\n") . "\n",
            $cgi->div({-class => 'secondary_controls'},
                      $cgi->p({-class => 'controls_toggle'},
                              $cgi->checkbox(-name => 'showhidecontrols',
                                             -onChange => 'toggleControlsDisplay()',
                                             -label => trans('showhidecontrols'))) . "\n",
                      $cgi->table({-id => 'secondary_controls_box'},
                                  $cgi->Tr({-valign => 'top'},
                                           $cgi->td(q( )),
                                           $cgi->td($cgi->checkbox(-name => 'fixedscale', -label => trans('i18n_fixedscale'), -checked => $opts->{fixedscale})),
                                           $cgi->td(q( )),
                                           ),
                                  $cgi->Tr({-valign => 'top'},
                                           $cgi->td({-class => 'control_label'},trans('zoom')),
                                           $cgi->td($cgi->popup_menu(-name => 'geom', -values => [@geom])),
                                           $cgi->td(q( )),
                                           ),
                                  $cgi->Tr({-valign => 'top'},
                                           $cgi->td({-class => 'control_label'},trans('periods')),
                                           $cgi->td($cgi->popup_menu(-name => 'period', -values => [@PERIODS], -size => PERIODLISTROWS, -multiple => 1)),
                                           $cgi->td($cgi->button(-name => 'clear', -label => trans('clear'), -onClick => 'clearPeriodSelection()')),
                                           ),
                                  ($context eq 'both' || $context eq 'service')
                                  ? $cgi->span({-id => 'db_controls'},
                                               $cgi->Tr({-valign => 'top'},
                                                        $cgi->td({-class => 'control_label'},trans('selectds')),
                                                        $cgi->td($cgi->popup_menu(-name => 'db', -values => [], -size => DBLISTROWS, -multiple => 1)),
                                                        $cgi->td($cgi->button(-name => 'clear', -label => trans('clear'), -onClick => 'clearDBSelection()')),
                                                        ))
                                  : q(),
                                  ) . "\n",
                      ) . "\n",
            $cgi->end_form . "\n");
}

sub printgraphlinks {
    my ($cgi, $params, $period, $link) = @_;
    if (! defined $link) { $link = q(); }
    dumper(DBDEB, 'printgraphlinks params', $params);
    dumper(DBDEB, 'printgraphlinks period', $period);

    my $url = $Config{nagiosgraphcgiurl} . '/showgraph.cgi?';
    my $alttag = q();
    my $desc = q();

    my $showtitle = $params->{showtitle};
    my $showdesc = $params->{showdesc};
    my $showgraphtitle = $params->{showgraphtitle};

    # the title is the service and host.  do not translate the host, and do
    # not complain about missing service definitions.
    my $title = trans($params->{service}, 1) . q( ) . trans('on') . q( )
        . $params->{host};

    # the description contains a list of the data set names.  we first see
    # if there is a translation for the complete name, e.g. 'cpu,idle'.  if
    # not, then we try for the smaller part, e.g. 'idle'.  if that fails,
    # just display the full name, e.g. 'cpu,idle'.  in any case do not 
    # complain about missing translations for these.
    if ($showdesc) {
        if ($params->{db} &&
            $#{$params->{db}} >= 0 &&
            ${$params->{db}}[0] ne $params->{service}) {
            foreach my $ii (sortnaturally(@{$params->{db}})) {
                if ($desc ne q()) { $desc .= $cgi->br(); }
                my $x = trans($ii, 1);
                if ($x eq $ii) {
                    my ($a,$b) = split /,/, $ii;
                    if ($b && $b ne q()) {
                        my $y = trans($b, 1);
                        if ($y ne $b) {
                            $x = $y;
                        }
                    }
                }
                $desc .= $x;
            }
        }
    }

    # include quite a bit of information in the alt tag - it helps when
    # debugging configuration files.
    $alttag = trans('graphof') . q( ) . $params->{service} .
        q( ) . trans('on') . q( ) . $params->{host};
    if ($params->{db}) {
        $alttag .= ' (';
        foreach my $ii (sortnaturally(@{$params->{db}})) {
            $alttag .= q( ) . $ii;
        }
        $alttag .= ' )';
    }

    dumper(DBDEB, 'printgraphlinks rrdopts', $params->{rrdopts});
    my $rrdopts = $params->{rrdopts};
    if ($showgraphtitle) {
        if ($rrdopts !~ /(-t|--title)/) {
            $rrdopts .= ' -t ' . $title;
        }
    }
    if ($params->{graphonly}) {
        $rrdopts .= ' -j';
    }
    if ($params->{hidelegend}) {
        $rrdopts .= ' -g';
    }
    $rrdopts .= ' -snow-' . $period->[1];
    $rrdopts .= ' -enow-' . $params->{offset};
    $rrdopts =~ tr/ /+/;
    debug(DBDEB, "printgraphlinks rrdopts = $rrdopts");

    if ($params->{db}) {
        $url .= buildurl($params->{host}, $params->{service},
                         { graph => $period->[1],
                           geom => $params->{geom},
                           rrdopts => [$rrdopts],
                           fixedscale => $params->{fixedscale},
                           db => $params->{db}});
    } else {
        $url .= buildurl($params->{host}, $params->{service},
                         { graph => $period->[1],
                           geom => $params->{geom},
                           rrdopts => [$rrdopts],
                           fixedscale => $params->{fixedscale}});
    }
    debug(DBDEB, "printgraphlinks url = $url");

    my $titlestr = $showtitle
        ? $cgi->p({-class=>'graph_title'}, $title) : q();
    my $linkstr = $link ne q()
        ? $cgi->p({-class=>'graph_link'}, $link) : q();
    my $descstr = $desc ne q()
        ? $cgi->p({-class=>'graph_description'}, $desc) : q();

    return $cgi->div({-class => 'graph'},
                     $cgi->img({-src=>$url, -alt=>$alttag})) . "\n" .
           $cgi->div({-class => 'graph_details'}, "\n",
                     $titlestr, $titlestr ne q() ? "\n" : q(),
                     $descstr, $descstr ne q() ? "\n" : q(),
                     $linkstr, $linkstr ne q() ? "\n" : q(),
                     ) . "\n";
}

sub printperiodlinks {
    my($cgi, $params, $period, $now, $content) = @_;
    my (@navstr) = getperiodctrls($cgi, $params, $period, $now);
    my $label = (($period->[0] eq 'day') ? 'dai' : $period->[0]) . 'ly';
    my $id = 'period_data_' . $period->[0];
    return $cgi->div({-class => 'period_title'},
                     $cgi->span({-class => 'period_anchor'},
                                $cgi->button(-id => 'toggle_' . $period->[0],
                                             -label => q(-),
                                             -onClick => 'togglePeriodDisplay(\'' . $id . '\', this)'),
                                $cgi->a({ -id => $period->[0] },
                                        trans($label))),
                     $cgi->span({-class => 'period_controls'},
                             $navstr[0],
                             $cgi->span({-class => 'period_detail'},
                                        $navstr[1]),
                             $navstr[2]),
                     $cgi->div({-id => $id }, $content)), "\n";
}

# quietly translate services and groups, but not hosts.
sub printsummary {
    my($cgi, $opts) = @_;

    my $s = q();
    if ($opts->{call} eq 'both') {
        $s = trans('perfforhost') . q( ) .
            $cgi->span({-class => 'item_label'},
                       $cgi->a({href => $opts->{hosturl}},
                               $opts->{host})) .
            ', ' .
            trans('service') . q( ) .
            $cgi->span({-class => 'item_label'},
                       $cgi->a({href => $opts->{serviceurl}},
                               trans($opts->{service}, 1)));
    } elsif ($opts->{call} eq 'host') {
        $s = trans('perfforhost') . q( ) .
            $cgi->span({-class => 'item_label'},
                       $cgi->a({href => $opts->{hosturl}},
                               $opts->{host}));
    } elsif ($opts->{call} eq 'service') {
        $s = trans('perfforserv') . q( ) .
            $cgi->span({-class => 'item_label'},
                       trans($opts->{service}, 1));
    } elsif ($opts->{call} eq 'group') {
        $s = trans('perfforgroup') . q( ) .
            $cgi->span({-class => 'item_label'},
                       trans($opts->{group}, 1));
    }

    return $cgi->p({ -class => 'summary' },
                   $s . q( ) . trans('asof') . q( ) .
                   $cgi->span({ -class => 'timestamp' },
                              formattime(time, 'timeformat_now')));
}

sub printheader {
    my ($cgi, $opts) = @_;

    my $rval = $cgi->header;
    $rval .= $cgi->start_html(-id => 'nagiosgraph',
                              -title => "nagiosgraph: $opts->{title}",
                              -head => getrefresh($cgi),
                              getstyle());

    # Print Navigation Menu if we have a separator set that will allow
    # navigation menu to correctly split the filenames/filepaths in
    # host/service/db names.
    if (defined $Config{dbseparator} && $Config{dbseparator} eq 'subdir') {
        File::Find::find(\&getgraphlist, $Config{rrddir});
        #dumper(DBDEB, 'printheader: Navmenu', \%Navmenu);

        my %result = getserverlist($cgi->remote_user());
        my(@servers) = @{$result{host}};
        my(%servers) = %{$result{hostserv}};
        $rval .= printjavascript(\@servers, \%servers);
    }

    $rval .= printcontrols($cgi, $opts) . "\n";

    $rval .= (defined $Config{hidengtitle} and $Config{hidengtitle} eq 'true')
        ? q() : $cgi->h1('Nagiosgraph') . "\n";

    $rval .= printsummary($cgi, $opts) . "\n";

    return $rval;
}

sub printfooter {
    my ($cgi) = @_;
    return $cgi->div({-class => 'footer'}, q(), # or instead of q() $cgi->hr()
    	$cgi->small(trans('createdby') . q( ) .
    	$cgi->a({href => NAGIOSGRAPHURL },
    	'Nagiosgraph ' . $VERSION) . q(.) )) . $cgi->end_html();
}

# Full page routine ###########################################################
# Determine the number of graphs that will be displayed on the page
# and the time period they will cover.  This expects a comma-delimited list
# of time periods.
sub graphsizes {
    my $conf = shift;
    $conf =~ s/,/ /g; # convert to spaces so we can split on whitespace
    dumper(DBDEB, 'graphsizes period', $conf);
    my @config_times = split /\s+/, $conf;

    # [Label, period span, offset] (in seconds)
    ## no critic (ProhibitMagicNumbers)
    # Pre-defined available graph sizes
    #     Daily      =  33h = 118800s
    #     Weekly     =   9d = 777600s
    #     Monthly    =   5w = 3024000s
    #     Quarterly  =  14w = 8467200s
    #     Yearly     = 400d = 34560000s
    my @default_times = (['day', 118_800, 86_400],
                         ['week', 777_600, 604_800],
                         ['month', 3_024_000, 2_592_000],
                         ['year', 34_560_000, 31_536_000],);
    my %default_times = ('day' => 0,
                         'week' => 1,
                         'month' => 2,
                         'year' => 3,
                         'quarter' => ['quarter', 8_467_200, 7_776_000],);

    # Configuration entry was absent or empty. Use default
    if (not @config_times) {
        debug(DBDEB, 'cannot determine period, using defaults');
        return @default_times;
    }

    # Try to match known entries from configuration file
    my @final_t;
    foreach my $ii (@config_times) {
        chomp $ii;
        next if not exists $default_times{$ii};
        if (ref($default_times{$ii}) eq 'ARRAY') {
            push @final_t, $default_times{$ii};
        } else {
            push @final_t, $default_times[$default_times{$ii}];
        }
    }

    # Final check to see if we matched any known entry or use default
    if (not @final_t) {
        debug(DBDEB, 'final check for period failed, using defaults');
        @final_t = @default_times;
    }

    my @rval = sort {$a->[1] <=> $b->[1]} @final_t;
    return @rval;
}

# returns three strings: a url for previous period, a label for current
# display, and a url for the next period.  do not permit voyages into
# the future.
# FIXME: prevent going back in time before there are rrd slots (filled or not)
sub getperiodctrls {
    my ($cgi, $params, $period, $now) = @_;
    debug(DBDEB, "getperiodctrls(now: $now period: @{$period})");

    # strip any offset from the url
    my $url = $ENV{REQUEST_URI};
    $url =~ s/&*offset=[^&]*//;

    # now calculate and inject our own offset
    my $offset = ($params->{offset} + $period->[2]);
    my $p = $cgi->a({-href=>"$url&offset=$offset"}, '<');
    my $c = getperiodlabel($now,$params->{offset},$period->[1],$period->[0]);
    $offset = ($params->{offset} - $period->[2]);
    my $n = $cgi->a({-href=>"$url&offset=$offset"}, '>');
    if ($offset < 0) { $n = q(); }

    return ($p, $c, $n);
}

# returns a human-readable string with the start and end time relative to
# the current hour plus the indicated offset.  the resolution determines
# how much information to put into the label string.
sub getperiodlabel {
    my($now, $offset, $period, $res) = @_;
    my $e = $now - $offset;
    my $s = $e - $period;
    my $sstr = formattime($s, 'timeformat_' . $res);
    my $estr = formattime($e, 'timeformat_' . $res);
    return $sstr . q( - ) . $estr;
}

sub formattime {
    my ($t, $key) = @_;
    return $key && defined $Config{$key}
        ? strftime $Config{$key}, localtime $t
        : scalar localtime $t;
}

# insert.pl subroutines here for unit testability #############################
# Check that we have some data to work on
sub inputdata {
    my @inputlines;
    debug(DBDEB, 'inputdata()');
    if ( $ARGV[0] ) {
        @inputlines = $ARGV[0];
    } elsif ( defined $Config{perflog} ) {
        if (-s $Config{perflog}) {
            my $worklog = $Config{perflog} . '.nagiosgraph';
            rename $Config{perflog}, $worklog;
            open my $PERFLOG, '<', $worklog or return @inputlines;
            while (<$PERFLOG>) {
                push @inputlines, $_;
            }
            close $PERFLOG or debug(DBCRT, "error closing $worklog: $OS_ERROR");
            unlink $worklog;
        }
        if (not @inputlines) { debug(DBDEB, "inputdata empty $Config{perflog}"); }
    }
    return @inputlines;
}

# Process received data
sub getrras {
    my ($service, $rras, $choice) = @_;
    if (not $choice) {
        if (defined $Config{maximums}->{$service}) {
            $choice = 'MAX';
        } elsif (defined $Config{minimums}->{$service}) {
            $choice = 'MIN';
        } else {
            $choice = 'AVERAGE';
        }
    }
    return "RRA:$choice:0.5:1:$rras->[0]", "RRA:$choice:0.5:6:$rras->[1]",
           "RRA:$choice:0.5:24:$rras->[2]", "RRA:$choice:0.5:288:$rras->[3]";
}

# Create new rrd databases if necessary
sub runcreate {
    my $ds = shift;
    dumper(DBDEB, 'runcreate DS', $ds);
    RRDs::create(@{$ds});
    my $ERR = RRDs::error();
    if ($ERR) {
        debug(DBERR, 'runcreate RRDs::create ERR ' . $ERR);
        if ($Config{debug} < DBDEB) { dumper(DBERR, 'runcreate ds', $ds); }
    }
    return;
}

sub checkdatasources {
    my ($dsmin, $directory, $filenames, $labels) = @_;
    if (scalar @{$dsmin} == 3 and scalar @{$filenames} == 1) { ## no critic (ProhibitMagicNumbers)
        debug(DBCRT, "createrrd no data sources defined for $directory/$filenames->[0]");
        dumper(DBCRT, 'createrrd labels', $labels);
        return 0;
    }
    return 1;
}

sub createrrd {
    my ($host, $service, $start, $labels) = @_;
    debug(DBDEB, "createrrd($host, $service, $start, $labels->[0])");
    my ($directory,             # modifiable directory name for rrd database
        @filenames,             # rrd file name(s)
        @datasets,
        $db,                    # value of $labels->[0]
        @rras,                  # number of rows of data kept in each data set
        @resolution,            # temporary hold for configuration values
        @ds,                    # rrd create options for regular data
        @dsmin,                 # rrd create options for minimum points
        @dsmax,                 # rrd create options for maximum points
        $ds);                    # data set ID string

    if (defined $Config{resolution}) {
        @resolution = split / /, $Config{resolution};
        dumper(DBINF, 'createrrd resolution',  \@resolution);
    }

    ## no critic (ProhibitMagicNumbers)
    $rras[0] = defined $resolution[0] ? $resolution[0] : 600;
    $rras[1] = defined $resolution[1] ? $resolution[1] : 700;
    $rras[2] = defined $resolution[2] ? $resolution[2] : 775;
    $rras[3] = defined $resolution[3] ? $resolution[3] : 797;
    ## use critic

    $db = shift @{$labels};
    ($directory, $filenames[0]) = mkfilename($host, $service, $db);
    debug(DBDEB, "createrrd checking $directory/$filenames[0]");
    @ds = ("$directory/$filenames[0]", '--start', $start);
    @dsmin = ("$directory/$filenames[0]_min", '--start', $start);
    @dsmax = ("$directory/$filenames[0]_max", '--start', $start);
    push @datasets, [];
    for my $ii (0 .. @{$labels} - 1) {
        next if not $labels->[$ii];
        dumper(DBDEB, "labels->[$ii]", $labels->[$ii]);
        $ds = join q(:), ('DS', $labels->[$ii]->[0], $labels->[$ii]->[1],
            $Config{heartbeat}, $labels->[$ii]->[1] eq 'DERIVE' ? '0' : 'U', 'U');
        if (defined $Config{hostservvar}->{$host} and
            defined $Config{hostservvar}->{$host}->{$service} and
            defined $Config{hostservvar}->{$host}->{$service}->{$labels->[$ii]->[0]}) {
            my $filename = (mkfilename($host, $service . $labels->[$ii]->[0], $db, 1))[1];
            push @filenames, $filename;
            push @datasets, [$ii];
            if (not -e "$directory/$filename") {
                runcreate(["$directory/$filename", '--start', $start, $ds,
                    getrras($service, \@rras)]);
            }
            if (checkminmax('min', $service, $directory, $filename)) {
                runcreate(["$directory/${filename}_min", '--start', $start, $ds,
                    getrras($service, \@rras, 'MIN')]);
            }
            if (checkminmax('max', $service, $directory, $filename)) {
                runcreate(["$directory/${filename}_max", '--start', $start, $ds,
                    getrras($service, \@rras, 'MAX')]);
            }
            next;
        } else {
            push @ds, $ds;
            push @{$datasets[0]}, $ii;
            if (defined $Config{withminimums}->{$service}) { push @dsmin, $ds; }
            if (defined $Config{withmaximums}->{$service}) { push @dsmax, $ds; }
        }
    }
    if (not -e "$directory/$filenames[0]" and
        checkdatasources(\@ds, $directory, \@filenames, $labels)) {
        push @ds, getrras($service, \@rras);
        runcreate(\@ds);
    }
    dumper(DBDEB, 'createrrd filenames', \@filenames);
    dumper(DBDEB, 'createrrd datasets', \@datasets);
    createminmax(\@dsmin, \@filenames, \@rras, {conf => 'min',
        service => $service, directory => $directory, labels => $labels});
    createminmax(\@dsmax, \@filenames, \@rras, {conf => 'max',
        service => $service, directory => $directory, labels => $labels});
    return \@filenames, \@datasets;
}

sub checkminmax {
    my ($conf, $service, $directory, $filename) = @_;
    debug(DBDEB, "checkminmax($conf, $service, $directory, $filename)");
    if (defined $Config{'with' . $conf . 'imums'}->{$service} and
        not -e $directory . q(/) . $filename . q(_) . $conf) {
        return 1;
    }
    return 0;
}

sub createminmax {
    my ($ds, $filenames, $rras, $opts) = @_;
    dumper(DBDEB, 'createminmax opts', $opts);
    if (checkminmax($opts->{conf}, $opts->{service}, $opts->{directory}, $filenames->[0]) and
        checkdatasources($ds, $opts->{directory}, $filenames, $opts->{labels})) {
        my $conf = $opts->{conf};
        $conf =~ tr/[a-z]/[A-Z]/;
        push @{$ds}, getrras($opts->{service}, $rras, $conf);
        runcreate($ds);
    }
    return;
}

# Use RRDs to update rrd file
sub runupdate {
    my $dataset = shift;
    dumper(DBINF, 'runupdate dataset', $dataset);
    RRDs::update(@{$dataset});
    my $ERR = RRDs::error();
    if ($ERR) {
        debug(DBERR, 'runupdate RRDs::update ERR ' . $ERR);
        if ($Config{debug} < DBINF) { dumper(DBERR, 'runupdate dataset', $dataset); }
    }
    return;
}

sub rrdupdate {
    my ($file, $time, $values, $host, $dataset) = @_;
    debug(DBDEB, "rrdupdate($file, $time, $host)");
    my ($directory, @dataset, $ii, $service) = ($Config{rrddir});

    # Select target folder depending on config settings
    if ($Config{dbseparator} eq 'subdir') { $directory .= "/$host"; }

    push @dataset, "$directory/$file",  $time;
    for my $ii (0 .. @{$values} - 1) {
        for (@{$dataset}) {
            if ($ii == $_) {
                $values->[$ii]->[2] ||= 0;
                $dataset[1] .= ":$values->[$ii]->[2]";
                last;
            }
        }
    }
    runupdate(\@dataset);

    $service = (split /_/, $file)[0];
    if (defined $Config{withminimums}->{$service}) {
        $dataset[0] = "$directory/${file}_min";
        runupdate(\@dataset);
    }
    if (defined $Config{withmaximums}->{$service}) {
        $dataset[0] = "$directory/${file}_max";
        runupdate(\@dataset);
    }
    return;
}

# Read the map file and define a subroutine that parses performance data
sub getrules {
    my $file = shift;
    debug(DBDEB, "getrules($file)");
    my ($rval, $FH, @rules, $rules);
    open $FH, '<', $file or die "$OS_ERROR\n";
    while (<$FH>) {
        push @rules, $_;
    }
    close $FH or debug(DBCRT, "error closing $file: $OS_ERROR");
    ## no critic (ValuesAndExpressions)
    $rules = 'sub evalrules { $_ = $_[0];' .
        ' my ($d, @s) = ($_);' .
        ' no strict "subs";' .
        join(q(), @rules) .
        ' use strict "subs";' .
        ' return () if ($#s > -1 && $s[0] eq "ignore");' .
        ' debug(3, "perfdata not recognized: " . $d) unless @s;'.
        ' return @s; }';
    $rval = eval $rules; ## no critic (ProhibitStringyEval)
    if ($EVAL_ERROR or $rval) {
        debug(DBCRT, "Map file eval error: $EVAL_ERROR in: $rules");
    }
    return $rval;
}

# Process all input performance data
sub processdata {
    my (@lines) = @_;
    debug(DBDEB, 'processdata(' . scalar(@lines) . ')');
    my (@data, $debug, $rrds, $sets);
    for my $line (@lines) {
        @data = split /\|\|/, $line;
        # Suggested by Andrew McGill for 0.9.0, but I'm (Alan Brenner) not sure
        # it is still needed due to urlencoding in file names by mkfilename.
        # replace spaces with - in the description so rrd doesn't choke
        # $data[2] =~ s/\W+/-/g;
        $debug = $Config{debug};
        getdebug('insert', $data[1], $data[2]);
        dumper(DBDEB, 'processdata data', \@data);
        $_ = "servicedescr:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
        for my $s ( evalrules($_) ) {
            ($rrds, $sets) = createrrd($data[1], $data[2], $data[0] - 1, $s);
            next if not $rrds;
            for my $ii (0 .. @{$rrds} - 1) {
                rrdupdate($rrds->[$ii], $data[0], $s, $data[1], $sets->[$ii]);
            }
        }
        $Config{debug} = $debug;
    }
    return;
}

# I18N ########################################################################
%Ctrans = (
    # These come from the timeall, timehost and timeservice values defined in
    # the configuration file. +ly is the adverb form.
    day => 'Today',
    daily => 'Daily',
    week => 'This Week',
    weekly => 'Weekly',
    month => 'This Month',
    monthly => 'Monthly',
    quarter => 'This Quarter',
    quarterly => 'Quarterly',
    year => 'This Year',
    yearly => 'Yearly',

    # These are used as is, in the source. Verify with:
    # grep trans cgi/* etc/* | sed -e 's/^.*trans(\([^)]*\).*/\1/' | sort -u
    asof => 'as of',
    clear => 'clear',
    createdby => 'Created by',
    graph => 'Graph',
    graphof => 'Graph of',
    nohostgiven => 'no host specified',
    noservicegiven => 'no service specified',
    on => 'on',
    perfforgroup => 'Data for group',
    perfforhost => 'Data for host',
    perfforserv => 'Data for service',
    periods => 'Periods: ',
    selectds => 'Data Sets: ',
    selectgroup => 'Group: ',
    selecthost => 'Host: ',
    selectserv => 'Service: ',
    service => 'service',
    showhidecontrols => 'Show Controls',
    i18n_fixedscale => 'Fixed Scale',
    submit => 'Update Graphs',
    testcolor => 'Show Colors',
    typesome => 'Enter names separated by spaces',
    zoom => 'Size: ',

    # These come from Nagios, so are just from what I use.
    apcupsd => 'Uninterruptible Power Supply Status',
    bps => 'Bits Per Second',
    clamdb => 'Clam Database',
    diskgb => 'Disk Usage in GigaBytes',
    diskpct => 'Disk Usage in Percent',
    http => 'Bits Per Second',
    load => 'System Load Average',
    losspct => 'Loss Percentage',
    'Mem: swap' => 'Swap Utilization',
    swap => 'Swap Utilization',
    mailq => 'Pending Output E-mail Messages',
    memory => 'Memory Usage',
    ping => 'Ping Loss Percentage and Round Trip Average',
    pingloss => 'Ping Loss Percentage',
    pingrta => 'Ping Round Trip Average',
    PLW => 'Perl Log Watcher Events',
    procs => 'Processes',
    qsize => 'Messages in Outbound Queue',
    rta => 'Round Trip Average',
    smtp => 'E-mail Status',
);

sub trans {
    my ($text, $quiet) = @_;
    if (! defined($text) || $text eq q()) { return q(); }
    my $hexslash = '%2F';
    return unescape($text) if substr $text, 0, length($hexslash) eq $hexslash;
    return $Config{$text} if $Config{$text};
    return $Config{escape($text)} if $Config{escape($text)};
    if (not $Config{warned} and not $quiet) {
        debug(DBWRN, 'define "' . escape($text) . '" in ' . $CFGNAME);
        $Config{warned} = 1;
    }
    # The hope is not to get to here except in the case of upgrades where
    # the configuration file doesn't have the translation values.
    return $Ctrans{$text} if $Ctrans{$text};
    if (not $Config{ctrans}
        and not $quiet
        and $text !~ /%2F/
        and $text !~ /^\//) {
        debug(DBCRT, "please define '$text' in $CFGNAME and report it");
        $Config{ctrans} = 1;
    }
    # This can get ugly, so make sure %Ctrans has everything.
    return $text
}

# sort a list naturally using implementation by tye at 
# http://www.perlmonks.org/?node=442237
sub sortnaturally {
    my(@list) = @_;
    return @list[
        map { unpack 'N', substr $_,-4 } ## no critic (ProhibitMagicNumbers)
        sort
        map {
            my $key = $list[$_];
            $key =~ s/((?<!\.)(\d+)\.\d+(?!\.)|\d+)/
                my $len = length( defined($2) ? $2 : $1 );
                pack( 'N', $len ) . $1 . ' ';
            /ge;
            $key . pack 'N', $_
        } 0..$#list
    ];
}

1;

__END__

=head1 NAME

ngshared.pm - shared subroutines for the nagiosgraph programs

=head1 SYNOPSIS

B<use lib '/path/to/this/file';>
B<use ngshared;>

=head1 DESCRIPTION

A shared set of routines for reading configuration files, logging, etc.

=head1 USAGE

There is no direct invocation.  ngshared.pm contains functions that can be used to graph RRD data sets with data for hosts and services from Nagios.

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 DIAGNOSTICS

=head1 EXIT STATUS

=head1 CONFIGURATION

ngshared.pm uses B<nagiosgraph.conf> for most configuration.  ngshared.pm also includes subroutines to read from B<hostdb.conf>, B<servdb.conf>, B<groupdb.conf>, and B<rrdopts.conf> files.  These files are typically located in /etc/nagiosgraph.

=head1 INSTALLATION

Copy this file into a configuration directory (/etc/nagiosgraph, for example) and modify the B<use lib> line in each *.cgi file to the directory.

=head1 DEPENDENCIES

=over 4

=item B<rrdtool>

This provides the data storage and graphing system.

=item B<RRDs>

This provides the perl interface to rrdtool.

=back

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this simple and tested.

=head1 INCOMPATIBILITIES

=head1 SEE ALSO

B<insert.pl> B<showgraph.cgi> B<show.cgi> B<showhost.cgi> B<showservice.cgi> B<showgroup.cgi> B<testcolor.cgi>

=head1 AUTHOR

Soren Dossing, the original author in 2005.

Alan Brenner - alan.brenner@ithaka.org; I've updated this from the version at http://nagiosgraph.wiki.sourceforge.net/ by moving some subroutines into this shared file (ngshared.pm) for use by insert.pl and the show*.cgi files.

Matthew Wall.  Added some graphing and display features.  General bugfixing,
cleanup and refactoring.  Added showgraph.cgi.  Added CSS and JavaScript for
graph and time period controls.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005 Soren Dossing, 2009 Andrew W. Mellon Foundation

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
