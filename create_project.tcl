#------------------------------------------------------------------------
# create_project.tcl: complete project creation and block design setup
#------------------------------------------------------------------------

# ---- Project variables ----

# ---- Project variables ----
if {[llength $argv] > 0} {
    set proj_name [lindex $argv 0]
} else {
     error "Supply a name for the project: vivado -mode batch -tclargs <proj_name>"
}

set part_name "xczu7ev-ffvc1156-2-e"

set base_dir [file normalize [file dirname [info script]]]
set proj_dir [file join $base_dir "../build/$proj_name"]
set report_dir [file join $base_dir "../build/reports"]
set rtl_dir [file normalize [file join $base_dir "../rtl"]]
set sim_dir [file normalize [file join $base_dir "../sim/"]]
set constr_dir [file normalize [file join $base_dir "../constraints/${proj_name}"]]
set bd_dir [file normalize [file join $base_dir "../bd"]]
set ip_dir  [file normalize [file join $base_dir "../ip"]]

# ---- Project creation ----

file mkdir ../build
create_project $proj_name $proj_dir -part $part_name -force

# ---- Add sources ----
# - RTL

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

# Add files with glob
foreach ext {v sv vhd} {
    foreach file [glob -nocomplain -directory $rtl_dir -types f ./**/*.$ext] {
        add_files -fileset sources_1 $file
    }
}

update_compile_order -fileset sources_1

# - Simulation

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -srcset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]

# Add files with glob
foreach ext {v sv vhd} {
    foreach file [glob -nocomplain -directory $sim_dir -types f ./*.$ext] {
        add_files -fileset sim_1 $file
    }
}

update_compile_order -fileset sim_1

# - Constraints

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add files with glob
foreach file [glob -nocomplain "$constr_dir/*.xdc"] {
    add_files -fileset constrs_1 $file
}

update_compile_order -fileset constrs_1


# Note: If you prefer working on the copy of files, uncomment next line
# import_files -force -norecurse

# ---- Block design ----
set bd_tcl [file join $base_dir "../bd/${proj_name}.tcl"]
if {[file exists $bd_tcl]} {
    source $bd_tcl
} else {
    error "Block design Tcl $bd_tcl not found."
}

# Absolute path of BD inside the build project
set bd_path [glob -nocomplain "$proj_dir/${proj_name}.srcs/sources_1/bd/${proj_name}/${proj_name}.bd"]

if {![file exists $bd_path]} {
    error "Block design file not found: $bd_path"
}

open_bd_design $bd_path
set_property synth_checkpoint_mode None [get_files $bd_path]
generate_target all [get_files $bd_path]

# Setup wrapper and add sources
make_wrapper -files [get_files $bd_path] -top
set wrapper_path "$proj_dir/${proj_name}.gen/sources_1/bd/${proj_name}/hdl/${proj_name}_wrapper.v"

if {[file exists $wrapper_path]} {
    add_files -fileset sources_1 $wrapper_path
} else {
    error "Wrapper file not found: $wrapper_path"
}

export_ip_user_files -of_objects [get_files $bd_path]
close_bd_design [current_bd_design]

# ---- Set top module ----
set_property top ${proj_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

# ---- Synthesis/Implementation properties ----

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part $part_name -flow {Vivado Synthesis 2024} -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2024" [get_runs synth_1]
}

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part $part_name -flow {Vivado Implementation 2024} -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2024" [get_runs impl_1]
}

# ---- Close project ----
close_project
