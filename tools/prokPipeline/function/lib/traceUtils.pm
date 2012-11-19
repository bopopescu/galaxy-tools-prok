package traceUtils;

# Trace/track utilities Phil Goetz wrote while writing prok autoAnnotate.
# Copyright 2009, 2010 by JCVI
# This code is under the BSD license, which means others may use it freely.

use strict;
#use Carp qw(cluck confess);
# This awesome line makes errors give a stack trace:
#local $SIG{__WARN__} = \&Carp::cluck;
use Exporter 'import';

our @EXPORT = qw( $DEBUG $TRACE $TRACE2 $TraceDepth &profile &queryKey &slowQueries &trace &tracing &track &trackBegin &trackEnd );


############## BEGIN FUNCTIONS FOR trace, trackBegin, trackEnd

our ( $DEBUG, $TRACE, $TRACE2 ):shared;
$DEBUG = 0;
$TRACE = 0;     # Print trace info down to depth $TRACE
$TRACE2 = 0;    # Track time spent down to max($TRACE, $TRACE2)

# Data for trace and track
# A hash to track how much time each type of query uses
our %QueryTimes:shared = ();
# A hash to track how many times each type of query is called
our %QueryCalls:shared = ();
# Depth of callstack of functions that we trace
our $TraceDepth:shared = 0;  # is sometimes set from outside after a throw
# Stack of start times of functions that we trace
our @TrackStarts:shared = ();
our @TrackChildren:shared = ();  # Stack of refs to lists of children names
# %TChildren is built from the results left on @TrackChildren
our %TChildren:shared = ();  # $TChildren{caller} = \('subroutine1', 'subroutine2')
our $TRoot:shared;   # starting point for traversing tree in %TChildren
my %NodesUsed;       # avoid infinite loop by not calling queryTree twice


# Print something indented according to $TraceDepth
# Will not indent if $TRACE = 0
sub trace {
	my ($msg) = @_;
	print ' ' x $TraceDepth, "$msg\n";
}


# Like trace, but also like trackBegin in that it requires $TRACE > $TraceDepth
# It should be possible to track a trackBegin/trackEnd without tracking everything inside it
sub track {
	my ($msg) = @_;
	print ' ' x $TraceDepth, "$msg\n" if ($TRACE > $TraceDepth+1);
}


# Returns 1 if program will currently print a track
# Used to avoid costly computation of strings that won't be printed
sub tracing {
	return ($TRACE > $TraceDepth+1);
}


# Call this on entering a statement, to track time and print trace info
# Updates callstack depth for TRACE statements
# First argument is a string to print
# Saves time() on stack
# $offset: undef => print according to trace, number => use $TraceDepth + $offset
# This is used to track without printing and without upping $TRACE2,
#   for a spammy but important subroutine
# If you want it never to print, use $offset = -99
# Setting it >= 0 has no effect
sub trackBegin($$) {
	my ($info, $offset) = @_;

	if ($TRACE > ++$TraceDepth || $TRACE2 > $TraceDepth) {
		$offset = 0 if !defined($offset);
		print ' ' x ($TraceDepth-1) , "ENTER $info\n" if $TRACE + $offset > $TraceDepth;
		push(@TrackStarts, time());
		# Push a ref to an empty list onto the stack of child lists
		# All children of this routine will put their ID in it
		push(@TrackChildren, []);
	}
}


# Call this after executing a statement to track time spent in it
# $qkey: key that represents all calls of this type
# $info: info string to print for this specific call
# This might cause a lot of garbage collection
sub trackEnd($$$) {
	my ($qkey, $info, $offset) = @_;
	if (!defined($info)) {
		# Common error: Forgot to provide first parm, bcoz it's similar to 2nd parm
		die "ERR: Called trackEnd with only 1 parm: $qkey";
	}
	my $effective = ($offset) ? $TRACE + $offset : $TRACE;

	if ($TRACE > $TraceDepth-- || $TRACE2 > $TraceDepth+1) {
		my $startTime = pop(@TrackStarts);
		my $totalTime = time() - $startTime;
		if (!exists($QueryTimes{$qkey})) {
			$QueryTimes{$qkey} = 0; $QueryCalls{$qkey} = 0;
		}
		$QueryTimes{$qkey} = $QueryTimes{$qkey} + $totalTime;
		$QueryCalls{$qkey}++;

		$offset = 0 if !defined($offset);
		if ($TRACE + $offset > $TraceDepth+1) {
			# For calls that take over a second, print how long they take
			if ($totalTime > 2) {
				$info = "EXIT $info ${totalTime}s\n";
			}
			else {
				$info = "EXIT $info\n";
			}
			print ' ' x ($TraceDepth), $info
		}

		# Note all the children of the call that just ended
		my @priorChildren = (exists($TChildren{$qkey})) ? @{$TChildren{$qkey}} : ();
		my @latestChildren = @{pop(@TrackChildren)};
		foreach my $child (@latestChildren) {
			push(@priorChildren, $child) if !&member($child, @priorChildren);
		}
		$TChildren{$qkey} = \@priorChildren;
		if (@TrackChildren) {
			# This is not the root caller
			# Register the call that just ended as the child of the call above it
			my @parentsKids = @{pop(@TrackChildren)};
			push(@parentsKids, $qkey) if !&member($qkey, @parentsKids);
			push(@TrackChildren, \@parentsKids);
		}
		# If you call &queryTree(), print the tree starting with the root
		#   as the last node that was exited.
		# Otherwise, when you're running the program, the root node would be set to
		#   a query made before entering the main loop, and you'd see nothing
		#   on the visible query tree until the entire program terminated.
		$TRoot = $qkey;
	}
}


# Compute an identifier for a category of query
sub queryKey($) {
	my ($query) = @_;
	my $orderby = "";
	if ( $query =~ m/(.*)(ORDER BY .*)$/i ) {
		$query = $1; $orderby = " $2";
	}
	my $wordpat = qr/[^<>=\s]*/;
	my $oppat = qr/[^\s]*/;
	# WARNING: Will not correctly match eg  WHERE feat_name='ORF09422'
	if ( $query =~ m/^(SELECT .* FROM .* WHERE ($wordpat)\s+($oppat))\s+$wordpat(.*)$/i ) {
		my $qkey = $1;
		my $ands = $4;
		while ( $ands =~ m/^\s+AND\s+($wordpat)\s+($oppat)\s+$wordpat(.*)$/i ) {
			$qkey .= " AND $1 $2";
			$ands = $3;
		}
		return "$qkey$orderby";
	}
	if ( $query =~ m/^(SELECT .* FROM .*)/i ) { return "$1$orderby"; }
	if ( $query =~ m/^INSERT((\s+\S+)+)\s+VALUES/i ) { return "INSERT$1$orderby" }
	if ( $query =~ m/^UPDATE(\s+\S+\s+SET\s+\S+)\s/i ) { return "UPDATE$1$orderby" }
	if ( $query =~ m/^((\S+\s+){2})/ ) { return "$1$orderby" }
	return "misc";
}

sub profile() {
	#&slowQueries(%QueryTimes);
	&slowQueries();
	print "\nCall tree, with seconds, # of calls:\n";
	if (!defined($TRoot)) {
		# $TRoot is undefined if $TRACE == 1
		print "ERR: \$TRoot never defined.  Use larger -trace argument.\n";
		my @k = keys(%TChildren);
		$TRoot = $k[0];  # choose one arbitrarily
	}
	&queryTree($TRoot, 0) if defined($TRoot);
	print "\n";
}

# Print out top time-consuming queries
# Input was a hash such as %QueryTimes
# Then I cheated and directly accessed %QueryCalls
sub slowQueries {
	# Sort in descending order by time
	my @queryKeys = sort( { $QueryTimes{$b} <=> $QueryTimes{$a} } keys(%QueryTimes) );
	print "Queries and functions in descending order of seconds used, with # of calls:\n";
	my $dbtime = 0;
	foreach my $q (@queryKeys) {
		print &queryString($q, 0);
		if ($q =~ m/SELECT/) { $dbtime += $QueryTimes{$q}; }
	}
	print "Total time spent doing DB queries: $dbtime seconds\n";
}

# Print out a call tree, starting at $root
# Recursive; entered as &queryTree($TRoot, 0)
# $depth will be used to set indentation; currently unused
sub queryTree($$) {
	my ($root, $depth) = @_;
	print &queryString($root, $depth);
	undef(%NodesUsed) if $depth == 0;

	if (!$NodesUsed{$root}++) {
		foreach my $child (@{$TChildren{$root}}) {
			if ($child eq $root) {
				# Avoid recursion; it would go on forever
				print &queryString($root, $depth+1);
			}
			else {
				&queryTree($child, $depth+1);
			}
		}
	}
}

sub queryString($$) {
	my ($q, $depth) = @_;
	my $timeString = &rightJustify($QueryTimes{$q}, 6);
	my $countString = &rightJustify($QueryCalls{$q}, 8);
	return "$timeString $countString\t" . ' ' x $depth . "$q\n";
}


############## END FUNCTIONS FOR trace, trackBegin, trackEnd


### BEGIN COPIED FROM pgoetzUtils.pm TO AVOID CIRCULAR DEPENDENCY

# Return 1 iff $item is in @list
# Does not return $item in case it is zero
sub member($@) {
	my ($item, @list) = @_;
	foreach my $l (@list) {
		if ($l eq $item) { return 1; }
	}
	return 0;
}


# Print $in right-justified in $cols columns
# If length($in) > $cols, use length($in) columns
# TODO: Right-justify on the '.' in a number
sub rightJustify($$) {
	use List::Util qw[min max];
	my ($in, $cols) = @_;
	my $len = max($cols, length($in));   # number of output columns
	$in = ' ' x $cols . $in; $in = substr($in, length($in)-$len, $len);
	return $in;
}

### END COPIED FROM pgoetzUtils.pm TO AVOID CIRCULAR DEPENDENCY


1;
