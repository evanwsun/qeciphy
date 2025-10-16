# SPDX-License-Identifier: None
# Copyright (c) 2025 Riverlane Ltd.

# Vivado synthesis script
# Usage: vivado -mode batch -source vivado_synth.tcl -tclargs <SYN_TOP> <XDC> <PART> <BOARD> <HOOKS> <SYN_FILES>

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

# Parse hooks (space-separated script paths)
set hooks [split $hooks_raw]
puts "DEBUG: Total hooks: [llength $hooks]"
foreach hook $hooks {
    puts "DEBUG: Hook script: $hook"
}

# Run pre-setup hooks
proc run_pre_setup_hooks {hooks part_number} {
    foreach hook_script $hooks {
        if {$hook_script ne ""} {
            puts "INFO: Running pre_setup hook script: $hook_script"
            if {[file exists $hook_script]} {
                set original_argv $::argv
                set ::argv [list $part_number]
                source $hook_script
                set ::argv $original_argv
            } else {
                puts "WARNING: Hook script not found: $hook_script"
            }
        }
    }
}

# Create synthesis project
set output_dir "./run/synth_qeciphy"
create_project synth_qeciphy $output_dir -part $part_number -force

if { $board ne "" } {
    set_property board_part $board [current_project]
}

# Run pre-setup hooks
run_pre_setup_hooks $hooks $part_number

# Add source files
foreach f $syn_files {
    add_files -fileset sources_1 $f
}

# Add IP cores from xci/
if { [file exists "xci"] } {
    foreach xci_file [glob -nocomplain xci/*.xci] {
        import_ip $xci_file
    }
}

# Add XDC files
add_files -fileset constrs_1 -norecurse $xdc_file

# Set synthesis top
set_property top $syn_top [current_fileset]

# Update hierarchy and upgrade IPs
update_compile_order -fileset sources_1
upgrade_ip [get_ips]

# Run synthesis
launch_runs synth_1
wait_on_run synth_1

# Run implementation
launch_runs impl_1
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1