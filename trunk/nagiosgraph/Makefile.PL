use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'ABSTRACT'      => 'Nagios performance data storage and graphing',
    'AUTHOR'        => 'Alan Brenner <alan.brenner@ithaka.org>',
    'NAME'	    => 'nagiosgraph',
    'VERSION_FROM'  => 'etc/ngshared.pm',
    'EXE_FILES'     => [ 'lib/insert.pl',
                         'cgi/show.cgi',
                         'cgi/showhost.cgi',
                         'cgi/showservice.cgi',
                         'cgi/showgroup.cgi',
                         'cgi/testcolor.cgi' ],
    'PREREQ_PM'     => { 'RRDs' => 0 },
    'dist'          => { 'SUFFIX'       => ".gz",
                         'DIST_DEFAULT' => 'all tardist',
                         'COMPRESS'     => "gzip -9f" },
    'realclean'     => { 'FILES' => 'cover_db Debian_CPANTS.txt Makefile.old' },
    'clean'         => { 'FILES' => 'perltidy.ERR test.*' },
);

sub MY::install {
	"install :: all pure_install doc_install\n\t./install.pl";
}

# check everything with perlcritic.
sub MY::postamble {
'
critic:
	perlcritic -1 etc/ngshared.pm cgi/show.cgi cgi/showhost.cgi cgi/showservice.cgi cgi/showgroup.cgi cgi/testcolor.cgi lib/insert.pl

test-coverage:
	PERL5OPT=-MDevel::Cover make test
	cover cover_db
';
}
