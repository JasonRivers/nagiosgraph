use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'ABSTRACT'      => 'Nagios performance data storage and graphing',
    'AUTHOR'        => 'Alan Brenner <alan.brenner@ithaka.org>',
    'NAME'	        => 'nagiosgraph',
    'VERSION_FROM'  => 'etc/ngshared.pm',
    'EXE_FILES'     => [ 'lib/insert.pl', 'cgi/show.cgi', 'cgi/showhost.cgi',
		'cgi/showservice.cgi', 'cgi/testcolor.cgi'],
    'PREREQ_PM'     => { 'RRDs' => 0 },
    'dist'          => { 'SUFFIX'       => ".gz",
                         'DIST_DEFAULT' => 'all tardist',
                         'COMPRESS'     => "gzip -9f" },
    'realclean'     => { 'FILES' => '' },
    'clean'         => { 'FILES' => 'test.*' },
);
