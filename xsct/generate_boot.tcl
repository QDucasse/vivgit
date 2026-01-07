#----------------------------------------------------------------------------
# generate_sdt.tcl: generates the BOOT.BIN from the XSA and petalinux build
#----------------------------------------------------------------------------

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

if {[info exists ::env(PLNX_PROJECT)]} {
    set plnx_proj_path $::env(PLNX_PROJECT)
} else {
    error "PLNX_PROJECT environment variable not set"
}

# Dirs/Paths setup
# -- vivado related
set proj_dir    [file join $base_dir build $proj_name]
set sdt_dir     [file join $proj_dir "${proj_name}.sdt"]
set boot_dir    [file join $proj_dir "${proj_name}.boot"]
set xsa_path    "$proj_dir/${proj_name}.xsa"
set boot_dir    "$proj_dir/${proj_name}.boot"
# -- plnx related
set bit_path    [glob -nocomplain -directory $proj_dir *.bit]
set uboot_path  [glob -nocomplain -directory "$plnx_proj_path/images/linux" u-boot.elf]
set bl31_path   [glob -nocomplain -directory "$plnx_proj_path/images/linux" bl31.elf]
# Note: No kernel image or dtb since we load them through PXE in u-boot
set sysdtb_path [glob -nocomplain -directory "$plnx_proj_path/images/linux" system.dtb]

# Ensure output directory exists
file mkdir $boot_dir

set fsbl_dir       "$boot_dir/zynqmp_fsbl"
set fsbl_path      "$fsbl_dir/zynqmp_fsbl.elf"
set pmufw_dir      "$boot_dir/pmu_fw"
set pmufw_path     "$pmufw_dir/pmufw.elf"
set bif_path       "$boot_dir/bootgen.bif"
set boot_bin_path  "$boot_dir/BOOT.BIN"

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
    global proj_dir fsbl_path pmufw_path bif_path bit_path uboot_path bl31_path sysdtb_path
    set fileId [open $bif_path "w"]
    puts $fileId "the_ROM_image:"
    puts $fileId "{"
    puts $fileId "\t\[bootloader, destination_cpu=a53-0\] $fsbl_path"
    puts $fileId "\t\[pmufw_image\] $pmufw_path"
    if {$bl31_path != ""} {
        puts $fileId "\[destination_cpu=a53-0, exception_level=el-3, trustzone\]\t$bl31_path"
    } else {
        puts "WARNING! No bl31 binary found, skipping inclusion in BOOT.BIN."
    }
    # Note: No kernel image or dtb since we load them through PXE in u-boot
    if {$sysdtb_path != ""} {
        puts $fileId "\[destination_cpu=a53-0, load=0x100000\] $sysdtb_path"
    } else {
        puts "WARNING! No system.dtb binary found, skipping inclusion in BOOT.BIN."
    }
    if {$uboot_path != ""} {
        puts $fileId "\[destination_cpu=a53-0, exception_level=el-2\] $uboot_path"
    } else {
        puts "WARNING! No uboot binary found, skipping inclusion in BOOT.BIN."
    }
    # Note: Bitstream is loaded dynamically with fpgamanager at run time
    # if {$bit_path != ""} {
    #     puts $fileId "\[destination_device=pl\] $bit_path"
    # } else {
    #     puts "WARNING! No bitstream found, skipping inclusion in BOOT.BIN."
    # }
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
    set fsbl_design [hsi::create_sw_design fsbl_1 -proc $fsbl_proc -app zynqmp_fsbl]

    # Set compiler and flags
    common::set_property APP_COMPILER "aarch64-none-elf-gcc" $fsbl_design

    # Create app skeleton to get the flags
    hsi::generate_app -dir $fsbl_dir -compile

    # Capture the flags
    set current_flags [common::get_property APP_COMPILER_FLAGS $fsbl_design]
    # Add new flags
    common::set_property -name APP_COMPILER_FLAGS \
        -value "$current_flags -DRSA_SUPPORT -DXPS_BOARD_ZCU104" \
        -objects $fsbl_design

    # Note: If the error of a missing library occurs (missing xiicps.h), I2C1 might be missing,
    # https://adaptivesupport.amd.com/s/article/73673?language=en_US
    # Note 2: Both I2C1 and UART0 are required for the FSBL to instanciate them correctly

    # Generate PMUFW
    hsi::generate_app -app zynqmp_pmufw -proc $pmu_proc -dir $pmufw_dir -compile

    # Rename generated ELF files to expected names
    file rename -force "$fsbl_dir/executable.elf" "$fsbl_dir/zynqmp_fsbl.elf"
    file rename -force "$pmufw_dir/executable.elf" "$pmufw_dir/pmufw.elf"

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

# Cleanup psu_init files that got here for no reason...
file delete -force {*}[glob -nocomplain -directory $proj_dir psu_init*]