#!/bin/bash
set -e

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

xilinx_env Vitis Vivado
# Keep Vivado's log and journal under build/logs/ (named after the script)
# instead of piling up vivado*.log/.jou in the directory make runs from.
log_args=()
if [ -n "$PROJECT_ROOT" ]; then
    log_dir="$PROJECT_ROOT/build/logs"
    mkdir -p "$log_dir"
    name=$(basename "$1" .tcl)
    log_args=(-log "$log_dir/$name.log" -journal "$log_dir/$name.jou")
fi

exec vivado -mode batch "${log_args[@]}" -source "$@"