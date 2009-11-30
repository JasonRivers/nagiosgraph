#!/usr/bin/perl
# File:    $Id$
# Author:  (c) Alan Brenner, Ithaka, 2009
# License: OSI Artistic License
#          http://www.opensource.org/licenses/artistic-license.php

# The configuration file and ngshared.pm must be in this directory.
use lib '/etc/nagios/nagiosgraph';
# The configuration loader will look for nagiosgraph.conf in this directory.

use strict;
use warnings;
use ngshared;
use English qw(-no_match_vars);
use Fcntl qw(:DEFAULT :flock);

use vars qw($VERSION);
$VERSION = '0.2';

readconfig('write');

my $lock = $Config{userdb} . '.lock';
my %authz;

sysopen DBLOCK, $lock, O_RDONLY | O_CREAT
	or die "Cannot open lock file: $OS_ERROR\n";
flock DBLOCK, LOCK_EX or die "cannot lock $lock: $OS_ERROR\n";
tie %authz, $Config{dbfile}, $Config{userdb}, O_RDWR | O_CREAT ## no critic (ProhibitTies)
	or die "cannot tie database $Config{dbfile}: $OS_ERROR\n";

# Change this to suit your needs
$authz{'server1'} = {'user1' => 1, 'user2' => 1};
$authz{'server2'} = {'user1' => 1, 'user3' => 1};
# end change this

untie %authz;
close DBLOCK or die "cannot close $lock: $OS_ERROR\n";
unlink $lock;

__END__

=head1 NAME

authz.pl - set up the host/user authorization database

=head1 DESCRIPTION

An example of how to create the database that allows specific users to see
the graphs for given servers.

The setup is a simple hash by host name that points to a hash of user names
that are allowed to see that host.

=head1 INSTALLATION

Copy this file into a convinient directory (/usr/local/bin, for example) and
modify line 4 to point to the directory with ngshared.pm.

=head1 CONFIGURATION

=head1 USAGE

=head1 REQUIRED ARGUMENTS

=head1 OPTIONS

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Undoubtedly there are some in here. I (Alan Brenner) have endevored to keep this
simple and tested.

=head1 SEE ALSO

B<ngshared.pm>

=head1 AUTHOR

Alan Brenner - alan.brenner@ithaka.org, original author.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Andrew W. Mellon Foundation

This program is free software; you can redistribute it and/or modify it under
the terms of the OSI Artistic License see:
http://www.opensource.org/licenses/artistic-license-2.0.php

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
