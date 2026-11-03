#------------------------------------------------------------------------
# critical_warnings.tcl: summarize the CRITICAL WARNINGs of Vivado runs,
# sourced by run_synth.tcl and run_impl.tcl.
#
# They are often real problems (a constraint matching nothing, an
# unconstrained clock, a failed timing requirement) but end up buried in
# each run's runme.log. This prints a count per message ID with one
# example, and writes them all to <out_file>.
#------------------------------------------------------------------------

# report_critical_warnings <runs> <out_file>
#   runs      Vivado run objects (e.g. [get_runs impl_1])
#   out_file  where to write every critical warning, prefixed by its run
proc report_critical_warnings {runs out_file} {
    set all {}
    set count {}
    set example {}
    set per_run {}
    foreach run $runs {
        set log [file join [get_property DIRECTORY $run] runme.log]
        if {![file exists $log]} {
            continue
        }
        set n 0
        set fh [open $log r]
        while {[gets $fh line] >= 0} {
            if {![regexp {^CRITICAL WARNING: \[([^\]]+)\] (.*)$} $line -> id msg]} {
                continue
            }
            incr n
            lappend all "$run: $line"
            dict incr count $id
            if {![dict exists $example $id]} {
                dict set example $id $msg
            }
        }
        close $fh
        if {$n > 0} {
            lappend per_run "$run: $n"
        }
    }

    file mkdir [file dirname $out_file]
    set fh [open $out_file w]
    foreach line $all {
        puts $fh $line
    }
    close $fh

    if {[llength $all] == 0} {
        puts "CRITICAL WARNINGS: none"
        return 0
    }
    puts "CRITICAL WARNINGS: [llength $all] ([join $per_run {, }]), all in $out_file"
    # Most frequent first
    foreach {id n} [lsort -stride 2 -index 1 -integer -decreasing $count] {
        set msg [dict get $example $id]
        if {[string length $msg] > 160} {
            set msg "[string range $msg 0 156]..."
        }
        puts [format "  %4dx \[%s\] %s" $n $id $msg]
    }
    return [llength $all]
}
