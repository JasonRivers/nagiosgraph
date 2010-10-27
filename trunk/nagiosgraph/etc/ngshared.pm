#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license-2.0.php
# Author:  (c) Soren Dossing, 2005
# Author:  (c) Alan Brenner, Ithaka Harbors, 2008
# Author:  (c) Matthew Wall, 2010

# FIXME: get rid of the global variables

## no critic (RegularExpressions)
## no critic (ProhibitCascadingIfElse)
## no critic (ProhibitExcessComplexity)
## no critic (ProhibitDeepNests)
## no critic (ProhibitMagicNumbers)
## no critic (ProhibitConstantPragma)

use strict;
use warnings;
use Carp;
use CGI qw(escape unescape -nosticky);
use Data::Dumper;
use English qw(-no_match_vars);
use Fcntl qw(:DEFAULT :flock);
use File::Find;
use File::Basename;
use RRDs;
use POSIX;
use Time::HiRes qw(gettimeofday);
use MIME::Base64;

use constant PROG => basename($PROGRAM_NAME);

use constant {
    DBCRT => 1,
    DBERR => 2,
    DBWRN => 3,
    DBINF => 4,
    DBDEB => 5,
};

use constant {
    NAGIOSGRAPHURL => 'http://nagiosgraph.sourceforge.net/',
    ERRSTYLE => 'font-family: sans-serif; font-size: 0.8em; padding: 0.5em; background-color: #fff6f3; border: solid 1px #cc3333; margin-bottom: 1.5em;',
    DBLISTROWS => 3,
    PERIODLISTROWS => 5,
    RRDEXT => '.rrd',
    DEFAULT => 'default',
    DSNAME_MAXLEN => 19,
};

# the javascript version number here must match the version number in the
# nagiosgraph.js file.  change this number when the javascript is not
# backward compatible with previous versions.
use constant {
    JSVERSION => 1.5,
    JSWARNING => 'nagiosgraph.js is not installed or wrong version, or JavaScript is disabled.',
};

# default values for configuration options
use constant {
    GEOMETRIES => '500x80,650x150,1000x200',
    GRAPHWIDTH => 600,
    COLORMAX => '888888',
    COLORMIN => 'BBBBBB',
    COLORS => 'D05050,D08050,D0D050,50D050,50D0D0,5050D0,D050D0',
    COLORSCHEME => 1,
    STEPSIZE => 300,
    HEARTBEAT => 600,
    RESOLUTIONS => '600 700 775 797',
    PERIODS => 'day week month year',
};

# 5x5 clear image
use constant IMG => 'iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAIXRFWHRTb2Z0d2FyZQBHcmFwaGljQ29udmVydGVyIChJbnRlbCl3h/oZAAAAGUlEQVR4nGL4//8/AzrGEKCCIAAAAP//AwB4w0q2n+syHQAAAABJRU5ErkJggg==';

use vars qw(%Config %Labels %i18n %authhosts %authz %hsdata $colorsub $VERSION $LOG); ## no critic (ProhibitPackageVars)
$colorsub = -1;
$VERSION = '1.4.3';

my $CFGNAME = 'nagiosgraph.conf';

# Pre-defined available graph periods
#     Daily      =  33h = 118800s
#     Weekly     =   9d = 777600s
#     Monthly    =   5w = 3024000s
#     Quarterly  =  14w = 8467200s
#     Yearly     = 400d = 34560000s
# Period data tuples are [name, period (seconds), offset (seconds)]
my @PERIOD_KEYS = qw(day week month quarter year);
my %PERIOD_DATA = ('day' => ['day', 118_800, 86_400],
                   'week' => ['week', 777_600, 604_800],
                   'month' => ['month', 3_024_000, 2_592_000],
                   'quarter' => ['quarter', 8_467_200, 7_776_000],
                   'year' => ['year', 34_560_000, 31_536_000],);
my %PERIOD_LABELS =qw(day Day week Week month Month quarter Quarter year Year);

# keys for string literals in the javascript
my @JSLABELS = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
push @JSLABELS, qw(Mon Tue Wed Thu Fri Sat Sun);
push @JSLABELS, qw(OK Now Cancel);
push @JSLABELS, 'now', 'graph data';

# image parameters
my @IMG_FG_COLOR = (255,20,20);

# Debug/logging support #######################################################
# Write information to STDERR
sub stacktrace {
    my $msg = shift;
    warn "$msg\n";
    my $max_depth = 30;
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
        print ${LOG} "$message\n" or carp("cannot write to LOG: $OS_ERROR");
        flock $LOG, LOCK_UN;
        return 0;
    };
    if ($EVAL_ERROR or $rval) {
        stacktrace($message);
    }
    return;
}

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

sub gettimestamp {
    return (gettimeofday)[1];
}

# if a filename is relative, we look for it in the configuration directory.
# otherwise use the complete filename.
sub getcfgfn {
    my ($fn) = @_;
    if ( substr($fn, 0, 1) ne q(/) ) {
        $fn = $INC[0] . q(/) . $fn;
    }
    return $fn;
}

sub formatelapsedtime {
    my ($s,$e) = @_;
    my $ms = $e - $s;
    my $hh = int $ms / 3_600_000_000;
    $ms -= $hh * 3_600_000_000;
    my $mm = int $ms / 60_000_000;
    $ms -= $mm * 60_000_000;
    my $ss = int $ms / 1_000_000;
    $ms -= $ss * 1_000_000;
    $ms = int $ms / 1_000;
    if ($hh < 10) { $hh = '0' . $hh; }
    if ($mm < 10) { $mm = '0' . $mm; }
    if ($ss < 10) { $ss = '0' . $ss; }
    if ($ms < 1) { $ms = '000'; }
    elsif ($ms < 10) { $ms = '00' . $ms; }
    elsif ($ms < 100) { $ms = '0' . $ms; }
    return $hh . q(:) . $mm . q(:) . $ss . q(.) . $ms;
}

sub init {
    my ($app) = @_;

    my $errmsg = readconfig($app, 'cgilogfile');
    if ($errmsg ne q()) {
        htmlerror($errmsg);
        croak($errmsg);
    }

    my ($cgi, $params) = getparams();
    getdebug($app, $params->{host}, $params->{service});

    $errmsg = readi18nfile($cgi->param('language'));
    if ($errmsg ne q()) {
        debug(DBWRN, $errmsg);
    }
    $errmsg = readlabelsfile();
    if ($errmsg ne q()) {
        debug(DBWRN, $errmsg);
    }
    $errmsg = checkrrddir('read');
    if ($errmsg ne q()) {
        htmlerror($errmsg);
        croak($errmsg);
    }
    $errmsg = readrrdoptsfile();
    if ($errmsg ne q()) {
        htmlerror($errmsg);
        croak($errmsg);
    }
    $errmsg = loadperms( $cgi->remote_user() );
    if ($errmsg ne q()) {
        htmlerror($errmsg);
        croak($errmsg);
    }

    dumper(DBDEB, 'config', \%Config);
    dumper(DBDEB, 'params', $params);
    dumper(DBDEB, 'i18n', \%i18n);
    dumper(DBDEB, 'labels', \%Labels);

    scanhsdata();
    #dumper(DBDEB, 'all host/service data', \%hsdata);
    %authhosts = getserverlist( $cgi->remote_user() );
    #dumper(DBDEB, 'data for ' . $cgi->remote_user(), \%authhosts);

    return $cgi, $params;
}

# If logging is enabled, make sure we can write to the log file.
# Attempt to write to the log file.  If that fails, write to STDERR.
# CGI scripts will typically fail to write to the log file (unless
# the web server user has write permissions on it), so output will
# go to the web server logs.
sub initlog {
    my ($app, $logfn) = @_;
    if (defined $Config{'debug_' . $app}) {
        $Config{debug} = $Config{'debug_' . $app};
    }
    if (! $logfn) {
        $logfn = defined $Config{logfile} ? $Config{logfile} : q();
    }
    if ($Config{debug} > 0) {
        if (not open $LOG, '>>', $logfn) { ## no critic (RequireBriefOpen)
            open $LOG, '>&=STDERR' or ## no critic (RequireBriefOpen)
                croak('Cannot log to file or STDERR');
            debug(DBCRT, "Cannot write to '$logfn', using STDERR instead");
        }
    }
    return;
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
            debug(DBDEB, "getdebug found host $host");
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
            debug(DBDEB, "getdebug found service $serv");
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
# db=db[,ds[,ds[...]]] (may be comma-delimited or specified multiple times)
# geom=WxH
# rrdopts=
# offset=seconds
# period=(day,week,month,quarter,year)
# graphonly
# showgraphtitle
# hidelegend
# fixedscale
# showtitle
# showdesc
# expand_controls
# expand_period=(day,week,month,quarter,year)
#
sub getparams {
    my $cgi = new CGI;  ## no critic (ProhibitIndirectSyntax)
    $cgi->autoEscape(0);
    my %rval;

    # these flags are either string or array
    for my $ii (qw(host service db label group geom rrdopts offset period expand_period)) {
        if ($cgi->param($ii)) {
            if (ref($cgi->param($ii)) eq 'ARRAY') {
                my @rval = $cgi->param($ii);
                $rval{$ii} = \@rval;
            } elsif ($ii eq 'db' || $ii eq 'label') {
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
    if (not $rval{db}) { $rval{db} = []; }
    if (not $rval{label}) { $rval{label} = []; }

    if ($rval{offset}) { $rval{offset} = int $rval{offset}; }
    if (not $rval{offset} or $rval{offset} <= 0) { $rval{offset} = 0; }

    return $cgi, \%rval;
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
    my @refresh;
    if ($Config{refresh}) {
        @refresh = (-http_equiv => 'Refresh', -content => "$Config{refresh}");
    }
    return @refresh;
}

# configure parameters with something that we are sure will work.  grab values
# from the supplied default object.  if there are any gaps, use values from the
# configuration.
sub cfgparams {
    my($p, $dflt) = @_;

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

    return;
}

sub arrayorstring {
    my ($opts, $param) = @_;
    #dumper(DBDEB, "arrayorstring param=$param opts", $opts);
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
        return q();
    }
    debug(DBDEB, "buildurl($host, $service)");
    dumper(DBDEB, 'buildurl opts', $opts);
    my $url = join q(&), 'host=' . $host, 'service=' . $service;
    $url .= arrayorstring($opts, 'db');
    $url .= arrayorstring($opts, 'geom');
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
    my ($host, $service, $db) = @_;
    if (not $host or not $service) {
        debug(DBWRN, 'cannot construct filename: missing host or service');
        return 'BOGUSDIR', 'BOGUSFILE';
    }
    $db ||= q();
    my $directory = $Config{rrddir};
    my $filename = q();
    if (defined $Config{dbseparator} && $Config{dbseparator} eq 'subdir') {
        $directory .=  q(/) . $host;
        if ($db) {
            $filename = escape("${service}___${db}") . RRDEXT;
        } else {
            $filename = escape("${service}___");
        }
    } else {
        # Build filename for traditional separation
        if ($db) {
            $filename = escape("${host}_${service}_${db}") . RRDEXT;
        } else {
            $filename = escape("${host}_${service}_");
        }
    }
    return $directory, $filename;
}

# this is completely self-contained so that it can be called no matter what
# error we encounter.  stylesheet is hard-coded so no dependencies.
sub htmlerror {
    my ($msg) = @_;
    my $cgi = new CGI; ## no critic (ProhibitIndirectSyntax)
    print $cgi->header(-type => 'text/html', -expires => 0) .
        $cgi->start_html(-id => 'nagiosgraph',
                         -title => 'NagiosGraph Error',
                         -head => $cgi->style({-type=>'text/css'},
                                              '.error {' . ERRSTYLE . '}')) .
        $cgi->div( { -class => 'error' }, $msg ) . "\n" .
        $cgi->end_html() or
        debug(DBCRT, "could not write to STDOUT: $OS_ERROR");
    return;
}

sub imgerror {
    my ($cgi, $msg) = @_;
    $OUTPUT_AUTOFLUSH = 1;
    print $cgi->header(-type => 'image/png') .
        ( defined $msg && $msg ne q() ? getimg($msg) : decode_base64(IMG))
        or debug(DBCRT, "could not write to STDOUT: $OS_ERROR");
    return;
}

# emit a png image with the message in it.  only works if GD is available.
# if no GD, just return a small blank image.
sub getimg {
    my ($msg) = @_;
    debug(DBDEB, "getimg($msg)");
    my $rval = eval { require GD; };
    if (defined $rval && $rval == 1) {
        my @lines = split /\n/, $msg;
        my $pad = 4;
        my $maxw = 600;
        my $maxh = 15;
        my $width = 2 * $pad + $maxw;
        my $height = 2 * $pad + $maxh * scalar @lines;
        my $img = GD::Image->new($width, $height);
        my $wht = $img->colorAllocate(255, 255, 255);
        my $fg = $img->colorAllocate($IMG_FG_COLOR[0],
                                     $IMG_FG_COLOR[1],
                                     $IMG_FG_COLOR[2]);
        $img->transparent($wht);
        $img->rectangle(2,2,$width-3,$height-3,$wht);
        my $y = $pad;
        foreach my $line (@lines) {
            $img->string(GD->gdSmallFont,$pad,$y,"$line",$fg);
            $y += $maxh;
        }
        return $img->png;
    }
    return decode_base64(IMG);
}

# Color subroutines ###########################################################
# Choose a color for service
sub hashcolor {
    my $label = shift;
    my $color = shift;
    $color ||= $Config{colorscheme};
    debug(DBDEB, "hashcolor($color)");

    # color 9 is user defined (or the default rainbow if nothing userdefined).
    if ($color == 9) {
        # Wrap around, if we have more values than given colors
        $colorsub++;
        if ($colorsub >= scalar @{$Config{colors}}) { $colorsub = 0; }
        debug(DBDEB, 'hashcolor: returning color = ' . $Config{colors}[$colorsub]);
        return $Config{colors}[$colorsub];
    }

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
# parse string values and store them as a data structure
sub listtodict {
    my ($val, $sep, $commasplit) = @_;
    $sep ||= q(,);
    $commasplit ||= 0;
    #debug(DBDEB, "listtodict($val, $sep, $commasplit)");
    my (%rval);
    $Config{$val} ||= q();
    if (ref $Config{$val} eq 'HASH') {
        #debug(DBDEB, 'listtodict returning existing hash');
        return $Config{$val};
    }
    $Config{$val . 'sep'} ||= $sep;
    #debug(DBDEB, 'listtodict splitting "' . $Config{$val} . '" on "' . $Config{$val . 'sep'} . q(")); # "
    foreach my $ii (split $Config{$val . 'sep'}, $Config{$val}) {
        if ($val eq 'hostservvar') {
            my @data = split /,/, $ii;
            #dumper(DBDEB, 'listtodict hostservvar data', \@data);
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
            #dumper(DBDEB, 'listtodict commasplit data', \@data);
            $rval{$data[0]} = $data[1];
        } else {
            $rval{$ii} = 1;
        }
    }
    $Config{$val} = \%rval;
    #dumper(DBDEB, 'listtodict rval', $Config{$val});
    return $Config{$val};
}

sub str2hash {
    my ($str) = @_;
    my %rval;
    foreach my $i (split /;/, $str) {
        my ($n, $v) = split /=/, $i;
        $rval{$n} = $v;
    }
    return \%rval;
}

sub str2list {
    my ($str) = @_;
    my @rval;
    foreach my $i (split /;/, $str) {
        push @rval, $i;
    }
    return \@rval;
}

# Subroutine for checking that the directory with RRD file is not empty
sub checkdirempty {
    my $directory = shift;
    if (not opendir DIR, $directory) {
        debug(DBCRT, "cannot open directory $directory: $OS_ERROR");
        return 0;
    }
    my @files = readdir DIR;
    closedir DIR or debug(DBERR, "cannot close $directory: $OS_ERROR");
    return (scalar @files > 2) ? 0 : 1;
}

# pass a debug value if you want to debug the initial config file parsing.
# otherwise the debug level will be set by whatever is found in the config.
sub readfile {
    my ($filename, $hashref, $debug) = @_;
    $debug ||= 0;
    debug(DBDEB, "readfile($filename, $debug)");
    if ($debug) { $Config{debug} = $debug; }
    open my $FH, '<', $filename or ## no critic (RequireBriefOpen)
        return "cannot open $filename: $OS_ERROR";
    my $cfgdebug;
    my ($key, $val);
    while (<$FH>) {
        next if /^\s*#/;        # skip commented lines
        s/^\s+//;               # removes leading whitespace
        /^([^=]+)\s*=\s*(.*)$/x and do { # splits into key=val pairs
            $key = $1;
            $val = $2;
            $key =~ s/\s+$//;   # removes trailing whitespace
            $val =~ s/\s+$//;   # removes trailing whitespace
            if ($key eq 'debug') {
                $cfgdebug = $val;
            } else {
                $hashref->{$key} = $val;
            }
            #debug(DBDEB, "$filename $key:$val");
        };
    }
    close $FH or return "close failed for $filename: $OS_ERROR";
    if (defined $cfgdebug) {
        $hashref->{debug} = $cfgdebug;
    }
    return q();
}

# check status of the rrd directory.  this expects either 'write' or 'read'.
sub checkrrddir {
    my ($rrdstate) = @_;
    my $errmsg = q();
    if ($rrdstate eq 'write') {
        # Make sure rrddir exists and is writable
        if (not -d $Config{rrddir}) {
            debug(DBINF, "checkrrddir: creating directory $Config{rrddir}");
            mkdir $Config{rrddir} or
                $errmsg = "Cannot create rrd directory: $OS_ERROR";
        } elsif (not -w $Config{rrddir}) {
            $errmsg = "Cannot write to rrd directory $Config{rrddir}";
        }
    } else {
        # Make sure rrddir is readable and not empty
        if (! -r $Config{rrddir} ) {
            $errmsg = "Cannot read rrd directory $Config{rrddir}";
        } elsif (checkdirempty($Config{rrddir})) {
            $errmsg = "No data in rrd directory $Config{rrddir}";
        }
    }
    if ($errmsg ne q()) { debug(DBCRT, $errmsg); }
    return $errmsg;
}

# read the config file.  get the log initialized as soon as possible.
# ensure sane default values for everything, even if not specified.
sub readconfig {
    my ($app, $logid) = @_;
    if (! $logid) { $logid = 'logfile'; }

    my $debug = 0; # set this higher to debug config file parsing
    my $errstr = readfile($INC[0] . q(/) . $CFGNAME, \%Config, $debug);
    if ($errstr ne q()) { return $errstr; }

    initlog($app, $Config{$logid});

    $Config{rrdoptshash}{global} =
        defined $Config{rrdopts} ? $Config{rrdopts} : q();

    foreach my $ii ('maximums', 'minimums', 'withmaximums', 'withminimums',
                    'altautoscale', 'nogridfit', 'logarithmic', 'negate',
                    'plotasLINE1', 'plotasLINE2', 'plotasLINE3',
                    'plotasAREA', 'plotasTICK', 'stack') {
        listtodict($ii, q(,));
    }
    foreach my $ii ('hostservvar', 'lineformat') {
        listtodict($ii, q(;));
    }
    foreach my $ii ('altautoscalemax', 'altautoscalemin') {
        listtodict($ii, q(;), 1);
    }
    foreach my $ii ('heartbeats', 'stepsizes', 'resolutions') {
        if (defined $Config{$ii}) {
            $Config{$ii . 'list'} = str2list($Config{$ii});
        }
    }

    # set these only if they have not been specified in the config file
    foreach my $ii (['timeall', 'day week month'],
                    ['timehost', 'day'],
                    ['timeservice', 'day'],
                    ['timegroup', 'day'],
                    ['expand_timeall', 'day week month'],
                    ['expand_timehost', 'day'],
                    ['expand_timeservice', 'day'],
                    ['expand_timegroup', 'day'],
                    ['geometries', GEOMETRIES],
                    ['colorscheme', COLORSCHEME],
                    ['colors', COLORS],
                    ['colormax', COLORMAX],
                    ['colormin', COLORMIN],
                    ['resolution', RESOLUTIONS],
                    ['heartbeat', HEARTBEAT],
                    ['stepsize', STEPSIZE],) {
        if (not $Config{$ii->[0]}) { $Config{$ii->[0]} = $ii->[1]; }
    }
    $Config{colors} = [split /\s*,\s*/, $Config{colors}];

    return q();
}

sub readrrdoptsfile {
    if ( defined $Config{rrdoptsfile} ) {
        my $errstr = readfile(getcfgfn($Config{rrdoptsfile}),
                              $Config{rrdoptshash});
        if ($errstr ne q()) {
            return $errstr;
        }
    }
    return q();
}

sub loadperms {
    my ($user) = @_;

    if ( defined $Config{authzmethod} ) {
        if ( $Config{authzmethod} eq 'nagios3' ) {
            return readnagiosperms( $user );
        } elsif ( $Config{authzmethod} eq 'nagiosgraph' ) {
            return readpermsfile( $user );
        } else {
            return "unknown authzmethod '$Config{authzmethod}'";
        }
    }
    return q();
}

# FIXME: respect contacts, not just all host/services
# FIXME: verify intent of nagios 'default_user'.  do we have to match the
#        user, or if default_user is defined then anything goes?
# read the nagios permissions configuration.  this would be a lot easier if
# there were an api.  instead we have to read the config files and basically
# reverse engineer the nagios behavior.
sub readnagiosperms {
    my ($user) = @_;

    undef %authz;
    $authz{default_host_access}{default_service_access} = 0;
    if ( not defined $user or $user eq q() ) {
        debug(DBWRN, 'no discernable user, defaulting to no permissions');
        return q();
    }
    if ( not defined $Config{authz_nagios_cfg}
         or $Config{authz_nagios_cfg} eq q() ) {
        return 'authz_nagios_cfg is not defined';
    }
    my $authenabled = 0;
    my $fn = $Config{authz_nagios_cfg};
    open my $FH, '<', $fn or
        return "cannot open nagios config $fn: $OS_ERROR";
    while (<$FH>) {
        next if /^\s*#/;        # skip commented lines
        if ( /\s*use_authentication\s*=\s*([\d])/ ) {
            $authenabled = $1;
            last;
        }
    }
    close $FH or return "close failed for $fn: $OS_ERROR";

    if ( not $authenabled ) {
        undef %authz;
        debug(DBINF, 'nagios authorization is disabled, full access granted');
        return q();
    }

    if (not defined $Config{authz_cgi_cfg} or $Config{authz_cgi_cfg} eq q()) {
        return 'authz_cgi_cfg is not defined';
    }
    $fn = $Config{authz_cgi_cfg};
    my $host_users = q();
    my $serv_users = q();
    my $default_user = q();
    open $FH, '<', $fn or ## no critic (RequireBriefOpen)
        return "cannot open nagios cgi config $fn: $OS_ERROR";
    while (<$FH>) {
        next if /^\s*#/;        # skip commented lines
        if ( /\s*authorized_for_all_hosts=\s*(.*)/ ) {
            $host_users = $1;
            $host_users =~ s/\s//g;
        } elsif ( /\s*authorized_for_all_services=\s*(.*)/ ) {
            $serv_users = $1;
            $serv_users =~ s/\s//g;
        } elsif ( /\s*default_user_name\s*=\s*(.*)/ ) {
            $default_user = $1;
        }
    }
    close $FH or return "close failed for $fn: $OS_ERROR";

    # if there is a nagios default user, they can do anything
    if ( $user eq $default_user ) {
        $authz{default_host_access}{default_service_access} = 1;
    } else {
        foreach my $i (split /,/, $host_users) {
            if ( $user eq $i ) {
                $authz{default_host_access}{default_service_access} = 1;
                last;
            }
        }
        foreach my $i (split /,/, $serv_users) {
            if ( $user eq $i ) {
                $authz{default_host_access}{default_service_access} = 1;
                last;
            }
        }
    }

    return q();
}

# read the authz file.  we load permissions only for the indicated user (no
# need to know permissions for anyone else).  if no authzfile is specified,
# do not apply access control rules.  if no user is specified, then lockdown.
sub readpermsfile {
    my ($user) = @_;

    # defining authz enables enforcement of access controls.
    # default to no permissions.
    undef %authz;
    $authz{default_host_access}{default_service_access} = 0;
    if ( not defined $user or $user eq q() ) {
        debug(DBWRN, 'no discernable user, defaulting to no permissions');
        return q();
    }
    if ( not defined $Config{authzfile} or $Config{authzfile} eq q() ) {
        return 'authzfile is not defined';
    }
    my $fn = getcfgfn($Config{authzfile});
    open my $FH, '<', $fn or ## no critic (RequireBriefOpen)
        return "cannot open access control file $fn: $OS_ERROR";
    my $lineno = 0;
    while (<$FH>) {
        $lineno += 1;
        next if /^\s*#/;        # skip commented lines
        s/^\s+//;               # removes leading whitespace
        if ( /^([^=]+)\s*=\s*(.*)$/x ) {
            my $n = $1;
            my $v = $2;
            $n =~ s/\s+$//;
            $v = scrubuserlist($v);
            if (checkuserlist($v)) {
                debug(DBWRN, "authzfile: bad userlist '$v' (line $lineno)");
                next;
            }
            my ($h,$s) = split /,/, $n;
            $h =~ s/\s+//g;
            if (not $h or $h eq q() or $h eq q(*)) {
                $h = 'default_host_access';
            }
            if (not $s or $s eq q() or $s eq q(*)) {
                $s = 'default_service_access';
            }
            my $p = getperms($user, $v);
            if (defined $p) {
                $authz{$h}{$s} = $p;
            }
        } else {
            debug(DBWRN, "authzfile: bad format (line $lineno)");
        }
    }
    close $FH or return "close failed for $fn: $OS_ERROR";
    return q();
}

sub scrubuserlist {
    my ($v) = @_;
    $v =~ s/\s+//g;      # remove all spaces from userlist
    return $v;
}

sub checkuserlist {
    my ($v) = @_;
    if ( $v =~ /[^!a-zA-Z0-9_\.\*-,]/ ) {
        return 1;
    }
    return 0;
}

# do glob matching.  wrap it in an eval to ensure no failures.
# return 1 if user matches positive, 0 if matches negative, undef if no match.
# consider bad pattern a rejection.
sub getperms {
    my ($user, $str) = @_;
    if ($str eq q()) { return 0; }
    my $match;
    foreach my $pattern (split /,/, $str) {
        $pattern =~ s/\./\\./g;
        $pattern =~ s/\*/\.\*/g;
        my $rval = eval {
            my $m = 1;
            if (substr($pattern, 0, 1) eq q(!)) {
                $pattern = substr $pattern, 1;
                $m = 0;
            }
            if ( $user =~ /^${pattern}$/ ) {
                return $m;
            }
            return;
        };
        if ($EVAL_ERROR) {
            debug(DBCRT, "bad regex pattern '$pattern'");
            return 0;
        }
        if (defined $rval) {
            $match = $rval;
        }
    }
    return $match;
}

# determine whether the user can view the indicated host and service.
# the format for the authz structure is:
#
# authz = { * => { * => 0, service9 => 1 },
#           host0 => { * => 1, service1 => 0 },
#           host1 => { service0 => 0, service3 => 0 },
#           host2 => { service0 => 1, service1 => 0 },
#         };
#
sub havepermission {
    my ($host, $service) = @_;
    if ( not defined %authz ) {
        return 1;
    }
    my $ok = 0;
    if ( defined $authz{default_host_access}{default_service_access} ) {
        $ok = $authz{default_host_access}{default_service_access};
        if ( defined $service
             and defined $authz{default_host_access}{$service} ) {
            $ok = $authz{default_host_access}{$service};
        }
    }
    if ( defined $host and defined $authz{$host} ) {
        if ( defined $authz{$host}{default_service_access} ) {
            $ok = $authz{$host}{default_service_access};
        }
        if ( defined $service and defined $authz{$host}{$service} ) {
            $ok = $authz{$host}{$service};
        }
    }
    return $ok;
}

sub readlabelsfile {
    if ( defined $Config{labelfile} ) {
        undef %Labels;
        my $errstr = readfile(getcfgfn($Config{labelfile}), \%Labels);
        if ($errstr ne q()) {
            return $errstr;
        }
    }
    return q();
}

# get the i18n strings.  use the language we are given.  if there is none, use
# the language from the config file.  if there is none, use the environment.
# if that fails, warn.  if there is no file corresponding to the language,
# warn about it so someone can create a translation.  if someone defines a
# specialized en file, use it, but do not complain if we do not find en since
# that is what we fall back to.
sub readi18nfile {
    my ($lang) = @_;
    if ( ! $lang ) {
        $lang = $Config{language};
    }
    if ( ! $lang ) {
        ($lang) = ($ENV{HTTP_ACCEPT_LANGUAGE}
                   ? split /,/, $ENV{HTTP_ACCEPT_LANGUAGE} : q());
    }
    if ( $lang && $lang ne q()) {
        $lang =~ tr/-/_/;
        my $fn = getcfgfn( mki18nfilename( $lang ));
        if ( ! -f $fn  && $lang =~ /(..)_/ ) {
            $lang = $1;
            $fn = getcfgfn( mki18nfilename( $lang ));
        }
        if ( -f $fn ) {
            my $errstr = readfile( $fn, \%i18n );
            if ( $errstr ne q() ) {
                return $errstr;
            }
        } elsif ( substr($lang, 0, 2) ne q(en)) {
            return "No translations for '$lang' ($fn)";
        }
    } else {
        return 'Cannot determine language';
    }
    return q();
}

sub mki18nfilename {
    my ($key) = @_;
    return 'nagiosgraph_' . $key . '.conf';
}

sub parsedb {
    my ($line) = @_;
    $line =~ s/^&db=//;
    my @db = split /&db=/, $line;
    my %labels;
    for my $i (0 .. @db - 1) {
        if ($db[$i] =~ /([^&]+)&label=(.*)/) {
            $db[$i] = $1;
            $labels{$db[$i]} = $2;
        }
    }
    return \@db, \%labels;
}

# return all databases for the indiated host-service pair
sub getdbs {
    my ($host, $service, $data) = @_;
    my @db;
    if ($data->{$host}{$service}) {
        @db = @{$data->{$host}{$service}};
    }
    return \@db;
}

# return the subset of the specified databases for which we actually have data.
sub filterdb {
    my ($host, $service, $dblist, $data) = @_;
    my @actualdb;
    if ($data->{$host}{$service} && $dblist) {
        my @dbs = @{$data->{$host}{$service}};
        foreach my $x (@{$dblist}) {
            my $found = 0;
            my ($db,$ds) = split /,/, $x;
            for my $i (0 .. @dbs-1) {
                my @known = @{$dbs[$i]};
                if ($db eq $known[0]) {
                    if ($ds) {
                        for my $i (1 .. @known-1) {
                            if ($ds eq $known[$i]) {
                                push @actualdb, $x;
                                last;
                            }
                        }
                    } else {
                        push @actualdb, $x;
                    }
                }
            }
        }
    }
    return \@actualdb;
}

# remove leading and trailing spaces.  there is no need to escape the strings
# in the config files, but we unescape just in case someone has done this.
# older distributions included escaped labels in the sample configs.
sub cleanline {
    my ($line) = @_;
    $line = unescape($line);
    $line =~ tr/+/ /;
    $line =~ s/^\s+//g;
    $line =~ s/\s+$//g;
    return $line;
}

# Read hostdb file
#
# This returns a list of graph infos for the specified host based on the
# contents of the hostdb file.
#
# If there is no file defined or if the file contains no service lines,
# return all services for which data exist for the indicated host.
#
# Services are defined with this format:
#
#   service=name[&db=db[,ds][&label=text][&db=db[,ds][&label=text][...]]]
#
sub readhostdb {
    my ($host) = @_;
    $host ||= q();
    if ($host eq q() || $host eq q(-)) { return (); }

    debug(DBDEB, "readhostdb($host)");

    my $usedefaults = 1;
    my @ginfo;
    if (defined $Config{hostdb}) {
        my $fn = getcfgfn($Config{hostdb});
        if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
            my $lineno = 0;
            while (my $line = <$DB>) {
                chomp $line;
                $lineno += 1;
                next if $line =~ /^\s*#/;        # skip commented lines
                $line = cleanline($line);
                my $service = q();
                my $label = q();
                if ( $line =~ s/^service\s*=\s*([^&]+)// ) {
                    $service = $1;
                    if ($line =~ s/^&label=([^&]+)//) {
                        $label = $1;
                    }
                }
                if ( ! $service ) {
                    if ( $line =~ /\S+/ ) {
                        debug(DBWRN, "hostdb: bad format (line $lineno)");
                    }
                    next;
                }
                $usedefaults = 0;
                my ($db, $dblabel);
                if ($line ne q()) {
                    ($db, $dblabel) = parsedb($line);
                    $db = filterdb($host, $service, $db, $authhosts{hostserv});
                    next if scalar @{$db} == 0;
                } else {
                    # find out if there are data for this host-service, but
                    # do not specify the databases explicitly.
                    my $x = getdbs($host, $service, \%hsdata);
                    next if scalar @{$x} == 0;
                    $db = [];
                    $dblabel = [];
                }
                my %info;
                $info{host} = $host;
                $info{service} = $service;
                if ($label ne q())  { $info{service_label} = $label; }
                $info{db} = $db;
                $info{db_label} = $dblabel;
                push @ginfo, \%info;
                debug(DBDEB, "readhostdb: match for $host $service $line");
            }
            close $DB or debug(DBERR, "readhostdb: close failed for $fn: $OS_ERROR");
        } else {
            my $msg = "cannot open hostdb $fn: $OS_ERROR";
            debug(DBERR, $msg);
            htmlerror($msg);
            die $msg; ## no critic (RequireCarping)
        }
    } else {
        debug(DBINF, 'no hostdb file has been specified');
    }

    if ($usedefaults) {
        debug(DBDEB, 'readhostdb: using defaults');
        my $defaultds = readdatasetdb();
        my @services = sortnaturally(keys %{$hsdata{$host}});
        foreach my $service (@services) {
            my %info;
            $info{host} = $host;
            $info{service} = $service;
            if ($defaultds && $defaultds->{$service}) {
                $info{db} = $defaultds->{$service};
            } else {
                $info{db} = \@{$hsdata{$host}{$service}};
            }
            push @ginfo, \%info;
        }
    }

    dumper(DBDEB, 'graphinfos', \@ginfo);
    return \@ginfo;
}

# Read the servdb file
#
# This returns a list of hosts that have data for the specified service and db.
#
# If there is no file defined or if the file contains no hosts,
# return all hosts for which data exist for the indicated service and db.
#
# Hosts are defined with this format:
#
#   host=name[,name1[,name2[...]]]
#
sub readservdb {
    my ($service, $dblist) = @_;
    $service ||= q();
    if ($service eq q() || $service eq q(-)) { return (); }

    debug(DBDEB, "readservdb($service, " .
          ($dblist ? join ', ', @{$dblist} : q()) . ')');

    my $usedefaults = 1;
    my @allhosts;
    my @validhosts;
    if (defined $Config{servdb}) {
        my $fn = getcfgfn($Config{servdb});
        if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
            my $lineno = 0;
            while (my $line = <$DB>) {
                chomp $line;
                $lineno += 1;
                next if $line =~ /^\s*#/;        # skip commented lines
                $line = cleanline($line);
                if ( $line =~ /^host\s*=\s*(.+)/ ) {
                    $usedefaults = 0;
                    push @allhosts, split /\s*,\s*/, $1;
                } elsif ( $line =~ /\S+/ ) {
                    debug(DBWRN, "servdb: bad format (line $lineno)");
                }
            }
            close $DB or debug(DBERR, "readservdb: close failed for $fn: $OS_ERROR");
        } else {
            my $msg = "cannot open servdb $fn: $OS_ERROR";
            debug(DBERR, $msg);
            htmlerror($msg);
            die $msg; ## no critic (RequireCarping)
        }

        # check to see if there is a valid database for the host/service
        foreach my $host (@allhosts) {
            if ($dblist) {
                my $db = filterdb($host,$service,$dblist,$authhosts{hostserv});
                if ($db && scalar @{$db} > 0) {
                    push @validhosts, $host;
                }
            } else {
                my $x = getdbs($host, $service, \%hsdata);
                if (scalar @{$x} > 0) {
                    push @validhosts, $host;
                }
            }
        }
    } else {
        debug(DBINF, 'no servdb file has been specified');
    }

    if ($usedefaults) {
        debug(DBDEB, 'readservdb: using defaults');
        @allhosts = sortnaturally(keys %hsdata);
        foreach my $host (@allhosts) {
            if ($hsdata{$host}{$service}
                && scalar @{$hsdata{$host}{$service}} > 0) {
                push @validhosts, $host;
            }
        }
    }

    dumper(DBDEB, 'readservdb: all hosts', \@allhosts);
    dumper(DBDEB, 'readservdb: validated hosts', \@validhosts);
    return \@validhosts;
}

# Read the groupdb file
#
# This returns a list of graph infos for the specified group and a list
# of all group names.
#
# Groups are defined with this format:
#
#   groupname=host,service[&label=text][&db=db[,ds][&label=text][...]]
#
sub readgroupdb {
    my ($g) = @_;
    $g ||= q();
    debug(DBDEB, "readgroupdb($g)");

    if (! defined $Config{groupdb} || $Config{groupdb} eq q()) {
        my $msg = 'no groupdb file has been specified';
        debug(DBERR, $msg);
        htmlerror($msg);
        die $msg; ## no critic (RequireCarping)
    }

    my $fn = getcfgfn($Config{groupdb});
    my %gnames;
    my @ginfo;
    if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
        my $lineno = 0;
        while (my $line = <$DB>) {
            chomp $line;
            $lineno += 1;
            next if $line =~ /^\s*#/;        # skip commented lines
            $line = cleanline($line);
            my $group = q();
            my $host = q();
            my $service = q();
            my $label = q();
            if ( $line =~ s/^([^=]+)\s*=\s*([^,]+)\s*,\s*([^&]+)// ) {
                $group = $1;
                $host = $2;
                $service = $3;
                if ($line =~ s/^&label=([^&]+)//) {
                    $label = $1;
                }
            }
            if ( ! $group || ! $host || ! $service ) {
                if ( $line =~ /\S+/ ) {
                    debug(DBWRN, "groupdb: bad format (line $lineno)");
                }
                next;
            }
            $gnames{$group} = 1;
            next if $group ne $g;
            my ($db, $dblabel);
            if ($line ne q()) {
                ($db, $dblabel) = parsedb($line);
                $db = filterdb($host, $service, $db, $authhosts{hostserv});
                next if scalar @{$db} == 0;
            } else {
                # find out if there are data for this host-service, but
                # do not specify the databases explicitly.
                my $x = getdbs($host, $service, \%hsdata);
                next if scalar @{$x} == 0;
                $db = [];
                $dblabel = [];
            }
            my %info;
            $info{host} = $host;
            $info{service} = $service;
            if ($label ne q())  { $info{service_label} = $label; }
            $info{db} = $db;
            $info{db_label} = $dblabel;
            push @ginfo, \%info;
            debug(DBDEB, "readgroupdb: match for $host $service $line");
        }
        close $DB or debug(DBERR, "readgroupdb: close failed for $fn: $OS_ERROR");
    } else {
        my $msg = "cannot open groupdb $fn: $OS_ERROR";
        debug(DBERR, $msg);
        htmlerror($msg);
        die $msg; ## no critic (RequireCarping)
    }

    my @gnames = sortnaturally(keys %gnames);

    dumper(DBDEB, 'groups', \@gnames);
    dumper(DBDEB, 'graphinfos', \@ginfo);
    return \@gnames, \@ginfo;
}

# Default data for services are defined using lines with this format:
#
#   service=name&db=database[,ds-name][&db=database[,ds-name][...]]
#
# Data sets from the db file are used only if no data sets are specified as
# an argument to this subroutine.
sub readdatasetdb {
    if (! defined $Config{datasetdb} || $Config{datasetdb} eq q()) {
        my $msg = 'no datasetdb file has been specified';
        debug(DBDEB, $msg);
        my %rval;
        return \%rval;
    }

    my %data;
    my $fn = getcfgfn($Config{datasetdb});
    if (open my $DB, '<', $fn) { ## no critic (RequireBriefOpen)
        my $lineno = 0;
        while (my $line = <$DB>) {
            chomp $line;
            $lineno += 1;
            next if $line =~ /^\s*#/;        # skip commented lines
            $line = cleanline($line);
            if ( $line =~ /^service\s*=\s*([^&]+)(.+)/ ) {
                my $service = $1;
                my $dbstr = $2;
                my ($db, $dblabel) = parsedb($dbstr);
                $data{$service} = $db;
                debug(DBDEB, 'readdatasetdb: match for ' . $line);
            } elsif ( $line =~ /\S+/ ) {
                debug(DBWRN, "datasetdb: bad format (line $lineno)");
            }
        }
        close $DB or debug(DBERR, "readdatasetdb: close failed for $fn: $OS_ERROR");
    } else {
        my $msg = "cannot open datasetdb $fn: $OS_ERROR";
        debug(DBERR, $msg);
        htmlerror($msg);
        die $msg; ## no critic (RequireCarping)
    }

    dumper(DBDEB, 'readdatasetdb: data sets', \%data);
    return \%data;
}

# Get list of matching rrd files
# unescape the filenames as we read in since they should be escaped on disk
sub dbfilelist {
    my ($host, $serv) = @_;
    my @rrd;
    debug(DBDEB, "dbfilelist($host, $serv)");
    if ($host ne q() && $host ne q(-) && $serv ne q() && $serv ne q(-)) {
        my ($directory, $filename) = mkfilename($host, $serv);
        debug(DBDEB, "dbfilelist scanning $directory for $filename");
        if (opendir DH, $directory) {
            while (my $entry=readdir DH) {
                next if $entry =~ /^\./;
                if ($entry =~ /^${filename}(.+)\.rrd$/) {
                    push @rrd, unescape($1);
                }
            }
            closedir DH or debug(DBERR, "cannot close $directory: $OS_ERROR");
        } else {
            debug(DBERR, "cannot open directory $directory: $OS_ERROR");
        }
    }
    dumper(DBDEB, 'dbfilelist', \@rrd);
    return \@rrd;
}

# Graphing routines ###########################################################
# Return a list of the data 'lines' in an rrd file
sub getdataitems {
    my ($file) = @_;
    my ($ds,                 # return value from RRDs::info
        %dupes);             # temporary hash to filter duplicate values with
    if (-f $file) {
        $ds = RRDs::info($file);
    } else {
        $ds = RRDs::info("$Config{rrddir}/$file");
    }
    my $ERR = RRDs::error();
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
    debug(DBDEB, "graphinfo: host=$host service=$service");
    dumper(DBDEB, 'graphinfo: db', $db);

    my ($hs,                    # host/service
        @rrd,                    # the returned list of hashes
        $ds);

    if (defined $Config{dbseparator} && $Config{dbseparator} eq 'subdir') {
        $hs = $host . q(/) . escape("$service") . q(___);
    } else {
        $hs = escape("${host}_${service}") . q(_);
    }

    # Determine which files to read lines from
    if ($db && scalar @{$db} > 0) {
        my $nn = 0;
        for my $dd (@{$db}) {
            my ($dbname, @lines) = split /,/, $dd; # db filename, data sources
            $rrd[$nn]{file} = $hs . escape("$dbname") . RRDEXT;
            $rrd[$nn]{dbname} = $dbname;
            for my $ll (@lines) {
                my ($line, $unit) = split /~/, $ll;
                if ($unit) {
                    $rrd[$nn]{line}{$line}{unit} = $unit;
                } else {
                    $rrd[$nn]{line}{$line} = 1;
                }
            }
            $nn++;
        }
        debug(DBDEB, "graphinfo: Specified $hs db files in $Config{rrddir}: "
                     . join ', ', map { $_->{file} } @rrd);
    } else {
        @rrd = map {{ file=>$_ }}
                     map { "${hs}${_}.rrd" }
                     @{dbfilelist($host, $service)};
        debug(DBDEB, "graphinfo: Listing $hs db files in $Config{rrddir}: "
                     . join ', ', map { $_->{file} } @rrd);
    }

    foreach my $rrd ( @rrd ) {
        if (not $rrd->{line}) {
            foreach my $ii (getdataitems($rrd->{file})) {
                $rrd->{line}{$ii} = 1;
            }
            debug(DBDEB, "graphinfo: DS $rrd->{file} lines: "
                  . join ', ', keys %{$rrd->{line}});
        }
        if (not $rrd->{dbname}) {
            if ($rrd->{file} =~ /___(.*).rrd/) {
                $rrd->{dbname} = unescape($1);
            } elsif ($rrd->{file} =~ /_(.*).rrd/) {
                $rrd->{dbname} = unescape($1);
            }
            debug(DBDEB, "graphinfo: DS $rrd->{file} dbname: "
                  . $rrd->{dbname});
        }
    }

    dumper(DBDEB, 'graphinfo: rrd', \@rrd);
    return \@rrd;
}

sub getlineattr {
    my ($ds) = @_;
    my $stack = 0;
    if (defined $Config{stack}->{$ds}) {
        $stack = 1;
    }
    my $linestyle = $Config{plotas};
    foreach my $ii (qw(LINE1 LINE2 LINE3 AREA TICK)) {
        if (defined $Config{'plotas' . $ii}->{$ds}) {
            $linestyle = $ii;
            last;
        }
    }
    my $linecolor = q();
    if (defined $Config{lineformat}) {
        foreach my $tuple (keys %{$Config{lineformat}}) {
            if ($tuple =~ /^$ds,/) {
                my @values = split /,/, $tuple;
                foreach my $value (@values) {
                    if ($value eq 'LINE1' || $value eq 'LINE2' ||
                        $value eq 'LINE3' || $value eq 'AREA' ||
                        $value eq 'TICK') {
                        $linestyle = $value;
                    } elsif ($value =~ /[0-9a-f][0-9a-f][0-9a-f]+/) {
                        $linecolor = $value;
                    } elsif ($value eq 'STACK') {
                        $stack = 1;
                    }
                }
            }
        }
    }
    if ($linecolor eq q()) {
        $linecolor = hashcolor($ds);
    }
    return $linestyle, $linecolor, $stack;
}

# the rrd vname can contain only A-Za-z0-9_- and must be no more than 255 long
sub mkvname {
    my ($dbname, $dsname) = @_;
    my $vname = $dbname . '_' . $dsname;
    $vname =~ s/[^A-Za-z0-9_-]/_/g;
    if (length $vname > 255) {
        $vname = substr $vname, 0, 255;
    }
    return $vname;
}

# prepare a string for the rrd graph legend.  pad with trailing spaces.
# escape colons so they do not confuse rrdtool
sub mklegend {
    my ($s, $maxlen) = @_;
    $s =~ s/:/\\:/g;
    return sprintf "%-${maxlen}s", $s;
}

sub setlabels { ## no critic (ProhibitManyArgs)
    my ($dsname, $dbname, $file, $serv, $label, $maxlen) = @_;
    debug(DBDEB, "setlabels($dsname, $dbname, $file, $serv, $maxlen)");
    my @ds;
    my $id = mkvname($dbname, $dsname);
    my $legend = mklegend($label, $maxlen);
    my ($linestyle, $linecolor, $stack) = getlineattr($dsname);
    my $sdef = q();
    if ($stack) {
        $sdef = ':STACK';
    }
    if (defined $Config{maximums}->{$serv}) {
        push @ds, "DEF:$id=$file:$dsname:MAX"
                , "CDEF:ceil$id=$id,CEIL"
                , "$linestyle:${id}#$linecolor:$legend$sdef";
    } elsif (defined $Config{minimums}->{$serv}) {
        push @ds, "DEF:$id=$file:$dsname:MIN"
                , "CDEF:floor$id=$id,FLOOR"
                , "$linestyle:${id}#$linecolor:$legend$sdef";
    } else {
        push @ds, "DEF:${id}=$file:$dsname:AVERAGE";
        if (defined $Config{negate}->{$dsname}) {
            push @ds, "CDEF:${id}_neg=${id},-1,*";
            push @ds, "$linestyle:${id}_neg#$linecolor:$legend$sdef";
        } else {
            push @ds, "$linestyle:${id}#$linecolor:$legend$sdef";
        }
    }
    return @ds;
}

sub setdata { ## no critic (ProhibitManyArgs)
    my ($dsname, $dbname, $file, $serv, $fixedscale, $dur) = @_;
    debug(DBDEB, "setdata($dsname, $dbname, $file, $serv, $fixedscale, $dur)");
    my @ds;
    my $id = mkvname($dbname, $dsname);
    my $format = ($fixedscale ? '%7.2lf' : '%7.2lf%s');
    if ($dur > 120_000) { # long enough to start getting summation
        if (defined $Config{withmaximums}->{$serv}) {
            my $maxcolor = (defined $Config{colormax}
                            ? $Config{colormax} : COLORMAX);
            push @ds, "DEF:${id}_max=${file}_max:$dsname:MAX"
                    , "LINE1:${id}_max#${maxcolor}:" . _('maximum');
        }
        if (defined $Config{withminimums}->{$serv}) {
            my $mincolor = (defined $Config{colormin}
                            ? $Config{colormin} : COLORMIN);
            push @ds, "DEF:${id}_min=${file}_min:$dsname:MIN"
                    , "LINE1:${id}_min#${mincolor}:" . _('minimum');
        }
        if (defined $Config{withmaximums}->{$serv}) {
            push @ds, "CDEF:${id}_maxif=${id}_max,UN"
                    , "CDEF:${id}_maxi=${id}_maxif,${id},${id}_max,IF"
                    , "GPRINT:${id}_maxi:MAX:Max\\:$format";
        } else {
            push @ds, "GPRINT:$id:MAX:Max\\:$format";
        }
        push @ds, "GPRINT:$id:AVERAGE:Avg\\:$format";
        if (defined $Config{withminimums}->{$serv}) {
            push @ds, "CDEF:${id}_minif=${id}_min,UN"
                    , "CDEF:${id}_mini=${id}_minif,${id},${id}_min,IF"
                    , "GPRINT:${id}_mini:MIN:Min\\:$format\\n"
        } else {
            push @ds, "GPRINT:$id:MIN:Min\\:$format\\n"
        }
    } else {
        push @ds, "GPRINT:$id:MAX:Max\\:$format"
                , "GPRINT:$id:AVERAGE:Avg\\:$format"
                , "GPRINT:$id:MIN:Min\\:$format"
                , "GPRINT:$id:LAST:Cur\\:$format\\n";
    }
    return @ds;
}

# Generate all the parameters for rrd to produce a graph
sub rrdline {
    my ($params) = @_;
    dumper(DBDEB, 'rrdline params', $params);

    my @ds;
    my $host = $params->{host};
    my $service = $params->{service};
    my $db = $params->{db};
    my ($graphinfo) = graphinfo($host, $service, $db);

    my $errmsg = q();
    if (scalar @{$graphinfo} == 0) {
        $errmsg = 'No data available: host=' . $host . ' service=' . $service;
        if ($db) { $errmsg .= ' db=' . join q(,), @{$db}; }
    } else {
        foreach my $ii (@{$graphinfo}) {
            my @lines = keys %{$ii->{line}};
            if (scalar @lines == 0) {
                if ($errmsg ne q()) { $errmsg .= "\n"; }
                $errmsg .= 'No data available: host=' . $host . ' service=' . $service . ' db=' . $ii->{dbname};
            }
        }
    }
    if ($errmsg ne q()) {
        return \@ds, $errmsg;
    }

    # assimilate any labels that were specified
    if (defined $params->{label}) {
        foreach my $k (@{$params->{label}}) {
            if ( $k =~ /([^:]+):(.+)/ ) {
                $Labels{$1} = $2;
            }
        }
    }

    my $geom = $params->{geom};
    my $fixedscale = 0;
    if (defined $params->{fixedscale}) {
        $fixedscale = $params->{fixedscale};
    }
    my $duration = 118_800;
    if (defined $params->{period} && $PERIOD_DATA{$params->{period}}) {
        $duration = $PERIOD_DATA{$params->{period}}[1];
    }
    my $offset = 0;
    if (defined $params->{offset} && $params->{offset} ne q()) {
        $offset = $params->{offset};
    }

    # start with global rrdopts from the config file
    my $rrdopts = mergeopts(q(), $Config{rrdoptshash}{global});
    # add options for the specified service
    $rrdopts = mergeopts($rrdopts, $Config{rrdoptshash}{$service});
    # add options from the parameters
    $rrdopts = mergeopts($rrdopts, $params->{rrdopts});

    # use duration and offset from rrdopts if they were specified there.
    # this assumes formatting from printgraphicslinks.
    if ($rrdopts =~ /-enow-(\d+)/) {
        $offset = $1;
    }
    if ($rrdopts =~ /-snow-(\d+)/) {
        $duration = $1 - $offset;
    }

    # build the list of arguments for rrdtool
    push @ds, q(-);
    if (index($rrdopts, '-a') == -1 && index($rrdopts, '--imgformat') == -1) {
        push @ds, '-a', 'PNG';
    }
    if (index($rrdopts, '-s') == -1 && index($rrdopts, '--start') == -1) {
        my $s = $duration + $offset;
        push @ds, '-s', "now-$s";
    }
    if (index($rrdopts, '-e') == -1 && index($rrdopts, '--end') == -1) {
        push @ds, '-e', "now-$offset";
    }

    # Identify where to pull data from and what to call it
    my $directory = $Config{rrddir};
    # Compute the longest label length
    my $longest = 0;
    for my $ii (@{$graphinfo}) {
        my $dbname = $ii->{dbname};
        foreach my $dsname (keys %{$ii->{line}}) {
            my $label = getdatalabel("$dbname,$dsname");
            if (length $label > $longest) {
                $longest = length $label;
            }
        }
    }
    # now get the data and labels
    for my $ii (@{$graphinfo}) {
        my $file = $ii->{file};
        my $dbname = $ii->{dbname};
        my $fn = "$directory/$file";
        dumper(DBDEB, 'rrdline: this graphinfo entry', $ii);
        for my $dsname (sortnaturally(keys %{$ii->{line}})) {
            my ($serv, $pos) = ($service, length($service) - length $dsname);
            if (substr($service, $pos) eq $dsname) {
                $serv = substr $service, 0, $pos;
            }
            my $label = getdatalabel("$dbname,$dsname");
            push @ds, setlabels($dsname, $dbname, "$fn", $serv, $label, $longest);
            push @ds, setdata($dsname, $dbname, "$fn", $serv, $fixedscale, $duration);
        }
    }

    # Dimensions of graph
    my $w = 0;
    my $h = 0;
    if ($geom && $geom ne DEFAULT) {
        ($w, $h) = split /x/, $geom;
    } elsif (defined $Config{default_geometry}) {
        ($w, $h) = split /x/, $Config{default_geometry};
    } else {
        $w = GRAPHWIDTH; # make graph wider than rrdtool default
    }
    if ($w > 0 && index($rrdopts, '-w') == -1) {
        push @ds, '-w', $w;
    }
    if ($h > 0 && index($rrdopts, '-h') == -1) {
        push @ds, '-h', $h;
    }

    # Additional parameters to rrd graph, if specified
    my $opt = q();
    foreach my $ii (split /\s+/, $rrdopts) {
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
    if ($fixedscale && index($rrdopts, '-X') == -1) {
        push @ds, '-X', '0';
    }
    foreach my $ii (['altautoscale', '-A'],
                    ['altautoscalemin', '-J'],
                    ['altautoscalemax', '-M'],
                    ['nogridfit', '-N'],
                    ['logarithmic', '-o']) {
        push @ds, addopt($ii->[0], $service, $rrdopts, $ii->[1]);
    }
    return \@ds, q();
}

sub addopt {
    my ($conf, $service, $rrdopts, $rrdopt) = @_;
    my @ds;
    if (defined $Config{$conf}
        and exists $Config{$conf}{$service}
        and index($rrdopts, $rrdopt) == -1) {
        push @ds, $rrdopt;
    }
    return @ds;
}

# FIXME: at some point it might be nice to replace args in a with corresponding
# args from b.  for now we just append everything in b to a.
sub mergeopts {
    my ($a, $b) = @_;
    $b ||= q();
    return $a . ($b eq q() ? q() : q( ) . $b);
}

# Server/service menu routines ################################################
# scan the rrd files and populate the hsdata object with the result.
sub scanhsdata {
    if (defined $Config{dbseparator} && $Config{dbseparator} eq 'subdir') {
        File::Find::find(\&scanhierarchy, $Config{rrddir});
    } else {
        File::Find::find(\&scandirectory, $Config{rrddir});
    }
    return;
}

# scan for rrd files in a directory hierarchy.  build a hash with the result.
sub scanhierarchy {
    my $current = $_;
    my $rrdlen = 0 - length RRDEXT;
    if (-d $current and substr($current, 0, 1) ne q(.)) {
        # Directories are for hostnames
        if (not checkdirempty($current)) { %{$hsdata{$current}} = (); }
    } elsif (-f $current && substr($current, $rrdlen) eq RRDEXT) {
        # Files are for services
        my $host = $File::Find::dir;
        $host =~ s|^$Config{rrddir}/||;
        # We got the server to associate with and now
        # we get the service name by splitting on separator
        my ($service, $db) = split /___/, $current;
        if ($db) { $db = substr $db, 0, $rrdlen; }
        if (not exists $hsdata{$host}{unescape($service)}) {
            @{$hsdata{$host}{unescape($service)}} = (unescape($db));
        } else {
            push @{$hsdata{$host}{unescape($service)}}, unescape($db);
        }
    }
    return;
}

# scan for rrd files in a single directory.  build a hash with the result.
sub scandirectory {
    my $current = $_;
    my $rrdlen = 0 - length RRDEXT;
    if (-f $current && substr($current, $rrdlen) eq RRDEXT) {
        my $fn = substr $current, 0, $rrdlen;
        my ($host, $service, $db) = split /_/, $fn;
        if ($host && $service && $db) {
            if (not exists $hsdata{$host}{unescape($service)}) {
                @{$hsdata{$host}{unescape($service)}} = (unescape($db));
            } else {
                push @{$hsdata{$host}{unescape($service)}}, unescape($db);
            }
        }
    }
    return;
}

# get the list of hosts and services for which the user has permission.  the
# userid does nothing in this subroutine - it is just used in the messages.
sub getserverlist {
    my($userid) = @_;
    $userid ||= q();
    debug(DBDEB, "getserverlist userid=$userid");

    my @hosts;
    foreach my $ii (sortnaturally(keys %hsdata)) {
        if (havepermission($ii)) {
            push @hosts, $ii;
        } else {
            debug(DBINF, "permission denied: user $userid, host $ii");
        }
    }

    my %hostserv; # hash of hosts, services, and data
    foreach my $ii (@hosts) {
        my @services = sortnaturally(keys %{$hsdata{$ii}});
        foreach my $jj (@services) {
            if ( ! havepermission($ii, $jj) ) {
                debug(DBINF, "permission denied: user $userid, host $ii, service $jj");
                next;
            }
            foreach my $kk (@{$hsdata{$ii}{$jj}}) {
                my @dataitems =
                    getdataitems(join q(/), mkfilename($ii, $jj, $kk));
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

# Create Javascript i18n string constants
sub printi18nscript {
    if ( ! defined $Config{javascript} || $Config{javascript} eq q() ) {
        return q();
    }
    my $rval = "var i18n = {\n";
    foreach my $ii (@JSLABELS) {
        $rval .= '  "' . $ii . '": \'' . _($ii) . "',\n";
    }
    $rval .= "};\n";
    return "<script type=\"text/javascript\">\n" . $rval . "</script>\n";
}

# Create Javascript Arrays for client-side menu navigation
sub printmenudatascript {
    my ($hosts, $lookup) = @_;

    if ( ! defined $Config{javascript} || $Config{javascript} eq q() ) {
        return q();
    }

    my $rval .= "menudata = new Array();\n";
    for my $ii (0 .. @{$hosts} - 1) {
        $rval .= "menudata[$ii] = [\"$hosts->[$ii]\"\n";
        my @services = sortnaturally(keys %{$hsdata{$hosts->[$ii]}});
        #dumper(DBDEB, 'printmenudatascript: keys', \@services);
        foreach my $jj (@services) {
            my $s = $jj;
            $s =~ s/\\/\\\\/g;
            $rval .= " ,[\"$s\",";
            my $c = 0;
            foreach my $kk (@{$lookup->{$hosts->[$ii]}{$jj}}) {
                if ($c) {
                    $rval .= q(,);
                }
                my $name = q();
                my @ds;
                foreach my $x (@{$kk}) {
                    $x =~ s/\\/\\\\/g;
                    if ($name eq q()) {
                        $name = $x;
                    } else {
                        push @ds, $x;
                    }
                }
                $rval .= '["' . $name . '","' . join('","', sortnaturally(@ds)) . '"]';
                $c = 1;
            }
            $rval .= "]\n";
        }
        $rval .= "];\n";
    }
    return "<script type=\"text/javascript\">\n" . $rval . "</script>\n";
}

# Create Javascript Arrays for default service listings.
#
# sample input:
#  ( "net", ( "bytes-received", "bytes-transmitted" ),
#    "ping", ( "rta,rtaloss", "ping,loss" )
#  )
#
# sample output:
#  defaultds = new Array();
#  defaultds[0] = ["net", "bytes-received", "bytes-transmitted" ];
#  defaultds[1] = ["ping", "rta,rtaloss", "ping,loss"];
#
sub printdefaultsscript {
    my ($dsref) = @_;

    if ( ! defined $Config{javascript} || $Config{javascript} eq q() ) {
        return q();
    }

    my $rval = "defaultds = new Array();\n";
    if ($dsref) {
        my %dsdata = %{$dsref};
        my @keys = keys %dsdata;
        for my $ii (0 .. @keys - 1) {
            $rval .= "defaultds[$ii] = [\"$keys[$ii]\"";
            foreach my $ds (@{$dsdata{$keys[$ii]}}) {
                $rval .= ", \"$ds\"";
            }
            $rval .= "];\n";
        }
    }
    return "<script type=\"text/javascript\">\n" . $rval . "</script>\n";
}

sub printincludescript {
    if ( ! defined $Config{javascript} || $Config{javascript} eq q() ) {
        return q();
    }
    return "<script type=\"text/javascript\" src=\"$Config{javascript}\"></script>\n";
}

# emit the javascript that configures the web page.  this has to be at the
# end of the web page so that all elements have a chance to be instantiated
# before the javascript is invoked.
sub printinitscript {
    my ($host, $service, $expanded_periods) = @_;
    if ( ! defined $Config{javascript} || $Config{javascript} eq q() ) {
        return q();
    }
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
    my @geom = (DEFAULT, split /,/, $Config{geometries});
    my %geom_labels;
    foreach my $i (@geom) {
        $geom_labels{$i} = _($i);
    }
    my %period_labels;
    foreach my $i (@PERIOD_KEYS) {
        $period_labels{$i} = _($PERIOD_LABELS{$i});
    }

    my $menustr = q();
    if ($context eq 'both') {
        my $host = $opts->{host};
        my $service = $opts->{service};
        $menustr = $cgi->span({-class => 'selector'},
                              _('Host:') . q( ) .
                              $cgi->popup_menu(-name => 'servidors',
                                               -onChange => 'hostChange()',
                                               -values => [$host],
                                               -default => $host)) . "\n";
        $menustr .= $cgi->span({-class => 'selector'},
                               _('Service:') . q( ) .
                               $cgi->popup_menu(-name => 'services',
                                                -onChange => 'serviceChange()',
                                                -values => [$service],
                                                -default => $service));
    } elsif ($context eq 'host') {
        my $host = $opts->{host};
        $menustr = $cgi->span({-class => 'selector'},
                              _('Host:') . q( ) .
                              $cgi->popup_menu(-name => 'servidors',
                                               -values => [$host],
                                               -default => $host));
    } elsif ($context eq 'service') {
        my $service = $opts->{service};
        $menustr = $cgi->span({-class => 'selector'},
                              _('Service:') . q( ) .
                              $cgi->popup_menu(-name => 'services',
                                               -onChange => 'serviceChange()',
                                               -values => [$service],
                                               -default => $service));
    } elsif ($context eq 'group') {
        my $group = $opts->{group};
        my @groups = (q(-), @{$opts->{grouplist}});
        $menustr = $cgi->span({-class => 'selector'},
                              _('Group:') . q( ) .
                              $cgi->popup_menu(-name => 'groups',
                                               -values => [@groups],
                                               -default => $group));
    }

    return $cgi->
        div({-class => 'controls'}, "\n" .
            $cgi->start_form(-method => 'GET',
                             -action => $action,
                             -name => 'menuform') . "\n",
            $cgi->div({-id => 'js_version_' . JSVERSION, -style => ERRSTYLE},
                      _(JSWARNING)) . "\n",
            $cgi->div({-class => 'primary_controls'}, "\n",
                      $menustr . "\n",
                      $cgi->span({-class => 'executor'},
                                 $cgi->button(-name => 'go',
                                              -label => _('Update Graphs'),
                                              -onClick => 'jumpto()')
                                 ) . "\n"), "\n",
            $cgi->div({-class => 'secondary_controls'}, "\n" .
                      $cgi->p({-class => 'controls_toggle'},
                              $cgi->button(-name => 'showhidecontrols',
                                           -onClick => 'toggleControlsDisplay(this)',
                                           -label => q(-))) . "\n",
                      $cgi->div({-id => 'secondary_controls_box', -style => 'display:none'}, "\n" .
                                $cgi->table(($context eq 'both' || $context eq 'service')
                                            ? $cgi->Tr({-valign => 'top', -id => 'db_controls' },
                                                       $cgi->td({-class => 'control_label'}, _('Data Sets:')),
                                                       $cgi->td($cgi->popup_menu(-name => 'db', -values => [], -size => DBLISTROWS, -multiple => 1)),
                                                       $cgi->td($cgi->button(-name => 'clear', -label => _('Clear'), -onClick => 'clearDBSelection()')),
                                                       )
                                            : q(),
                                            $cgi->Tr({-valign => 'top'},
                                                     $cgi->td({-class => 'control_label'}, _('Periods:')),
                                                     $cgi->td($cgi->popup_menu(-name => 'period', -values => [@PERIOD_KEYS], -labels => \%period_labels, -size => PERIODLISTROWS, -multiple => 1)),
                                                     $cgi->td($cgi->button(-name => 'clear', -label => _('Clear'), -onClick => 'clearPeriodSelection()')),
                                                     ),
                                            $cgi->Tr($cgi->td({-class => 'control_label'}, _('End Date:')),
                                                     $cgi->td({-colspan => '2'}, $cgi->button(-name => 'enddate', -label => 'now', -onClick => 'showDateTimePicker(this)')),
                                                     ),
                                            $cgi->Tr($cgi->td({-class => 'control_label'}, _('Size:')),
                                                     $cgi->td($cgi->popup_menu(-name => 'geom', -values => [@geom], -labels => \%geom_labels)),
                                                     $cgi->td(q( )),
                                                     ),
                                            )) . "\n",
                      ) . "\n",
            $cgi->end_form . "\n");
}

sub printgraphlinks {
    my ($cgi, $params, $period, $title) = @_;
    if (! defined $title) { $title = q(); }
    dumper(DBDEB, 'printgraphlinks params', $params);
    dumper(DBDEB, 'printgraphlinks period', $period);

    my $gtitle = q();
    my $alttag = q();
    my $desc = q();

    my $showtitle = $params->{showtitle};
    my $showdesc = $params->{showdesc};
    my $showgraphtitle = $params->{showgraphtitle};

    # the description contains a list of the data set names.
    if ($showdesc) {
        if ($params->{db} && scalar @{$params->{db}} > 0) {
            foreach my $ii (sortnaturally(@{$params->{db}})) {
                if ($desc ne q()) { $desc .= $cgi->br(); }
                $desc .= getdatalabel($ii);
            }
        }
    }
    debug(DBDEB, 'printgraphlinks desc = ' . $desc);

    # include quite a bit of information in the alt tag - it helps when
    # debugging configuration files.
    $gtitle = $params->{service} . q( ) . _('on') . q( ) . $params->{host};
    $alttag = _('Graph of') . q( ) . $gtitle;
    if ($params->{db} && scalar @{$params->{db}} > 0) {
        $alttag .= ' (';
        foreach my $ii (sortnaturally(@{$params->{db}})) {
            $alttag .= q( ) . $ii;
        }
        $alttag .= ' )';
    }
    debug(DBDEB, 'printgraphlinks alttag = ' . $alttag);

    my $rrdopts = q();
    if ($params->{rrdopts}) {
        $rrdopts .= $params->{rrdopts};
    }
    if ($params->{graphonly} && index($rrdopts, '-j') == -1) {
        $rrdopts .= ' -j';
    }
    if ($params->{hidelegend} && index($rrdopts, '-g') == -1) {
        $rrdopts .= ' -g';
    }
    # the '-snow' and '-enow' formats matter - they are detected by rrdline
    my $soff = $period->[1] + $params->{offset};
    $rrdopts .= ' -snow-' . $soff;
    $rrdopts .= ' -enow-' . $params->{offset};
    if ($showgraphtitle) {
        if ($rrdopts !~ /(-t|--title)/) {
            my $t = $gtitle;
            $t =~ s/<br.*//g;     # use only the first line
            $t =~ s/<[^>]+>//g;   # punt any html markup
            $t =~ tr/-/:/;        # hyphens cause problems
            $rrdopts .= ' -t ' . $t;
        }
    }
    $rrdopts =~ tr/ /+/;
    $rrdopts =~ s/#/%23/g;
    debug(DBDEB, 'printgraphlinks rrdopts = ' . $rrdopts);

    my $url = $Config{nagiosgraphcgiurl} . '/showgraph.cgi?'
        . buildurl($params->{host}, $params->{service},
                   { geom => $params->{geom},
                     rrdopts => [$rrdopts],
                     fixedscale => $params->{fixedscale},
                     db => $params->{db},
                 });
    debug(DBDEB, "printgraphlinks url = $url");

    my $titlestr = $showtitle
        ? $cgi->p({-class=>'graph_title'}, $title) : q();
    my $descstr = $desc ne q()
        ? $cgi->p({-class=>'graph_description'}, $desc) : q();

    return $cgi->div({-class => 'graph'}, "\n",
                     $cgi->div({-class => 'graph_image'},
                               $cgi->img({-src=>$url,
                                          -alt=>$alttag,
                                          -onmouseover=>'ngzInit(this)'})) . "\n",
                     $cgi->div({-class => 'graph_details'}, "\n",
                               $titlestr, $titlestr ne q() ? "\n" : q(),
                               $descstr, $descstr ne q() ? "\n" : q(),
                               ));
}

sub printperiodlinks {
    my($cgi, $params, $period, $now, $content) = @_;
    my (@navstr) = getperiodctrls($cgi, $params->{offset}, $period, $now);
    my $id = 'period_data_' . $period->[0];
    return $cgi->div({-class => 'period_banner'},
                     $cgi->span({-class => 'period_title'},
                                $cgi->button(-id => 'toggle_' . $period->[0],
                                             -label => q(-),
                                             -onClick => 'togglePeriodDisplay(\'' . $id . '\', this)'),
                                $cgi->a({ -id => $period->[0] },
                                        _($PERIOD_LABELS{$period->[0]}))),
                     $cgi->span({-class => 'period_controls'},
                                $navstr[0],
                                $cgi->span({-class => 'period_detail'},
                                           $navstr[1]),
                                $navstr[2]),
                     ) . "\n" .
           $cgi->div({-class => 'period', -id => $id }, "\n" .
                     $content) . "\n";
}

sub printsummary {
    my($cgi, $opts) = @_;

    my $s = q();
    if ($opts->{call} eq 'both') {
        $s = _('Data for host') . q( ) .
            $cgi->span({-class => 'item_label'},
                       $cgi->a({href => $opts->{hosturl}},
                               $opts->{host})) .
            ', ' .
            _('service') . q( ) .
            $cgi->span({-class => 'item_label'},
                       $cgi->a({href => $opts->{serviceurl}},
                               getlabel($opts->{service})));
    } elsif ($opts->{call} eq 'host') {
        $s = _('Data for host') . q( ) .
            $cgi->span({-class => 'item_label'},
                       $cgi->a({href => $opts->{hosturl}},
                               $opts->{host}));
    } elsif ($opts->{call} eq 'service') {
        $s = _('Data for service') . q( ) .
            $cgi->span({-class => 'item_label'},
                       getlabel($opts->{service}));
    } elsif ($opts->{call} eq 'group') {
        $s = _('Data for group') . q( ) .
            $cgi->span({-class => 'item_label'},
                       getlabel($opts->{group}));
    }

    return $cgi->p({ -class => 'summary' },
                   $s . q( ) . _('as of') . q( ) .
                   $cgi->span({ -class => 'timestamp' },
                              formattime(time, 'timeformat_now')));
}

sub printheader {
    my ($cgi, $opts) = @_;

    my $rval = $cgi->header;
    $rval .= $cgi->start_html(-id => 'nagiosgraph',
                              -title => "nagiosgraph: $opts->{title}",
                              -head => $cgi->meta( { getrefresh() } ),
                              getstyle());

    $rval .= printmenudatascript($authhosts{host}, $authhosts{hostserv});
    if ($opts->{defaultdatasets}) {
        $rval .= printdefaultsscript($opts->{defaultdatasets});
    }
    $rval .= printincludescript();

    $rval .= printcontrols($cgi, $opts) . "\n";

    $rval .= (defined $Config{hidengtitle} and $Config{hidengtitle} eq 'true')
        ? q() : $cgi->h1('Nagiosgraph') . "\n";

    $rval .= printsummary($cgi, $opts) . "\n";

    return $rval;
}

sub printfooter {
    my ($cgi,$sts,$ets) = @_;
    $sts ||= 0;
    $ets ||= 0;
    my $tstr = (defined $Config{showprocessingtime}
                && $Config{showprocessingtime} eq 'true')
        ? $cgi->br() . formatelapsedtime($sts, $ets)
        : q();
    return $cgi->div({-class => 'footer'}, q(), # or instead of q() $cgi->hr()
                     _('Created by') . q( ) .
                     $cgi->a({href => NAGIOSGRAPHURL },
                             'Nagiosgraph ' . $VERSION) . $tstr )
        . $cgi->end_html();
}

# Full page routine ###########################################################
# Determine the number of graphs that will be displayed on the page
# and the time period they will cover.  This expects a comma-delimited
# or space-delimited list of period names.
#
# returns an array of period data, where each array element is a
# tuple of name, period, offset.
sub graphsizes {
    my $conf = shift;
    $conf =~ s/,/ /g; # we will split on whitespace
    dumper(DBDEB, 'graphsizes: period', $conf);
    my @unsorted;
    foreach my $ii (split /\s+/, $conf) {
        next if not exists $PERIOD_DATA{$ii};
        push @unsorted, $PERIOD_DATA{$ii};
    }
    if (not @unsorted) {
        debug(DBDEB, 'graphsizes: no period data found, using defaults');
        foreach my $ii (split / /, PERIODS) {
            push @unsorted, $PERIOD_DATA{$ii};
        }
    }
    my @rval = sort {$a->[1] <=> $b->[1]} @unsorted;
    return @rval;
}

# returns three strings: a url for previous period, a label for current
# display, and a url for the next period.  do not permit voyages into
# the future.
sub getperiodctrls {
    my ($cgi, $offset, $period, $now) = @_;

    # strip any offset from the url
    my $url = $ENV{REQUEST_URI} ? $ENV{REQUEST_URI} : q();
    $url =~ s/&*offset=[^&]*//;

    # now calculate and inject our own offset
    my $x = ($offset + $period->[2]);
    my $p = $cgi->a({-href=>"$url&offset=$x"}, '<');
    my $c = getperiodlabel($now,$offset,$period->[1],$period->[0]);
    $x = ($offset - $period->[2]);
    my $n = ($x < 0 ? q() : $cgi->a({-href=>"$url&offset=$x"}, '>'));

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

# read data from the perflog
sub readperfdata {
    my ($fn) = @_;
    my @lines;
    debug(DBDEB, 'readperfdata: ' . $fn);
    if (-s $fn) {
        my $worklog = $fn . '.nagiosgraph';
        if (! rename $fn, $worklog) {
            debug(DBCRT, "cannot process perflog: rename failed for $fn");
            return @lines;
        }
        if (open my $PERFLOG, '<', $worklog) {
            while (<$PERFLOG>) {
                push @lines, $_;
            }
            close $PERFLOG or debug(DBERR, "close failed for $worklog: $OS_ERROR");
            unlink $worklog;
        } else {
            debug(DBWRN, "cannot read perfdata from $worklog: $OS_ERROR");
            return @lines;
        }
    }
    if (not @lines) {
        debug(DBINF, 'readperfdata: empty perflog ' . $fn);
    }
    return @lines;
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
    dumper(DBINF, 'runcreate creating RRD: DS', $ds);
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
    if (scalar @{$dsmin} == 3 and scalar @{$filenames} == 1) {
        debug(DBCRT, "no data sources defined for $directory/$filenames->[0]");
        dumper(DBCRT, 'labels', $labels);
        return 0;
    }
    return 1;
}

# ensure that the name is ok as an rrd ds name.  if not, fail loudly.  we do
# not try to fix the name - just complain loudly about it and bail out.
sub checkdsname {
    my ($dsname) = @_;
    if (length $dsname > DSNAME_MAXLEN or $dsname =~ /[^a-zA-Z0-9_-]/) {
        return 1;
    }
    return 0;
}

sub gethsdmatch {
    my ($key, $val, $host, $service, $db) = @_;
    my $x = $val;
    if ( defined $Config{$key} ) {
        $x = $Config{$key};
    }
    if ( defined $Config{$key . 'list'} ) {
        foreach my $i (@{$Config{$key . 'list'}}) {
            my ($n, $v) = split /=/, $i;
            my $tuple = $host . q(,) . $service . q(,) . $db;
            if ($tuple =~ /$n/) {
                $x = $v;
            }
        }
    }
    return $x;
}

sub createrrd {
    my ($host, $service, $start, $labels) = @_;
    debug(DBDEB, "createrrd($host, $service, $start, $labels->[0])");
    my ($directory,             # directory in which to put rrd files
        @filenames);            # rrd file name(s)

    my $db = shift @{$labels};
    ($directory, $filenames[0]) = mkfilename($host, $service, $db);
    debug(DBDEB, "createrrd rrdfile is $directory/$filenames[0]");
    if (not -e $directory) { # ensure we can write to data directory
        debug(DBINF, "createrrd: creating directory $directory");
        if ( ! mkdir $directory, 0775 ) {
            my $msg = "cannot create directory $directory: $OS_ERROR";
            debug(DBCRT, $msg);
            croak($msg);
        }
    }
    if (not -w $directory) {
        my $msg = 'cannot write to directory ' . $directory;
        debug(DBCRT, $msg);
        croak($msg);
    }

    my $res = gethsdmatch('resolution', RESOLUTIONS, $host, $service, $db);
    my @rras = split / /, $res;
    if (scalar @rras != 4) {
        my $msg = 'wrong number of values for resolution (expecting 4, got '
            . scalar @rras . ')';
        debug(DBCRT, $msg);
        croak($msg);
    }

    my $heartbeat = gethsdmatch('heartbeat', HEARTBEAT, $host, $service, $db);

    my $stepsize = gethsdmatch('stepsize', STEPSIZE, $host, $service, $db);

    debug(DBDEB, 'createrrd step=' . $stepsize
          . ' heartbeat=' . $heartbeat
          . ' resolutions=' . join q( ), @rras);

    my @ds = ("$directory/$filenames[0]",
              '--start', $start, '--step', $stepsize,);
    my @dsmin = ("$directory/$filenames[0]_min",
                 '--start', $start, '--step', $stepsize,);
    my @dsmax = ("$directory/$filenames[0]_max",
                 '--start', $start, '--step', $stepsize,);

    my @datasets = [];
    for my $ii (0 .. @{$labels} - 1) {
        next if not $labels->[$ii];
        dumper(DBDEB, "labels->[$ii]", $labels->[$ii]);
        if (checkdsname($labels->[$ii]->[0])) {
            my $msg = 'ds-name is not valid: ' . $labels->[$ii]->[0];
            debug(DBCRT, $msg);
            croak($msg);
        }
        my $ds = join q(:), ('DS',
                             $labels->[$ii]->[0],
                             $labels->[$ii]->[1],
                             $heartbeat,
                             $labels->[$ii]->[1] eq 'DERIVE' ? '0' : 'U',
                             'U');
        if (defined $Config{hostservvar}->{$host} and
            defined $Config{hostservvar}->{$host}->{$service} and
            defined $Config{hostservvar}->{$host}->{$service}->{$labels->[$ii]->[0]}) {
            my $fn = (mkfilename($host, $service . $labels->[$ii]->[0], $db))[1];
            push @filenames, $fn;
            push @datasets, [$ii];
            if (not -e "$directory/$fn") {
                runcreate(["$directory/$fn",
                           '--start', $start, '--step', $stepsize,
                           $ds, getrras($service, \@rras)]);
            }
            if (checkminmax('min', $service, $directory, $fn)) {
                runcreate(["$directory/${fn}_min",
                           '--start', $start, '--step', $stepsize,
                           $ds, getrras($service, \@rras, 'MIN')]);
            }
            if (checkminmax('max', $service, $directory, $fn)) {
                runcreate(["$directory/${fn}_max",
                           '--start', $start, '--step', $stepsize,
                           $ds, getrras($service, \@rras, 'MAX')]);
            }
            next;
        } else {
            push @ds, $ds;
            push @{$datasets[0]}, $ii;
            if (defined $Config{withminimums}->{$service}) {
                push @dsmin, $ds;
            }
            if (defined $Config{withmaximums}->{$service}) {
                push @dsmax, $ds;
            }
        }
    }
    if (not -e "$directory/$filenames[0]" and
        checkdatasources(\@ds, $directory, \@filenames, $labels)) {
        push @ds, getrras($service, \@rras);
        runcreate(\@ds);
    }
    createminmax(\@dsmin, \@filenames, \@rras, {conf => 'min',
        service => $service, directory => $directory, labels => $labels});
    createminmax(\@dsmax, \@filenames, \@rras, {conf => 'max',
        service => $service, directory => $directory, labels => $labels});
    dumper(DBDEB, 'createrrd filenames', \@filenames);
    dumper(DBDEB, 'createrrd datasets', \@datasets);
    return \@filenames, \@datasets;
}

sub checkminmax {
    my ($conf, $service, $directory, $filename) = @_;
#    debug(DBDEB, "checkminmax($conf, $service, $directory, $filename)");
    if (defined $Config{'with' . $conf . 'imums'}->{$service} and
        not -e $directory . q(/) . $filename . q(_) . $conf) {
        return 1;
    }
    return 0;
}

sub createminmax {
    my ($ds, $filenames, $rras, $opts) = @_;
#    dumper(DBDEB, 'createminmax opts', $opts);
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
    }
    return;
}

sub rrdupdate {
    my ($file, $time, $values, $host, $ds) = @_;
    debug(DBDEB, "rrdupdate($file, $time, $host)");
    my $directory = $Config{rrddir};

    # Select target folder depending on config settings
    if (defined $Config{dbseparator} && $Config{dbseparator} eq 'subdir') {
        $directory .= "/$host";
    }

    my @dataset;
    push @dataset, "$directory/$file",  $time;
    for my $ii (0 .. @{$values} - 1) {
        for (@{$ds}) {
            if ($ii == $_) {
                $values->[$ii]->[2] ||= 0;
                $dataset[1] .= ":$values->[$ii]->[2]";
                last;
            }
        }
    }
    runupdate(\@dataset);

    my $service = (split /_/, $file)[0];
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
    my $file = getcfgfn(shift);
    debug(DBDEB, "getrules($file)");
    my @rules;
    if ( open my $FH, '<', $file ) {
        while (<$FH>) {
            push @rules, $_;
        }
        close $FH or debug(DBERR, "close failed for $file: $OS_ERROR");
    } else {
        my $msg = "cannot open $file: $OS_ERROR";
        debug(DBCRT, $msg);
        croak($msg);
    }
    ## no critic (RequireInterpolationOfMetachars)
    my $code = 'sub evalrules { $_ = $_[0];' .
        ' my ($d, @s) = ($_);' .
        ' no strict "subs";' .
        join(q(), @rules) .
        ' use strict "subs";' .
        ' return () if ($#s > -1 && $s[0] eq "ignore");' .
        ' debug(3, "output/perfdata not recognized:\n" . $d) unless @s;'.
        ' return @s; }';
    my $rval = eval $code; ## no critic (ProhibitStringyEval)
    if ($EVAL_ERROR or $rval) {
        debug(DBCRT, "Map file eval error: $EVAL_ERROR in: $code");
    }
    return $rval;
}

# process one or more lines that are nagios perfdata format
sub processdata {
    my (@lines) = @_;
    debug(DBDEB, 'processdata (' . scalar(@lines) . ' lines)');
    for my $line (@lines) {
        chomp $line;
        my @data = split /\|\|/, $line;
        $data[0] ||= q();
        $data[1] ||= q();
        $data[2] ||= q();
        $data[3] ||= q();
        $data[4] ||= q();
        if ( $data[0] eq q() ) {
            debug(DBWRN, 'processdata: no timestamp found');
            next;
        }
        if ( $data[1] eq q() ) {
            debug(DBWRN, 'processdata: no host found');
            next;
        }
        if ( $data[2] eq q() ) {
            debug(DBWRN, 'processdata: no service found');
            next;
        }
        my $debug = $Config{debug};
        getdebug('insert', $data[1], $data[2]);
        dumper(DBDEB, 'processdata data', \@data);
        $_ = "hostname:$data[1]\nservicedesc:$data[2]\noutput:$data[3]\nperfdata:$data[4]";
        for my $s ( evalrules($_) ) {
            my ($rrds, $sets) = createrrd($data[1], $data[2], $data[0]-1, $s);
            next if not $rrds;
            for my $ii (0 .. @{$rrds} - 1) {
                rrdupdate($rrds->[$ii], $data[0], $s, $data[1], $sets->[$ii]);
            }
        }
        $Config{debug} = $debug;
    }
    return;
}

# return a translation for the indicated key.  if there is no translation,
# return the key.
sub _ {
    my ($key) = @_;
    return $i18n{$key} ? $i18n{$key} : $key;
}

# labels use the same lookup mechanism as translations, but labels are not
# necessarily defined with a specific language.  we keep separate functions
# to make explicit the difference between a label and a translation.
sub getlabel {
    my ($key) = @_;
    return $Labels{$key} ? $Labels{$key} : $key;
}

# get the label associated with the indicated name.  the name could be a
# database name, a data source name, or a db,ds pair.
sub getdatalabel {
    my ($name) = @_;
    my $x = getlabel($name);
    if ($x eq $name) {
        my ($db,$ds) = split /,/, $name;
        if ($ds) {
            my $y = getlabel($ds);
            if ($y ne $ds) {
                $x = $y;
            }
        } elsif ($db) {
            my $y = getlabel($db);
            if ($y ne $db) {
                $x = $y;
            }
        }
    }
    return $x;
}

# sort a list naturally using implementation by tye at
# http://www.perlmonks.org/?node=442237
sub sortnaturally {
    my(@list) = @_;
    return @list[
        map { unpack 'N', substr $_,-4 }
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
