use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'ABSTRACT'      => 'nagiosgraph is an add-on to Nagios. It collects performance data into RRD files and displays graphs in web pages.',
    'AUTHOR'        => 'Alan Brenner <alan.brenner@ithaka.org>',
    'NAME'	    => 'nagiosgraph',
    'VERSION_FROM'  => 'etc/ngshared.pm',
    'EXE_FILES'     => [ 'install.pl',
                         'lib/insert.pl',
                         'cgi/show.cgi',
                         'cgi/showconfig.cgi',
                         'cgi/showgroup.cgi',
                         'cgi/showgraph.cgi',
                         'cgi/showhost.cgi',
                         'cgi/showservice.cgi',
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
                         'File::Temp' => 0,
                         'IPC::Open3' => 0,
                         'MIME::Base64' => 0,
                         'POSIX' => 0,
                         'RRDs' => 0,
                         'Time::HiRes' => 0 },
    'dist'          => { 'SUFFIX'       => ".gz",
                         'DIST_DEFAULT' => 'all tardist',
                         'COMPRESS'     => "gzip -9f" },
    'realclean'     => { 'FILES' => 'Makefile.old nagiosgraph-*.tar.gz nagiosgraph-*.deb nagiosgraph-*.rpm' },
    'clean'         => { 'FILES' => 'cover_db perltidy.ERR test.* Debian_CPANTS.txt install-log' },
);

sub MY::install { "
install:
\t./install.pl
";
}

sub MY::postamble { "
critic:
\tperlcritic -1 install.pl etc/ngshared.pm lib/insert.pl cgi/*.cgi t/*.t

test-coverage:
\tPERL5OPT=-MDevel::Cover make test
\tcover cover_db

code-summary:
\twc cgi/*.cgi etc/ngshared.pm lib/insert.pl
\twc share/nagiosgraph.css share/nagiosgraph.js share/nagiosgraph.ssi
\twc t/*.t
\twc etc/*.conf etc/map

rpm-package: dist
\tmkdir -p /tmp/rpmbuild
\tmkdir -p /tmp/rpmbuild/BUILD
\tmkdir -p /tmp/rpmbuild/BUILDROOT
\tmkdir -p /tmp/rpmbuild/RPMS
\tmkdir -p /tmp/rpmbuild/SOURCES
\tmkdir -p /tmp/rpmbuild/SPECS
\tmkdir -p /tmp/rpmbuild/SRPMS
\tmv nagiosgraph-\$(VERSION).tar.gz /tmp/rpmbuild/SOURCES
\tcp nagiosgraph.spec /tmp/rpmbuild/SPECS
\tperl -pi -e 's%VERSION%\$(VERSION)%' /tmp/rpmbuild/SPECS/nagiosgraph.spec
\trpmbuild -ba --clean --define '_topdir /tmp/rpmbuild' --target noarch /tmp/rpmbuild/SPECS/nagiosgraph.spec
\tmv /tmp/rpmbuild/RPMS/noarch/nagiosgraph* .
\tmv /tmp/rpmbuild/SRPMS/nagiosgraph* .
\trm -rf /tmp/rpmbuild

deb-package:
\trm -rf nagiosgraph-\$(VERSION)
\tmkdir -m 0755 nagiosgraph-\$(VERSION)
\tDESTDIR=nagiosgraph-\$(VERSION) NG_LAYOUT=debian fakeroot perl install.pl --no-check-prereq --no-chown
\tmkdir -m 0755 nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/compat nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/conffiles nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/control nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/copyright nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/docs nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/rules nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/postinst nagiosgraph-\$(VERSION)/DEBIAN
\tcp debian/postrm nagiosgraph-\$(VERSION)/DEBIAN
\tutils/cvtchangelog.pl > nagiosgraph-\$(VERSION)/DEBIAN/changelog
\tperl -pi -e 's/Version:.*/Version: \$(VERSION)/' nagiosgraph-\$(VERSION)/DEBIAN/control
\tdpkg -b nagiosgraph-\$(VERSION)
\trm -rf nagiosgraph-\$(VERSION)
";
}
