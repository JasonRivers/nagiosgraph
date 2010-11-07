#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# If you run this script manually it will prompt for all the information needed
# to do an install.  To do automated or unattended installations, set the
# environment variables.

## no critic (ProhibitExcessMainComplexity)
## no critic (ProhibitExcessComplexity)
## no critic (ProhibitCascadingIfElse)
## no critic (ProhibitPostfixControls)
## no critic (RequireBriefOpen)
## no critic (RequireCheckedSyscalls)
## no critic (RegularExpressions)
## no critic (ProhibitConstantPragma)

use English qw(-no_match_vars);
use File::Copy qw(copy move);
use ExtUtils::Command qw(touch);
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '1.0';

use constant EXIT_FAIL => -1;
use constant EXIT_OK => 0;
use constant DPERMS => oct 755;
use constant FPERMS => oct 644;
my $CACHE_FN = '.install-cache';
my $NAGIOS_STUB_FN = 'nagiosgraph-nagios.cfg';
my $APACHE_STUB_FN = 'nagiosgraph-apache.conf';

# put the keys in a specific order to make it easier to see where things go
my @CONFKEYS = qw(ng_layout ng_dest_dir ng_bin_dir ng_etc_dir ng_cgi_dir ng_doc_dir ng_css_dir ng_js_dir ng_util_dir ng_rrd_dir ng_log_file ng_cgilog_file ng_cgi_url ng_css_url ng_js_url nagios_cgi_url nagios_perfdata_file nagios_user www_user);

my @PRESETS = (
    { ng_layout => 'standalone',
      ng_var_dir => '/var/nagiosgraph',
      ng_url => '/nagiosgraph',
      ng_bin_dir => 'bin',
      ng_etc_dir => 'etc',
      ng_cgi_dir => 'cgi',
      ng_doc_dir => 'doc',
      ng_css_dir => 'share',
      ng_js_dir => 'share',
      ng_util_dir => 'util',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'overlay',
      ng_var_dir => '/var/nagios',
      ng_url => '/nagios',
      ng_bin_dir => 'libexec',
      ng_etc_dir => 'etc/nagiosgraph',
      ng_cgi_dir => 'sbin',
      ng_doc_dir => 'docs/nagiosgraph',
      ng_css_dir => 'share',
      ng_js_dir => 'share',
      ng_util_dir => 'docs/nagiosgraph/util',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'overlay',
      ng_dest_dir => q(/),
      ng_var_dir => '/var/nagios',
      ng_url => '/nagios',
      ng_bin_dir => '/usr/libexec/nagios',
      ng_etc_dir => '/etc/nagios/nagiosgraph',
      ng_cgi_dir => '/usr/nagios/sbin',    # FIXME: not sure about this one
      ng_doc_dir => '/usr/share/nagios/docs/nagiosgraph',
      ng_css_dir => '/usr/share/nagios',
      ng_js_dir => '/usr/share/nagios',
      ng_util_dir => '/usr/share/nagios/docs/nagiosgraph/util',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'standalone',
      ng_dest_dir => q(/),
      ng_var_dir => '/var/nagiosgraph',
      ng_url => '/nagiosgraph',
      ng_bin_dir => '/usr/libexec/nagiosgraph',
      ng_etc_dir => '/etc/nagiosgraph',
      ng_cgi_dir => '/usr/nagiosgraph/cgi',
      ng_doc_dir => '/usr/share/nagiosgraph/doc',
      ng_css_dir => '/usr/share/nagiosgraph',
      ng_js_dir => '/usr/share/nagiosgraph',
      ng_util_dir => '/usr/share/nagiosgraph/util',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },
    );

my @CONF =
    ( { conf => 'ng_bin_dir',
        msg => 'Location of executables' },
      { conf => 'ng_etc_dir',
        msg => 'Location of configuration files' },
      { conf => 'ng_cgi_dir',
        msg => 'Location of CGI scripts' },
      { conf => 'ng_doc_dir',
        msg => 'Location of documentation and examples' },
      { conf => 'ng_css_dir',
        msg => 'Location of CSS files' },
      { conf => 'ng_js_dir',
        msg => 'Location of JavaScript files' },
      { conf => 'ng_util_dir',
        msg => 'Location of utilities' },
      { conf => 'ng_rrd_dir',
        msg => 'Location of RRD files' },
      { conf => 'ng_log_file',
        msg => 'Path of log file' },
      { conf => 'ng_cgilog_file',
        msg => 'Path of CGI log file' },
      { conf => 'ng_cgi_url',
        msg => 'URL of CGI scripts' },
      { conf => 'ng_css_url',
        msg => 'URL of CSS file' },
      { conf => 'ng_js_url',
        msg => 'URL of JavaScript file' },
      { conf => 'nagios_perfdata_file',
        msg => 'Nagios performance data file',
        def => '/var/nagios/perfdata.log' },
      { conf => 'nagios_cgi_url',
        msg => 'URL of Nagios CGI scripts',
        def => '/nagios/cgi-bin' },
      { conf => 'nagios_user',
        msg => 'username or userid of Nagios user',
        def => 'nagios' },
      { conf => 'www_user',
        msg => 'username or userid of web server user',
        def => 'www-data' },
    );

my $verbose = 1;
my $layout = 'standalone';
my $destdir = q();
my $vardir = q();
my $etcdir = q();
my $doit = 1;
my @actions;

while ($ARGV[0]) {
    my $arg = shift;
    if($arg eq '--version') {
        print 'nagiosgraph installer ' . $VERSION . "\n";
        exit EXIT_OK;
    } elsif($arg eq '--install') {
        @actions = qw(check-prereq install check-config);
    } elsif ($arg eq '--dry-run') {
        $doit = 0;
    } elsif ($arg eq '--check') {
        @actions = qw(check-prereq check-config);
    } elsif ($arg eq '--check-config') {
        @actions = ('check-config');
    } elsif ($arg eq '--check-prereq') {
        @actions = ('check-prereq');
    } elsif ($arg eq '--layout') {
        $layout = shift;
    } elsif ($arg eq '--dest-dir' || $arg eq '--prefix') {
        $destdir = shift;
        $destdir = trimslashes($destdir);
    } elsif ($arg eq '--var') {
        $vardir = shift;
        $vardir = trimslashes($vardir);
    } elsif ($arg eq '--etc') {
        $etcdir = shift;
        $etcdir = trimslashes($etcdir);
    } else {
        my $code = EXIT_OK;
        if ($arg ne '--help') {
            $code = EXIT_FAIL;
            print "unknown option $arg\n";
            print "\n";
        }
        print "options include:\n";
        print "  --install        do the installation\n";
        print "  --check          check pre-requisites and configuration\n";
        print "  --check-prereq   check pre-requisites\n";
        print "  --check-config   check the configuration\n";
        print "\n";
        print "  --dry-run\n";
        print "  --verbose | --silent\n";
        print "\n";
        print "  --layout (overlay | standalone)\n";
        print "  --dest-dir path\n";
        print "  --var path\n";
        print "  --etc path\n";
        print "  --nagios-cgiurl url\n";
        print "  --nagios-perfdata path\n";
        print "  --nagios-user userid\n";
        print "  --www-user userid\n";
        print "\n";
        print "environment variables include:\n";
        foreach my $v (envvars()) {
            print "  $v\n";
        }
        exit $code;
    }
}

if ($destdir eq q() && $ENV{NG_DEST_DIR}) {
    $destdir = $ENV{NG_DEST_DIR};
}

my $conf;
my $fail = 0;
for my $action (@actions) {
    if($action eq 'check-prereq') {
        $fail |= checkprereq();
    } elsif($action eq 'check-config') {
        checkdestdir($destdir) && exit EXIT_FAIL;
        $conf = getconfig($layout,$destdir,$vardir,$etcdir) if not $conf;
        $fail |= checkconfig($conf, $destdir);
    } elsif($action eq 'install') {
        checkdestdir($destdir) && exit EXIT_FAIL;
        $conf = getconfig($layout,$destdir,$vardir,$etcdir) if not $conf;
        printconfig($conf);
        my $confirm = getanswer('is this configuration ok', 'y');
        if ($confirm !~ /y/) {
            logmsg('installation aborted');
            exit EXIT_OK;
        }
        $fail |= doinstall($conf, $doit);
        my $nagios = getanswer('modify the nagios configuration', 'n');
        my $modnagios = $nagios =~ /[yY]/ ? 1 : 0;
        my $apache = getanswer('modify the apache configuration', 'n');
        my $modapache = $apache =~ /[yY]/ ? 1 : 0;
        printinstructions($conf, !$modnagios, !$modapache);
# FIXME: prompt for config file locations
# FIXME: modify nagios
# FIXME: modify apache
    }
}

if ($fail) {
    logmsg(q());
    logmsg('*** one or more problems were detected!');
    logmsg(q());
    exit EXIT_FAIL;
}

exit EXIT_OK;





sub logmsg {
    my ($msg) = @_;
    if ($verbose) {
        print $msg . "\n";
    }
    return;
}

sub readconfigcache {
    my ($conf) = @_;
    if (! defined $conf->{ng_etc_dir}) {
        return 1;
    }
    my $fn = $conf->{ng_etc_dir} . q(/) . $CACHE_FN;
    if (! -f $fn) {
        return 1;
    }
    my ($key, $val);
    my $fail = 0;
    if (open my $CONF, '<', $fn) {
        while(<$CONF>) {
            s/\s*#.*//;             # Strip comments
            /^(\S+)\s*=\s*(.*)$/x and do {
                $key = $1;
                $val = $2;
                $val =~ s/\s+$//;   # removes trailing whitespace
                if ($key ne 'version') {
                    $conf->{$key} = $val;
                }
            };
        }
        if (! close $CONF) {
            logmsg("cannot close install cache $fn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot open install cache $fn: $!");
        $fail = 1;
    }
    return $fail;
}

sub writeconfigcache {
    my ($conf) = @_;
    if (! defined $conf->{ng_etc_dir}) {
        return 1;
    }
    if (! -d $conf->{ng_etc_dir}) {
        return 1;
    }
    logmsg('saving configuration cache');
    my $fn = $conf->{ng_etc_dir} . q(/) . $CACHE_FN;
    my $fail = 0;
    if (open my $FH, '>', $fn) {
        print ${FH} "version = $VERSION\n";
        foreach my $ii (sort keys %{$conf}) {
            print ${FH} "$ii = $conf->{$ii}\n";
        }
        if (! close $FH) {
            logmsg("cannot close install cache $fn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot write to install cache $fn: $!");
        $fail = 1;
    }
    return $fail;
}

sub getanswer {
    my ($question, $default) = @_;
    $default ||= q();
    print $question . '? ';
    if ($default ne q()) {
        print '[' . $default . '] ';
    }
    my $answer = readline *STDIN;
    chomp $answer;
    return ($answer =~ /^\s*$/) ? $default : $answer;
}

sub prependpath {
    my ($pfx, $path) = @_;
    return $path =~ /^\//
        ? $path
        : $pfx . ($pfx !~ /\/$/ ? q(/) : q()) . $path;
}

# get a configuration.  we need the following as a minimum:
#
#   layout
#   destdir
#
# get what we can from the environment.  prompt for anything that is not
# defined or specified.
sub getconfig {
    my ($layout, $destdir, $vardir, $etcdir, $promptall) = @_;
    my %conf;

    # guess whatever we can.  do overrides for var and etc.  if we get a layout
    # for which we have something pre-defined, then use the pre-defined layout.
    foreach my $ii (@PRESETS) {
        if ($ii->{ng_layout} ne $layout) {
            next;
        }
        if (defined $ii->{ng_dest_dir} && $ii->{ng_dest_dir} ne $destdir) {
            next;
        }
        $conf{ng_layout} = $layout;
        $conf{ng_dest_dir} = $destdir;
        foreach my $jj (@CONF) {
            my $pfx = $conf{ng_dest_dir};
            my $var = $vardir ne q() ? $vardir : $ii->{ng_var_dir};
            my $url = $ii->{ng_url};
            if ($jj->{conf} eq 'ng_etc_dir' && $etcdir ne q()) {
                $conf{$jj->{conf}} = $etcdir;
            } elsif ($jj->{conf} eq 'ng_bin_dir' ||
                $jj->{conf} eq 'ng_etc_dir' ||
                $jj->{conf} eq 'ng_cgi_dir' ||
                $jj->{conf} eq 'ng_doc_dir' ||
                $jj->{conf} eq 'ng_css_dir' ||
                $jj->{conf} eq 'ng_js_dir' ||
                $jj->{conf} eq 'ng_util_dir') {
                $conf{$jj->{conf}} = prependpath($pfx, $ii->{$jj->{conf}});
            } elsif ($jj->{conf} eq 'ng_cgi_url' ||
                     $jj->{conf} eq 'ng_css_url' ||
                     $jj->{conf} eq 'ng_js_url') {
                $conf{$jj->{conf}} = prependpath($url, $ii->{$jj->{conf}});
            } elsif ($jj->{conf} eq 'ng_rrd_dir' ||
                     $jj->{conf} eq 'ng_log_file' ||
                     $jj->{conf} eq 'ng_cgilog_file') {
                $conf{$jj->{conf}} = prependpath($var, $ii->{$jj->{conf}});
            } else {
                $conf{$jj->{conf}} = $ii->{$jj->{conf}};
            }
        }
    }

    # get the hard-coded defaults
    foreach my $ii (@CONF) {
        if (! defined $conf{$ii->{conf}} && defined $ii->{def}) {
            $conf{$ii->{conf}} = $ii->{def};
        }
    }

    # get anything else we can from the environment variables
    foreach my $ii (@CONF) {
        my $vname = $ii->{conf};
        $vname =~ tr/a-z/A-Z/;
        if ($ENV{$vname}) {
            $conf{$ii->{conf}} = $ENV{$vname};
        }
    }

    # if there is a cache from a previous installation, try to use it
    readconfigcache(\%conf);

    # prompt for anything we do not yet know
    foreach my $ii (@CONF) {
        if ($promptall || ! defined $conf{$ii->{conf}}) {
            $conf{$ii->{conf}} = getanswer($ii->{msg}, $conf{$ii->{conf}});
        }
    }

    return \%conf;
}

sub envvars {
    my @vars = qw(NG_DEST_DIR);
    foreach my $ii (@CONF) {
        my $vname = $ii->{conf};
        $vname =~ tr/a-z/A-Z/;
        push @vars, $vname;
    }
    return @vars;
}

sub printconfig {
    my ($conf) = @_;
    logmsg('environment:');
    my $found = 0;
    foreach my $v (envvars()) {
        if (defined $ENV{$v}) {
            $found = 1;
            logmsg("  $v=" . $ENV{$v});
        }
    }
    if (! $found) {
        logmsg('  no relevant environment variables are set');
    }
    logmsg('configuration:');
    foreach my $ii (@CONFKEYS) {
        logmsg(sprintf '  %-20s %s', $ii, $conf->{$ii});
    }
    return;
}

sub checkconfig {
    my ($conf, $destdir) = @_;

# FIXME: check the configuration

    return 0;
}

# check pre-requisites.  return 0 if everything is ok, 1 otherwise.
sub checkprereq {
    my $fail = 0;

    logmsg('checking required PERL modules');
    $fail |= checkmodule('Carp');
    $fail |= checkmodule('CGI');
    $fail |= checkmodule('Data::Dumper');
    $fail |= checkmodule('File::Basename');
    $fail |= checkmodule('File::Find');
    $fail |= checkmodule('MIME::Base64');
    $fail |= checkmodule('POSIX');
    $fail |= checkmodule('RRDs');
    $fail |= checkmodule('Time::HiRes');

    logmsg('checking optional PERL modules');
    checkmodule('GD', 1);

    my $found = 0;
    my @dirs;

    logmsg('checking nagios installation');
    @dirs = qw(/usr/local/nagios/bin /opt/nagios/bin /usr/bin /usr/sbin /bin /sbin);
    $found = checkexec('nagios', @dirs);
    if (! $found) {
        logmsg("nagios not found in any of:\n" . join "\n", @dirs);
        $fail = 1;
    }

    logmsg('checking web server installation');
    @dirs = qw(/usr/local/apache/bin /opt/apache/bin /usr/local/apache2/bin /opt/apache2/bin /usr/local/httpd/bin /opt/httpd/bin /usr/bin /usr/sbin /bin /sbin);
    $found = checkexec('httpd', @dirs);
    if (! $found) {
        $found = checkexec('apache2', @dirs);
    }
    if (! $found) {
        logmsg("nagios not found in any of:\n" . join "\n", @dirs);
        $fail = 1;
    }

    return $fail;
}

# return 0 if ok, 1 if failure
sub checkmodule {
    my ($func, $optional) = @_;
    my $rval = eval "{ require $func; }"; ## no critic (ProhibitStringyEval)
    my $status = 'fail';
    if (defined $rval && $rval == 1) {
        $status = $func->VERSION;
    }
    logmsg("  $func...$status");
    return $status eq 'fail' ? 1 : 0;
}

# return 1 if found, 0 otherwise
sub checkexec {
    my ($app, @dirs) = @_;
    my $found = 0;
    for (my $ii=0; $ii<$#dirs+1; $ii++) { ## no critic (ProhibitCStyleForLoops)
        my $a = "$dirs[$ii]/$app";
        if (-f $a && -x $a) {
            $found = 1;
        }
        $dirs[$ii] = q(  ) . $dirs[$ii];
    }
    return $found;
}

# return 0 if ok, 1 if not set
sub checkdestdir {
    my ($dir) = @_;
    if ($dir eq q()) {
        logmsg('destination directory has not been specified');
        return 1;
    }
    return 0;
}

sub getfiles {
    my ($dir, $pattern) = @_;
    my @files;
    if (opendir DH, $dir) {
        @files = grep { /$pattern/ } readdir DH;
        closedir DH;
    } else {
        logmsg ("cannot read directory $dir: $!");
    }
    return @files;
}

sub replacetext {
    my ($ifn, $pat) = @_;
    my $ofn = $ifn . 'bak';
    my $fail = 0;
    if (open my $IFILE, '<', $ifn) {
        if (open my $OFILE, '>', $ofn) {
            while(<$IFILE>) {
                my $line = $_;
                foreach my $orig (keys %{$pat}) {
                    $line =~ s/$orig/$pat->{$orig}/;
                }
                print ${OFILE} $line;
            }
            if (close $OFILE) {
                move $ofn, $ifn;
            } else {
                logmsg ("cannot close $ofn: $!");
                $fail = 1;
            }
        } else {
            logmsg ("cannot write to $ofn: $!");
            $fail = 1;
        }
        if (! close $IFILE) {
            logmsg ("cannot close $ifn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot read from $ifn: $!");
        $fail = 1;
    }
    return $fail;
}

sub writeapachestub {
    my ($fn, $conf) = @_;
    my $fail = 0;
    if (open my $FILE, '>', $fn) {
        print ${FILE} <<'EOB';
# enable nagiosgraph CGI scripts
  ScriptAlias $conf->{ng_cgi_url} $conf->{ng_cgi_dir}
  <Directory "$conf->{ng_cgi_dir}">
     Options ExecCGI
     AllowOverride None
     Order allow,deny
     Allow from all
  </Directory>
EOB
        if (! close $FILE) {
            logmsg("cannot close $fn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot write to $fn: $!");
        $fail = 1;
    }
    return $fail;
}

sub writenagiosstub {
    my ($fn, $conf) = @_;
    my $fail = 0;
    if (open my $FILE, '>', $fn) {
        print ${FILE} <<'EOB';
# process nagios performance data using nagiosgraph
     process_performance_data=1
     service_perfdata_file=$conf->{nagios_perfdata_file}
     service_perfdata_file_template=\$LASTSERVICECHECK\$\|\|\$HOSTNAME\$\|\|\$SERVICEDESC\$\|\|\$SERVICEOUTPUT\$\|\|\$SERVICEPERFDATA\$
     service_perfdata_file_mode=a
     service_perfdata_file_processing_interval=30
     service_perfdata_file_processing_command=process-service-perfdata
EOB
        if (! close $FILE) {
            logmsg("cannot close $fn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot write to $fn: $!");
        $fail = 1;
    }
    return $fail;
}

sub printinstructions {
    my ($conf, $nagios, $apache) = @_;
    if ($nagios || $apache) {
        print "\n";
        print "     To complete the installation, do the following:\n";
    }
    if ($nagios) {
        print "\n";
        print "       * Ensure that 'service_perfdata_command' is commented\n";
        print "         or not defined in any nagios configuration file(s).\n";
        print "\n";
        print "       * In the nagios configuration file (e.g. nagios.cfg),\n";
        print "         add this line:\n";
        print "\n";
        print "         include $conf->{ng_etc_dir}/$NAGIOS_STUB_FN\n";
    }
    if ($apache) {
        print "\n";
        print "       * In the apache configuration file (e.g. httpd.conf),\n";
        print "         add this line:\n";
        print "\n";
        print "         include $conf->{ng_etc_dir}/$APACHE_STUB_FN\n";
    }
    print "\n";

    return;
}

# FIXME: check mkdir return codes
# FIXME: check copy return codes
sub doinstall {
    my ($conf, $doit) = @_;
    my $dst;
    my $fail = 0;

    if (defined $conf->{ng_dest_dir}) {
        $dst = $conf->{ng_dest_dir};
        mkdir "$dst" if $doit;
    }

    if (defined $conf->{ng_etc_dir}) {
        $dst = $conf->{ng_etc_dir};
        mkdir "$dst" if $doit;
        my @files = getfiles('etc', '.*.conf');
        for my $f (@files) {
            copy("etc/$f", "$dst") if $doit;
        }
        copy('etc/map', "$dst") if $doit;
        copy('etc/ngshared.pm', "$dst") if $doit;
        replacetext("$dst/nagiosgraph.conf", {
  '^perflog\\s*=.*', 'perflog = ' . $conf->{nagios_perfdata_file},
  '^rrddir\\s*=.*', 'rrddir = ' . $conf->{ng_rrd_dir},
  '^mapfile\\s*=.*', 'mapfile = ' . $conf->{ng_etc_dir} . '/map',
  '^nagiosgraphcgiurl\\s*=.*', 'nagiosgraphcgiurl = ' . $conf->{ng_cgi_url},
  '^javascript\\s*=.*', 'javascript = ' . $conf->{ng_js_url},
  '^stylesheet\\s*=.*', 'stylesheet = ' . $conf->{ng_css_url},
  '^logfile\\s*=.*', 'logfile = ' . $conf->{ng_log_file},
  '^cgilogfile\\s*=.*', 'cgilogfile = ' . $conf->{ng_cgilog_file},
                    } ) if $doit;
        writenagiosstub($conf->{ng_etc_dir} . q(/) . $NAGIOS_STUB_FN, $conf);
        writeapachestub($conf->{ng_etc_dir} . q(/) . $APACHE_STUB_FN, $conf);
    }

    if (defined $conf->{ng_cgi_dir}) {
        $dst = $conf->{ng_cgi_dir};
        mkdir "$dst" if $doit;
        my @files = getfiles('cgi', '.*.cgi');
        for my $f (@files) {
            copy("cgi/$f", "$dst") if $doit;
            replacetext("$dst/$f",
                        { 'use lib \'/opt/nagiosgraph/etc\'' =>
                              "use lib '$conf->{ng_etc_dir}'" } ) if $doit;
        }
    }

    if (defined $conf->{ng_bin_dir}) {
        $dst = $conf->{ng_bin_dir};
        mkdir "$dst" if $doit;
        copy('lib/insert.pl', "$dst") if $doit;
        replacetext("$dst/insert.pl",
                    { 'use lib \'/opt/nagiosgraph/etc\'' =>
                          "use lib '$conf->{ng_etc_dir}'" } ) if $doit;
    }

    if (defined $conf->{ng_css_dir}) {
        $dst = $conf->{ng_css_dir};
        mkdir "$dst" if $doit;
        copy('share/nagiosgraph.css', "$dst") if $doit;
    }

    if (defined $conf->{ng_js_dir}) {
        $dst = $conf->{ng_js_dir};
        mkdir "$dst" if $doit;
        copy('share/nagiosgraph.js', "$dst") if $doit;
    }

    if (defined $conf->{ng_doc_dir}) {
        $dst = $conf->{ng_doc_dir};
        mkdir "$dst" if $doit;
        my @files = getfiles('examples', '^[^\.]');
        for my $f (@files) {
            copy("examples/$f", "$dst") if $doit;
        }
        copy('share/action.gif', "$dst") if $doit;
        copy('share/nagiosgraph.ssi', "$dst") if $doit;
        copy('README', "$dst") if $doit;
        copy('INSTALL', "$dst") if $doit;
        copy('CHANGELOG', "$dst") if $doit;
        copy('AUTHORS', "$dst") if $doit;
    }

    if (defined $conf->{ng_rrd_dir}) {
        mkdir $conf->{ng_rrd_dir};
        chmod DPERMS, $conf->{ng_rrd_dir};
        chown $conf->{nagios_user}, $conf->{ng_rrd_dir};
    }

    if (defined $conf->{ng_log_file}) {
        touch $conf->{ng_log_file};
        chmod FPERMS, $conf->{ng_log_file};
        chown $conf->{nagios_user}, $conf->{ng_log_file};
    }

    if (defined $conf->{ng_cgilog_file}) {
        touch $conf->{ng_cgilog_file};
        chmod FPERMS, $conf->{ng_cgilog_file};
        chown $conf->{www_user}, $conf->{ng_cgilog_file};
    }

    writeconfigcache($conf) if $doit;

    return $fail;
}

sub trimslashes {
    my ($path) = @_;
    while(length($path) > 1 && $path =~ /\/$/) { $path =~ s/\/$//; }
    return $path;
}


__END__

=head1 NAME

install.pl - install nagiosgraph

=head1 DESCRIPTION

This will copy nagiosgraph files to the appropriate directories and create a
default configuration.  It will not modify apache or nagios, but it will
indicate what changes must be made to those components to complete the
installation.

When run interactively, this script will prompt for the information it needs.

When environment variables are configured with installation information, this
script will run with no intervention required.

=head1 USAGE

B<install.pl> [--version]
   (--check-prereq |
    --check-config |
    --install --dest-dir path
             [--dry-run]
             [--verbose | --silent]
             [--layout (overlay | standalone)]
             [--nagios-cgiurl url]
             [--nagios-perfdata path]
             [--nagios-user userid]
             [--www-user userid]
             [--etc path]
             [--var path] )

=head1 OPTIONS

B<--version>        Print the version then exit.

B<--install>        Install nagiosgraph.

B<--dry-run>        Report what would happen, but do not do it.

B<--check-prereq>   Report which prerequisites are missing.

B<--check-config>   Check the configuration.

B<--verbose>        Emit messages about what is happening.

B<--silent>         Do not emit messages about what is happening.

B<--layout> layout  Which layout to use.  Can be I<standalone> or I<overlay>.

B<--destdir> path   Directory in which files should be installed.

B<--etc> path       Directory for configuration files.  The default value
                 depends upon the layout and the destination directory.

B<--var> path       Directory for log and RRD files.  The default value
                 depends upon the layout.  For standalone layout, the
                 default is /var/nagiosgraph.  For overlay layout, the
                 default is /var/nagios.

B<--nagios-cgiurl> url     URL to Nagios CGI scripts.

B<--nagios-perfdata> path  Path to Nagios perfdata file.

B<--nagios-user> userid    Name or uid of Nagios user.

B<--www-user> userid       Name or uid of web server user.

Automate this script for use in rpmbuild or other automated tools by setting
these environment variables:

  NG_LAYOUT               - standalone or overlay
  NG_DEST_DIR             - the root directory for the installation
  NG_NAGIOS_CGIURL        - URL to Nagios CGI scripts
  NG_NAGIOS_PERFDATA_FILE - path to Nagios perfdata file
  NG_NAGIOS_USER          - Nagios user
  NG_WWW_USER             - web server user

Use one or more of these environment variables to specialize an automated
install:

  NG_VAR_DIR     - the directory for log files and RRD files
  NG_BIN_DIR     - the directory for nagiosgraph executables
  NG_ETC_DIR     - the directory for nagiosgraph configuration files
  NG_CGI_DIR     - the directory for nagiosgraph CGI scripts
  NG_DOC_DIR     - the directory for nagiosgraph documentation and examples
  NG_CSS_DIR     - the directory for nagiosgraph CSS
  NG_JS_DIR      - the directory for nagiosgraph Javascript
  NG_LOG_FILe    - the nagiosgraph log file
  NG_CGILOG_FILE - the nagiosgraph CGI log file
  NG_RRD_DIR     - the directory for nagiosgraph RRD files
  NG_CGI_URL     - URL to nagiosgraph CGI scripts
  NG_CSS_URL     - URL to nagiosgraph CSS
  NG_JS_URL      - URL to nagiosgraph Javascript

=head1 REQUIRED ARGUMENTS

The following options must be specified:

  dest_dir

All other options have default values.

=head1 CONFIGURATION

Nagiosgraph requires the following pre-requisites:

  nagios
  nagios-plugins
  rrdtool
  CGI perl module
  RRAs perl module
  perl module (optional)

Nagiosgraph requires the following information for installation:

  ng_dest_dir          - directory for nagiosgraph files
  ng_bin_dir           - directory for executables
  ng_etc_dir           - directory for configuration files
  ng_cgi_dir           - directory for CGI scripts
  ng_doc_dir           - directory for documentation and examples
  ng_css_dir           - directory for CSS
  ng_js_dir            - directory for Javascript
  ng_log_file          - path to nagiosgraph log file
  ng_cgilog_file       - path to nagiosgraph cgi log file
  ng_rrd_dir           - directory for nagiosgraph RRD files
  ng_cgi_url           - URL to nagiosgraph CGI scripts
  ng_css_url           - URL to nagiosgraph CSS
  ng_js_url            - URL to nagiosgraph Javascript
  nagios_cgi_url       - URL to Nagios CGI scripts
  nagios_perfdata_file - path to Nagios perfdata log file
  nagios_user          - Nagios user
  www_user             - Apache user

  configure nagios?    - whether to configure Nagios
  processing_mode      - batch or immediate
  n_cfg_file           - path to nagios config file
  n_commands_cfg_file  - path to nagios commands file

  configure apache?    - whether to configure Apache
  apache_cfg           - path to apache config file

In some cases these can be inferred from the configuration.  In other cases
they must be specified explicitly.

There are two standard layouts: overlay and standalone.  The overlay puts
nagiosgraph files into a Nagios installation.  The standalone puts nagiosgraph
files into a separate directory tree.  Use the names of nagiosgraph components
to create custom layouts.

Default overlay with destination /opt/nagios

  ng_dest_dir /opt/nagios
  ng_bin_dir /opt/nagios/libexec
  ng_etc_dir /opt/nagios/etc/nagiosgraph
  ng_cgi_dir /opt/nagios/sbin
  ng_doc_dir /opt/nagios/share/docs
  ng_css_dir /opt/nagios/share
  ng_js_dir /opt/nagios/share

Default standalone with destination /opt/nagiosgraph

  ng_dest_dir /opt/nagiosgraph
  ng_bin_dir /opt/nagiosgraph/bin
  ng_etc_dir /opt/nagiosgraph/etc
  ng_cgi_dir /opt/nagiosgraph/cgi
  ng_doc_dir /opt/nagiosgraph/doc
  ng_css_dir /opt/nagiosgraph/share
  ng_js_dir /opt/nagiosgraph/share

Log files, userids, and URLs must also be specified.  These depend on system
configuration, nagios configuration, and web server configuration.  Here are
the default values:

  ng_log_file /var/nagiosgraph/nagiosgraph.log
  ng_cgilog_file /var/nagiosgraph/nagiosgraph-cgi.log
  ng_rrd_dir /var/nagiosgraph/rrd
  ng_css_url /nagiosgraph/nagiosgraph.css
  ng_js_url /nagiosgraph/nagiosgraph.js
  nagios_cgi_url /nagios/cgi-bin
  nagios_perfdata_file /var/nagios/perfdata.log
  nagios_user nagios
  www_user www-data

These values install nagiosgraph onto an existing Nagios installation
at /usr/local/nagios:

  NG_LAYOUT overlay
  NG_DEST_DIR /usr/local/nagios
  NG_NAGIOS_CGI_URL /nagios/cgi-bin
  NG_NAGIOS_PERFDATA_FILE /var/nagios/perfdata.log
  NG_NAGIOS_USER nagios
  NG_WWW_USER www-data

  NG_ETC_DIR /usr/local/nagios/etc/nagiosgraph
  NG_BIN_DIR /usr/local/nagios/libexec
  NG_CGI_DIR /usr/local/nagios/sbin
  NG_DOC_DIR /usr/local/nagios/share/docs
  NG_CSS_DIR /usr/local/nagios/share
  NG_JS_DIR /usr/local/nagios/share
  NG_LOG_FILE /var/nagios/nagiosgraph.log
  NG_CGILOG_FILE /var/nagios/nagiosgraph-cgi.log
  NG_RRD_DIR /var/nagios/rrd
  NG_CGI_URL /nagios/cgi-bin
  NG_CSS_URL /nagios/nagiosgraph.css
  NG_JS_URL /nagios/nagiosgraph.js

These values install nagiosgraph to its own directory tree in /opt/nagiosgraph:

  NG_LAYOUT standalone
  NG_DEST_DIR /opt/nagiosgraph
  NG_NAGIOS_CGI_URL /nagios/cgi-bin
  NG_NAGIOS_PERFDATA_FILE /var/nagios/perfdata.log
  NG_NAGIOS_USER nagios
  NG_WWW_USER www-data

This set is similar to the previous configuration, but this keeps the RRD
and log files in the system /var directory tree and configuration files in
the system /etc directory.

  NG_LAYOUT standalone
  NG_DEST_DIR /opt/nagiosgraph
  NG_ETC_DIR /etc/nagiosgraph
  NG_VAR_DIR /var/nagiosgraph
  NG_NAGIOS_CGI_URL /nagios/cgi-bin
  NG_NAGIOS_PERFDATA_FILE /var/nagios/perfdata.log
  NG_NAGIOS_USER nagios
  NG_WWW_USER www-data

=head1 EXIT STATUS

Returns 0 if the installation was successful, -1 otherwise.

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=over 4

=item B<Nagios>

Nagios provides the data collection system.

=item B<rrdtool>

rrdtool provides the data storage and graphing system.

=item B<RRDs>

RRDs provides the perl interface to rrdtool.

=item B<GD> (optional)

If the perl interface to GD is installed, nagiosgraph will provide more
feedback about graphing errors.

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Alan Brenner - alan.brenner@ithaka.org, the original author in 2008.
Matthew Wall in 2010

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 Ithaka Harbors, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
