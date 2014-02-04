#!/usr/local/bin/perl

print map {"$_\n"} @ARGV;

use Config::IniFiles;
use Getopt::Long qw( :config no_ignore_case no_auto_abbrev);
use File::Path;
use lib "/usr/local/projects/prok/perl/function/lib";

my %opts;
my $results = GetOptions( \%opts,
                          'template_config=s',
                          'contact_ba=s',
                          'locus_sym=s',
                          'genome_fasta_file=s',
                          'organism=s',
                          'taxon_id=i',
                          'gcode=i',
                          'gram_stain=i',
                        );
# Take care of what we need to infer from passed-in options.
my $project_name = uc( $opts{locus_sym} );
my $database_name = lc( $opts{locus_sym} );
my $project_dir = "/usr/local/annotation/$project_name\n";
( my $f_moniker = $opts{organism} ) =~ s/\s+/_/g;

# 1. create the config.
my $contents= qq(
[Globals]
PIPELINE_EXEC_BIN=/usr/local/projects/prok/perl/run_prok_pipeline.pl
PIPELINE_CONFIG_TEMPLATE=/usr/local/annotation/generic.config.ini
EMPTY_SGD=/usr/local/annotation/empty.sgd
PROJECT_ROOT=/usr/local/annotation

[$database_name]
PROJECT_DIR=/usr/local/annotation/$project_name
YOUR_FILE_NAME=$opts{genome_fasta_file}
ORGANISM="$opts{organism}"
TAXON_ID=$opts{taxon_id}
GCODE=$opts{gcode}
GRAM=$opts{gram}
FILE_MONIKER=$f_moniker
LOCUS_SYM=$opts{locus_sym}
CONTACT_BA="$opts{contact_ba}"
DATABASE=$database_name
PROJECT_NAME=$project_name
PROJECT_CODE=08100
);

# 2. launch the job.

# 3. make tarball of pipeline.

exit(0);
