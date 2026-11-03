#------------------------------------------------------------------------
# run_impl.tcl: run implementation through bitstream (see run_synth.tcl for
# synthesis; requires synth_1 to already have been run at least once -
# launch_runs will pick up if it's stale)
#
# Optional IMPL_STRATEGY env var overrides the impl_1 run's strategy before
# launching (e.g. IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt) --
# useful for re-running place/route with a different strategy without
# re-synthesizing. Leave unset to keep whatever strategy is already on the
# run (Vivado's default the first time).
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
set report_dir  [file join $base_dir build reports $proj_name impl]

# Absolute path of project inside the build project
set xpr_path [glob -nocomplain "$proj_dir/${proj_name}.xpr"]

if {![file exists $xpr_path]} {
    error "Project file (.xpr) not found: $xpr_path"
}

open_project $xpr_path

set impl_run [get_runs impl_1]

# ---- Optional strategy override ----
if {[info exists ::env(IMPL_STRATEGY)] && $::env(IMPL_STRATEGY) ne ""} {
    set requested_strategy $::env(IMPL_STRATEGY)
    set valid_strategies [list_property_value strategy $impl_run]
    if {[lsearch -exact $valid_strategies $requested_strategy] == -1} {
        error "IMPL_STRATEGY '$requested_strategy' is not a valid strategy for impl_1. Valid options: $valid_strategies"
    }
    puts "Setting impl_1 strategy to: $requested_strategy"
    set_property strategy $requested_strategy $impl_run
}

# ---- Launch implementation ----
reset_run impl_1
launch_runs impl_1 -verbose -to_step write_bitstream -jobs $njobs
wait_on_run impl_1

# ---- Copy bitstream ----
set gen_bit_path "$proj_dir/${proj_name}.runs/impl_1/${proj_name}_wrapper.bit"
set bit_path "$proj_dir/${proj_name}.bit"
file copy -force $gen_bit_path $bit_path

# ---- Export hardware design ----
set xsa_path "$proj_dir/${proj_name}.xsa"
write_hw_platform -fixed -force -file $xsa_path

# ---- Export bin from bitstream ----
set bin_path "$proj_dir/${proj_name}.bin"
write_cfgmem -force -format bin -interface smapx32 -disablebitswap -loadbit "up 0x0 $bit_path" $bin_path

# ---- Copy reports ----
file mkdir $report_dir
file copy -force {*}[glob -nocomplain "$proj_dir/${proj_name}.runs/impl_1/*.rpt"] $report_dir

puts "IMPL_WNS: [get_property STATS.WNS $impl_run]"
puts "IMPL_TNS: [get_property STATS.TNS $impl_run]"

close_project
