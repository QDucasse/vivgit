# generate_boot.tcl
# Usage: xsct generate_boot.tcl <proj_name>

if { $argc != 1 } {
    puts "Usage: xsct generate_boot.tcl <proj_name>"
    exit 1
}

set proj_name [lindex $argv 0]
# Path setup
set base_dir [file normalize [file dirname [info script]]]
set proj_dir [file join $base_dir "../../build/$proj_name"]
set xsa_path "$proj_dir/${proj_name}.xsa"
set boot_dir "$proj_dir/${proj_name}.boot"
set bit_path [glob -nocomplain -directory $proj_dir *.bit]

file mkdir $boot_dir
set fsbl_dir "$boot_dir/zynqmp_fsbl"
set fsbl_path "$fsbl_dir/executable.elf"
set pmufw_dir "$boot_dir/pmu_fw"
set pmufw_path "$pmufw_dir/executable.elf"
set bif_path "$boot_dir/bootgen.bif"
set boot_bin_path "$boot_dir/BOOT.BIN"

 # ---- Utility procedures ----
proc get_device_family {} {
    return [common::get_property FAMILY [hsi::current_hw_design]]
}

proc get_processors {} {
    return [hsi::get_cells * -filter {IP_TYPE==PROCESSOR}]
}

proc get_proc_by_name {name} {
    set procs [get_processors]
    foreach p $procs {
        if {[string match $name* $p]} { return $p }
    }
    return ""
}

proc has_pl_ip {} {
    set pl_cells [hsi::get_cells * -filter {IS_PL==1}]
    return [expr {[llength $pl_cells] > 0}]
}

# ---- Boot creation ----
proc create_bif {} {
    global proj_dir fsbl_path pmufw_path bif_path bit_path
    set fileId [open $bif_path "w"]
    puts $fileId "the_ROM_image:"
    puts $fileId "{"
    puts $fileId "\[bootloader\] $fsbl_path"
    puts $fileId "\[pmufw_image\] $pmufw_path"
    if {$bit_path != ""} {
        puts $fileId "\[destination_device=pl\] $bit_path"
    }
    puts $fileId "}"
    close $fileId
    puts "BIF file created successfully"
}

# Main procedure
proc create_boot {} {
    global xsa_path fsbl_dir pmufw_dir bif_path boot_bin_path
    set design_name [hsi::open_hw_design $xsa_path]

    # Check for Cortex-A53 existence
    set fsbl_proc [get_proc_by_name "psu_cortexa53_0"]
    if {$fsbl_proc == ""} {
        puts "Error: No Cortex-A53 processor found"
        exit 1
    }

    # Check for PMU existence
    set pmu_proc [get_proc_by_name "psu_pmu_0"]
    if {$pmu_proc == ""} {
        puts "Error: No PMU processor found"
        exit 1
    }

    # Generate FSBL
    hsi::generate_app -app zynqmp_fsbl -proc $fsbl_proc -dir $fsbl_dir -compile

    # Generate PMUFW
    hsi::generate_app -app zynqmp_pmufw -proc $pmu_proc -dir $pmufw_dir -compile

    create_bif

    if {[file exists $bif_path]} {
        exec bootgen -arch zynqmp -image $bif_path -o i $boot_bin_path -w on
        puts "BOOT.BIN generated successfully"
    } else {
        puts "Error: BIF file not found, cannot generate BOOT.BIN"
    }

    hsi::close_hw_design $design_name
}

create_boot