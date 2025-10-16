#------------------------------------------------------------------------
# update_bd.tcl: update the block design tcl rebuild with GUI changes
#------------------------------------------------------------------------

# ---- Project variables ----
if {[llength $argv] > 0} {
    set proj_name [lindex $argv 0]
} else {
     error "Supply a name for the project: vivado -mode batch -tclargs <proj_name>"
}

set base_dir [file normalize [file dirname [info script]]]
set proj_dir [file join $base_dir "../build/$proj_name"]
set bd_dir [file normalize [file join $base_dir "../bd"]]
set ip_dir [file normalize [file join $base_dir "../ip"]]

# Absolute path of project inside the build project
set xpr_path [glob -nocomplain "$proj_dir/${proj_name}.xpr"]

if {![file exists $xpr_path]} {
    error "Project file (.xpr) not found: $xpr_path"
}

open_project $xpr_path

# Absolute path of BD inside the build project
set bd_path [glob -nocomplain "$proj_dir/${proj_name}.srcs/sources_1/bd/${proj_name}/${proj_name}.bd"]

open_bd_design $bd_path
write_bd_tcl ./$bd_dir/$proj_name.tcl -force
set_property synth_checkpoint_mode None [get_files $bd_path]
generate_target all [get_files $bd_path]
close_bd_design [current_bd_design]

close_project
