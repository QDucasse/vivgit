#----------------------------------------------------------------------------
# generate_boot.tcl: generates the BOOT.BIN from the XSA (FSBL, PMU firmware)
# and prebuilt bl31.elf, u-boot.elf and system.dtb
#
# The prebuilt files are taken from, by priority:
#   BL31_ELF / UBOOT_ELF / SYSTEM_DTB   one file each
#   BOOT_FW_DIR                         a directory holding all three (e.g. a
#                                       shared per-board directory)
#   PLNX_PROJECT                        <PLNX_PROJECT>/images/linux
# A missing file is an error, unless ALLOW_INCOMPLETE_BOOT=1 (the BOOT.BIN is
# then built without it, and will not boot Linux).
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

# Returns the env var's value, or "" if unset
proc env_or_empty {name} {
    if {[info exists ::env($name)]} { return $::env($name) }
    return ""
}

# ---- Prebuilt boot files ----
set fw_dir [env_or_empty BOOT_FW_DIR]
if {$fw_dir eq "" && [env_or_empty PLNX_PROJECT] ne ""} {
    set fw_dir [file join [env_or_empty PLNX_PROJECT] images linux]
}
set allow_incomplete [expr {[env_or_empty ALLOW_INCOMPLETE_BOOT] eq "1"}]

# Resolves one prebuilt file: its own variable first, then fw_dir. Returns ""
# and records it in missing_fw when the file is not found.
set missing_fw {}
proc resolve_fw {var name} {
    global fw_dir missing_fw
    set path [env_or_empty $var]
    if {$path eq "" && $fw_dir ne ""} {
        set path [file join $fw_dir $name]
    }
    if {$path ne "" && [file isfile $path]} {
        return [file normalize $path]
    }
    lappend missing_fw "  $name ([expr {$path eq "" ? "$var, BOOT_FW_DIR and PLNX_PROJECT not set" : "not found: $path"}])"
    return ""
}
set bl31_path   [resolve_fw BL31_ELF bl31.elf]
set uboot_path  [resolve_fw UBOOT_ELF u-boot.elf]
# Note: No kernel image since we load it through PXE in u-boot
set sysdtb_path [resolve_fw SYSTEM_DTB system.dtb]

if {[llength $missing_fw] > 0} {
    set msg "Missing prebuilt boot files:\n[join $missing_fw \n]\nPoint BOOT_FW_DIR at a directory holding bl31.elf, u-boot.elf and system.dtb (or set BL31_ELF/UBOOT_ELF/SYSTEM_DTB, or PLNX_PROJECT)."
    if {!$allow_incomplete} {
        error $msg
    }
    puts "WARNING: $msg\nALLOW_INCOMPLETE_BOOT=1: building BOOT.BIN without them, it will not boot Linux."
}

# Dirs/Paths setup
# -- vivado related
set proj_dir    [file join $base_dir build $proj_name]
set sdt_dir     [file join $proj_dir "${proj_name}.sdt"]
set boot_dir    [file join $proj_dir "${proj_name}.boot"]
set xsa_path    "$proj_dir/${proj_name}.xsa"
set bit_path    [glob -nocomplain -directory $proj_dir *.bit]

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

    # Board-specific FSBL code (e.g. the ZCU104 I2C setup in xfsbl_board.c) is
    # selected by the XPS_BOARD_* define that the BSP's xparameters.h gets from
    # the project's board part (BOARD_NAME), so no extra compiler flags here.
    hsi::generate_app -dir $fsbl_dir -compile

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