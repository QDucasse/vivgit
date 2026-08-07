#!/bin/bash
#------------------------------------------------------------------------
# check_bd.sh: guard against building a design that does not match the
#              checked-in block design tcl.
#
# The two BD scripts move in opposite directions:
#   update_bd.tcl      project -> bd/$PROJECT.tcl   (run by `project` unless NO_UPDATE=1)
#   create_project.tcl bd/$PROJECT.tcl -> project   (always run by `project`)
#
# So a hand-edit to the tcl is only applied with NO_UPDATE=1, and is silently
# overwritten otherwise. Neither case reports anything, and `impl` will happily
# implement whatever BD the project already holds -- which is how a bitstream
# can end up missing a connection that is present in the checked-in tcl.
#
# Usage: check_bd.sh <freshness|overwrite>
#   freshness  the project BD is older than the tcl, so building it would
#              produce a design that does not match what is checked in
#   overwrite  `project` is about to export the project's older BD over a
#              newer tcl, discarding the edit
#
# Env: PROJECT, PROJECT_ROOT (required); NO_UPDATE, ALLOW_STALE_BD (optional).
# Set ALLOW_STALE_BD=1 to downgrade either check to a warning.
#------------------------------------------------------------------------
set -e

: "${PROJECT:?PROJECT not set}"
: "${PROJECT_ROOT:?PROJECT_ROOT not set}"

mode="${1:?usage: check_bd.sh <freshness|overwrite>}"
no_update="${NO_UPDATE:-0}"
allow_stale="${ALLOW_STALE_BD:-0}"

bd_tcl="$PROJECT_ROOT/bd/$PROJECT.tcl"
bd_file="$PROJECT_ROOT/build/$PROJECT/$PROJECT.srcs/sources_1/bd/$PROJECT/$PROJECT.bd"

# Nothing to compare: a project that does not exist yet is not stale, and a
# missing tcl is a different problem that create_project.tcl reports itself.
[ -f "$bd_tcl" ] && [ -f "$bd_file" ] || exit 0

# Only the tcl being strictly newer indicates a pending edit.
[ "$bd_tcl" -nt "$bd_file" ] || {
    [ "$mode" = "freshness" ] && \
        echo "[+] block design in sync: bd/$PROJECT.tcl is not newer than the project BD"
    exit 0
}

# The overwrite case only arises when `project` will actually run update_bd.tcl.
if [ "$mode" = "overwrite" ] && [ "$no_update" != "0" ]; then
    exit 0
fi

echo ""
if [ "$mode" = "overwrite" ]; then
    echo "[!] bd/$PROJECT.tcl is newer than the project's block design, and"
    echo "    NO_UPDATE=0 would run update_bd.tcl, exporting the project's OLDER"
    echo "    BD over your tcl and losing the edit."
    echo ""
    echo "    To apply the tcl to the project (what you want after editing it):"
    echo "        make NO_UPDATE=1 PROJECT=$PROJECT synth"
    echo "    To deliberately export GUI changes over the tcl:"
    echo "        make ALLOW_STALE_BD=1 PROJECT=$PROJECT project"
else
    echo "[!] bd/$PROJECT.tcl is NEWER than the project's block design."
    echo "    tcl     : $bd_tcl"
    echo "    project : $bd_file"
    echo ""
    echo "    The project was created from an older BD, so this would build a"
    echo "    design that does not match the checked-in tcl."
    echo ""
    echo "    Rebuild the project from the tcl:"
    echo "        make NO_UPDATE=1 PROJECT=$PROJECT synth"
    echo "    or build the project as-is:"
    echo "        make ALLOW_STALE_BD=1 PROJECT=$PROJECT impl"
fi
echo ""

if [ "$allow_stale" = "1" ]; then
    echo "[.] ALLOW_STALE_BD=1, continuing anyway."
    exit 0
fi
exit 1
