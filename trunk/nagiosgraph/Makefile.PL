use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'ABSTRACT'      => 'Nagiosgraph',
    'AUTHOR'        => 'Alan Brenner <alan.brenner@ithaka.org>',
#    'NAME'	        => 'nagiosgraph',
#    'VERSION_FROM'  => 'nagiosgraph',
#    'EXE_FILES'     => [ 'plw', ],
#    'PREREQ_PM'     => { 'XML::Twig'},
    'dist'          => { 'SUFFIX'       => ".gz",
                         'DIST_DEFAULT' => 'all tardist',
                         'COMPRESS'     => "gzip -9f" },
    'realclean'     => { 'FILES' => '' },
    'clean'         => { 'FILES' => 'test.*' },
);
