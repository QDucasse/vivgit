#------------------------------------------------------------------------
# run_synth.tcl: run synthesis only (see run_impl.tcl for implementation)
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

if {[info exists ::env(NJOBS)]} {
    set njobs $::env(NJOBS)
} else {
    set njobs 8
}

# Paths relative to project root
set proj_dir    [file join $base_dir build $proj_name]
set report_dir  [file join $base_dir build reports $proj_name synth]

# Absolute path of project inside the build project
set xpr_path [glob -nocomplain "$proj_dir/${proj_name}.xpr"]

if {![file exists $xpr_path]} {
    error "Project file (.xpr) not found: $xpr_path"
}

open_project $xpr_path

# ---- Launch synthesis ----
reset_run synth_1
launch_runs synth_1 -jobs $njobs
wait_on_run synth_1

# ---- Copy reports ----
source [file join [file dirname [info script]] copy_reports.tcl]
copy_reports [get_runs synth_1] $report_dir

# ---- Critical warnings ----
# All synthesis runs: synth_1 and the out-of-context IP runs
source [file join [file dirname [info script]] critical_warnings.tcl]
report_critical_warnings [get_runs -filter {IS_SYNTHESIS}] [file join $report_dir critical_warnings.txt]

close_project
