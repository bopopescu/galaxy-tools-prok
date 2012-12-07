#!/usr/bin/env perl
use strict;
use warnings;
use autodie;
$|++;

=head1 NAME

bulk_pipeline_runner.pl - setup several pipelines to be submitted as grid jobs.

=head1 SYNOPSIS

    USAGE: bulk_pipeline_runner.pl  --bulk_config_file /path/to/bulk_config
                                 [  --pipeline_config_template /path/to/PCT  ]
                                 [  --input_fasta_dir /path/to/input_fasta_files ]
                                 [  --setup_only  ]
                                   

=head1 OPTIONS

=over

=item B<--bulk_config_file, -b>         :   Configuration file detailing the file 
                                            path, genome name, and other details of 
                                            each genome to run through the pipeline.

=item B<--pipeline_config_template, -p> :   Path to the pipeline.config template, 
                                            which will be updated per genome with 
                                            details from the bulk_config_file.
                                            May be specified within the bulk_config_file.

=item B<--setup_only, -s>               :   When given, this option prevents execution of
                                            the pipeline, but each project is still set
                                            up to be run later.

=item B<--input_fasta_dir, -i>          :   This directory contains the location of the genome
                                            fasta files named in the --bulk_config_file.

=back

=head2 Galaxy-specific Options

=over

=item B<--output_list, -o>              :   When given, this parameter provides the
                                            name of a file that will contain the path
                                            of each config file generated.  If jobs
                                            have been submitted, the sge job id is 
                                            listed before each file path.

=item B<--output_dir, -d>               :   When given, this paramter causes all 
                                            new pipeline config files to be created
                                            in this directory.


=back

=head1 DESCRIPTION

    Setup multiple invocations of the prok annotation pipelin, to be run on the
    SGE/Univa Grid.

    Inputs for the pipeline invocations are passed in through the declaration
    of a 'bulk_config_file', the contents of which describe certain parameters
    that will be used to fill out the 'pipeline_config_template'.

    When --setup_only is used, the project areas and files get created, but are
    not started.  The run_prok_pipeline.pl script can be used to invoke these
    instances of the pipeline.

    No tracking is attempted once the jobs are launched.  Users should be familiar
    with both the SGE/Univa Grid tools and the individual steps of the pipeline
    to track and monitor progress.

=head1 CONTACT

    Jason Inman
    jinman@jcvi.org

=cut

use Config::IniFiles;
use Getopt::Long;
use File::Basename;
use File::Copy;
use File::Path;
use Pod::Usage;

my %opts = ();
my $global_values;
my $setup_only;
my @output_list;

my @required_params = ( 'PROJECT_DIR',
                        'YOUR_FILE_NAME',
                        'ORGANISM',
                        'TAXON_ID',
                        'FILE_MONIKER',
                        'LOCUS_SYM',
                        'DATABASE',
                        'PROJECT_NAME',
                        'PROJECT_CODE'
                        );

GetOptions( \%opts, 'bulk_config_file|b=s',
                    'pipeline_config_template|p=s',
                    'setup_only|s',
					'input_fasta_dir|i=s',
                    'output_list|o=s',
                    'output_dir|d=s',
                    'galaxy_list_id|g=s',
                    'help|h',
        ) || die "Problem getting options!\n";

pod2usage( {-exitval => 0, -verbose => 2} ) if $opts{help};

my $bcf_ini = parse_opts( \%opts );

# Run each section, corresponding to a genome.
for my $genome ( $bcf_ini->Sections() ) {

    # Skip [Globals] section.
    next if $genome eq 'Globals';

    # 0. Check that this section is complete
    check_required_params( $bcf_ini, $genome, \@required_params );

    # 1. Make the project area
    my $proj_dir = make_project_area( $bcf_ini, $genome );

    # 2. Copy the genome file over
    create_and_populate_GenomeFasta( $proj_dir, $bcf_ini, $genome );

    # 3. Create a clone of the empty sgd in SQLite
    create_and_populate_SQLite( $proj_dir, $bcf_ini, $genome );

    # 4. Create a copy of the config file
    my $conf_file_path = create_config_file( $proj_dir, $bcf_ini, $genome );

    # 5. Send it off! (don't wait for it.  this is parallel!)
    my $job_id = execute_pipeline( $bcf_ini, $genome, $conf_file_path ) unless $setup_only;

    if ( $opts{output_list} ) {

        my $line = "$job_id\t" unless $setup_only;
        $line .= $conf_file_path;
        push( @output_list, $line );

    }


}

if ( $opts{output_list} ) {

    open( my $ofh, '>', $opts{output_list} );
    select $ofh;
    print map {"$_\n"} @output_list;

}

exit (0);


sub check_required_params {
# Given a Config::IniFiles object, a section header, and an array_ref of
# parameter names, check that each exists.  Die and report any that are not
# present in the config file.

    my ( $cfg, $section, $params ) = @_;
    my @missing; 
    
    foreach my $param ( @{$params} ) {
        
        push (@missing, $param) unless $cfg->exists( $section, $param );

    } 

    if (scalar @missing) {
        
        die ("$section is missing the following parameters: ", join( ',', @missing ) );

    }

}


sub make_project_area {
# Given a config file and section name (corresponding to the project name)
# will create the path:
# /project_root/project_name if it doesn't already exist.
# Note that project_name is uppercased.

    my ( $cfg, $project_name ) = @_;

    my $proj_dir = get_param( $cfg, $project_name, 'PROJECT_DIR' );

    # Note that MASK defaults to 0777, so any prohibitive permissions are the
    # fault of the user's umask.
    unless ( -e $proj_dir ) {

        mkpath( $proj_dir, { mode => 0777 } ) || die "Couldn't create project directory $proj_dir : $!\n";

		chmod 0777, $proj_dir || die "Can't change permissions on $proj_dir\n";

    }

    return $proj_dir;

}


sub create_and_populate_GenomeFasta {
# Given a project dir, bulk config ini object and genome name, create:
# /project_dir/GenomeFasta
# and move the file into that directory.
# There is no check that the fasta file is actually a fasta file.

    my ( $proj_dir, $cfg, $genome ) = @_;

	# Check for existance of genome fasta
    my $fasta_name = get_param( $cfg, $genome, 'YOUR_FILE_NAME' );
	my $fasta_file_path = $opts{input_fasta_dir} . "/$fasta_name";

	unless ( -e $fasta_file_path ) {

		die "Can't find genome fasta $fasta_file_path\n";

	}

    my $fasta_dir_path = "$proj_dir/GenomeFasta";

    unless ( -e $fasta_dir_path ) {

        mkpath( $fasta_dir_path, { mode => 0777 } )  or die "Can't create $fasta_dir_path: $!\n";

		chmod 0777, $fasta_dir_path || die "Can't change permissions on $fasta_dir_path\n";

    }

    unless ( -e "$fasta_dir_path/$fasta_name" ) {
    
        copy( $fasta_file_path, $fasta_dir_path ) || die "Can't copy fasta file $fasta_file_path into $fasta_dir_path: $!\n";
		chmod 0777, $fasta_file_path || die "Can't change permissions on $fasta_file_path\n";
	

    }

}


sub create_and_populate_SQLite {
# Given a project_dir, bulk config ini object, and genome name create:
# /project_dir/SQLite directory, and copies the empty
# /project_root/empty_sgd file as
# /project_dir/SQLite/db_name
# where db_name is lowercase project_name

    my ( $proj_dir, $cfg, $genome ) = @_;

    my $sqlite_dir = "$proj_dir/SQLite";

    my $empty_sgd = $global_values->{EMPTY_SGD};

	# Check for existence of empty_sgd
	unless ( -e $empty_sgd ) {

		die "Can't find empty_sgd $empty_sgd\n";

	}

    my $proj_name = get_param( $cfg, $genome, 'PROJECT_NAME' );

    my $new_sgd = "$sqlite_dir/" . lc( $proj_name );

    unless ( -e $sqlite_dir ) {

        mkpath( $sqlite_dir, { mode => 0777 } ) || die "Can't create $sqlite_dir: $!\n";

		chmod 0777, $sqlite_dir || die "Can't change permissions on $sqlite_dir\n";

    }

    copy ( $empty_sgd, $new_sgd ) || die "Can't copy $empty_sgd to $new_sgd: $!\n";

	chmod 0777, $new_sgd || die "Can't change permissions on $new_sgd\n";

}


sub create_config_file {
# Given a project_dir, bulk config ini object, and genome name,  will copy the template, assumed to be:
# /project_root/generic.config.ini
# to 
# /project_dir/project_name.config.ini
# Where project_name is lower-cased.

    my ( $proj_dir, $cfg, $genome ) = @_;

    my $generic_conf = $global_values->{PIPELINE_CONFIG_TEMPLATE};

    my $new_conf = "$proj_dir/" . lc( $genome ) . '.config.ini';

	# Check for existance of generic.conf
	unless ( -e $generic_conf ) {

		die "Can't find generic.conf.ini $generic_conf\n";

	}

    copy ( $generic_conf, $new_conf ) or die "Can't copy $generic_conf to $new_conf: $!\n";

    my $pcfg = Config::IniFiles->new( -file => $new_conf );

    # set 'YOUR_FILE_NAME'
    my $your_file_name   = get_param( $cfg, $genome, 'YOUR_FILE_NAME' );
    my $genome_file_path = $opts{input_fasta_dir} . "/$your_file_name";
    $cfg->newval( $genome, 'GENOME_FILE_PATH', $genome_file_path );

    for my $param ( $pcfg->Parameters( 'Globals' ) ) {

        if ( $cfg->exists( $genome, $param ) ) {

            $pcfg->setval( 'Globals', $param, get_param( $bcf_ini, $genome, $param ) );

        }

    }

    $pcfg->RewriteConfig;

    if ( defined $opts{output_dir} ) {
    # This whole block of nonsense is to get around Galaxy's irksome way of dealing
    # with an unknown number of output files and how to get them into the history.

        my @name_parts = ( 'primary', $opts{galaxy_list_id}, $genome, 'visible', 'input' );
        my $conf_name_galaxy = join( '_', @name_parts );
        my $output_dir_conf = $opts{output_dir} . "/" . $conf_name_galaxy;

		# ensure existance of new_conf:
		unless ( -e $new_conf ) {

			die "Can't find supposedly just-written config file $new_conf\n";

		}

        copy( $new_conf, $output_dir_conf ) or die "Can't copy $new_conf to $output_dir_conf: $!\n";

        $new_conf = $output_dir_conf;

    }
 
    return( $new_conf );

}


sub execute_pipeline {
# Given a pipeline config file, will call run_prok_pipeline
# via qsub to get it running on the grid.

    my ( $cfg, $genome, $conf ) = @_;

    my $project_code = get_param( $cfg, $genome, 'PROJECT_CODE' );
    my $project_dir  = get_param( $cfg, $genome, 'PROJECT_DIR'  );

    my $cmd = "/opt/sge/bin/lx24-amd64/qsub -V -terse -e $project_dir/$genome.run_prok_pipeline.$$.err";
    $cmd .= " -o $project_dir/$genome.run_prok_pipeline.$$.out";
#    $cmd .= " -P $project_code " if ( defined $project_code);

    $cmd .= $global_values->{PIPELINE_EXEC_BIN} . " -c $conf --trace 0";

    my $job_id = `$cmd`;

    print "$genome launched: $job_id\n";    

    return $job_id;
}


sub get_param {
# Given a config object, a section, and a parameter key, will replace any string found
# between $; demarcations with the value associated with that string when used as the key for
# the 'global_values' hash.

    my ( $cfg, $section, $param ) = @_;

    my $value = $cfg->val( $section, $param );
    return undef unless (defined $value);

    while ( $value =~ /(\$;([^\$;\s\/]+)\$;)/g ) {

        my ($token, $key_name) = ($1, $2);

        if ( exists $global_values->{$key_name} ) {

            # Have to turn off interpolation with \Q & \E for the first part here:
            $value =~ s/\Q$token\E/$global_values->{$key_name}/;

        } else {

            die "Global param $2 is not defined\n";

        }

    }

    return $value;

}


sub set_global_values {
# pull out the globals hash

    my ( $cfg ) = @_;

    if ( $cfg->SectionExists( 'Globals' ) ) {
    
        foreach my $k ( $cfg->Parameters( 'Globals' ) ) {

            $global_values->{$k} = get_param( $cfg, 'Globals', $k );

        }

    }

}


sub get_pipeline_config_template {
# given a bulk_config ini file, retrieve the path to the pipeline.config.ini file
# that will be used as the basis for all runs.

    my ( $cfg ) = @_; # bulk_config_file

    my $pct = ''; # pipeline_config_template

    if ( $cfg->SectionExists( 'Globals' ) ) {

        $pct = $cfg->val( 'Globals', 'PIPELINE_CONFIG_TEMPLATE' );

    } else {

        die "Need to have a 'Globals' section in the config.  See --help for more info.\n";

    }

    return $pct; 

}


sub parse_opts {
# Given an options hash, perform a sanity check.

    my ( $opts ) = @_;
    my $cfg;

    if ( $opts->{bulk_config_file} ) {

        die "bulk_config_file $opts->{bulk_config_file} is not readable.\n"
            unless ( -r $opts->{bulk_config_file} );

    } else {

        die "Need --bulk_config_file\n";

    }

    $cfg = Config::IniFiles->new( -file => $opts->{bulk_config_file} )
        or die "Could not create a Config::IniFiles from $opts->{bulk_config_file}\n";

    $opts->{pipeline_config_template} = $opts->{pipeline_config_template} ||
                                        get_pipeline_config_template( $cfg );

    if ( $opts->{pipeline_config_template} ) {

        die "pipeline_config_template $opts->{pipeline_config_template} is not readable.\n"
            unless ( -r $opts->{pipeline_config_template} );

    } else {

        die "Need --pipeline_config_template\n";

    }

    if ( $opts->{input_fasta_dir} ) {

		# take care of galaxies behavior regarding '@' in the path:
		if ( $opts->{input_fasta_dir} ) {

			$opts->{input_fasta_dir} =~ s/__at__/@/g;

		}

        die "input_fasta_dir $opts->{input_fasta_dir} is not readable.\n"
            unless ( -r $opts{input_fasta_dir} );

    } else {

        die "Need --input_fasta_dir\n";

    }

    set_global_values( $cfg );

    if ( $opts{output_dir} ) {

        die "Can't find $opts{output_dir}\n" unless ( -e $opts{output_dir} );
        die "Can't write to $opts{output_dir}\n" unless ( -w $opts{output_dir} );

        chop $opts{output_dir} if ( $opts{output_dir} =~ /\/$/ );

    }


    $setup_only = $opts->{setup_only} // 0;

    return( $cfg );

}
