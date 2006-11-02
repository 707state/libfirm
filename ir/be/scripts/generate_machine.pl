#!/usr/bin/perl -w

# This script generates the data structures for the machine description.
# Creation: 2006/10/20
# $Id$

use strict;
use Data::Dumper;

my $specfile   = $ARGV[0];
my $target_dir = $ARGV[1];

our $arch;
our %cpu;
our %vliw;

# include spec file

my $return;

no strict "subs";
unless ($return = do $specfile) {
	warn "couldn't parse $specfile: $@" if $@;
	warn "couldn't do $specfile: $!"    unless defined $return;
	warn "couldn't run $specfile"       unless $return;
}
use strict "subs";

my $target_c = $target_dir."/gen_".$arch."_machine.c";
my $target_h = $target_dir."/gen_".$arch."_machine.h";

# stacks for output
my @obst_unit_tp_defs;     # stack for execution unit type defines
my @obst_unit_defs;        # stack for execution unit defines
my @obst_init;             # stack for cpu description initialization
my @obst_execunits;        # stack for execunit variables
my @obst_execunits_header; # stack for execunit variables
my @obst_init_unit_types;  # stack for unit type variable init

my $bundle_size       = exists($vliw{"bundle_size"})       ? $vliw{"bundle_size"} : 3;
my $bundles_per_cycle = exists($vliw{"bundles_per_cycle"}) ? $vliw{"bundles_per_cycle"} : 1;

my $num_unit_types = scalar(keys(%cpu));
my $tmp            = uc($arch);
my $idx            = 0;
my $has_desc       = defined(%cpu);

if ($has_desc) {
	push(@obst_unit_tp_defs, "/* enum for execution unit types */\n");
	push(@obst_unit_tp_defs, "enum $arch\_execunit_tp_vals {\n");
}

foreach my $unit_type (keys(%cpu)) {
	my $tp_name   = "$tmp\_EXECUNIT_TP_$unit_type";
	my @cur_tp    = @{ $cpu{"$unit_type"} };
	my $num_units = scalar(@cur_tp);

	push(@obst_init_unit_types, "\t{ $num_units, \"$unit_type\", $arch\_execution_units_$unit_type },\n");
	push(@obst_execunits, "be_execution_unit_t $arch\_execution_units_".$unit_type."[$num_units];\n");
	push(@obst_execunits_header, "extern be_execution_unit_t $arch\_execution_units_".$unit_type."[$num_units];\n");

	push(@obst_unit_tp_defs, "\t$tp_name,\n");
	push(@obst_init, "\n\t\t/* init of execution unit type $tp_name */\n");
	push(@obst_init, "\t\tcur_unit_tp = &$arch\_execution_unit_types[$tp_name];\n");

	push(@obst_unit_defs, "/* enum for execution units of type $unit_type */\n");
	push(@obst_unit_defs, "enum $arch\_execunit_tp_$unit_type\_vals {\n");
	foreach my $unit (@cur_tp) {
		my $unit_name = "$tp_name\_$unit";

		push(@obst_unit_defs, "\t$unit_name,\n");
		push(@obst_init, "\t\t$arch\_execution_units_".$unit_type."[".$unit_name."].tp   = cur_unit_tp;\n");
		push(@obst_init, "\t\t$arch\_execution_units_".$unit_type."[".$unit_name."].name = \"$unit\";\n");
	}
	push(@obst_unit_defs, "};\n\n");
}

push(@obst_unit_tp_defs, "};\n\n") if ($has_desc);

open(OUT, ">$target_h") || die("Could not open $target_h, reason: $!\n");

my $creation_time = localtime(time());

print OUT<<EOF;
#ifndef _GEN_$tmp\_MACHINE_H_
#define _GEN_$tmp\_MACHINE_H_

/**
 * Function prototypes for the machine description.
 * DO NOT EDIT THIS FILE, your changes will be lost.
 * Edit $specfile instead.
 * created by: $0 $specfile $target_dir
 * date:       $creation_time
 */

#include "../bemachine.h"

/**
 * Returns the $arch machine description.
 */
const be_machine_t *$arch\_init_machine_description(void);

EOF

print OUT @obst_execunits_header, "\n";
print OUT @obst_unit_tp_defs;
print OUT @obst_unit_defs;

print OUT<<EOF;

#endif /* _GEN_$tmp\_MACHINE_H_ */

EOF

close(OUT);

open(OUT, ">$target_c") || die("Could not open $target_c, reason: $!\n");

$creation_time = localtime(time());

print OUT<<EOF;
/**
 * Generated functions for machine description interface.
 * DO NOT EDIT THIS FILE, your changes will be lost.
 * Edit $specfile instead.
 * created by: $0 $specfile $target_dir
 * date:       $creation_time
 */
#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include "gen_$arch\_machine.h"

EOF

print OUT @obst_execunits;

print OUT<<EOF;

be_execution_unit_type_t $arch\_execution_unit_types[] = {
EOF

print OUT @obst_init_unit_types;

print OUT<<EOF;
};

be_machine_t $arch\_cpu = {
	$bundle_size,
	$bundles_per_cycle,
	$num_unit_types,
	$arch\_execution_unit_types
};

/**
 * Returns the $arch machines description
 */
const be_machine_t *$arch\_init_machine_description(void) {
	static int initialized = 0;

	if (! initialized) {
		be_execution_unit_type_t *cur_unit_tp;
EOF

print OUT @obst_init;

print OUT<<EOF;

		initialized = 1;
	}

	return &$arch\_cpu;
}

EOF

close(OUT);
