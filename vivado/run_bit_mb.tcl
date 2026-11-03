#------------------------------------------------------------------------
# run_bit_mb.tcl: bake a Microblaze app into the bitstream, so the CPU runs it
# as soon as the bitstream is loaded (no JTAG/debugger needed).
#
# updatemem replaces the BRAM contents of the Microblaze (MB_CPU) in
# build/<proj>/<proj>.bit with microblaze/<app>/<app>.elf, using the memory
# map (.mmi) Vivado wrote with the bitstream; other processors in the design
# (e.g. the DDR4 calibration MicroBlaze) are left alone. No implementation is
# rerun. Writes build/<proj>/<proj>_<app>.bit and its .bin (same format as
# run_impl.tcl's). The app must be linked entirely in the Microblaze's BRAM.
#
# Required env: PROJECT, MB_PROJECT; optional: PROJECT_ROOT, MB_CPU
#------------------------------------------------------------------------

# ---- Project variables ----
foreach var {PROJECT MB_PROJECT} {
    if {![info exists ::env($var)] || $::env($var) eq ""} {
        error "$var environment variable not set"
    }
}
set proj_name $::env(PROJECT)
set app_name  $::env(MB_PROJECT)

if {[info exists ::env(PROJECT_ROOT)]} {
    set base_dir $::env(PROJECT_ROOT)
} else {
    set base_dir [file normalize [file join [file dirname [info script]] ../../]]
}

if {[info exists ::env(MB_CPU)] && $::env(MB_CPU) ne ""} {
    set mb_cpu $::env(MB_CPU)
} else {
    set mb_cpu microblaze_riscv_0
}

set proj_dir "$base_dir/build/$proj_name"
set bit_path "$proj_dir/${proj_name}.bit"
set mmi_path "$proj_dir/${proj_name}.runs/impl_1/${proj_name}_wrapper.mmi"
set elf_path "$base_dir/microblaze/$app_name/${app_name}.elf"
set out_bit  "$proj_dir/${proj_name}_${app_name}.bit"
set out_bin  "$proj_dir/${proj_name}_${app_name}.bin"

foreach {path hint} [list \
        $bit_path "run 'make PROJECT=$proj_name impl'" \
        $mmi_path "run 'make PROJECT=$proj_name impl' (the design must contain a Microblaze)" \
        $elf_path "run 'make PROJECT=$proj_name MB_PROJECT=$app_name elf-mb'"] {
    if {![file exists $path]} {
        error "$path not found, $hint"
    }
}

# ---- Find the Microblaze in the memory map ----
# One <Processor InstPath="<design>_i/.../<instance>"> per processor
set fh [open $mmi_path r]
set mmi [read $fh]
close $fh
set procs [regexp -all -inline {<Processor[^>]*InstPath="([^"]+)"} $mmi]
set all_insts {}
set inst ""
foreach {_ path} $procs {
    lappend all_insts $path
    if {[file tail $path] eq $mb_cpu} {
        set inst $path
    }
}
if {$inst eq ""} {
    error "no processor named $mb_cpu in $mmi_path (found: [join $all_insts {, }]), set MB_CPU"
}
puts "Microblaze: $inst"

# ---- Update the BRAM contents ----
exec updatemem -force -meminfo $mmi_path -data $elf_path -proc $inst \
    -bit $bit_path -out $out_bit >@ stdout 2>@ stderr

# ---- Export bin from bitstream ----
write_cfgmem -force -format bin -interface smapx32 -disablebitswap -loadbit "up 0x0 $out_bit" $out_bin

puts "wrote $out_bit"
puts "wrote $out_bin"
