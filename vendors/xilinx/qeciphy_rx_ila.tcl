##################################################################
# Vivado Version Warning Only (Script is version-agnostic)
##################################################################
set scripts_vivado_version 2024.1
set current_vivado_version [version -short]
if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
  puts "WARNING: Script was generated in Vivado $scripts_vivado_version, running in $current_vivado_version."
  puts "If you encounter issues, open the IP in Vivado and upgrade it if needed."
}

##################################################################
# Accept part_number and output_dir as arguments
##################################################################
if { !([info exists ::argv] && [llength $::argv] >= 2) } {
  puts "ERROR: Usage: vivado -mode batch -source vendor/xilinx/qeciphy_rx_ila.tcl -tclargs <part_number> <output_dir>"
  return 1
}
set part_number [lindex $::argv 0]
set output_dir [lindex $::argv 1]
puts "INFO: Using part number: $part_number"
puts "INFO: Output directory: $output_dir"

##################################################################
# Create Project in output_dir
##################################################################
if { [file exists $output_dir] } {
  foreach f [glob -nocomplain -directory $output_dir *] {
    file delete -force $f
  }
} else {
  file mkdir $output_dir
}

create_project temp_project $output_dir -part $part_number
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

##################################################################
# Check Required IPs
##################################################################
set required_ips { xilinx.com:ip:ila:6.2 }
foreach ip_vlnv $required_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    puts "ERROR: Missing IP $ip_vlnv in catalog. Add repository or install missing IP."
    return 1
  }
}

##################################################################
# Create IP qeciphy_rx_ila
##################################################################
set ip_name qeciphy_rx_ila
set ip_obj [create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name $ip_name]

# Set IP parameters (customize as needed)
set_property -dict [list \
  CONFIG.C_NUM_OF_PROBES {8} \
  CONFIG.C_PROBE0_WIDTH {64} \
  CONFIG.C_PROBE4_WIDTH {4} \
  CONFIG.C_PROBE5_WIDTH {4} \
  CONFIG.C_PROBE6_WIDTH {4} \
  CONFIG.C_PROBE7_WIDTH {1} \
] [get_ips $ip_name]

# The .xci file is created automatically; find and copy it
set xci_path "[get_property IP_FILE [get_ips $ip_name]]"
set xci_filename [file tail $xci_path]
file copy -force $xci_path $output_dir/$xci_filename

# Cleanup: Remove all files in output_dir except .xci
foreach f [glob -nocomplain -directory $output_dir *] {
  if { [file extension $f] ne ".xci" } {
    file delete -force $f
  }
}

puts "INFO: IP core '$ip_name' .xci generated at $output_dir/$xci_filename"

close_project
exit