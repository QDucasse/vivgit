#!/bin/bash
#------------------------------------------------------------------------
# build_summary.sh: one-file summary of the last build of a project, in
#                   build/reports/$PROJECT/summary.txt
#
# Gathers what the other steps recorded: impl/impl_info.txt (Vivado,
# strategy, timing, from run_impl.tcl), the utilization report, the
# critical warnings of synth and impl, the CDC counts (run_cdc.tcl) when
# `cdc` ran on this bitstream, and the SHA-256 of build/$PROJECT/$PROJECT.bin
# to tell which bitstream a board runs. `deploy` stages it next to the .bin.
#
# Usage: build_summary.sh [--record-git]
#   --record-git  record the commits of the design repository and of vivgit
#                 (git describe --dirty: modified tracked files) in
#                 impl/git_info.txt. Run right after impl, so the summary
#                 describes the sources that were built, not later ones.
#
# Env: PROJECT, PROJECT_ROOT (required); SCRIPTS_DIR (default
# $PROJECT_ROOT/scripts).
#------------------------------------------------------------------------
set -e

: "${PROJECT:?PROJECT not set}"
: "${PROJECT_ROOT:?PROJECT_ROOT not set}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_ROOT/scripts}"

build_dir="$PROJECT_ROOT/build/$PROJECT"
report_dir="$PROJECT_ROOT/build/reports/$PROJECT"
impl_info="$report_dir/impl/impl_info.txt"
git_info="$report_dir/impl/git_info.txt"
cdc_counts="$report_dir/cdc/cdc_counts.txt"
bin="$build_dir/$PROJECT.bin"
summary="$report_dir/summary.txt"

git_line() {  # git_line <dir>: describe (dirty if tracked files modified), subject
    git -C "$1" log -1 --format="$(git -C "$1" describe --always --dirty --abbrev=12) %s" 2>/dev/null \
        || echo "(not a git repository)"
}

if [ ! -f "$impl_info" ]; then
    echo "no build summary: $impl_info not found (impl not run, or failed)"
    exit 0
fi

if [ "$1" = "--record-git" ]; then
    {
        echo "design: $(git_line "$PROJECT_ROOT")"
        echo "vivgit: $(git_line "$SCRIPTS_DIR")"
    } > "$git_info"
fi

value() {  # value <file> <key>: the rest of the "key: ..." line
    sed -n "s/^$2: //p" "$1" 2>/dev/null | head -1
}

# First row of the utilization table for each resource
# (UltraScale names, then 7-series ones)
utilization() {
    local rpt
    rpt=$(ls "$report_dir"/impl/*utilization_placed.rpt 2>/dev/null | head -1)
    [ -n "$rpt" ] || { echo "  (no utilization report)"; return; }
    awk -F'|' '
        function trim(s) { gsub(/^ +| +$/, "", s); return s }
        {
            name = trim($2)
            if ((name == "CLB LUTs" || name == "Slice LUTs" || name == "CLB Registers" ||
                 name == "Slice Registers" || name == "Block RAM Tile" || name == "URAM" ||
                 name == "DSPs") && !(name in seen)) {
                seen[name] = 1
                printf "  %-16s %8s / %-8s %6s%%\n", name, trim($3), trim($6), trim($7)
            }
        }' "$rpt"
}

count_lines() {  # count_lines <file>: number of lines, or "not run"
    if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo "not run"; fi
}

{
    echo "Build summary: $PROJECT"
    echo
    echo "built:     $(value "$impl_info" date)"
    if [ -f "$git_info" ]; then
        echo "design:    $(value "$git_info" design)"
        echo "vivgit:    $(value "$git_info" vivgit)"
    fi
    echo "vivado:    $(value "$impl_info" vivado), part $(value "$impl_info" part)"
    echo "strategy:  $(value "$impl_info" impl_strategy)"
    if [ -f "$bin" ]; then
        echo "bitstream: $PROJECT.bin, sha256 $(sha256sum "$bin" | cut -d' ' -f1)"
    fi
    echo
    echo "timing:    $(value "$impl_info" timing)"
    echo "  WNS $(value "$impl_info" wns)  TNS $(value "$impl_info" tns)  WHS $(value "$impl_info" whs)  THS $(value "$impl_info" ths)  TPWS $(value "$impl_info" tpws)"
    echo
    echo "utilization:"
    utilization
    echo
    echo "critical warnings: synth $(count_lines "$report_dir/synth/critical_warnings.txt"), impl $(count_lines "$report_dir/impl/critical_warnings.txt")"
    # CDC counts only describe this bitstream if cdc ran after it was built
    if [ -f "$cdc_counts" ] && { [ ! -f "$bin" ] || [ "$cdc_counts" -nt "$bin" ]; }; then
        echo "cdc ($(value "$cdc_counts" run)): $(value "$cdc_counts" cdc)"
    else
        echo "cdc: not run on this build (make PROJECT=$PROJECT cdc)"
    fi
} > "$summary"

echo "wrote $summary"
