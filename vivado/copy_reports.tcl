#------------------------------------------------------------------------
# copy_reports.tcl: copy a run's reports to build/reports/<proj>/<step>/
# under stable names, sourced by run_synth.tcl and run_impl.tcl.
#
# Vivado names them <top>_<report>_<step>.rpt (e.g.
# fuzzsight_tri_wrapper_timing_summary_routed.rpt); the <top>_ prefix is
# dropped (timing_summary_routed.rpt). Reports of the previous build are
# removed first, so none from e.g. another strategy is left behind.
#------------------------------------------------------------------------

# copy_reports <run> <report_dir>: copy the run's .rpt files, returns the
# copied names
proc copy_reports {run report_dir} {
    set top [get_property TOP [get_filesets sources_1]]
    file mkdir $report_dir
    foreach old [glob -nocomplain -directory $report_dir *.rpt] {
        file delete $old
    }
    set copied {}
    foreach rpt [glob -nocomplain -directory [get_property DIRECTORY $run] *.rpt] {
        set name [file tail $rpt]
        if {[string first "${top}_" $name] == 0} {
            set name [string range $name [string length "${top}_"] end]
        }
        file copy -force $rpt [file join $report_dir $name]
        lappend copied $name
    }
    return $copied
}
