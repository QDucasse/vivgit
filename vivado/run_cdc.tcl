#------------------------------------------------------------------------
# run_cdc.tcl: clock domain crossing analysis of the last build, without
# rerunning anything.
#
# Opens the implemented design (impl_1), or the synthesized one (synth_1)
# when there is no implementation yet, and writes to
# build/reports/<proj>/cdc/:
#   cdc_summary.rpt        report_cdc summary, by clock pair and CDC type
#   cdc_details.rpt        report_cdc -details, every crossing
#   clock_interaction.rpt  report_clock_interaction, how each clock pair is
#                          timed (e.g. a missing clock group or false path)
# Then prints the number of crossings per severity, and the Critical and
# Warning ones per check. CDC_STRICT=1 fails if there are Critical ones.
# Waived crossings (create_waiver) are counted apart.
#
# The project is opened read-only.
#------------------------------------------------------------------------

# ---- Project variables ----
if {[info exists ::env(PROJECT)]} {
    set proj_name $::env(PROJECT)
} else {
    error "PROJECT environment variable not set"
}

if {[info exists ::env(PROJECT_ROOT)]} {
    set base_dir $::env(PROJECT_ROOT)
} else {
    set base_dir [file normalize [file join [file dirname [info script]] ../../]]
}

set cdc_strict [expr {[info exists ::env(CDC_STRICT)] && $::env(CDC_STRICT) eq "1"}]

set proj_dir   [file join $base_dir build $proj_name]
set report_dir [file join $base_dir build reports $proj_name cdc]
set xpr_path   "$proj_dir/${proj_name}.xpr"

if {![file exists $xpr_path]} {
    error "Project file (.xpr) not found: $xpr_path, run 'make PROJECT=$proj_name project'"
}

open_project -read_only $xpr_path

# ---- Pick the most advanced completed run ----
set run ""
foreach name {impl_1 synth_1} {
    set r [get_runs -quiet $name]
    if {$r ne "" && [get_property PROGRESS $r] eq "100%"} {
        set run $r
        break
    }
}
if {$run eq ""} {
    close_project
    error "neither impl_1 nor synth_1 has completed, run 'make PROJECT=$proj_name synth' (or impl) first"
}
if {[get_property NEEDS_REFRESH $run]} {
    puts "WARNING: $run is out of date with the project sources, this analyses the previous build"
}
puts "Analysing $run ([get_property STATUS $run])"
open_run $run

# ---- Reports ----
file mkdir $report_dir
report_cdc -name cdc -file [file join $report_dir cdc_summary.rpt]
report_cdc -details -file [file join $report_dir cdc_details.rpt]
report_clock_interaction -file [file join $report_dir clock_interaction.rpt]

# ---- Summary ----
set count [dict create Critical 0 Warning 0 Info 0]
set waived 0
set checks [dict create]
foreach v [get_cdc_violations -quiet -name cdc] {
    if {[get_property IS_WAIVED $v]} {
        incr waived
        continue
    }
    set sev [get_property SEVERITY $v]
    dict incr count $sev
    if {$sev ne "Info"} {
        dict incr checks "$sev \[[get_property CHECK $v]\] [get_property DESCRIPTION $v]"
    }
}
set n_crit [dict get $count Critical]
set total 0
foreach {sev n} $count {
    incr total $n
}
puts "CDC ($run): $total crossings: $n_crit Critical, [dict get $count Warning] Warning, [dict get $count Info] Info ($waived waived)"
foreach {check n} [lsort -stride 2 -index 0 $checks] {
    puts [format "  %5dx %s" $n $check]
}
puts "  reports in $report_dir"

close_project

if {$n_crit > 0 && $cdc_strict} {
    error "$n_crit Critical clock domain crossings and CDC_STRICT=1"
}
