# SPDX-License-Identifier: None
# Copyright (c) 2025 Riverlane Ltd.

##################################################################
# Argument handling
##################################################################
# Usage:
# vivado -mode batch -source vivado_synth.tcl -tclargs <SYN_TOP> <XDC> <PART> <BOARD> <HOOKS> <SYN_FILES>
# BOARD is optional. HOOKS is a single quoted string containing space-separated hook dicts.
# SYN_FILES is a space-separated list of files.

if { !([info exists ::argv] && [llength $::argv] >= 5) } {
    puts "ERROR: Usage: vivado -mode batch -source vivado_synth.tcl -tclargs <SYN_TOP> <XDC> <PART> <BOARD?> <HOOKS?> <SYN_FILES>"
    exit 1
}

set syn_top      [lindex $::argv 0]
set xdc_file     [lindex $::argv 1]
set part_number  [lindex $::argv 2]
set board        [lindex $::argv 3]
set hooks_raw    [lindex $::argv 4]
set syn_files    [lrange $::argv 5 end]

puts "INFO: Synthesis top: $syn_top"
puts "INFO: Constraints file: $xdc_file"
puts "INFO: Part number: $part_number"
if { $board ne "" } {
    puts "INFO: Board: $board"
}
puts "INFO: Hooks: $hooks_raw"

##################################################################
# Utility: Parse hooks argument (simple space-separated list)
##################################################################
# The hooks_raw string now contains space-separated script paths:
# script1.tcl script2.tcl script3.tcl

set hooks [split $hooks_raw]
puts "DEBUG: Total hooks: [llength $hooks]"
foreach hook $hooks {
    puts "DEBUG: Hook script: $hook"
}

##################################################################
# Utility: Run hooks (simplified for pre_setup only)
##################################################################
proc run_pre_setup_hooks {hooks part_number} {
    foreach hook_script $hooks {
        if {$hook_script ne ""} {
            puts "INFO: Running pre_setup hook script: $hook_script"
            if {[file exists $hook_script]} {
                # Save original argv
                set original_argv $::argv
                # Set hook-specific arguments: only <part_number> is needed now
                set ::argv [list $part_number]
                # Source the hook script
                source $hook_script
                # Restore original argv
                set ::argv $original_argv
            } else {
                puts "WARNING: Hook script not found: $hook_script"
            }
        }
    }
}

##################################################################
# Project creation
##################################################################
set output_dir "./run/synth_qeciphy"
create_project synth_qeciphy $output_dir -part $part_number -force

if { $board ne "" } {
    set_property board_part $board [current_project]
}

##################################################################
# Pre-setup hooks (run after project creation)
##################################################################
run_pre_setup_hooks $hooks $part_number

##################################################################
# Add sources from argument list
##################################################################
foreach f $syn_files {
    add_files -fileset sources_1 $f
}

##################################################################
# Add all .xci files from xci/
##################################################################
if { [file exists "xci"] } {
    foreach xci_file [glob -nocomplain xci/*.xci] {
        import_ip $xci_file
    }
}

##################################################################
# Add constraints file
##################################################################
add_files -fileset constrs_1 -norecurse $xdc_file

##################################################################
# Set synthesis top
##################################################################
set_property top $syn_top [current_fileset]

##################################################################
# Pre-synth hooks
##################################################################
# run_pre_setup_hooks $hooks $part_number (pre_synth hooks removed for simplicity)

##################################################################
# Update hierarchy and upgrade IPs
##################################################################
update_compile_order -fileset sources_1
upgrade_ip [get_ips]

##################################################################
# Run synthesis
##################################################################
launch_runs synth_1
wait_on_run synth_1

##################################################################
# Pre-impl hooks
##################################################################
# run_pre_setup_hooks $hooks $part_number (pre_impl hooks removed for simplicity)

##################################################################
# Run implementation (place and route)
##################################################################
launch_runs impl_1
wait_on_run impl_1

##################################################################
# Post-route hooks (after place and route, before bitstream)
##################################################################
# run_pre_setup_hooks $hooks $part_number (post_route hooks removed for simplicity)

##################################################################
# Generate bitstream
##################################################################
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

##################################################################
# Post-impl hooks (after bitstream generation)
##################################################################
# run_pre_setup_hooks $hooks $part_number (post_impl hooks removed for simplicity)