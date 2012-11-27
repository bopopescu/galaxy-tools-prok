#!/usr/local/bin/perl
use strict;
use warnings;
$|++;

=head1 NAME

run_prok_pipeline.pl - Invoke the JCVI Prokaryotic Annotation Pipeline

=head1 SYNOPSIS

    USAGE: run_prok_pipeline.pl -c <config_file>
                [   --project_root </path/to/repository/area>   ]

=head1 OPTIONS

B<--config_file,-c> :   Pipeline config file.  This file describes the input for each sub-section of the pipeline. It is the only I<required> parameter to this script.

B<--project_root>   :   Usually present in the config file, this option allows an override.

=head1 DESCRIPTION

Upon invocation, this script reads in a given configuration file and begins to process each step of the pipeline according
to the instructions contained within.

=head2 CONFIGURATION

The config file is in .ini-style format, where section names are supplied within square brackets, and key value pairs seperated by equals signs make up the parameters in that section.  For example:

 [section_name]
 key1=value1
 key2=9999

=head2 REQUIRED SECTIONS

There are two required sections for this script to run normally given a config file: [Globals] and [run_prok_pipeline].

=head3 [Globals]

Within globals, convention is to name these parameters in ALL_CAPS.  For example:

 [Globals]
 DATABASE_NAME=mydbname
 DB_USER=dbuserid
 DB_PASS=badpassword

These parameters can then be used within other sections by enclosing them within $; delimiters:

 [other_section]
 exec_path=/path/to/program
 --user=$;DB_USER$;
 --pass=$;DB_PASS$;
 --db_path=/path/directory/$;DATABASE_NAME$;.db_extention

=head3 [run_prok_pipeline]

Named for this script, this section contains parameters that act as defaults for this script.
They can be over-ridden by supplying them as options to this script via command line.

See B<OPTIONS> above for more information about a specific option.

=head2 OPTIONAL SECTIONS

The remaining sections in the config file describe components of the pipeline controlled by this script.  Parameters (with the exception of five 'special' parameters described later) are included as key-value pairs.  For example, given the following section:

 [simple_command]
 exec_path=/usr/bin/command
 -a=42
 -o=/some/path

the command that would be executed would be built as:

 /usr/bin/command -a 42 -o /some/path

Each key is reproduced exactly as represented in the config file, followed by a space character and the exact contents of the value.  The next paramter name is seperated from the previous parameter value by a single space.

Note that currently, a limitation of this script is that specific delimiters that link a keyed parameter to its value cannot be specified.  This limitation can be overcome with creative use of the special paramters.

=head2 OVERRIDING CONFIG

If the occasion happens where it is desired to run a configuration file but with a small number of tweaks, it might be useful to employ a config override on the command line.  This is accomplished by running this script with a ' -- ' separator on the command line following any other options in the USAGE section (above).  After the ' -- ' has been used, additional parameters can be specified as: <section>:<key>=<value>

For example, given a config file with the [simple_command] section (from OPTIONAL SECTIONS, above), the pipeline script can be invoked as:

 ./run_prok_pipeline.pl -c /path/to/config -- simple_command:-a=47

which would change the command that gets executed to:

 /usr/bin/command -a 47 -o /some/path

Global variables can also be overridden in this way:

 ./run_prok_pipeline.pl -c /path/to/config -- Globals:DATABASE_NAME=myotherdbname

Keep in mind, however, that if you want to override a Global variable with a value that interpolates another global variable, the following conditions must be met:

 1. The variable to be interpolated must be listed prior to the variable being tweaked from the command line

 2. The $; sigils must be properly shell-escaped for the shell running this script.

For example, given the [Globals] section above, if we wanted to invoke the pipeline with a DB_PASS that was identical to the username in the config file we could invoke it like this (in tcsh):

./run_prok_pipeline.pl -c /path/to/config -- 'Globals:DB_PASS=$;DB_USER$;'

=head2 SPECIAL PARAMETERS

=head3 exec_path

The I<required> paramter exec_path must be supplied for each section.  Exec path can be as simple or complicated as needed.  For example, on most Linux/Unix machines the following will work from pretty much anywhere:

 [run_ls]
 exec_path=ls

Scripts that are not in the path, or need libraries to be specified from the command line can do something like:

 [script_abc]
 exec_path=perl -I $;SCRIPTS_AREA$; $;SCRIPTS_AREA/script_abc.pl

In short, exec_path becomes the 'front' of the command line.

=head3 args

The I<optional> args parameter is used for non-keyed arguments that must be present in a given command-line.  For example:

 [command]
 exec_path=command
 args=first second third
 -key1=val1
 -key2=val2

results in the following command-line to be executed:

 command first second third -key1 val1 -key2 val2

In short, args is appended to the command line directly behind the exec_path.

=head3 flags

The I<optional> flags parameter is similar to the args parameter. The difference is that instead of being appended before the remaining parameters, it is appended after them.  For example:

 [command]
 exec_path=command
 flags=first second third
 -key1=val1
 -key2=val2

results in the following command-line to be executed:

 command -key1 val1 -key2 val2 first second third

=head3 runbit

The I<optional> runbit parameter can be used to declare that a given section is not to be executed.  If runbit is not present, or if runbit is set to 1, a given section will be executed.  If runbit is set to 0, that section will B<not> be executed.  For example:

 [don't run me]
 runbit=0
 exec_path=/path/to/command

will not run.

=head3 exit_status

Most perl scripts in the pipeline are expected to return exit status of 0 upon normal completion.  When a script is used that normally reports a non-zero value, the exit_status parameter must be added to the to that script's section in the config file:

 [non-standard script]
 exec_path=/path/to/command
 exit_status=1

By default, the expected exit_status is set to 0.  It is unnecessary but allowable to explicitely set exit_status=0 in a section.

=head3 run_order

run_order is a strange beast, and not yet implemented.  When present for one section, it must be present for all, with the exception of the two required sections [Globals] and [run_prok_pipeline].  run_order specifies the order in which a given section falls within the pipeline.  Without run_order, the order of invcation is top-down through the config file.  When two or more sections share the same value for run_order, they are launched in parallel, and the next section will only be invoked when all of the concurrently running sections have completed succesfully.

=head1 AUTHOR

    Jason Inman
    jinman@jcvi.org

=cut

# These are necessary for running through galaxy on the grid.  For some reason, galaxy isn't
# honoring its own environmental pass-through mechanism.
$ENV{ANNOTATION_DIR} = '/usr/local/annotation';
$ENV{ANNOTATION_DEVEL} = '/usr/local/devel/ANNOTATION';
$ENV{COILSDIR} = '/usr/local/bin/coils';
$ENV{BLASTBIN} = '/usr/local/bin/ncbi-blast-2.2.26+/bin';
$ENV{HMM_SCRIPTS} = '/usr/local/common';
$ENV{PERL5LIB} = '/usr/local/share/perl5';

#print map {"$_\t$ENV{$_}\n"} keys %ENV; exit;

use Config::IniFiles;
use Getopt::Long qw( :config no_ignore_case no_auto_abbrev);
use File::Path;
use FindBin qw($Bin);
use Pod::Usage;
use lib "$Bin/function/lib";
use traceUtils qw( $TRACE trace track trackBegin trackEnd );

my %opts;
my $Cfg;
my $global_values;
my $results = GetOptions( \%opts,
                          'config_file|c=s',
                          'project_root=s',
                          'help|h',
                          'trace=i',
                        );
$TRACE = $opts{trace} // 6;

die "Unable to retrieve options: $!" unless $results;

pod2usage( {-exitval => 0, -verbose => 2} ) if $opts{help};

$Cfg = parse_options( \%opts );

my $Project_root = setup_pipeline( $Cfg );

# my $sgd_path = setup_sqlite3_sgd( $Cfg, $Project_root );

my @sections = $Cfg->Sections;
print "sections=@sections\n" if $TRACE;

my @ignorable_sections = ( 'run_prok_pipeline', 'Globals' );
print "ignorable sections=@ignorable_sections\n" if $TRACE;

# TODO: Implement use of 'run_sequence' parameter to run as a series of parallel steps.
foreach my $section ( @sections ) {

    next if $section ~~ @ignorable_sections;
    run_section( $Cfg, $section );

}


print "Done.\n";
exit(0);


sub run_section {
# Given a config object and a section name, pull out the parameters and script 
# name and launch the script with the given parameters.

    my ( $cfg, $section ) = @_;
    &trackBegin("run_section($section)");
    my $result;

    my @params = $cfg->Parameters( $section );
    die "No parameters found for $section!\n" unless @params;
    &track("parameters($section)=@params");

    # MUST have at least an execution path value in the config_section.
    check_required_params( $cfg, $section, ['exec_path'] );

    # check for non-default exit status.
    my $exit_status = $cfg->val( $section, 'exit_status' ) || 0;

    # Check for 'runbit masking'
    my $runbit = $cfg->val( $section, 'runbit' );
    if ( defined $runbit && $runbit == 0 ) {

        warn "Skipping execution of $section: runbit set to 0\n";
        #return undef;

    } else {

        my $cmd = build_command_string( $cfg, $section, \@params );   
        print "\nRunning $section:\n$cmd\n";
        system($cmd);

        my $result = $? >> 8;
        die "Child process $section returned unexpected exit status: $result\n" unless ( $result == $exit_status );

    }

    &trackEnd('run_section', "run_section($section)");
    return($result);
}


sub build_command_string {
# Given a config object, a section name, and an array ref of parameter names,
# retrieve the script_name parameter and build the string of parameters that 
# should be present in this invocation.  Return the entire command as a string.

    my ( $cfg, $section, $params ) = @_;
    my $command = '';

    $command = get_param( $cfg, $section, 'exec_path' );

    # Handle unkeyed arguments:
    my $args = get_param( $cfg, $section, 'args' );
    $command .= " $args" if $args;

    # Handle keyed arguments with values.
    my @ignorable_params = ( 'exec_path', 'runbit', 'args', 'flags', 'exit_status' );
    foreach my $param ( @{$params} ) {

        next if $param ~~ @ignorable_params;
        my $val = get_param( $cfg, $section, $param );
        die "$param has no associated value!  Perhaps this should go in the ".
            "special 'flags' parameter.  See helpinfo.\n" unless (defined $val);
        $command .= " $param $val";

    }

    # Handle keyed arguments without values (flags).
    my $flags = get_param( $cfg, $section, 'flags' );
    $command .= " $flags" if $flags;

    # Capture logs like the VICS services... might change:
	$command .= " > $global_values->{REPOSITORY_AREA}/logs/$section"."Task.$$.log";
	$command .= " 2> $global_values->{REPOSITORY_AREA}/logs/$section"."Task.$$.ERR.log";

    return $command;

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


sub setup_sqlite3_sgd {
# Given a cfg object, retrieve the db name and initialize an empty copy of the
# sgd in sqlite3.

    my ($cfg, $project_root) = @_;

    # retrieve values from config for this operation:
    my $dbname              = $cfg->val( 'run_prok_pipeline', 'database');
    my $sgd_sqlite3_schema  = $cfg->val( 'run_prok_pipeline', 'sgd_sqlite3_schema' );
    my $sqlite_exec         = $cfg->val( 'run_prok_pipeline', 'sqlite3' );

    my $db_path = "$project_root/SQLite/$dbname";

    # Setup the sqlite3 database building command:
    if ( ! -s $db_path ) {

        my $sqlite_cmd = $sqlite_exec;
        my $sqlite_params = "$db_path < $sgd_sqlite3_schema";
        system( "$sqlite_cmd $sqlite_params" );

    } else {

        print "Skipping generation of sqlite3 sgd, already exists at: $db_path\n";

    }

    return "$db_path";

}


sub check_required_params {
# Given a Config::IniFiles object, a section header, and an array_ref of
# parameter names, check that each exists.  Die and report any that are not
# present in the config file.

    my ($cfg, $section, $params) = @_;
    my @missing;

    foreach my $param ( @{$params} ) {

        push (@missing, $param) unless $cfg->exists( $section, $param );

    }

    if (scalar @missing) {

        die ("$section is missing the following parameters: ", join( ',', @missing ) );

    }

}


sub setup_pipeline {
# Do things like:
#   change to the project_root directory
#   create a 'logs' directory

    my ( $cfg ) = @_;

    # change to the project_root directory
    my @required_params = ( 'project_root' );
    check_required_params( $cfg, 'run_prok_pipeline', \@required_params );

    my $project_root = get_param( $cfg, 'run_prok_pipeline', 'project_root' );

    die "Project root does not exist: $project_root\n"     unless -e $project_root;
    die "Project root is not writeable: $project_root\n"   unless -w $project_root;
    die "Project root is not a directory: $project_root\n" unless -d $project_root;

    chdir $project_root || die "Couldn't chdir to $project_root: $!\n";

    # Create a logs directory:
    umask 0000;
    mkdir "$project_root/logs/" || die "Couldn't create $project_root/logs : $!\n";

    return $project_root

}


sub parse_options {
# handle options from the command line

    my $opts = shift;
    my $errors = '';

    if (exists $opts->{config_file} ) {

        $errors .= "--config_file does not exist: $opts->{config_file}\n"
            unless -e $opts->{config_file};

        $errors .= "--config_file points to an empty file: $opts->{config_file}\n"
            if -z $opts->{config_file}; 

        $errors .= "--config_file points to a directory: $opts->{config_file}\n"
            if -d $opts->{config_file};
        &track("config_file=$opts->{config_file}");


    } else {

        $errors .= "Must provide a --config_file.  See --help for more info\n";

    }

    my $cfg = Config::IniFiles->new( -file => $opts->{config_file} )
       or die "ERR: Could not create a Config::IniFiles from $opts->{config_file}";
    $errors .= "Problem getting --config_file setup: $!\n" unless $cfg;

    my $section_overrides = get_section_overrides( \@ARGV );
    set_section_overrides( $cfg, $section_overrides ) if $section_overrides;

    set_global_values( $cfg );

    set_overrides( $cfg, $opts );

    die $errors if $errors;

    return($cfg);
}


sub set_section_overrides {
# replace section key-value pairs for given overrides;

    my ($cfg, $overrides) = @_;

    for my $section ( keys %$overrides ) {

        die "Non-existant section: $section\n" unless ( $cfg->SectionExists( $section ) );

        for my $param ( keys %{$overrides->{$section}} ) {

            if ( $cfg->exists( $section, $param ) ) {

                $cfg->setval( $section, $param, $overrides->{$section}->{$param} );

            } else {

                die "Non-existant param: $section:$param\n";

            }

        }

    }

}


sub get_section_overrides {
# Parse the remaining values from ARGV and fill a hash with the appropriate values.

    my ( $args ) = @_;

    my $overrides;

    for my $arg ( @$args ) {

        if ( $arg =~ /([^:]+):([^=]+)=(.*)/ ) {

            # $overrides->{Section}->{key} = value.
            $overrides->{$1}->{$2} = $3;

            print "Found override: $arg\n" if ($TRACE);

        } else {

            die "Found indescipherable override: $arg\n" if ($TRACE);

        }

    }

    return $overrides;

}


sub set_overrides {
# Replace config-file options with any that might have happened to be passed in.

    my ( $cfg, $opts ) = @_;

    my @params = $cfg->Parameters( 'run_prok_pipeline' );

    foreach my $param ( @params ) {

        if ( exists $opts->{$param} ) {

            $cfg->setval( 'run_prok_pipeline', $param, $opts->{$param} );

        } 

    }

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
