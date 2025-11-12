# generate_sdt.tcl
# Usage: xsct generate_sdt.tcl <proj.xsa> <output sdt dir> <board_dts>
# Arguments:
#   1 -> XSA path
#   2 -> SDT output directory
#   3 -> Board DTS path

if { $argc != 3} {
    puts "Usage: xsct generate_sdt.tcl <proj.xsa> <output sdt dir> <board_dts>"
    exit 1
}

# Get arguments
set xsa_path [lindex $argv 0]
set sdt_path [lindex $argv 1]
set board_dts [lindex $argv 2]

# Ensure output directory exists
file mkdir $sdt_path

# Set DT parameters for SDT generation
sdtgen set_dt_param -xsa $xsa_path -dir $sdt_path -board_dts $board_dts

# Generate SDT
sdtgen generate_sdt
