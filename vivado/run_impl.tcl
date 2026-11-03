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
puts "IMPL_WHS: [get_property STATS.WHS $impl_run]"
puts "IMPL_THS: [get_property STATS.THS $impl_run]"
puts "IMPL_TPWS: [get_property STATS.TPWS $impl_run]"

# ---- Timing check ----
# Vivado writes the bitstream even when timing fails. Check setup (WNS),
# hold (WHS) and pulse width (TPWS, e.g. a clock above a pin's maximum
# frequency), and with TIMING_STRICT=1 fail instead of only warning.
set timing_failed {}
set timing_unknown {}
foreach {check stat} {setup STATS.WNS hold STATS.WHS {pulse width} STATS.TPWS} {
    set slack [get_property $stat $impl_run]
    if {![string is double -strict $slack]} {
        lappend timing_unknown $check
    } elseif {$slack < 0} {
        lappend timing_failed "$check ([string range $stat 6 end] = $slack ns)"
    }
}
set timing_strict [expr {[info exists ::env(TIMING_STRICT)] && $::env(TIMING_STRICT) eq "1"}]
if {[llength $timing_unknown] > 0} {
    # Not reported by the run: count it as a failure for TIMING_STRICT
    lappend timing_failed "no [join $timing_unknown {/}] slack reported by impl_1"
}
if {[llength $timing_failed] == 0} {
    puts "TIMING MET"
} else {
    puts "TIMING FAILED: [join $timing_failed {, }]"
    puts "  details: [file join $report_dir *timing_summary_routed.rpt]"
}

close_project

if {[llength $timing_failed] > 0 && $timing_strict} {
    error "timing not met and TIMING_STRICT=1 (the bitstream was written anyway)"
}
