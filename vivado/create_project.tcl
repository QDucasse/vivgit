#------------------------------------------------------------------------
# create_project.tcl: complete project creation and block design setup
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

# Fixed project settings
if {[info exists ::env(PART_NAME)]} {
    set part_name $::env(PART_NAME)
} else {
    error "PART_NAME environment variable not set"
}

# Paths relative to project root
set proj_dir    [file join $base_dir build $proj_name]
set report_dir  [file join $base_dir build reports $proj_name]
set rtl_dir     [file join $base_dir rtl]
set sim_dir     [file join $base_dir sim]
set constr_dir  [file join $base_dir constraints $proj_name]
set bd_dir      [file join $base_dir bd]
set ip_dir      [file join $base_dir ip]

# ---- Project creation ----

file mkdir "${base_dir}/build"
create_project $proj_name $proj_dir -part $part_name -force

if {[info exists ::env(BOARD_NAME)]} {
    set_property BOARD_PART $::env(BOARD_NAME) [current_project]
} else {
    error "BOARD_NAME environment variable not set"
}

# ---- Add sources ----
# - RTL

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]

# Add files recursively. rtl/attic holds superseded modules kept for reference.
# Tcl's glob has no globstar, so do it manually
proc collect_sources {dir exts} {
    set found {}
    foreach f [glob -nocomplain -directory $dir -types f *] {
        set e [string tolower [string trimleft [file extension $f] .]]
        if {[lsearch -exact $exts $e] >= 0} {
            lappend found $f
        }
    }
    foreach sub [glob -nocomplain -directory $dir -types d *] {
        lappend found {*}[collect_sources $sub $exts]
    }
    return $found
}

# Add the sources under dir, skipping attic at any depth (not just as the
# immediate parent)
proc add_rtl_dir {dir} {
    foreach file [collect_sources $dir {v sv vhd}] {
        if {[lsearch -exact [file split $file] attic] >= 0} {
            continue
        }
        add_files -fileset sources_1 $file
    }
}

add_rtl_dir $rtl_dir

# External RTL: rtl.ext at the project root lists extra source directories,
# one per line, relative to the project root ('#' starts a comment). Typical
# use: a subdirectory of a git submodule. Each directory is walked like rtl/.
set ext_file [file join $base_dir rtl.ext]
if {[file exists $ext_file]} {
    set fh [open $ext_file r]
    set ext_lines [split [read $fh] "\n"]
    close $fh
    foreach line $ext_lines {
        set line [string trim [regsub {#.*$} $line ""]]
        if {$line eq ""} {
            continue
        }
        set ext_dir [file normalize [file join $base_dir $line]]
        if {![file isdirectory $ext_dir]} {
            error "rtl.ext: $ext_dir not found (submodule not initialised? run git submodule update --init)"
        }
        add_rtl_dir $ext_dir
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

# Also copy data
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

# Copy trace data into the xsim run directory
set_property -name {xsim.simulate.xsim.more_options} -value {} -objects [get_filesets sim_1]

# Tell Vivado to include trace_data as simulation data files
foreach f [glob -nocomplain "$sim_dir/data/*"] {
    add_files -fileset sim_1 -norecurse $f
    set_property file_type {Data Files} [get_files  $f]
}

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
set bd_tcl [file join $bd_dir "${proj_name}.tcl"]
if {![file exists $bd_tcl]} {
    error "Block design Tcl $bd_tcl not found."
}

# A BD tcl that connects a pin the RTL/IP no longer has (e.g. a renamed module
# port) only triggers a warning in Vivado, and the connection is silently
# dropped from the design. Make it an error while sourcing the BD, unless
# ALLOW_MISSING_PINS=1. Scoped to the BD tcl so Vivado's own internals are
# unaffected.
set allow_missing_pins [expr {[info exists ::env(ALLOW_MISSING_PINS)] && $::env(ALLOW_MISSING_PINS) eq "1"}]
set missing_pin_msg {BD 5-235}
set missing_pin_hint "bd/${proj_name}.tcl connects pins that do not exist (see 'No pins matched' above),\
    typically a module port renamed in the RTL. Fix the block design, or set\
    ALLOW_MISSING_PINS=1 to build without those connections."

if {!$allow_missing_pins} {
    set_msg_config -id $missing_pin_msg -new_severity ERROR
}
if {[catch {source $bd_tcl} err]} {
    if {!$allow_missing_pins && [get_msg_config -count -id $missing_pin_msg] > 0} {
        error $missing_pin_hint
    }
    error $err $::errorInfo
}
if {!$allow_missing_pins} {
    reset_msg_config -id $missing_pin_msg -default_severity
} elseif {[get_msg_config -count -id $missing_pin_msg] > 0} {
    puts "WARNING: ALLOW_MISSING_PINS=1: bd/${proj_name}.tcl connects pins that do not exist\
        (see 'No pins matched' above), building without those connections."
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

# Run flows are named after the Vivado release year ("Vivado Synthesis 2024"),
# so derive it from the running Vivado instead of hardcoding it.
set flow_year [lindex [split [version -short] .] 0]

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
    create_run -name synth_1 -part $part_name -flow "Vivado Synthesis $flow_year" -strategy "Vivado Synthesis Defaults" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis $flow_year" [get_runs synth_1]
}

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
    create_run -name impl_1 -part $part_name -flow "Vivado Implementation $flow_year" -strategy "Vivado Implementation Defaults" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation $flow_year" [get_runs impl_1]
}

# ---- Close project ----
close_project
