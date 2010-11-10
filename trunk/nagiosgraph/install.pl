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
use File::Path qw(make_path);
use ExtUtils::Command qw(touch);
use POSIX qw(strftime);
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '1.0';

use constant EXIT_FAIL => 1;
use constant EXIT_OK => 0;
use constant DPERMS => 0755;
use constant FPERMS => 0644;
use constant CACHE_FN => '.install-cache';
use constant NAGIOS_STUB_FN => 'nagiosgraph-nagios.cfg';
use constant APACHE_STUB_FN => 'nagiosgraph-apache.conf';

# put the keys in a specific order to make it easier to see where things go
my @CONFKEYS = qw(ng_layout ng_dest_dir ng_etc_dir ng_bin_dir ng_cgi_dir ng_doc_dir ng_css_dir ng_js_dir ng_util_dir ng_var_dir ng_rrd_dir ng_log_file ng_cgilog_file ng_url ng_cgi_url ng_css_url ng_js_url nagios_cgi_url nagios_perfdata_file nagios_user www_user modify_nagios_config nagios_config_file modify_apache_config apache_config_file);

# these keys can be specified via command line
my @CMDKEYS = qw(ng_layout ng_dest_dir ng_var_dir ng_etc_dir nagios_cgi_url nagios_perfdata_file nagios_user www_user);

my @PRESETS = (
    { ng_layout => 'standalone',
      ng_url => '/nagiosgraph',
      ng_etc_dir => 'etc',
      ng_bin_dir => 'bin',
      ng_cgi_dir => 'cgi',
      ng_doc_dir => 'doc',
      ng_css_dir => 'share',
      ng_js_dir => 'share',
      ng_util_dir => 'util',
      ng_var_dir => 'var',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'overlay',
      ng_url => '/nagios',
      ng_etc_dir => 'etc/nagiosgraph',
      ng_bin_dir => 'libexec',
      ng_cgi_dir => 'sbin',
      ng_doc_dir => 'docs/nagiosgraph',
      ng_css_dir => 'share',
      ng_js_dir => 'share',
      ng_util_dir => 'docs/nagiosgraph/util',
      ng_var_dir => '/var/nagios',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'overlay',
      ng_dest_dir => q(/),
      ng_url => '/nagios',
      ng_etc_dir => '/etc/nagios/nagiosgraph',
      ng_bin_dir => '/usr/libexec/nagios',
      ng_cgi_dir => '/usr/nagios/sbin',    # FIXME: not sure about this one
      ng_doc_dir => '/usr/share/nagios/docs/nagiosgraph',
      ng_css_dir => '/usr/share/nagios',
      ng_js_dir => '/usr/share/nagios',
      ng_util_dir => '/usr/share/nagios/docs/nagiosgraph/util',
      ng_var_dir => '/var/nagios',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'standalone',
      ng_dest_dir => q(/),
      ng_url => '/nagiosgraph',
      ng_etc_dir => '/etc/nagiosgraph',
      ng_bin_dir => '/usr/libexec/nagiosgraph',
      ng_cgi_dir => '/usr/nagiosgraph/cgi',
      ng_doc_dir => '/usr/share/nagiosgraph/doc',
      ng_css_dir => '/usr/share/nagiosgraph',
      ng_js_dir => '/usr/share/nagiosgraph',
      ng_util_dir => '/usr/share/nagiosgraph/util',
      ng_var_dir => '/var/nagiosgraph',
      ng_rrd_dir => 'rrd',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },
    );

my @CONF =
    ( { conf => 'ng_layout',
        msg => 'Type of layout (standalone, overlay, or custom)',
        def => 'standalone' },
      { conf => 'ng_dest_dir',
        msg => 'Destination directory',
        def => '/usr/local/nagiosgraph' },
      { conf => 'ng_etc_dir',
        msg => 'Location of configuration files' },
      { conf => 'ng_bin_dir',
        msg => 'Location of executables' },
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
      { conf => 'ng_var_dir',
        msg => 'Location of RRD and log files' },
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

my %DIRDEPS =
    ( ng_dest_dir => [qw(ng_etc_dir ng_bin_dir ng_cgi_dir ng_doc_dir ng_css_dir ng_js_dir ng_util_dir ng_var_dir)],
      ng_url => [qw(ng_cgi_url ng_css_url ng_js_url)],
      ng_var_dir => [qw(ng_rrd_dir ng_log_file ng_cgilog_file)],
      );

my $verbose = 1;
my $doit = 1;
my $action = 'install';
my %conf;

while ($ARGV[0]) {
    my $arg = shift;
    if($arg eq '--version') {
        print 'nagiosgraph installer ' . $VERSION . "\n";
        exit EXIT_OK;
    } elsif($arg eq '--install') {
        $action = 'install';
    } elsif ($arg eq '--dry-run') {
        $doit = 0;
    } elsif ($arg eq '--check-installation') {
        $action = 'check-installation';
    } elsif ($arg eq '--check-prereq') {
        $action = 'check-prereq';
    } elsif ($arg eq '--layout') {
        $conf{ng_layout} = shift;
    } elsif ($arg eq '--dest-dir' || $arg eq '--prefix') {
        $conf{ng_dest_dir} = trimslashes(shift);
    } elsif ($arg eq '--var-dir') {
        $conf{ng_var_dir} = trimslashes(shift);
    } elsif ($arg eq '--etc-dir') {
        $conf{ng_etc_dir} = trimslashes(shift);
    } elsif ($arg eq '--nagios-cgi-url') {
        $conf{nagios_cgi_url} = shift;
    } elsif ($arg eq '--nagios-perfdata-file') {
        $conf{nagios_perfdata_file} = shift;
    } elsif ($arg eq '--nagios-user') {
        $conf{nagios_user} = shift;
    } elsif ($arg eq '--www-user') {
        $conf{www_user} = shift;
    } else {
        my $code = EXIT_OK;
        if ($arg ne '--help') {
            $code = EXIT_FAIL;
            print "unknown option $arg\n";
            print "\n";
        }
        print "options include:\n";
        print "  --install              do the installation\n";
        print "  --check-prereq         check pre-requisites\n";
        print "  --check-installation   check the installation\n";
        print "\n";
        print "  --dry-run\n";
        print "  --verbose | --silent\n";
        print "\n";
        print "  --layout (overlay | standalone)\n";
        print "  --dest-dir path\n";
        print "  --var-dir path\n";
        print "  --etc-dir path\n";
        print "  --nagios-cgi-url url\n";
        print "  --nagios-perfdata-file path\n";
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

my $fail = 0;
if($action eq 'check-prereq') {
    $fail |= checkprereq();
} elsif($action eq 'check-installation') {
    $fail |= getconfig(\%conf);
    $fail |= checkinstallation(\%conf);
} elsif($action eq 'install') {
    $fail |= checkprereq();
    $fail |= getconfig(\%conf);
    printconfig(\%conf);
    my $confirm = getanswer('Continue with this configuration', 'y');
    if ($confirm !~ /y/) {
        logmsg('installation aborted');
        exit EXIT_OK;
    }
    $fail |= writeconfigcache(\%conf);
    $fail |= doinstall(\%conf, $doit);
    printinstructions(\%conf);
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
    my $fn = CACHE_FN;
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
    logmsg('saving configuration cache');
    my $fn = CACHE_FN;
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

# append to the specified file.  do the append to a copy of the file, then
# move the original file to a time-stamped copy, then move the appended file
# to the original name.
sub appendtofile {
    my ($ifn, $txt, $doit) = @_;
    logmsg("append to $ifn");
    return 0 if !$doit;
    my $ofn = $ifn . '.tmp';
    if (ng_copy($ifn, $ofn)) {
        return 1;
    }
    my $ts = strftime '%Y.%m.%d', localtime time;
    my $fail = 0;
    if (open my $FILE, '>>', $ofn) {
        print ${FILE} "\n$txt\n";
        if (close $FILE) {
            my $bak = $ifn . '-' . $ts;
            if (ng_move($ifn, $bak) || ng_move($ofn, $ifn)) {
                $fail = 1;
            }
        } else {
            logmsg("cannot close $ofn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot append to $ofn: $!");
        $fail = 1;
    }
    return $fail;
}

sub prependpath {
    my ($pfx, $path) = @_;
    return $path =~ /^\//
        ? $path
        : $pfx . ($pfx !~ /\/$/ ? q(/) : q()) . $path;
}

# look for a value in the environment, fallback to a default.
sub getdefault {
    my ($conf, $key) = @_;
    if (! defined $conf->{$key}) {
        my $envname = mkenvname($key);
        if ($ENV{$envname}) {
            $conf->{$key} = $ENV{$envname};
        }
    }
    if (! defined $conf->{$key}){
        foreach my $ii (@CONF) {
            if ($ii->{conf} eq $key && defined $ii->{def}) {
                $conf->{$key} = $ii->{def};
            }
        }
    }
    return;
}

sub getdefaults {
    my ($conf, @keys) = @_;
    foreach my $key (@keys) {
        getdefault($conf, $key);
    }
    return;
}

# get a configuration.  this is the order in which variables are used:
#
#   mechanism          which variables are possible
#
#   command line       layout, destdir, vardir, etcdir
#   install-cache      anything
#   environment        anything
#   preset             everything
#
# if none of those give us something useful, then we prompt.
# some of the variables can be dependent on others.  for example, stuff that
# goes in the var directory depends on the var directory, but it can also be
# specified independently of any var directory.
sub getconfig {
    my ($conf) = @_;

    getdefaults($conf, @CMDKEYS);

    # if we have a pre-defined configuration, use it.
    foreach my $ii (@PRESETS) {
        if ($ii->{ng_layout} ne $conf->{ng_layout}) {
            next;
        }
        if (defined $ii->{ng_dest_dir} &&
            $ii->{ng_dest_dir} ne $conf->{ng_dest_dir}) {
            next;
        }
        if (! defined $conf->{ng_var_dir}) {
            $conf->{ng_var_dir} = prependpath($conf->{ng_dest_dir},
                                              $ii->{ng_var_dir});
        }
        $conf->{ng_url} = $ii->{ng_url};
        foreach my $jj (@CONF) {
            if ($jj->{conf} eq 'ng_etc_dir' &&
                ! defined $conf->{$jj->{conf}}) {
                $conf->{$jj->{conf}} = prependpath($conf->{ng_dest_dir},
                                                   $ii->{$jj->{conf}});
                next;
            }
            foreach my $supdir (keys %DIRDEPS) {
                foreach my $dir (@{$DIRDEPS{$supdir}}) {
                    if ($jj->{conf} eq $dir) {
                        $conf->{$jj->{conf}} = prependpath($conf->{$supdir},
                                                           $ii->{$jj->{conf}});
                        next;
                    }
                }
            }
            if (! defined $conf->{$jj->{conf}}) {
                $conf->{$jj->{conf}} = $ii->{$jj->{conf}};
            }
        }
    }

    # get anything else we can from the environment variables
    foreach my $ii (@CONF) {
        my $iscmd = 0;
        foreach my $jj (@CMDKEYS) {
            if ($ii->{conf} eq $jj) {
                $iscmd = 1;
            }
        }
        if (! $iscmd) {
            my $vname = mkenvname($ii->{conf});
            if ($ENV{$vname}) {
                $conf->{$ii->{conf}} = $ENV{$vname};
            }
        }
    }

    # get the hard-coded defaults, only if not set already
    foreach my $ii (@CONF) {
        if (! defined $conf->{$ii->{conf}} && defined $ii->{def}) {
            $conf->{$ii->{conf}} = $ii->{def};
        }
    }

    # if there is a cache from a previous installation, try to use it
    readconfigcache(\%conf);

    # prompt for anything we do not yet know
    foreach my $ii (@CONF) {
        if (! defined $conf->{$ii->{conf}}) {
            $conf->{$ii->{conf}} = getanswer($ii->{msg}, $conf->{$ii->{conf}});
        }
    }

    # find out if we should modify the nagios configuration
    my $dfltfile = defined $conf->{nagios_config_file} ?
        $conf->{nagios_config_file} :
        findfile('nagios.cfg', qw(/etc/nagios /usr/local/nagios/etc /opt/nagios/etc));
    $conf->{modify_nagios_config} = 
        getanswer('Modify the Nagios configuration file', 'n');
    if (isyes($conf->{modify_nagios_config})) {
        $conf->{nagios_config_file} =
            getanswer('Nagios configuration file', $dfltfile);

    }

    # find out if we should modify the apache configuration
    $dfltfile = defined $conf->{apache_config_file} ?
        $conf->{apache_config_file} :
        findfile('httpd.conf', qw(/etc/apache2/conf /usr/local/apache2/conf /opt/apache2/conf /usr/local/httpd/conf /opt/httpd/conf));
    $conf->{modify_apache_config} =
        getanswer('Modify the Apache configuration file', 'n');
    if (isyes($conf->{modify_apache_config})) {
        $conf->{apache_config_file} = 
            getanswer('Apache configuration file', $dfltfile);
    }

    return $fail;
}

sub envvars {
    my @vars;
    foreach my $ii (@CONF) {
        push @vars, mkenvname($ii->{conf});
    }
    return @vars;
}

sub mkenvname {
    my ($name) = @_;
    $name =~ tr/a-z/A-Z/;
    if ($name !~ /^NG_/) {
        $name = 'NG_' . $name;
    }
    return $name;
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
        logmsg(sprintf '  %-20s %s', $ii, defined $conf->{$ii} ? $conf->{$ii} : q());
    }
    return;
}

sub checkconfig {
    my ($conf) = @_;

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

    my $found;
    my @dirs;

    logmsg('checking nagios installation');
    @dirs = qw(/usr/local/nagios/bin /opt/nagios/bin /usr/bin /usr/sbin /bin /sbin);
    $found = checkexec('nagios', @dirs);
    if ($found ne q()) {
        logmsg("  found nagios at $found");
    } else {
        my $dlist;
        foreach my $d (@dirs) {
            $dlist .= "    $d\n";
        }
        logmsg("  nagios not found in any of:\n$dlist");
        $fail = 1;
    }

    logmsg('checking web server installation');
    @dirs = qw(/usr/local/apache/bin /opt/apache/bin /usr/local/apache2/bin /opt/apache2/bin /usr/local/httpd/bin /opt/httpd/bin /usr/bin /usr/sbin /bin /sbin);
    $found = checkexec('httpd', @dirs);
    if ($found eq q()) {
        $found = checkexec('apache', @dirs);
        if ($found eq q()) {
            $found = checkexec('apache2', @dirs);
        }
    }
    if ($found ne q()) {
        logmsg("  found apache at $found");
    } else {
        my $dlist;
        foreach my $d (@dirs) {
            $dlist .= "    $d\n";
        }
        logmsg("  apache not found in any of:\n$dlist");
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
    logmsg("  $func..." . ($status eq 'fail' ? ' ***FAIL***' : $status));
    return $status eq 'fail' ? 1 : 0;
}

# return the dir/app, empty string if not found
sub checkexec {
    my ($app, @dirs) = @_;
    my $found = q();
    for (my $ii=0; $ii<$#dirs+1; $ii++) { ## no critic (ProhibitCStyleForLoops)
        my $a = "$dirs[$ii]/$app";
        if (-f $a && -x $a) {
            $found = $a;
        }
    }
    return $found;
}

sub checkinstallation {
    my ($conf) = @_;

# TODO: check installation

    return;
}

sub findfile {
    my ($fn, @dirs) = @_;
    my $path;
    foreach my $dir (@dirs) {
        if (-f "$dir/$fn") {
            $path = "$dir/$fn";
        }
    }
    return $path;
}

sub getfiles {
    my ($dir, $pattern) = @_;
    my @files;
    if (opendir DH, $dir) {
        @files = grep { /$pattern/ } readdir DH;
        closedir DH;
    } else {
        logmsg("cannot read directory $dir: $!");
    }
    return @files;
}

# return 0 if successful, 1 if failure
sub replacetext {
    my ($ifn, $pat, $doit) = @_;
    logmsg("replace text in $ifn");
    return 0 if !$doit;
    my $ofn = $ifn . '-ngbak';
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
                if (ng_move($ofn, $ifn)) {
                    $fail = 1;
                }
            } else {
                logmsg("cannot close $ofn: $!");
                $fail = 1;
            }
        } else {
            logmsg("cannot write to $ofn: $!");
            $fail = 1;
        }
        if (! close $IFILE) {
            logmsg("cannot close $ifn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot read from $ifn: $!");
        $fail = 1;
    }
    return $fail;
}

sub writeapachestub {
    my ($fn, $conf, $doit) = @_;
    logmsg("write apache stub to $fn");
    return 0 if !$doit;
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
    logmsg("write nagios stub to $fn");
    return 0 if !$doit;
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
        print "         include $conf->{ng_etc_dir}/" . NAGIOS_STUB_FN . "\n";
    }
    if ($apache) {
        print "\n";
        print "       * In the apache configuration file (e.g. httpd.conf),\n";
        print "         add this line:\n";
        print "\n";
        print "         include $conf->{ng_etc_dir}/" . APACHE_STUB_FN . "\n";
    }
    print "\n";

    return;
}

sub doinstall {
    my ($conf, $doit) = @_;
    my $dst;
    my $fail = 0;

    if (defined $conf->{ng_dest_dir}) {
        $dst = $conf->{ng_dest_dir};
        $fail |= ng_mkdir($dst, $doit);
    }

    if (defined $conf->{ng_etc_dir}) {
        $dst = $conf->{ng_etc_dir};
        $fail |= ng_mkdir($dst, $doit);
        my @files = getfiles('etc', '.*.conf');
        for my $f (@files) {
            $fail |= ng_copy("etc/$f", "$dst", $doit);
        }
        $fail |= ng_copy('etc/map', "$dst", $doit);
        $fail |= ng_copy('etc/ngshared.pm', "$dst", $doit);
        $fail |= replacetext("$dst/nagiosgraph.conf", {
  '^perflog\\s*=.*', 'perflog = ' . $conf->{nagios_perfdata_file},
  '^rrddir\\s*=.*', 'rrddir = ' . $conf->{ng_rrd_dir},
  '^mapfile\\s*=.*', 'mapfile = ' . $conf->{ng_etc_dir} . '/map',
  '^nagiosgraphcgiurl\\s*=.*', 'nagiosgraphcgiurl = ' . $conf->{ng_cgi_url},
  '^javascript\\s*=.*', 'javascript = ' . $conf->{ng_js_url},
  '^stylesheet\\s*=.*', 'stylesheet = ' . $conf->{ng_css_url},
  '^logfile\\s*=.*', 'logfile = ' . $conf->{ng_log_file},
  '^cgilogfile\\s*=.*', 'cgilogfile = ' . $conf->{ng_cgilog_file},
                    }, $doit);
        $fail |= writenagiosstub($conf->{ng_etc_dir} . q(/) . NAGIOS_STUB_FN,
                                 $conf, $doit);
        $fail |= writeapachestub($conf->{ng_etc_dir} . q(/) . APACHE_STUB_FN,
                                 $conf, $doit);
    }

    if (defined $conf->{ng_cgi_dir}) {
        $dst = $conf->{ng_cgi_dir};
        $fail |= ng_mkdir($dst, $doit);
        my @files = getfiles('cgi', '.*.cgi');
        for my $f (@files) {
            $fail |= ng_copy("cgi/$f", "$dst", $doit);
            $fail |= replacetext("$dst/$f",
                                 { 'use lib \'/opt/nagiosgraph/etc\'' =>
                                       "use lib '$conf->{ng_etc_dir}'" },
                                 $doit );
        }
    }

    if (defined $conf->{ng_bin_dir}) {
        $dst = $conf->{ng_bin_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('lib/insert.pl', "$dst", $doit);
        $fail |= replacetext("$dst/insert.pl",
                             { 'use lib \'/opt/nagiosgraph/etc\'' =>
                                   "use lib '$conf->{ng_etc_dir}'" },
                             $doit);
    }

    if (defined $conf->{ng_css_dir}) {
        $dst = $conf->{ng_css_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('share/nagiosgraph.css', "$dst", $doit);
    }

    if (defined $conf->{ng_js_dir}) {
        $dst = $conf->{ng_js_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('share/nagiosgraph.js', "$dst", $doit);
    }

    if (defined $conf->{ng_doc_dir}) {
        $dst = $conf->{ng_doc_dir};
        $fail |= ng_mkdir($dst, $doit);
        my @files = getfiles('examples', '^[^\.]');
        for my $f (@files) {
            $fail |= ng_copy("examples/$f", "$dst", $doit);
        }
        $fail |= ng_copy('share/action.gif', "$dst", $doit);
        $fail |= ng_copy('share/nagiosgraph.ssi', "$dst", $doit);
        $fail |= ng_copy('README', "$dst", $doit);
        $fail |= ng_copy('INSTALL', "$dst", $doit);
        $fail |= ng_copy('CHANGELOG', "$dst", $doit);
        $fail |= ng_copy('AUTHORS', "$dst", $doit);
    }

    if (defined $conf->{ng_rrd_dir}) {
        $fail |= ng_mkdir($conf->{ng_rrd_dir}, $doit);
        $fail |= ng_chmod(DPERMS, $conf->{ng_rrd_dir}, $doit);
        $fail |= ng_chown($conf->{nagios_user}, '-', $conf->{ng_rrd_dir}, $doit);
    }

    if (defined $conf->{ng_log_file}) {
        $fail |= ng_touch($conf->{ng_log_file}, $doit);
        $fail |= ng_chmod(FPERMS, $conf->{ng_log_file}, $doit);
        $fail |= ng_chown($conf->{nagios_user}, '-', $conf->{ng_log_file}, $doit);
    }

    if (defined $conf->{ng_cgilog_file}) {
        $fail |= ng_touch($conf->{ng_cgilog_file}, $doit);
        $fail |= ng_chmod(FPERMS, $conf->{ng_cgilog_file}, $doit);
        $fail |= ng_chown($conf->{www_user}, '-', $conf->{ng_cgilog_file}, $doit);
    }

    if (defined $conf->{modify_nagios_config} &&
        isyes($conf->{modify_nagios_config})) {
        $fail |= appendtofile($conf->{nagios_config_file}, "# nagiosgraph configuration\ninclude $conf->{ng_etc_dir}/" . NAGIOS_STUB_FN . "\n", $doit);
    }

    if (defined $conf->{modify_apache_config} &&
        isyes($conf->{modify_apache_config})) {
        $fail |= appendtofile($conf->{apache_config_file}, "# nagiosgraph configuration\ninclude $conf->{ng_etc_dir}/" . APACHE_STUB_FN . "\n", $doit);
    }

    return $fail;
}

sub isyes {
    my ($s) = @_;
    return $s =~ /^[Yy]$/ ? 1 : 0;
}

sub trimslashes {
    my ($path) = @_;
    while(length($path) > 1 && $path =~ /\/$/) { $path =~ s/\/$//; }
    return $path;
}

sub ng_mkdir {
    my ($a, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 0;
    logmsg("mkdir $a");
    if ($doit) {
        make_path($a, {error => \my $err});
        if (@$err) {
            logmsg("cannot create directory $a: $!");
            $rc = 1;
        }
    }
    return $rc;
}

# return 0 on success, 1 on failure.  this is the opposite of what copy does.
sub ng_copy {
    my ($a, $b, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    logmsg("copy $a\n  to $b");
    $rc = copy($a, $b) if $doit;
    if ($rc == 0) {
        logmsg("cannot copy $a to $b: $!");
    }
    return ! $rc;
}

# return 0 on success, 1 on failure.  this is the opposite of what move does.
sub ng_move {
    my ($a, $b, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    logmsg("move $a\n  to $b");
    $rc = move($a, $b) if $doit;
    if ($rc == 0) {
        logmsg("cannot rename $a to $b: $!");
    }
    return ! $rc;
}

# return 0 on success, 1 on failure.
sub ng_chmod {
    my ($perms, $a, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    logmsg(sprintf "chmod %o on %s", $perms, $a);
    $rc = chmod $perms, $a if $doit;
    if ($rc == 0) {
        logmsg("cannot chmod on $a: $!");
    }
    return $rc == 0 ? 1 : 0;
}

sub ng_chown {
    my ($uname, $gname, $a, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    my $uid = $uname eq '-' ? -1 : getpwnam $uname;
    my $gid = $gname eq '-' ? -1 : getgrnam $gname;
    logmsg("chown $uname,$gname on $a");
    if (! defined $uid || ! defined $gid) {
        if (! defined $uid) {
            logmsg("no such user $uname");
        }
        if (! defined $gid) {
            logmsg("no such group $gname");
        }
        return 1;
    }
    $rc = chown $uid, $gid, $a if $doit;
    if ($rc == 0) {
        logmsg("cannot chown on $a: $!");
    }
    return $rc == 0 ? 1 : 0;
}

sub ng_touch {
    my ($fn, $doit) = @_;
    $doit = 1 if !defined $doit;
    logmsg("touching $fn");
    return 0 if !$doit;

    if (open my $FILE, '>>', $fn) {
        if (! close $FILE) {
            logmsg("cannot close $fn: $!");
            $fail = 1;
        }
    } else {
        logmsg("cannot create $fn: $!");
        $fail = 1;
    }
    return $fail;
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
    --check-installation |
    --install [--dry-run]
              [--verbose | --silent]
              [--layout (overlay | standalone | custom)]
              [--dest-dir path]
              [--etc-dir path]
              [--var-dir path]
              [--nagios-cgi-url url]
              [--nagios-perfdata-file path]
              [--nagios-user userid]
              [--www-user userid] )

=head1 OPTIONS

B<--version>        Print the version then exit.

B<--install>        Install nagiosgraph.

B<--dry-run>        Report what would happen, but do not do it.

B<--check-prereq>   Report which prerequisites are missing.

B<--check-installation>   Check the installation.

B<--verbose>        Emit messages about what is happening.

B<--silent>         Do not emit messages about what is happening.

B<--layout> layout  Which layout to use.  Can be I<standalone> or I<overlay>.

B<--destdir> path   Directory in which files should be installed.

B<--etc-dir> path   Directory for configuration files.  The default value
                 depends upon the layout and the destination directory.

B<--var-dir> path   Directory for log and RRD files.  The default value
                 depends upon the layout.  For standalone layout, the
                 default is /var/nagiosgraph.  For overlay layout, the
                 default is /var/nagios.

B<--nagios-cgi-url> url    URL to Nagios CGI scripts.

B<--nagios-perfdata-file> path  Path to Nagios perfdata file.

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

  NG_VAR_DIR     - directory for log files and RRD files
  NG_ETC_DIR     - directory for nagiosgraph configuration files
  NG_BIN_DIR     - directory for nagiosgraph executables
  NG_CGI_DIR     - directory for nagiosgraph CGI scripts
  NG_DOC_DIR     - directory for nagiosgraph documentation and examples
  NG_CSS_DIR     - directory for nagiosgraph CSS
  NG_JS_DIR      - directory for nagiosgraph Javascript
  NG_LOG_FILe    - nagiosgraph log file
  NG_CGILOG_FILE - nagiosgraph CGI log file
  NG_RRD_DIR     - directory for nagiosgraph RRD files
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
  GD perl module (optional)

Nagiosgraph requires the following information for installation:

  ng_dest_dir          - directory for nagiosgraph files
  ng_etc_dir           - directory for configuration files
  ng_bin_dir           - directory for executables
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

The default values for an overlay installation to /opt/nagios are:

  ng_dest_dir /opt/nagios
  ng_etc_dir /opt/nagios/etc/nagiosgraph
  ng_bin_dir /opt/nagios/libexec
  ng_cgi_dir /opt/nagios/sbin
  ng_doc_dir /opt/nagios/share/docs
  ng_css_dir /opt/nagios/share
  ng_js_dir /opt/nagios/share

The default values for a standalone installation to /opt/nagiosgraph are:

  ng_dest_dir /opt/nagiosgraph
  ng_etc_dir /opt/nagiosgraph/etc
  ng_bin_dir /opt/nagiosgraph/bin
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

=head1 EXAMPLES

Install a standalone configuration in /usr/local:

  install.pl --dest-dir /usr/local/nagiosgraph

Install to /usr/local but keep var and etc files separate:

  install.pl --var-dir /var/nagiosgraph --etc-dir /etc/nagiosgraph

Install overlay configuration to /opt/nagios

  install.pl --layout overlay --dest-dir /opt/nagios

Install standalone configuration to /opt/nagiosgraph

  install.pl --layout standalone --dest-dir /opt/nagiosgraph

Install nagiosgraph without prompting onto an existing Nagios installation
at /usr/local/nagios:

  export NG_LAYOUT=overlay
  export NG_DEST_DIR=/usr/local/nagios
  export NG_VAR_DIR=/var/nagios
  export NG_URL=/nagios
  install.pl

Install nagiosgraph without prompting to its own directory tree
at /opt/nagiosgraph with nagios user 'naguser' and web user 'apache':

  export NG_LAYOUT=standalone
  export NG_DEST_DIR=/opt/nagiosgraph
  export NG_NAGIOS_USER=naguser
  export NG_WWW_USER=apache
  install.pl

This set is similar to the previous configuration, but this keeps the RRD
and log files in the system /var directory tree and configuration files in
the system /etc directory.

  export NG_LAYOUT=standalone
  export NG_DEST_DIR=/opt/nagiosgraph
  export NG_ETC_DIR=/etc/nagiosgraph
  export NG_VAR_DIR=/var/nagiosgraph
  export NG_NAGIOS_USER=naguser
  export NG_WWW_USER=apache
  install.pl

=head1 EXIT STATUS

Returns 0 if the installation was successful, 1 otherwise.

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
