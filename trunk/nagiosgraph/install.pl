#!/usr/bin/perl
# $Id$
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php
# Author:  (c) 2008 Alan Brenner, Ithaka Harbors
# Author:  (c) 2010 Matthew Wall

# Installation script for nagiosgraph.  If you run this script manually it
# will prompt for all the information needed to do an install.  Specify one
# or more environment variables to do automated or unattended installations.

## no critic (ProhibitCascadingIfElse)
## no critic (ProhibitPostfixControls)
## no critic (RequireBriefOpen)
## no critic (RequireCheckedSyscalls)
## no critic (RegularExpressions)
## no critic (ProhibitConstantPragma)
## no critic (ProhibitMagicNumbers)
## no critic (ProhibitExcessComplexity)

use English qw(-no_match_vars);
use Fcntl ':mode';
use File::Copy qw(copy move);
use File::Path qw(mkpath);
use File::Temp qw(tempfile);
use IPC::Open3 qw(open3);
use POSIX qw(strftime);
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '1.0';

use constant EXIT_FAIL => 1;
use constant EXIT_OK => 0;
use constant DPERMS => oct 755;
use constant FPERMS => oct 644;
use constant XPERMS => oct 755;
use constant LOG_FN => 'install-log';
use constant NAGIOS_CFG_STUB_FN => 'nagiosgraph-nagios.cfg';
use constant NAGIOS_CMD_STUB_FN => 'nagiosgraph-commands.cfg';
use constant APACHE_STUB_FN => 'nagiosgraph-apache.conf';
use constant STAG => '# begin nagiosgraph configuration';
use constant ETAG => '# end nagiosgraph configuration';

my @NAGIOS_USERS = qw(nagios);
my @NAGIOS_GROUPS = qw(nagios);
my @APACHE_USERS = qw(www-data www apache webservd);
my @APACHE_GROUPS = qw(nagcmd www webservd);

# put the keys in a specific order to make it easier to see where things go
my @CONFKEYS = qw(ng_layout ng_prefix ng_etc_dir ng_bin_dir ng_cgi_dir ng_doc_dir ng_examples_dir ng_www_dir ng_util_dir ng_var_dir ng_rrd_dir ng_log_dir ng_log_file ng_cgilog_file ng_url ng_cgi_url ng_css_url ng_js_url nagios_cgi_url nagios_perfdata_file nagios_user www_user modify_nagios_config nagios_config_file nagios_commands_file modify_apache_config apache_config_dir apache_config_file);

# these are standard installation configurations.
my @PRESETS = (
    { ng_layout => 'standalone',
      ng_url => '/nagiosgraph',
      ng_etc_dir => 'etc',
      ng_bin_dir => 'bin',
      ng_cgi_dir => 'cgi',
      ng_doc_dir => 'doc',
      ng_examples_dir => 'examples',
      ng_www_dir => 'share',
      ng_util_dir => 'util',
      ng_var_dir => 'var',
      ng_rrd_dir => 'rrd',
      ng_log_dir => 'var',
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
      ng_examples_dir => 'docs/nagiosgraph/examples',
      ng_www_dir => 'share',
      ng_util_dir => 'docs/nagiosgraph/util',
      ng_var_dir => '/var/nagios',
      ng_rrd_dir => 'rrd',
      ng_log_dir => '/var/nagios',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js', },

    { ng_layout => 'debian',
      ng_prefix => q(/),
      ng_url => '/nagiosgraph',
      ng_etc_dir => '/etc/nagiosgraph',
      ng_bin_dir => '/usr/lib/nagiosgraph',
      ng_cgi_dir => '/usr/lib/cgi-bin/nagiosgraph',
      ng_doc_dir => '/usr/share/nagiosgraph/doc',
      ng_examples_dir => '/usr/share/nagiosgraph/examples',
      ng_www_dir => '/usr/share/nagiosgraph/htdocs',
      ng_util_dir => '/usr/share/nagiosgraph/util',
      ng_var_dir => '/var/spool/nagiosgraph',
      ng_rrd_dir => 'rrd',
      ng_log_dir => '/var/log/nagiosgraph',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js',
      nagios_cgi_url => '/nagios3/cgi-url',
      nagios_perfdata_file => '/tmp/perfdata.log',
      nagios_user => 'nagios',
      www_user => 'www-data',
      nagios_config_file => '/etc/nagios3/nagios.cfg',
      nagios_commands_file => '/etc/nagios3/commands.cfg',
      apache_config_dir => '/etc/apache2/conf.d', },

    { ng_layout => 'redhat',
      ng_prefix => q(/),
      ng_url => '/nagiosgraph',
      ng_etc_dir => '/etc/nagiosgraph',
      ng_bin_dir => '/usr/libexec/nagiosgraph',
      ng_cgi_dir => '/usr/lib/nagiosgraph/cgi-bin',
      ng_doc_dir => '/usr/share/doc/nagiosgraph',
      ng_examples_dir => '/usr/share/nagiosgraph/examples',
      ng_www_dir => '/usr/share/nagiosgraph/htdocs',
      ng_util_dir => '/usr/share/nagiosgraph/util',
      ng_var_dir => '/var/spool/nagiosgraph',
      ng_rrd_dir => 'rrd',
      ng_log_dir => '/var/log/nagiosgraph',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js',
      nagios_perfdata_file => '/tmp/perfdata.log',
      nagios_user => 'nagios',
      www_user => 'apache',
      nagios_config_file => '/etc/nagios/nagios.cfg',
      nagios_commands_file => '/etc/nagios/objects/commands.cfg',
      apache_config_dir => '/etc/httpd/conf.d', },

    { ng_layout => 'suse',
      ng_prefix => q(/),
      ng_url => '/nagiosgraph',
      ng_etc_dir => '/etc/nagiosgraph',
      ng_bin_dir => '/usr/lib/nagiosgraph',
      ng_cgi_dir => '/usr/lib/nagiosgraph/cgi-bin',
      ng_doc_dir => '/usr/share/doc/packages/nagiosgraph',
      ng_examples_dir => '/usr/share/nagiosgraph/examples',
      ng_www_dir => '/usr/share/nagiosgraph/htdocs',
      ng_util_dir => '/usr/share/nagiosgraph/util',
      ng_var_dir => '/var/spool/nagiosgraph',
      ng_rrd_dir => 'rrd',
      ng_log_dir => '/var/log/nagiosgraph',
      ng_log_file => 'nagiosgraph.log',
      ng_cgilog_file => 'nagiosgraph-cgi.log',
      ng_cgi_url => 'cgi-bin',
      ng_css_url => 'nagiosgraph.css',
      ng_js_url => 'nagiosgraph.js',
      nagios_perfdata_file => '/tmp/perfdata.log',
      nagios_user => 'nagios',
      www_user => 'wwwrun',
      nagios_config_file => '/etc/nagios/nagios.cfg',
      nagios_commands_file => '/etc/nagios/objects/commands.cfg',
      apache_config_dir => '/etc/apache2/conf.d', },
    );

my @CONF =
    ( { conf => 'ng_prefix',
        msg => 'Destination directory (prefix)',
        def => '/usr/local/nagiosgraph' },
      { conf => 'ng_etc_dir',
        msg => 'Location of configuration files (etc-dir)',
        parent => 'ng_prefix' },
      { conf => 'ng_bin_dir',
        msg => 'Location of executables',
        parent => 'ng_prefix' },
      { conf => 'ng_cgi_dir',
        msg => 'Location of CGI scripts',
        parent => 'ng_prefix' },
      { conf => 'ng_doc_dir',
        msg => 'Location of documentation (doc-dir)',
        parent => 'ng_prefix' },
      { conf => 'ng_examples_dir',
        msg => 'Location of examples',
        parent => 'ng_prefix' },
      { conf => 'ng_www_dir',
        msg => 'Location of CSS and JavaScript files',
        parent => 'ng_prefix' },
      { conf => 'ng_util_dir',
        msg => 'Location of utilities',
        parent => 'ng_prefix' },
      { conf => 'ng_var_dir',
        msg => 'Location of state files (var-dir)',
        parent => 'ng_prefix' },
      { conf => 'ng_rrd_dir',
        msg => 'Location of RRD files',
        parent => 'ng_var_dir' },
      { conf => 'ng_log_dir',
        msg => 'Location of log files (log-dir)',
        parent => 'ng_prefix' },
      { conf => 'ng_log_file',
        msg => 'Path of log file',
        parent => 'ng_log_dir' },
      { conf => 'ng_cgilog_file',
        msg => 'Path of CGI log file',
        parent => 'ng_log_dir' },
      { conf => 'ng_cgi_url',
        msg => 'URL of CGI scripts',
        parent => 'ng_url' },
      { conf => 'ng_css_url',
        msg => 'URL of CSS file',
        parent => 'ng_url' },
      { conf => 'ng_js_url',
        msg => 'URL of JavaScript file',
        parent => 'ng_url' },
      { conf => 'nagios_perfdata_file',
        msg => 'Path of Nagios performance data file',
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
my $dryrun = 0;
my $action = 'install';
my %conf = qw(ng_layout standalone);
my $checkprereq = 1;
my $dochown = 1;

while ($ARGV[0]) {
    my $arg = shift;
    if($arg eq '--version') {
        print 'nagiosgraph installer ' . $VERSION . "\n";
        exit EXIT_OK;
    } elsif($arg eq '--install') {
        $action = 'install';
    } elsif ($arg eq '--dry-run') {
        $dryrun = 1;
    } elsif ($arg eq '--silent' || $arg eq '--quiet') {
        $verbose = 0;
    } elsif ($arg eq '--verbose') {
        $verbose = 1;
    } elsif ($arg eq '--check-installation') {
        $action = 'check-installation';
    } elsif ($arg eq '--check-prereq') {
        $action = 'check-prereq';
    } elsif ($arg eq '--layout') {
        $conf{ng_layout} = shift;
    } elsif ($arg =~ /^--layout=(.+)/) {
        $conf{ng_layout} = $1;
    } elsif ($arg eq '--prefix') {
        $conf{ng_prefix} = trimslashes(shift);
    } elsif ($arg =~ /^--prefix=(.+)/) {
        $conf{ng_prefix} = trimslashes($1);
    } elsif ($arg eq '--var-dir') {
        $conf{ng_var_dir} = trimslashes(shift);
    } elsif ($arg =~ /^--var-dir=(.+)/) {
        $conf{ng_var_dir} = trimslashes($1);
    } elsif ($arg eq '--log-dir') {
        $conf{ng_log_dir} = trimslashes(shift);
    } elsif ($arg =~ /^--log-dir=(.+)/) {
        $conf{ng_log_dir} = trimslashes($1);
    } elsif ($arg eq '--etc-dir') {
        $conf{ng_etc_dir} = trimslashes(shift);
    } elsif ($arg =~ /^--etc-dir=(.+)/) {
        $conf{ng_etc_dir} = trimslashes($1);
    } elsif ($arg eq '--doc-dir') {
        $conf{ng_doc_dir} = trimslashes(shift);
    } elsif ($arg =~ /^--doc-dir=(.+)/) {
        $conf{ng_doc_dir} = trimslashes($1);
    } elsif ($arg eq '--nagios-cgi-url') {
        $conf{nagios_cgi_url} = shift;
    } elsif ($arg =~ /^--nagios-cgi-url=(.+)/) {
        $conf{nagios_cgi_url} = $1;
    } elsif ($arg eq '--nagios-perfdata-file') {
        $conf{nagios_perfdata_file} = shift;
    } elsif ($arg =~ /^--nagios-perfdata-file=(.+)/) {
        $conf{nagios_perfdata_file} = $1;
    } elsif ($arg eq '--nagios-user') {
        $conf{nagios_user} = shift;
    } elsif ($arg =~ /^--nagios-user=(.+)/) {
        $conf{nagios_user} = $1;
    } elsif ($arg eq '--www-user') {
        $conf{www_user} = shift;
    } elsif ($arg =~ /^--www-user=(.+)/) {
        $conf{www_user} = $1;
    } elsif ($arg eq '--no-check-prereq') {
        $checkprereq = 0;
    } elsif ($arg eq '--no-chown') {
        $dochown = 0;
    } elsif ($arg eq '--list-vars') {
        print "recognized environment variables include:\n";
        foreach my $v (envvars()) {
            print "  $v\n";
        }
        print "when building RPM or DEB package, use DESTDIR\n";
        exit EXIT_OK;
    } else {
        my $code = EXIT_OK;
        if ($arg ne '--help') {
            $code = EXIT_FAIL;
            print "unknown option $arg\n";
            print "\n";
        }
        print "options include:\n";
        print "  --install             do the installation\n";
        print "  --check-prereq        check pre-requisites\n";
        print "  --check-installation  check the installation\n";
        print "\n";
        print "  --dry-run\n";
        print "  --verbose | --silent\n";
        print "  --list-vars           list recognized environment variables\n";
        print "\n";
        print "  --layout (overlay | standalone | debian | redhat | suse | custom)\n";
        print "  --prefix path\n";
        print "  --etc-dir path\n";
        print "  --var-dir path\n";
        print "  --log-dir path\n";
        print "  --doc-dir path\n";
        print "  --nagios-cgi-url url\n";
        print "  --nagios-perfdata-file path\n";
        print "  --nagios-user userid\n";
        print "  --www-user userid\n";
        print "\n";
        print "examples:\n";
        print "to install on an ubuntu system with nagios3:\n";
        print "  install.pl --layout debian\n";
        print "to install on a redhat/fedora system with nagios3:\n";
        print "  install.pl --layout redhat\n";
        print "to install on a suse system with nagios3:\n";
        print "  install.pl --layout suse\n";
        print "to overlay with nagios at /usr/local/nagios:\n";
        print "  install.pl --layout overlay --prefix /usr/local/nagios\n";
        print "to install at /opt/nagiosgraph:\n";
        print "  install.pl --layout standalone --prefix /opt/nagiosgraph\n";
        print "\n";
        print "to install without prompts for automated or unattended\n";
        print "installations, specify one or more environment variables.\n";
        exit $code;
    }
}

if ($conf{ng_layout} ne 'standalone' &&
    $conf{ng_layout} ne 'overlay' &&
    $conf{ng_layout} ne 'debian' &&
    $conf{ng_layout} ne 'redhat' &&
    $conf{ng_layout} ne 'suse' &&
    $conf{ng_layout} ne 'custom') {
    print "unknown layout '$conf{ng_layout}'\n";
    exit 1;
}

my $LOG;
my $failure = 0;

if($action eq 'check-prereq') {
    $failure |= checkprereq();
} elsif($action eq 'check-installation') {
    $failure |= checkinstallation();
} elsif($action eq 'install') {
    open $LOG, '>', LOG_FN ||
        print 'cannot write to log file ' . LOG_FN . ": $OS_ERROR\n";
    $failure |= checkprereq() if $checkprereq;
    $failure |= getconfig(\%conf);
    if (checkconfig(\%conf)) {
        logmsg('*** one or more missing configuration parameters!');
        exit EXIT_FAIL;
    }
    printconfig(\%conf);
    if (! isyes($conf{automated})) {
        my $confirm = getanswer('Continue with this configuration', 'y');
        if ($confirm !~ /y/) {
            logmsg('installation aborted');
            exit EXIT_OK;
        }
    }
    $failure |= installfiles(\%conf, $dryrun ? 0 : 1);
    $failure |= patchnagios(\%conf, $dryrun ? 0 : 1);
    $failure |= patchapache(\%conf, $dryrun ? 0 : 1);
    if (! isyes($conf{automated})) {
        printinstructions(\%conf);
    }
    close $LOG || print "cannot close log file: $OS_ERROR\n";
    undef $LOG;
}

if ($failure) {
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
    if (${LOG}) {
        my $ts = strftime '%d.%m.%Y %H:%M:%S', localtime time;
        print ${LOG} "[$ts] $msg\n";
    }
    return;
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
    my $ts = strftime '%Y%m%d.%H%M', localtime time;
    my $fail = 0;
    if (open my $FILE, '>>', $ofn) {
        print ${FILE} "\n$txt\n";
        if (close $FILE) {
            my $bak = $ifn . q(-) . $ts;
            if (ng_move($ifn, $bak) || ng_move($ofn, $ifn)) {
                $fail = 1;
            }
        } else {
            logmsg("*** cannot close $ofn: $OS_ERROR");
            $fail = 1;
        }
    } else {
        logmsg("*** cannot append to $ofn: $OS_ERROR");
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

sub checkconfig {
    my ($conf) = @_;
    my $missing = 0;
    foreach my $ii (@CONFKEYS) {
        if (! defined $conf->{$ii}) {
            if($ii eq 'nagios_config_file' &&
               ! isyes($conf->{modify_nagios_config})) {
                next;
            } elsif($ii eq 'nagios_commands_file' &&
                    ! isyes($conf->{modify_nagios_config})) {
                next;
            } elsif(($ii eq 'apache_config_dir' ||
                     $ii eq 'apache_config_file') &&
                    ! isyes($conf->{modify_apache_config})) {
                next;
            } elsif($ii eq 'apache_config_file' &&
                    defined $conf->{apache_config_dir} &&
                    isyes($conf->{modify_apache_config})) {
                next;
            } elsif($ii eq 'apache_config_dir' &&
                    defined $conf->{apache_config_file} &&
                    isyes($conf->{modify_apache_config})) {
                next;
            } else {
                logmsg('parameter ' . $ii . ' is not defined');
                $missing = 1;
            }
        }
    }
    return $missing;
}

sub getconfig {
    my ($conf) = @_;
    my $fail = 0;

    if (readconfigenv($conf) > 0) {
        $conf->{automated} = 'y';
        return 0;
    }

    readconfigpresets($conf);

    if (! defined $conf->{nagios_perfdata_file}) {
        my $x = findfile('perfdata.log', qw(/var/nagios /var/spool/nagios /var/nagios3 /var/spool/nagios3));
        $conf->{nagios_perfdata_file} = $x if $x ne q();
    }

    if (! defined $conf->{nagios_user}) {
        my $x = finduser(@NAGIOS_USERS);
        $conf->{nagios_user} = $x if $x ne q();
    }

    if (! defined $conf->{www_user}) {
        my $x = finduser(@APACHE_USERS);
        $conf->{www_user} = $x if $x ne q();
    }

    # prompt for each item in the configuration
    foreach my $ii (@CONF) {
        my $def = defined $conf->{$ii->{conf}} ?
            $conf->{$ii->{conf}} :
            defined $ii->{def} ? $ii->{def} : q();
        if ($def ne q() &&
            defined $ii->{parent} &&
            defined $conf->{$ii->{parent}}) {
            $def = prependpath($conf->{$ii->{parent}}, $def);
        }
        $conf->{$ii->{conf}} = getanswer($ii->{msg}, $def);
    }

    # find out if we should modify the nagios configuration.  if there is a
    # conf.d directory, then use it.  if not, modify the .conf file.
    $conf->{modify_nagios_config} =
        getanswer('Modify the Nagios configuration', 'n');
    if (isyes($conf->{modify_nagios_config})) {
        my $x = defined $conf->{nagios_config_file} ?
            $conf->{nagios_config_file} : q();
        if ($x eq q()) {
            $x = findfile('nagios.cfg', qw(/etc/nagios /usr/local/nagios/etc /opt/nagios/etc /etc/nagios3 /usr/local/nagios3/etc /opt/nagios3/etc));
        }
        $conf->{nagios_config_file} =
            getanswer('Path of Nagios configuration file', $x);

        $x = defined $conf->{nagios_commands_file} ?
            $conf->{nagios_commands_file} : q();
        if ($x eq q()) {
            $x = findfile('commands.cfg', qw(/etc/nagios /usr/local/nagios/etc /opt/nagios/etc /etc/nagios3 /usr/local/nagios3/etc /opt/nagios3/etc));
        }
        $conf->{nagios_commands_file} =
            getanswer('Path of Nagios commands file', $x);
    }

    # find out if we should modify the apache configuration.  if there is a
    # conf.d directory, then use it.  if not, modify the .conf file.
    $conf->{modify_apache_config} =
        getanswer('Modify the Apache configuration', 'n');
    if (isyes($conf->{modify_apache_config})) {
        my @dirs = qw(/etc/apache2 /usr/local/apache2 /opt/apache2 /etc/httpd /usr/local/httpd /opt/httpd);
        my $x = defined $conf->{apache_config_dir} ?
            $conf->{apache_config_dir} : q();
        if ($x eq q()) {
            $x = finddir('conf.d', @dirs);
            $conf->{apache_config_dir} = $x if $x ne q();
        }
        if (! defined $conf->{apache_config_dir}) {
            $x = defined $conf->{apache_config_file} ?
                $conf->{apache_config_file} : q();
            if ($x eq q()) {
                $x = findfile('apache2.conf', @dirs);
            }
            if ($x eq q()) {
                $x = findfile('httpd.conf', qw(/etc/apache2/conf /usr/local/apache2/conf /opt/apache2/conf /etc/httpd /usr/local/httpd/conf /opt/httpd/conf));
            }
            $conf->{apache_config_file} =
                getanswer('Path of Apache configuration file', $x);
        }
    }

    return $fail;
}

sub readconfigpresets {
    my ($conf) = @_;
    foreach my $p (@PRESETS) {
        if (defined $conf->{ng_layout} &&
            $conf->{ng_layout} eq $p->{ng_layout} &&
            (! defined $p->{ng_prefix} ||
             ! defined $conf->{ng_prefix} ||
             $p->{ng_prefix} eq $conf->{ng_prefix})) {
            foreach my $ii (keys %{$p}) {
                if (! defined $conf->{$ii}) {
                    $conf->{$ii} = $p->{$ii};
                }
            }
            last;
        }
    }
    return 0;
}

sub readconfigenv {
    my ($conf) = @_;
    my $cnt = 0;
    if ($ENV{NG_LAYOUT}) {
        $conf->{ng_layout} = $ENV{NG_LAYOUT};
        $cnt += 1;
    }
    foreach my $ii (@CONF) {
        my $name = mkenvname($ii->{conf});
        if ($ENV{$name}) {
            $conf->{$ii->{conf}} = $ENV{$name};
            $cnt += 1;
        }
    }
    return 0 if $cnt == 0;

    my $n = mkenvname('modify_nagios_config');
    $conf->{modify_nagios_config} = $ENV{$n} && $ENV{$n} eq 'y' ? 'y' : 'n';
    $n = mkenvname('modify_apache_config');
    $conf->{modify_apache_config} = $ENV{$n} && $ENV{$n} eq 'y' ? 'y' : 'n';
    $n = mkenvname('nagios_config_file');
    $conf->{nagios_config_file} = $ENV{$n} if $ENV{$n};
    $n = mkenvname('nagios_commands_file');
    $conf->{nagios_commands_file} = $ENV{$n} if $ENV{$n};
    $n = mkenvname('apache_config_dir');
    $conf->{apache_config_dir} = $ENV{$n} if $ENV{$n};
    $n = mkenvname('apache_config_file');
    $conf->{apache_config_file} = $ENV{$n} if $ENV{$n};
    readconfigpresets($conf);
    foreach my $ii (@CONF) {
        my $def = defined $conf->{$ii->{conf}} ?
            $conf->{$ii->{conf}} :
            defined $ii->{def} ? $ii->{def} : q();
        if ($def ne q() &&
            defined $ii->{parent} &&
            defined $conf->{$ii->{parent}}) {
            $def = prependpath($conf->{$ii->{parent}}, $def);
        }
        $conf->{$ii->{conf}} = $def;
    }

    return $cnt;
}

sub envvars {
    my @vars;
    push @vars, 'NG_LAYOUT';
    foreach my $ii (@CONF) {
        push @vars, mkenvname($ii->{conf});
    }
    push @vars, 'NG_MODIFY_NAGIOS_CONFIG';
    push @vars, 'NG_NAGIOS_CONFIG_FILE';
    push @vars, 'NG_NAGIOS_COMMANDS_FILE';
    push @vars, 'NG_MODIFY_APACHE_CONFIG';
    push @vars, 'NG_APACHE_CONFIG_DIR';
    push @vars, 'NG_APACHE_CONFIG_FILE';
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
    logmsg('configuration:');
    if ($ENV{DESTDIR}) {
        logmsg('  DESTDIR=' . $ENV{DESTDIR});
    }
    foreach my $ii (@CONFKEYS) {
        logmsg(sprintf '  %-20s %s', $ii, defined $conf->{$ii} ? $conf->{$ii} : q());
    }
    return;
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
    @dirs = qw(/usr/local/nagios/bin /usr/local/nagios3/bin /opt/nagios/bin /opt/nagios3/bin /usr/bin /usr/sbin /bin /sbin);
    $found = checkexec('nagios', @dirs);
    if ($found eq q()) {
        $found = checkexec('nagios3', @dirs);
    }
    if ($found ne q()) {
        logmsg("  found nagios at $found");
    } else {
        my $dlist;
        foreach my $d (@dirs) {
            $dlist .= "\n    $d";
        }
        logmsg("  nagios not found in any of:$dlist");
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
        if (-f $a) {
            $found = $a;
            if (! -x $a) {
                $found .= ' (not executable)';
            }
        }
    }
    return $found;
}

# check for things that are often broken
sub checkinstallation {
    my $fail = 0;

    my $mapfn = getanswer('Path of map file', '/etc/nagiosgraph/map');
    my $rrddir = getanswer('Path of RRD directory', '/var/nagiosgraph/rrd');
    my $logdir = getanswer('Path of log directory', '/var/log/nagiosgraph');
    my $nuser = finduser(@NAGIOS_USERS);
    my $ngroup = findgroup(@NAGIOS_GROUPS);
    my $auser = finduser(@APACHE_USERS);
    my $agroup = findgroup(@APACHE_GROUPS);
    $nuser = getanswer('nagios user', $nuser);
    $ngroup = getanswer('nagios group', $ngroup);
    $auser = getanswer('apache user', $auser);
    $agroup = getanswer('apache group', $agroup);

    logmsg('checking RRDs');
    my $rval = eval { require RRDs; };
    if (defined $rval && $rval == 1) {
        my ($fh,$fn) = tempfile();
        RRDs::create("$fn",'-s 60',
                     'DS:temp:GAUGE:600:0:100',
                     'RRA:AVERAGE:0.5:1:576',
                     'RRA:AVERAGE:0.5:6:672',
                     'RRA:AVERAGE:0.5:24:732',
                     'RRA:AVERAGE:0.5:144:1460');
        my $err = RRDs::error();
        if (! $err) {
            logmsg('  RRDs::create: ok');
            RRDs::update("$fn", '-t', 'temp', 'N:50');
            $err = RRDs::error();
            if (! $err) {
                logmsg('  RRDs::update: ok');
            } else {
                logmsg('*** RRDs::update failed: ' . $err);
                $fail = 1;
            }
        } else {
            logmsg('*** RRDs::create failed: ' . $err);
            $fail = 1;
        }
        if (-f $fn) {
            unlink $fn;
        }
    } else {
        logmsg('*** RRDs is not installed');
        $fail = 1;
    }

    logmsg('checking GD');
    $rval = eval { require GD; };
    if (defined $rval && $rval == 1) {
        my $img = new GD::Image(5,5);
        if ($img) {
            logmsg('  GD:Image ok');
        } else {
            logmsg('*** GD::Image: failed');
            $fail = 1;
        }
    } else {
        logmsg('  GD is not installed (GD is recommended but not required)');
    }

    logmsg('checking map file with perl');
    my ($CHILD_IN, $CHILD_OUT, $CHILD_ERR);
    open3($CHILD_IN, $CHILD_OUT, $CHILD_ERR, "perl -c $mapfn");
    if (! $CHILD_ERR) {
        logmsg('  no errors detected in map file.');
    } else {
        logmsg('  one or more problems with map file');
        my $result = q();
        while( <$CHILD_ERR> ) {
            $result .= $_;
        }
        logmsg($result);
        $fail = 1;
    }

    logmsg('checking ability to load map file');
    if (open my $FH, '<', $mapfn) {
        my @rules;
        while(<$FH>) {
            push @rules, $_;
        }
        close $FH or logmsg("close failed for $mapfn");
        # this code must match the code in ngshared
        ## no critic (RequireInterpolationOfMetachars)
        my $code = 'sub evalrules {' . "\n" .
            ' $_ = $_[0];' . "\n" .
            ' my ($d, @s) = ($_);' . "\n" .
            ' no strict "subs";' . "\n" .
            join(q(), @rules) .
            ' use strict "subs";' . "\n" .
            ' return () if ($#s > -1 && $s[0] eq "ignore");' . "\n" .
            ' return @s;' . "\n" .
            '} 1' . "\n";
        my $rc = eval $code;  ## no critic (ProhibitStringyEval)
        if (defined $rc && $rc) {
            logmsg('  map file loaded successfully');
        } else {
            logmsg('*** map file eval error!');
            $fail = 1;
        }
    } else {
        logmsg("*** cannot open map file $mapfn: $OS_ERROR");
        $fail = 1;
    }

    logmsg('checking RRD directory permissions');
    if (-d $rrddir) {
        if (canwrite($rrddir, $nuser, $ngroup)) {
            logmsg("  writeable by nagios user $nuser");
        } else {
            logmsg("*** not writeable by nagios user $nuser:$ngroup");
        }
        if (canread($rrddir, $auser, $agroup)) {
            logmsg("  readable by apache user $auser");
        } else {
            logmsg("*** not readable by apache user $auser:$agroup");
        }
    } else {
        logmsg("*** no RRD directory at $rrddir");
    }

    logmsg('checking log directory permissions');
    if (-d $logdir) {
        if (canwrite($logdir, $nuser, $ngroup)) {
            logmsg("  writeable by nagios user $nuser");
        } else {
            logmsg("*** not writeable by nagios user $nuser:$ngroup");
        }
        if (canwrite($logdir, $auser, $agroup)) {
            logmsg("  writeable by apache user $auser");
        } else {
            logmsg("*** not writeable by apache user $auser:$agroup");
        }
    } else {
        logmsg("*** no log directory at $logdir");
    }

    return $fail;
}

sub finduser {
    my @users = @_;
    foreach my $u (@users) {
        my $uid = getpwnam $u;
        if (defined $uid) {
            return $u;
        }
    }
    return $users[0];
}

sub findgroup {
    my @groups = @_;
    foreach my $g (@groups) {
        my $gid = getgrnam $g;
        if (defined $gid) {
            return $g;
        }
    }
    return $groups[0];
}

sub findfile {
    my ($fn, @dirs) = @_;
    my $path = q();
    foreach my $dir (@dirs) {
        if (-f "$dir/$fn") {
            $path = "$dir/$fn";
        }
    }
    return $path;
}

sub finddir {
    my ($fn, @dirs) = @_;
    my $path = q();
    foreach my $dir (@dirs) {
        if (-d "$dir/$fn") {
            $path = "$dir/$fn";
        }
    }
    return $path;
}

sub getfiles {
    my ($dir, $pattern) = @_;
    my @files;
    if (opendir DH, $dir) {
        @files = grep { /^[^\.]/ && /$pattern/ } readdir DH;
        closedir DH;
    } else {
        logmsg("*** cannot read directory $dir: $OS_ERROR");
    }
    return @files;
}

# return 0 if successful, 1 if failure
sub replacetext {
    my ($ifn, $pat, $doit) = @_;
    logmsg("replace text in $ifn");
    return 0 if !$doit;
    my $ofn = $ifn . '-bak';
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
                logmsg("*** cannot close $ofn: $OS_ERROR");
                $fail = 1;
            }
        } else {
            logmsg("*** cannot write to $ofn: $OS_ERROR");
            $fail = 1;
        }
        if (! close $IFILE) {
            logmsg("*** cannot close $ifn: $OS_ERROR");
            $fail = 1;
        }
    } else {
        logmsg("*** cannot read from $ifn: $OS_ERROR");
        $fail = 1;
    }
    return $fail;
}

sub writestub {
    my ($fn, $str, $doit) = @_;
    logmsg("write stub to $fn");
    return 0 if !$doit;
    my $fail = 0;
    if (open my $FILE, '>', $fn) {
        print ${FILE} $str;
        if (! close $FILE) {
            logmsg("*** cannot close $fn: $OS_ERROR");
            $fail = 1;
        }
    } else {
        logmsg("*** cannot write to $fn: $OS_ERROR");
        $fail = 1;
    }
    return $fail;
}

# if the nagiosgraph cgi url is the same as the nagios cgi url, do not add a
# new entry - that would cause a configuration error.  same goes for the
# nagiosgraph base url, but in that case we must guess since the nagios base
# url is not specified for us anywhere.  for that we match nagios or nagios3.
sub printapacheconf {
    my ($cgiurl, $cgidir, $ngurl, $wwwdir, $nagioscgiurl) = @_;
    $nagioscgiurl = q() if ! defined $nagioscgiurl;
    my $str = q();
    my $cmmt = q();

    $str .= "# enable nagiosgraph CGI scripts\n";
    if ($cgiurl eq $nagioscgiurl) {
        $cmmt = q(#);
    } else {
        $cmmt = q();
    }
    $str .= $cmmt . "ScriptAlias $cgiurl \"$cgidir\"\n";
    $str .= $cmmt . "<Directory \"$cgidir\">\n";
    $str .= $cmmt . "   Options ExecCGI\n";
    $str .= $cmmt . "   AllowOverride None\n";
    $str .= $cmmt . "   Order allow,deny\n";
    $str .= $cmmt . "   Allow from all\n";
    $str .= $cmmt . "</Directory>\n";

    $str .= "# enable nagiosgraph CSS and JavaScript\n";
    if ($ngurl =~ /nagios\d*\/*$/) {
        $cmmt = q(#);
    } else {
        $cmmt = q();
    }
    $str .= $cmmt . "Alias $ngurl \"$wwwdir\"\n";
    $str .= $cmmt . "<Directory \"$wwwdir\">\n";
    $str .= $cmmt . "   Options None\n";
    $str .= $cmmt . "   AllowOverride None\n";
    $str .= $cmmt . "   Order allow,deny\n";
    $str .= $cmmt . "   Allow from all\n";
    $str .= $cmmt . "</Directory>\n";

    return $str;
}

sub printnagioscfg {
    my ($fn) = @_;
    my $str = "# process nagios performance data using nagiosgraph\n";
    $str .= "process_performance_data=1\n";
    $str .= "service_perfdata_file=$fn\n";
    $str .= "service_perfdata_file_template=\$LASTSERVICECHECK\$\|\|\$HOSTNAME\$\|\|\$SERVICEDESC\$\|\|\$SERVICEOUTPUT\$\|\|\$SERVICEPERFDATA\$\n";
    $str .= "service_perfdata_file_mode=a\n";
    $str .= "service_perfdata_file_processing_interval=30\n";
    $str .= "service_perfdata_file_processing_command=process-service-perfdata-for-nagiosgraph\n";
    return $str;
}

sub printnagioscmd {
    my ($fn) = @_;
    my $str = "# command to process nagios performance data for nagiosgraph\n";
    $str .= "define command {\n";
    $str .= "  command_name process-service-perfdata-for-nagiosgraph\n";
    $str .= "  command_line $fn\n";
    $str .= "}\n";
    return $str;
}

# ensure that the instructions are printed out whether or not we are verbose.
sub printinstructions {
    my ($conf) = @_;
    my $oldv = $verbose;
    $verbose = 1;
    if (!isyes($conf->{modify_nagios_config}) ||
        !isyes($conf->{modify_apache_config})) {
        logmsg(q());
        logmsg('  To complete the installation, do the following:');
    }
    if (!isyes($conf->{modify_nagios_config})) {
        logmsg(q());
        logmsg('  * In the nagios configuration file (e.g. nagios.cfg),');
        logmsg('    add these lines:');
        logmsg(q());
        logmsg(printnagioscfg($conf->{nagios_perfdata_file}));
        logmsg(q());
        logmsg('  * In the nagios commands file (e.g. command.cfg),');
        logmsg('    add these lines:');
        logmsg(q());
        logmsg(printnagioscmd("$conf->{ng_bin_dir}/insert.pl"));
    }
    if (!isyes($conf->{modify_apache_config})) {
        logmsg(q());
        logmsg('  * In the apache configuration file (e.g. httpd.conf),');
        logmsg('    add this line:');
        logmsg(q());
        logmsg("include $conf->{ng_etc_dir}/" . APACHE_STUB_FN);
    }
    logmsg(q());
    logmsg('  * Restart nagios to start data collection:');
    logmsg(q());
    logmsg('/etc/init.d/nagios restart');
    logmsg(q());
    logmsg('  * Restart apache to enable display of graphs:');
    logmsg(q());
    logmsg('/etc/init.d/apache restart');
    logmsg(q());
    logmsg('  * To enable graph links and mouseovers, see README sections:');
    logmsg('       Displaying Per-Service and Per-Host Graph Icons and Links');
    logmsg('       Displaying Graphs in Nagios Mouseovers');
    logmsg(q());
    $verbose = $oldv;
    return;
}

sub installfiles {
    my ($conf, $doit) = @_;
    my $dst;
    my $fail = 0;

    my $dd = $ENV{DESTDIR} ? "$ENV{DESTDIR}" : q();

    if (defined $conf->{ng_prefix}) {
        $dst = $dd . $conf->{ng_prefix};
        $fail |= ng_mkdir($dst, $doit);
    }

    if (defined $conf->{ng_etc_dir}) {
        $dst = $dd . $conf->{ng_etc_dir};
        $fail |= ng_mkdir($dst, $doit);
        my @files = getfiles('etc', '.*.conf$');
        for my $f (@files) {
            $fail |= ng_copy("etc/$f", "$dst/$f", $doit, 1);
        }
        $fail |= ng_copy('etc/map', "$dst/map", $doit, 1);
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
  '^groupdb\\s*=.*', 'groupdb = ' . $conf->{ng_etc_dir} . '/groupdb.conf',
  '^#labelfile\\s*=.*', 'labelfile = ' . $conf->{ng_etc_dir} . '/labels.conf',
  '^#datasetdb\\s*=.*', 'datasetdb = ' . $conf->{ng_etc_dir} . '/datasetdb.conf',
                    }, $doit);
        if ($conf->{ng_cgi_url} ne $conf->{nagios_cgi_url}) {
            $fail |= replacetext("$dst/nagiosgraph.conf", {
  '^#nagioscgiurl\\s*=.*', 'nagioscgiurl = ' . $conf->{nagios_cgi_url},
                    }, $doit);
        }
        $fail |= writestub($dst . q(/) . NAGIOS_CFG_STUB_FN,
                           printnagioscfg($conf->{nagios_perfdata_file}),
                           $doit);
        $fail |= writestub($dst . q(/) . NAGIOS_CMD_STUB_FN,
                           printnagioscmd("$conf->{ng_bin_dir}/insert.pl"),
                           $doit);
        $fail |= writestub($dst . q(/) . APACHE_STUB_FN,
                           printapacheconf($conf->{ng_cgi_url},
                                           $conf->{ng_cgi_dir},
                                           $conf->{ng_url},
                                           $conf->{ng_www_dir},
                                           $conf->{nagios_cgi_url}),
                           $doit);
    }

    if (defined $conf->{ng_cgi_dir}) {
        $dst = $dd . $conf->{ng_cgi_dir};
        $fail |= ng_mkdir($dst, $doit);
        my @files = getfiles('cgi', '.*.cgi$');
        for my $f (@files) {
            $fail |= ng_copy("cgi/$f", "$dst", $doit);
            $fail |= replacetext("$dst/$f",
                                 { 'use lib \'/opt/nagiosgraph/etc\'' =>
                                       "use lib '$conf->{ng_etc_dir}'" },
                                 $doit );
            $fail |= ng_chmod(XPERMS, "$dst/$f", $doit);
        }
    }

    if (defined $conf->{ng_bin_dir}) {
        $dst = $dd . $conf->{ng_bin_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('lib/insert.pl', "$dst", $doit);
        $fail |= replacetext("$dst/insert.pl",
                             { 'use lib \'/opt/nagiosgraph/etc\'' =>
                                   "use lib '$conf->{ng_etc_dir}'" },
                             $doit);
        $fail |= ng_chmod(XPERMS, "$dst/insert.pl", $doit);
    }

    if (defined $conf->{ng_www_dir}) {
        $dst = $dd . $conf->{ng_www_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('share/nagiosgraph.css', "$dst/nagiosgraph.css",
                         $doit, 1);
        $fail |= ng_copy('share/nagiosgraph.js', "$dst", $doit);
    }

    if (defined $conf->{ng_doc_dir}) {
        $dst = $dd . $conf->{ng_doc_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('AUTHORS', "$dst", $doit);
        $fail |= ng_copy('CHANGELOG', "$dst", $doit);
        $fail |= ng_copy('INSTALL', "$dst", $doit);
        $fail |= ng_copy('README', "$dst", $doit);
        $fail |= ng_copy('TODO', "$dst", $doit);
    }

    if (defined $conf->{ng_examples_dir}) {
        $dst = $dd . $conf->{ng_examples_dir};
        $fail |= ng_mkdir($dst, $doit);
        my @files = getfiles('examples', '[^~]$');
        for my $f (@files) {
            $fail |= ng_copy("examples/$f", "$dst", $doit);
        }
        $fail |= ng_copy('share/graph.gif', "$dst", $doit);
        $fail |= ng_copy('share/nagiosgraph.ssi', "$dst", $doit);
    }

    if (defined $conf->{ng_util_dir}) {
        $dst = $dd . $conf->{ng_util_dir};
        $fail |= ng_mkdir($dst, $doit);
        $fail |= ng_copy('utils/testentry.pl', "$dst", $doit);
        $fail |= ng_copy('utils/upgrade.pl', "$dst", $doit);
        $fail |= ng_chmod(XPERMS, "$dst/testentry.pl", $doit);
        $fail |= ng_chmod(XPERMS, "$dst/upgrade.pl", $doit);
    }

    if (defined $conf->{ng_rrd_dir}) {
        $dst = $dd . $conf->{ng_rrd_dir};
        $fail |= ng_mkdir("$dst", $doit);
        $fail |= ng_chmod(DPERMS, "$dst", $doit);
        $fail |= ng_chown($conf->{nagios_user}, q(-), "$dst", $doit);
    }

    if (defined $conf->{ng_log_dir}) {
        $dst = $dd . $conf->{ng_log_dir};
        if (! -d "$dst") {
            $fail |= ng_mkdir("$dst", $doit);
            $fail |= ng_chmod(DPERMS, "$dst", $doit);
        }
    }

    if (defined $conf->{ng_log_file}) {
        $dst = $dd . $conf->{ng_log_file};
        $fail |= ng_touch("$dst", $doit);
        $fail |= ng_chmod(FPERMS, "$dst", $doit);
        $fail |= ng_chown($conf->{nagios_user}, q(-), "$dst", $doit);
    }

    if (defined $conf->{ng_cgilog_file}) {
        $dst = $dd . $conf->{ng_cgilog_file};
        $fail |= ng_touch("$dst", $doit);
        $fail |= ng_chmod(FPERMS, "$dst", $doit);
        $fail |= ng_chown($conf->{www_user}, q(-), "$dst", $doit);
    }

    return $fail;
}

sub patchnagios {
    my ($conf, $doit) = @_;
    my $fail = 0;

    if (defined $conf->{modify_nagios_config} &&
        isyes($conf->{modify_nagios_config})) {
        if (defined $conf->{nagios_config_file}) {
            $fail |= appendtofile($conf->{nagios_config_file},
                                  STAG . "\n" .
                               printnagioscfg($conf->{nagios_perfdata_file}) .
                                  ETAG . "\n",
                                  $doit);
        }
        if (defined $conf->{nagios_commands_file}) {
            $fail |= appendtofile($conf->{nagios_commands_file},
                                  STAG . "\n" .
                               printnagioscmd("$conf->{ng_bin_dir}/insert.pl") .
                                  ETAG . "\n",
                                  $doit);
        }
    }

    return $fail;
}

sub patchapache {
    my ($conf, $doit) = @_;
    my $fail = 0;

    my $dd = $ENV{DESTDIR} ? "$ENV{DESTDIR}" : q();

    if (defined $conf->{modify_apache_config} &&
        isyes($conf->{modify_apache_config})) {
        if (defined $conf->{apache_config_dir}) {
            $fail |= ng_move($dd . $conf->{ng_etc_dir} . q(/) . APACHE_STUB_FN,
                             $conf->{apache_config_dir} . '/nagiosgraph.conf',
                             $doit);
        } elsif (defined $conf->{apache_config_file}) {
            $fail |= appendtofile($conf->{apache_config_file},
                                  STAG . "\n" .
                       "include $conf->{ng_etc_dir}/" . APACHE_STUB_FN . "\n" .
                                  ETAG . "\n",
                                  $doit);
        }
    }

    return $fail;
}

sub isyes {
    my ($s) = @_;
    return defined $s && $s =~ /^[Yy]$/ ? 1 : 0;
}

sub trimslashes {
    my ($path) = @_;
    while(length($path) > 1 && $path =~ /\/$/) { $path =~ s/\/$//; }
    return $path;
}

sub canread {
    my ($fn, $user, $group) = @_;
    my @s = stat $fn;
    my $mode = $s[2];
    my $uname = getpwuid $s[4];
    my $gname = getgrgid $s[5];
    if (($mode & S_IRUSR && $uname eq $user) ||
        ($mode & S_IRGRP && $gname eq $group) ||
        ($mode & S_IROTH)) {
        return 1;
    }
    return 0;
}

sub canwrite {
    my ($fn, $user, $group) = @_;
    my @s = stat $fn;
    my $mode = $s[2];
    my $uname = getpwuid $s[4];
    my $gname = getgrgid $s[5];
    if (($mode & S_IWUSR && $uname eq $user) ||
        ($mode & S_IWGRP && $gname eq $group)) {
        return 1;
    }
    return 0;
}

sub ng_mkdir {
    my ($a, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 0;
    logmsg("mkdir $a");
    if ($doit) {
        my $err;
        mkpath($a, {error => \$err});
        if ($err && @{$err}) {
            logmsg("*** cannot create directory $a: $OS_ERROR");
            $rc = 1;
        }
    }
    return $rc;
}

# return 0 on success, 1 on failure.  this is the opposite of what copy does.
# if the backup flag is true and a file already exists at the destination, then
# move it aside with a timestamp before doing the copy.
sub ng_copy {
    my ($a, $b, $doit, $moveaside) = @_;
    $doit = 1 if !defined $doit;
    $moveaside = 0 if !defined $moveaside;
    my $rc = 1;
    if ( $moveaside && -f $b ) {
        my $ts = strftime '%Y%m%d%H%M%S', localtime time;
        $rc = ng_move($b, "$b.$ts", $doit) ? 0 : 1;
    }
    if ($rc) {
        logmsg("copy $a to $b");
        $rc = copy($a, $b) if $doit;
    }
    if ($rc == 0) {
        logmsg("*** cannot copy $a to $b: $OS_ERROR");
    }
    return ! $rc;
}

# return 0 on success, 1 on failure.  this is the opposite of what move does.
sub ng_move {
    my ($a, $b, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    logmsg("move $a to $b");
    $rc = move($a, $b) if $doit;
    if ($rc == 0) {
        logmsg("*** cannot rename $a to $b: $OS_ERROR");
    }
    return ! $rc;
}

# return 0 on success, 1 on failure.
sub ng_chmod {
    my ($perms, $a, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    logmsg(sprintf 'chmod %o on %s', $perms, $a);
    $rc = chmod $perms, $a if $doit;
    if ($rc == 0) {
        logmsg("*** cannot chmod on $a: $OS_ERROR");
    }
    return $rc == 0 ? 1 : 0;
}

sub ng_chown {
    my ($uname, $gname, $a, $doit) = @_;
    $doit = 1 if !defined $doit;
    my $rc = 1;
    my $uid = $uname eq q(-) ? -1 : getpwnam $uname;
    my $gid = $gname eq q(-) ? -1 : getgrnam $gname;
    logmsg("chown $uname,$gname on $a");
    if (! $dochown) {
        logmsg('*** chown explicitly disabled');
        return 0;
    }
    if (! defined $uid || ! defined $gid) {
        if (! defined $uid) {
            logmsg("*** user '$uname' does not exist");
        }
        if (! defined $gid) {
            logmsg("*** group '$gname' does not exist");
        }
        return 1;
    }
    $rc = chown $uid, $gid, $a if $doit;
    if ($rc == 0) {
        logmsg("*** cannot chown on $a: $OS_ERROR");
    }
    return $rc == 0 ? 1 : 0;
}

sub ng_touch {
    my ($fn, $doit) = @_;
    $doit = 1 if !defined $doit;
    logmsg("touching $fn");
    return 0 if !$doit;

    my $fail = 0;
    if (open my $FILE, '>>', $fn) {
        if (! close $FILE) {
            logmsg("*** cannot close $fn: $OS_ERROR");
            $fail = 1;
        }
    } else {
        logmsg("*** cannot create $fn: $OS_ERROR");
        $fail = 1;
    }
    return $fail;
}



__END__

=head1 NAME

install.pl - install nagiosgraph

=head1 DESCRIPTION

This will copy nagiosgraph files to the appropriate directories and create a
default configuration.  It will optionally modify apache or nagios.

When run interactively, this script will prompt for the information it needs.

When environment variables are configured with installation information, this
script will run with no intervention required.

A log of the installation process is saved to a file called install-log.

=head1 USAGE

B<install.pl> [--version]
   (--check-prereq |
    --check-installation |
    --install [--dry-run]
              [--verbose | --silent]
              [--layout (overlay | standalone | debian | redhat | suse | custom)]
              [--prefix path]
              [--etc-dir path]
              [--var-dir path]
              [--log-dir path]
              [--doc-dir path]
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

B<--layout> layout  Which layout to use.  Can be I<standalone>, I<overlay>,
                 I<debian>, I<redhat>, I<suse>, or I<custom>.

B<--prefix> path    Base directory in which files should be installed.

B<--etc-dir> path   Directory for configuration files.

B<--var-dir> path   Directory for RRD files.

B<--log-dir> path   Directory for log files.

B<--etc-dir> path   Directory for configuration files.

B<--nagios-cgi-url> url    URL to Nagios CGI scripts.

B<--nagios-perfdata-file> path  Path to Nagios perfdata file.

B<--nagios-user> userid    Name or uid of Nagios user.

B<--www-user> userid       Name or uid of web server user.

Automate this script for use in rpmbuild or other automated tools by setting
these environment variables:

  NG_LAYOUT               - standalone, overlay, debian, redhat, suse, or custom
  NG_PREFIX               - the root directory for the installation
  NG_NAGIOS_CGI_URL       - URL to Nagios CGI scripts
  NG_NAGIOS_PERFDATA_FILE - path to Nagios perfdata file
  NG_NAGIOS_USER          - Nagios user
  NG_WWW_USER             - web server user

Use one or more of these environment variables to specialize an automated
install:

  NG_VAR_DIR      - directory for RRD files
  NG_LOG_DIR      - directory for log files
  NG_ETC_DIR      - directory for nagiosgraph configuration files
  NG_BIN_DIR      - directory for nagiosgraph executables
  NG_CGI_DIR      - directory for nagiosgraph CGI scripts
  NG_DOC_DIR      - directory for nagiosgraph documentation
  NG_EXAMPLES_DIR - directory for nagiosgraph examples
  NG_WWW_DIR      - directory for nagiosgraph CSS and JavaScript
  NG_LOG_FILE     - nagiosgraph log file
  NG_CGILOG_FILE  - nagiosgraph CGI log file
  NG_RRD_DIR      - directory for nagiosgraph RRD files
  NG_CGI_URL      - URL to nagiosgraph CGI scripts
  NG_CSS_URL      - URL to nagiosgraph CSS
  NG_JS_URL       - URL to nagiosgraph Javascript

=head1 REQUIRED ARGUMENTS

The following options must be specified:

  layout
  prefix

=head1 CONFIGURATION

Nagiosgraph requires the following pre-requisites:

  nagios
  nagios-plugins
  rrdtool
  CGI perl module
  RRAs perl module
  GD perl module (optional)

There are two standard layouts: overlay and standalone.  The overlay puts
nagiosgraph files into a Nagios installation.  The standalone puts nagiosgraph
files into a separate directory tree.

Nagiosgraph uses the following information for installation:

  ng_layout            - standalone, overlay, ubuntu, redhat, suse, or custom
  ng_prefix            - directory for nagiosgraph files
  ng_etc_dir           - directory for configuration files
  ng_bin_dir           - directory for executables
  ng_cgi_dir           - directory for CGI scripts
  ng_doc_dir           - directory for documentation
  ng_examples_dir      - directory for examples
  ng_www_dir           - directory for CSS and JavaScript
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
  nagios_config_file   - path to nagios config file
  nagios_commands_file - path to nagios commands files

  configure apache?    - whether to configure Apache
  apache_config_dir    - path to apache conf.d directory
  apache_config_file   - path to apache config file

In some cases these can be inferred from the configuration.  In other cases
they must be specified explicitly.

The minimal set of parameters which must be specified are:

  ng_layout
  ng_prefix
  nagios_cgi_url
  nagios_perfdata_file
  nagios_user
  www_user

The default values are:

  ng_layout              standalone
  ng_prefix              /usr/local/nagiosgraph
  nagios_cgi_url         /nagios/cgi-bin
  nagios_perfdata_file   /var/nagios/perfdata.log
  nagios_user            nagios
  www_user               www-data

The default values for an overlay installation to /opt/nagios are:

  ng_prefix   /opt/nagios
  ng_etc_dir  /opt/nagios/etc/nagiosgraph
  ng_bin_dir  /opt/nagios/libexec
  ng_cgi_dir  /opt/nagios/sbin
  ng_doc_dir  /opt/nagios/share/docs
  ng_www_dir  /opt/nagios/share

The default values for a standalone installation to /opt/nagiosgraph are:

  ng_prefix   /opt/nagiosgraph
  ng_etc_dir  /opt/nagiosgraph/etc
  ng_bin_dir  /opt/nagiosgraph/bin
  ng_cgi_dir  /opt/nagiosgraph/cgi
  ng_doc_dir  /opt/nagiosgraph/doc
  ng_www_dir  /opt/nagiosgraph/share

=head1 EXAMPLES

Install a standalone configuration in /usr/local:

  install.pl --prefix /usr/local/nagiosgraph

Install to /usr/local but keep var and etc files separate:

  install.pl --var-dir /var/nagiosgraph --etc-dir /etc/nagiosgraph

Install overlay configuration to /opt/nagios

  install.pl --layout overlay --prefix /opt/nagios

Install standalone configuration to /opt/nagiosgraph

  install.pl --layout standalone --prefix /opt/nagiosgraph

Install on a debian or ubuntu system with nagios3 installed from apt-get

  install.pl --layout debian

Install on a fedora or redhat system with nagios3 installed from RPM

  install.pl --layout redhat

Install on a fedora or suse system with nagios3 installed from RPM

  install.pl --layout suse

Install nagiosgraph without prompting onto an existing Nagios installation
at /usr/local/nagios:

  export NG_LAYOUT=overlay
  export NG_PREFIX=/usr/local/nagios
  export NG_VAR_DIR=/var/nagios
  export NG_URL=/nagios
  install.pl

Install nagiosgraph without prompting to its own directory tree
at /opt/nagiosgraph with nagios user 'naguser' and web user 'apache':

  export NG_LAYOUT=standalone
  export NG_PREFIX=/opt/nagiosgraph
  export NG_NAGIOS_USER=naguser
  export NG_WWW_USER=apache
  install.pl

This set is similar to the previous configuration, but this keeps the RRD
and log files in the system /var directory tree and configuration files in
the system /etc directory.

  export NG_LAYOUT=standalone
  export NG_PREFIX=/opt/nagiosgraph
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
