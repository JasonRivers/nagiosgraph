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
                         'cgi/export.cgi',
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
                         'Digest::MD5' => 0,
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
    'clean'         => { 'FILES' => 'cover_db perltidy.ERR test.* Debian_CPANTS.txt install-log pod2*.tmp' },
);

sub MY::install { "
install:
\t./install.pl
";
}

sub MY::postamble { "
docs:
\tpod2text README.pod --indent=2 --loose > README
\tpod2html README.pod > README.html
\tperl -pi -e 's/div name=\"index\"/div name=\"index\" class=\"index\"/' README.html
\tutils/mkpodidx.pl

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

DEBARCH=all
DEBREVISION=1
DEBVER=\$(VERSION)-\$(DEBREVISION)
DEBVERSION=\$(VERSION)-\$(DEBREVISION)_\$(DEBARCH)
deb-package:
\trm -rf nagiosgraph-\$(DEBVERSION)
\tmkdir -m 0755 nagiosgraph-\$(DEBVERSION)
\tDESTDIR=nagiosgraph-\$(DEBVERSION) NG_LAYOUT=debian fakeroot perl install.pl --no-check-prereq --no-chown
\tmkdir -m 0755 nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/compat nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/conffiles nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/copyright nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/docs nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/rules nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/postinst nagiosgraph-\$(DEBVERSION)/DEBIAN
\tcp debian/postrm nagiosgraph-\$(DEBVERSION)/DEBIAN
\tutils/cvtchangelog.pl > nagiosgraph-\$(DEBVERSION)/DEBIAN/changelog
\tsed -e 's/Version:.*/Version: \$(DEBVER)/' debian/control.in > nagiosgraph-\$(DEBVERSION)/DEBIAN/control
\tdpkg -b nagiosgraph-\$(DEBVERSION)
\trm -rf nagiosgraph-\$(DEBVERSION)
";
}
