#!/usr/local/bin/perl
use warnings;
use strict;

use Getopt::Long qw( :config no_ignore_case no_auto_abbrev );
use File::Path qw( remove_tree );

my %opts;
GetOptions( \%opts,	'project_root=s',
					'delivery_location=s',
				    'delete',
					) || die "Can't get options.\n";

die "Need a --project_root\n" unless ( defined $opts{project_root} );
die "Need a --delivery_location\n" unless ( defined $opts{delivery_location} );

die "Project root $opts{project_root} is not a directory\n" unless ( -d $opts{project_root} );
die "Delivery location $opts{delivery_location} is not a directory\n" unless ( -d $opts{delivery_location} );

die "Delievry location $opts{delivery_location} is not writable\n" unless ( -w $opts{delivery_location} );

# get the project name from the project root path.  Assume it's like: /blah/blah/project_name
( my $project_name = $opts{project_root} ) =~ s/.*\/([^\/]+)$/$1/;

# ok. everything looks ok.  tar.  ballin'.
my $tarball = "$opts{delivery_location}/$project_name.tgz";
my $cmd = "tar -zcvf $tarball $opts{project_root}";

print "Running: $cmd\n";
system( $cmd );

if ( $opts{delete} ) {

	if ( -s $tarball ) {

		print "deleting $opts{project_root}.";
		remove_tree( $opts{project_root}, { verbose => 1 } );

	}

}

exit (0);
