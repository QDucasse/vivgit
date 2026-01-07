#------------------------------------------------------------------------
# generate_sdt.tcl: generates the SDT from the XSA
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

if {[info exists ::env(BOARD_DTS)]} {
    set board_dts $::env(BOARD_DTS)
} else {
    error "BOARD_DTS environment variable not set"
}

# Paths relative to project root
set proj_dir    [file join $base_dir build $proj_name]
set sdt_dir     [file join $proj_dir "${proj_name}.sdt"]
set xsa_path    [file join $proj_dir "${proj_name}.xsa"]

# Ensure output directory exists
file mkdir $sdt_dir

# Set DT parameters for SDT generation
sdtgen set_dt_param -xsa $xsa_path -dir $sdt_dir -board_dts $board_dts

# Generate SDT
sdtgen generate_sdt
