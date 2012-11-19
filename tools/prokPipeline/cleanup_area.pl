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

	B<--delete>         :   Delete the entire directory tree starting with and including --project_root
                            VERY DANGEROUS.  Unless, of course, you actually want to do this, in which
                            case it's actually VERY USEFUL.

=head1 DESCRIPTION

    This script will remove known files/areas created by the prok pipeline from the given directory.
    If run with --delete parameter, attempts to remove the entire --project_root

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

# delete the whole thing if that's really how we were called.
if ( $opts{delete} ) {

    print "Deleting $opts{project_root}...\n";

    my $err;

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
        print "No error encountered\n";
    } 

    print "Deleted $opts{project_root}.\n";

} else {

    remove_files_from_dir( $opts{project_root} );

}

exit(0);


sub remove_files_from_dir {



}

