#------------------------------------------------------------------------
# run_synth_impl.tcl: run synthesis and implementation
#------------------------------------------------------------------------

# ---- Project variables ----
if {[llength $argv] > 0} {
    set proj_name [lindex $argv 0]
} else {
     error "Supply a name for the project: vivado -mode batch -tclargs <proj_name>"
}

if {[llength $argv] > 1} {
    set njobs [lindex $argv 1]
} else {
    set njobs 8
}

set board_dts "zcu104-revc"

set base_dir [file normalize [file dirname [info script]]]
set proj_dir [file join $base_dir "../build/$proj_name"]
set report_dir [file join $base_dir "../build/reports"]

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

# ---- Export sdt for petalinux ----
set sdt_path "$proj_dir/$proj_name.sdt"
file mkdir $sdt_path
# Pass arguments to xsct and use sdtgen
exec xsct -eval "set xsa_path $xsa_path; set sdt_path $sdt_path; set board_dts $board_dts; \
    sdtgen set_dt_param -xsa $xsa_path -dir $sdt_path -board_dts $board_dts; \
    sdtgen generate_sdt"

# ---- Copy reports ----
file mkdir $report_dir
file copy -force {*}[glob -nocomplain "$proj_dir/${proj_name}.runs/synth_1/*.rpt"] $report_dir
file copy -force {*}[glob -nocomplain "$proj_dir/${proj_name}.runs/impl_1/*.rpt"] $report_dir

close_project
