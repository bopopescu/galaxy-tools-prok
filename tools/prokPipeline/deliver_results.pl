#!/usr/local/bin/perl
use warnings;
use strict;

use Getopt::Long qw( :config no_ignore_case no_auto_abbrev );
use File::Path qw( remove_tree );
use Config::IniFiles;

my %opts;
GetOptions( \%opts,	
    'run_log=s',
    'project_root=s',
    'delivery_location=s',
    'delete',
) || die "Can't get options.\n";

if ($opts{run_log}) {
    open my $run_log, '<', $opts{run_log} or die "Can't open run log at $opts{run_log}. $?\n";
    my $config_file;
    while (my $line = <$run_log>) {
        if ($line =~ /^config_file\s*=\s*(\S+)$/) {
            $config_file = $1;
            last;
        }
    }
    close $run_log;
    die "Couldn't find config file in run log\n" unless ($config_file && -f $config_file);
    my $cfg = Config::IniFiles->new( -file=> $config_file );
    my $annotation_area = $cfg->val('Globals','ANNOTATION_AREA');
    my $project_name = $cfg->val('Globals','PROJECT_NAME');
    if ($annotation_area && $project_name) {
        $opts{project_root} = "$annotation_area/$project_name";
    }
    else {
        die "Could not parse ANNOTATION_AREA and PROJECT_NAME from config file at $config_file.\n";
    }
}



die "Need a --project_root\n" unless ( defined $opts{project_root} );
die "Need a --delivery_location\n" unless ( defined $opts{delivery_location} );

die "Project root $opts{project_root} is not a directory\n" unless ( -d $opts{project_root} );


my $tarball;
if ( -d $opts{delivery_location} and -w $opts{delivery_location} ) {
    # get the project name from the project root path.  Assume it's like: /blah/blah/project_name
    ( my $project_name = $opts{project_root} ) =~ s/.*\/([^\/]+)$/$1/;
    $tarball = "$opts{delivery_location}/$project_name.tgz";
}
elsif ( -f $opts{delivery_location} and -w $opts{delivery_location} ) {
    $tarball = $opts{delivery_location};
}
else {
    die "Could not write tarball to $opts{delivery_location}\n";
}

my $genbank_dir = "GenBank";
die "Could not find GenBank directory in $opts{project_root}\n" unless (-d "$opts{project_root}/$genbank_dir");

# ok. everything looks ok.  tar.  ballin'.
my $cmd = "tar -C $opts{project_root} -zcf $tarball GenBank";

# warn "Running: $cmd\n";
system( $cmd ) and die "Error creating tarball at $tarball. $?\n";
print "Tarball successfully created\n";

if ( $opts{delete} ) {

	if ( -s $tarball ) {

		print "deleting $opts{project_root}.";
		remove_tree( $opts{project_root}, { verbose => 1 } );

	}

}

exit (0);
