#!/usr/local/bin/perl
use strict;
use warnings;
# print join(" ",@ARGV);

use Getopt::Long qw( :config no_ignore_case no_auto_abbrev);
use File::Path;
use File::Temp;
use File::Spec::Functions qw/splitpath rel2abs/;

use lib "/usr/local/projects/prok/perl/function/lib";
my $EXEC_DIR;
BEGIN {
    my @d = splitpath($0);
    $EXEC_DIR=rel2abs($d[1]);
}

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
                          'output_path=s',
                          # 'output_list|o=s',
                          # 'galaxy_list_id|g=s',
                          # 'trace=i',
                        );
# Take care of what we need to infer from passed-in options.
my (undef,$input_dir,$input_filename) = splitpath($opts{genome_fasta_file});
my $project_name = uc( $opts{locus_sym} );
my $database_name = lc( $opts{locus_sym} );
my $project_dir = "/usr/local/annotation/$project_name\n";
( my $f_moniker = lc($opts{organism}) ) =~ s/\W+/_/g;


# 1. create the config.
my $contents= qq([Globals]
PIPELINE_EXEC_BIN=/usr/local/projects/prok/perl/run_prok_pipeline.pl
PIPELINE_CONFIG_TEMPLATE=/usr/local/annotation/generic.config.ini
EMPTY_SGD=/usr/local/annotation/empty.sgd
PROJECT_ROOT=/usr/local/annotation

[$database_name]
PROJECT_DIR=/usr/local/annotation/$project_name
YOUR_FILE_NAME=$input_filename
YOUR_FILE_PATH=$opts{genome_fasta_file}
ORGANISM="$opts{organism}"
TAXON_ID=$opts{taxon_id}
GCODE=$opts{gcode}
GRAM=$opts{gram_stain}
FILE_MONIKER=$f_moniker
LOCUS_SYM=$opts{locus_sym}
CONTACT_BA="$opts{contact_ba}"
DATABASE=$database_name
PROJECT_NAME=$project_name
PROJECT_CODE=08100
);

# my $fh= File::Temp->new(TEMPLATE=>'prok_pipeline_XXXXXXX',SUFFIX=>'.txt', DIR=>($ENV{TEMPDIR}?$ENV{TEMPDIR}:'/tmp/'), UNLINK=>0);
open my $fh, '>', $opts{output_path};
print $fh $contents;
close $fh;
# $fh->flush();
# print $fh->filename,"\n";


# 2. set up the work area
# open(my $config_path_fh, "-|", "$EXEC_DIR/prok_pipeline_setup.pl",
#     '--bulk_config'     => $fh->filename,
#     '--output_list'     => $opts{output_list},
#     '--galaxy_list_id'  => $opts{galaxy_list_id},
#     '--output_dir'      => $opts{output_dir},
#     '--input_fasta_dir' => $input_dir,
# );
# my @config_paths = <$config_path_fh>; # of which there should be only one
# close $config_path_fh;
# if ($?) { # die if setup didn't work
#     exit($?);
# }

# 2. launch the job.
# foreach my $cf_path (@config_paths) {
#     chomp $cf_path;
#     # TODO run run_prok_pipeline.pl
# }
# 3. make tarball of pipeline.

# remove temp config file

exit(0);
