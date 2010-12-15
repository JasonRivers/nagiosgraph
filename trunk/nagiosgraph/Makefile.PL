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
    'clean'         => { 'FILES' => 'perltidy.ERR test.* Debian_CPANTS.txt install-log' },
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
\tcd ~/rpmbuild/SPECS; rpmbuild --clean -ba --target noarch nagiosgraph.spec
\tmv ~/rpmbuild/RPMS/noarch/nagiosgraph* .
\tmv ~/rpmbuild/SRPMS/nagiosgraph* .

build-deb:
\trm -rf nagiosgraph-\$(VERSION)
\tmkdir nagiosgraph-\$(VERSION)
\tDESTDIR=nagiosgraph-\$(VERSION) NG_LAYOUT=debian fakeroot perl install.pl --no-check-prereq
\tmkdir -p nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/compat nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/control nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/copyright nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/docs nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/rules nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/postinst nagiosgraph-\$(VERSION)/DEBIAN
\tutils/cvtchangelog.pl > nagiosgraph-\$(VERSION)/DEBIAN/changelog
\tperl -pi -e 's/Version:.*/Version: \$(VERSION)/' nagiosgraph-\$(VERSION)/DEBIAN/control
\tdpkg -b nagiosgraph-\$(VERSION)
\trm -rf nagiosgraph-\$(VERSION)
";
}
