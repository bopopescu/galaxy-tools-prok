#!/usr/local/bin/perl
use strict;
use warnings;
$|++;

=head1 NAME

cleanup_area.pl - remove part or all of a given project

=head1 SYNOPSIS

    USAGE: cleanup_area.pl --project_root </path/to/repository/area> [ --delete ]

=head1 OPTIONS

    B<--project_root>   :   Path to the location to cleanup/remove

	B<--bulk_config> 	:   Path to a bulk_config file.  Used to 'reset' a project area

	B<--delete>         :   Delete the entire directory tree starting with and including --project_root
                            VERY DANGEROUS.  Unless, of course, you actually want to do this, in which
                            case it's actually VERY USEFUL.  Default is NOT to do this.

=head1 DESCRIPTION

    This script will remove known files/areas created by the prok pipeline from the given directory.
    If run with --delete parameter, attempts to remove the entire --project_root

	If run without --delete, will delete files from the project.

	If given a --bulk_config, will attempt to 'reset' the project root such that:
	  1.  The GenomeFasta is copied back over.
	  2.  The empty sgd sqlite database is copied back over.
	  3.  The project.config.ini file is left alone.
	  4.  Rows in the common database are removed.

=head1 AUTHOR

    Jason Inman
    jinman@jcvi.org

=cut

use File::Path qw( remove_tree );
use Getopt::Long qw( :config no_ignore_case no_auto_abbrev);
use Pod::Usage;

my %opts;
GetOptions( \%opts,
            'delete',
            'project_root=s',
            'help|h',
          ) || die "Unable to retrieve options: $!";

pod2usage( {-exitval => 0, -verbose => 2} ) if $opts{help};

my @pipeline_bits = qw( autoAnnotate auto_gene_curate BER_searches ber_search.log candidate.fa consistency_checks genecall gip glimmer HMM_searches load_genome locus_loader logs RNA_searches sge_grid_ber_search* small_genome_control tmp.file valet_pep );

# Check project_root
unless ( -e $opts{project_root} ) {

    die "$opts{project_root} is does not exist.\n";

}

unless ( -d $opts{project_root} ) {

        die "$opts{project_root} is not a directory.\n";

}

unless ( -w $opts{project_root} ) {

    die "$opts{project_root} is not modifiable by ", getlogin, "\n";

}

# setup for deletion
my @paths_to_delete;
if ( $opts{delete} ) {

	push( @paths_to_delete, $opts{project_root} );

} else {

	foreach my $path ( @pipeline_bits ) {

		push( @paths_to_delete, $opts{project_root} . '/' . $path );

	}

}

# delete.
delete_paths( \@paths_to_delete );

exit(0);


sub delete_paths {

	my ( $paths_to_delete ) = @_;

	for my $path ( @$paths_to_delete ) {

		my $err;
		print "Deleting $path\n";
		remove_tree( $opts{project_root}, { verbose => 1, error => \$err, } );

		if (@$err) {
			for my $diag (@$err) {
				my ($file, $message) = %$diag;
				if ($file eq '') {
					print "general error: $message\n";
				} else {
					warn "problem unlinking $file: $message\n";
				}
			} 
		} else {
			print "No error encountered deleting $path\n";
		} 

	}

}
