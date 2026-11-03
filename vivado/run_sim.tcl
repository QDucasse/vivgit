#------------------------------------------------------------------------
# run_sim.tcl: run behavioral simulation for a given testbench
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

if {[info exists ::env(TB)]} {
    set tb_name $::env(TB)
} else {
    error "TB environment variable not set (e.g. TB=fuzzsight_tb)"
}

# Simulation length passed to xsim's run command, e.g. "2000 ns", "10us" or "all"
if {[info exists ::env(SIM_TIME)] && $::env(SIM_TIME) ne ""} {
    set sim_time $::env(SIM_TIME)
} else {
    set sim_time "2000 ns"
}

set proj_dir    [file join $base_dir build $proj_name]
set report_dir  [file join $base_dir build reports $proj_name sim]
set sim_dir     [file join $proj_dir ${proj_name}.sim sim_1 behav xsim]

# ---- Open project ----
open_project [file join $proj_dir ${proj_name}.xpr]

# ---- Configure simulation fileset ----
set_property top       $tb_name       [get_filesets sim_1]
set_property top_lib   xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1


# ---- Launch and run behavioral simulation ----
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral


# ---- Open and log in vcd file ----
file mkdir $report_dir
open_vcd [file join $report_dir "${proj_name}_${tb_name}.vcd"]
log_vcd /*

run {*}$sim_time

# ---- Closing vcd ----
close_vcd

# ---- Collect reports before closing ----
# Save waveform database
set wcfg_file [file join $sim_dir wave.wcfg]
if {[file exists $wcfg_file]} {
    file copy -force $wcfg_file [file join $report_dir wave.wcfg]
}

# Export simulation log
set sim_log [file join $sim_dir simulate.log]
if {[file exists $sim_log]} {
    file copy -force $sim_log [file join $report_dir simulate.log]
}

# ---- Close simulator and project ----
close_sim -force    ;# -force ensures the xsim process is actually terminated
close_project