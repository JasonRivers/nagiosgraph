use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'ABSTRACT'      => 'Nagios performance data storage and graphing',
    'AUTHOR'        => 'Alan Brenner <alan.brenner@ithaka.org>',
    'NAME'	    => 'nagiosgraph',
    'LICENSE'       => 'OSI Artistic License',
    'VERSION_FROM'  => 'etc/ngshared.pm',
    'EXE_FILES'     => [ 'lib/insert.pl',
                         'cgi/show.cgi',
                         'cgi/showhost.cgi',
                         'cgi/showservice.cgi',
                         'cgi/showgroup.cgi',
                         'cgi/showconfig.cgi',
                         'cgi/testcolor.cgi' ],
    'PREREQ_PM'     => { 'Carp' => 0,
                         'CGI' => 0,
                         'Data::Dumper' => 0,
                         'English' => 0,
                         'Exporter' => 0,
                         'Fcntl' => 0,
                         'File::Copy' => 0,
                         'File::Basename' => 0,
                         'File::Find' => 0,
                         'File::Path' => 0,
                         'MIME::Base64' => 0,
                         'POSIX' => 0,
                         'RRDs' => 0,
                         'Time::HiRes' => 0 },
    'dist'          => { 'SUFFIX'       => ".gz",
                         'DIST_DEFAULT' => 'all tardist',
                         'COMPRESS'     => "gzip -9f" },
    'realclean'     => { 'FILES' => 'cover_db Makefile.old' },
    'clean'         => { 'FILES' => 'perltidy.ERR test.* Debian_CPANTS.txt install-log install-cache' },
);

sub MY::install { "
install:
\t./install.pl
";
}

sub MY::postamble { "
critic:
\tperlcritic -1 install.pl etc/ngshared.pm cgi/show.cgi cgi/showhost.cgi cgi/showservice.cgi cgi/showgroup.cgi cgi/showconfig.cgi cgi/testcolor.cgi lib/insert.pl

test-coverage:
\tPERL5OPT=-MDevel::Cover make test
\tcover cover_db

code-summary:
\twc cgi/*.cgi etc/ngshared.pm lib/insert.pl
\twc share/nagiosgraph.css share/nagiosgraph.js share/nagiosgraph.ssi
\twc t/*.t
\twc etc/*.conf etc/map

build-rpm: dist
\trpmdev-setuptree
\tmv nagiosgraph-\$(VERSION).tar.gz ~/rpmbuild/SOURCES
\tcp nagiosgraph.spec ~/rpmbuild/SPECS
\tperl -pi -e 's%VERSION%\$(VERSION)%' ~/rpmbuild/SPECS/nagiosgraph.spec
\tcd ~/rpmbuild/SPECS; rpmbuild -ba --target noarch nagiosgraph.spec

NG_PERFDATA_FILE=/var/nagios/perfdata.log
NG_BIN_DIR=/usr/lib/nagiosgraph
NG_ETC_DIR=/etc/nagiosgraph
NG_RRD_DIR=/var/nagiosgraph/rrd
NG_WWW_DIR=/usr/share/nagiosgraph/htdocs
NG_EXAMPLE_DIR=/usr/share/nagiosgraph/examples
NG_UTIL_DIR=/usr/share/nagiosgraph/util
NG_CGI_DIR=/usr/lib/cgi-bin/nagiosgraph
NG_CGI_URL=/nagios/cgi-bin
NG_VAR_DIR=/var/nagiosgraph

build-deb:
\trm -rf nagiosgraph-\$(VERSION)
\tmkdir nagiosgraph-\$(VERSION)
\tmkdir -p nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)
\tcp etc/*.conf nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)
\tcp etc/ngshared.pm nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)
\tcp etc/map nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)
\tcp examples/nagiosgraph-nagios.cfg nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)
\tcp examples/nagiosgraph-apache.conf nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)
\tmkdir -p nagiosgraph-\$(VERSION)\$(NG_BIN_DIR)
\tcp lib/insert.pl nagiosgraph-\$(VERSION)\$(NG_BIN_DIR)
\tmkdir -p nagiosgraph-\$(VERSION)\$(NG_CGI_DIR)
\tcp cgi/*.cgi nagiosgraph-\$(VERSION)\$(NG_CGI_DIR)
\tmkdir -p nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/map_1_3 nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/map_1_4_3 nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/map_1_4_4 nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/map_examples nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/map_minimal nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/map_mwall nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/nagiosgraph.1.css nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tcp examples/nagiosgraph.2.css nagiosgraph-\$(VERSION)\$(NG_EXAMPLE_DIR)
\tmkdir -p nagiosgraph-\$(VERSION)\$(NG_WWW_DIR)
\tcp share/action.gif nagiosgraph-\$(VERSION)\$(NG_WWW_DIR)
\tcp share/nagiosgraph.css nagiosgraph-\$(VERSION)\$(NG_WWW_DIR)
\tcp share/nagiosgraph.js nagiosgraph-\$(VERSION)\$(NG_WWW_DIR)
\tcp share/nagiosgraph.ssi nagiosgraph-\$(VERSION)\$(NG_WWW_DIR)
\tmkdir -p nagiosgraph-\$(VERSION)\$(NG_UTIL_DIR)
\tcp utils/testentry.pl nagiosgraph-\$(VERSION)\$(NG_UTIL_DIR)
\tcp utils/upgrade.pl nagiosgraph-\$(VERSION)\$(NG_UTIL_DIR)
\tmkdir -p nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/compat nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/control nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/copyright nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/docs nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/rules nagiosgraph-\$(VERSION)/DEBIAN
\tutils/cvtchangelog.pl > nagiosgraph-\$(VERSION)/DEBIAN/changelog
\tperl -pi -e 's/Version:.*/Version: \$(VERSION)/' nagiosgraph-\$(VERSION)/DEBIAN/control
\tperl -pi -e 's%^use lib .*%use lib \"\$(NG_ETC_DIR)\";%' nagiosgraph-\$(VERSION)\$(NG_CGI_DIR)/*.cgi nagiosgraph-\$(VERSION)\$(NG_BIN_DIR)/insert.pl
\tperl -pi -e 's%^perflog.*%perflog=\$(NG_PERFDATA_FILE)%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^rrddir.*%rrddir=\$(NG_RRD_DIR)%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^mapfile.*%mapfile=\$(NG_ETC_DIR)/map%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^nagiosgraphcgiurl.*%nagiosgraphcgiurl=\$(NG_CGI_URL)%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^javascript.*%javascript=/nagiosgraph/nagiosgraph.js%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^stylesheet.*%stylesheet=/nagiosgraph/nagiosgraph.css%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^logfile.*%logfile=\$(NG_VAR_DIR)/nagiosgraph.log%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^cgilogfile.*%cgilogfile=\$(NG_VAR_DIR)/nagiosgraph-cgi.log%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^groupdb.*%groupdb=\$(NG_ETC_DIR)/groupdb.conf%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph.conf
\tperl -pi -e 's%^ScriptAlias.*%ScriptAlias /nagiosgraph/cgi-bin \$(NG_CGI_DIR)%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph-apache.conf
\tperl -pi -e 's%^<Directory \"/usr/local/nagiosgraph/cgi-bin\">%<Diretory \"\$(NG_CGI_DIR)\">%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph-apache.conf
\tperl -pi -e 's%^Alias.*%Alias /nagiosgraph \$(NG_WWW_DIR)%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph-apache.conf
\tperl -pi -e 's%^<Directory \"/usr/local/nagiosgraph/share\">%<Diretory \"\$(NG_WWW_DIR)\">%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph-apache.conf
\tperl -pi -e 's%^service_perfdata_file=.*%service_perfdata_file=\$(NG_PERFDATA_FILE)%' nagiosgraph-\$(VERSION)\$(NG_ETC_DIR)/nagiosgraph-nagios.cfg
\tdpkg -b nagiosgraph-\$(VERSION)
\trm -rf nagiosgraph-\$(VERSION)
";
}
