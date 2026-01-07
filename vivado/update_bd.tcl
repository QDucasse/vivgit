#------------------------------------------------------------------------
# update_bd.tcl: update the block design tcl rebuild with GUI changes
#------------------------------------------------------------------------

# ---- Project variables ----
if {[info exists ::env(PROJECT)]} {
    set proj_name $::env(PROJECT)
} else {
    error "PROJECT environment variable not set"
}

# Optional: allow PROJECT_ROOT override
if {[info exists ::env(PROJECT_ROOT)]} {
    set base_dir $::env(PROJECT_ROOT)
} else {
    # fallback: project root is one level above scripts
    set base_dir [file normalize [file join [file dirname [info script]] ../../]]
}

# Paths relative to project root
set proj_dir    [file join $base_dir build $proj_name]
set bd_dir      [file join $base_dir bd]
set ip_dir      [file join $base_dir ip]

# Absolute path of project inside the build project
set xpr_path [glob -nocomplain "$proj_dir/${proj_name}.xpr"]

if {![file exists $xpr_path]} {
    error "Project file (.xpr) not found: $xpr_path"
}

# ---- BD update ----
open_project $xpr_path

# Absolute path of BD inside the build project
set bd_path [glob -nocomplain "$proj_dir/${proj_name}.srcs/sources_1/bd/${proj_name}/${proj_name}.bd"]

open_bd_design $bd_path
write_bd_tcl ./$bd_dir/$proj_name.tcl -force
set_property synth_checkpoint_mode None [get_files $bd_path]
generate_target all [get_files $bd_path]
close_bd_design [current_bd_design]

close_project
