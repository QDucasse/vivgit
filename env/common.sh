#!/bin/bash
# common.sh: sourced by the run_*.sh wrappers to set up the Xilinx environment.
#
# Usage: xilinx_env <tool> [<tool> ...]
#   Sources the settings64.sh of the first tool found, in the given order, for
#   $XILINX_VERSION under $XILINX_ROOT. Both install layouts are supported:
#     $XILINX_ROOT/<tool>/<version>/settings64.sh   (up to 2024.x)
#     $XILINX_ROOT/<version>/<tool>/settings64.sh   (unified installer, 2025.1+; untested)

: "${XILINX_ROOT:?XILINX_ROOT not set}"
: "${XILINX_VERSION:?XILINX_VERSION not set}"

xilinx_env() {
    local tool settings tried=() tools
    tools=$(printf '%s or ' "$@"); tools=${tools% or }
    for tool in "$@"; do
        for settings in "$XILINX_ROOT/$tool/$XILINX_VERSION/settings64.sh" \
                        "$XILINX_ROOT/$XILINX_VERSION/$tool/settings64.sh"; do
            if [ -f "$settings" ]; then
                set --  # settings64.sh must not see our arguments
                . "$settings"
                return 0
            fi
            tried+=("$settings")
        done
    done
    echo "error: no $tools $XILINX_VERSION install found under $XILINX_ROOT, tried:" >&2
    printf '    %s\n' "${tried[@]}" >&2
    echo "Set XILINX_ROOT/XILINX_VERSION to match your install." >&2
    exit 1
}
