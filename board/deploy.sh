#!/bin/bash
set -e

# Stages build/$PROJECT/$PROJECT.{bin,dtbo} and scripts/board/install_firmware.sh
# into $BOARD_DEST/$PROJECT/. Staging only: the actual install needs root and
# reconfigures live hardware, so it's always run by hand on the board.
#
# Required: PROJECT, PROJECT_ROOT, BOARD_DEST
# Optional: BOARD_HOST (user@host), stage over SSH instead of a local path
#           MB_PROJECT, stage the bitstream with that Microblaze app in BRAM
#           (build/$PROJECT/${PROJECT}_$MB_PROJECT.bin, from `make bit-mb`)
#           instead. It is staged as $PROJECT.bin, the name the overlay's
#           firmware-name expects.

: "${PROJECT:?PROJECT not set}"
: "${PROJECT_ROOT:?PROJECT_ROOT not set}"
: "${BOARD_DEST:?BOARD_DEST not set (e.g. /home/user/vivproj, or a path on the remote host)}"

BUILD_DIR="$PROJECT_ROOT/build/$PROJECT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_firmware.sh"
DEST="$BOARD_DEST/$PROJECT"

if [ -n "$MB_PROJECT" ]; then
    BIN="$BUILD_DIR/${PROJECT}_$MB_PROJECT.bin"
    BIN_HINT="make PROJECT=$PROJECT MB_PROJECT=$MB_PROJECT bit-mb"
else
    BIN="$BUILD_DIR/$PROJECT.bin"
    BIN_HINT="make PROJECT=$PROJECT impl"
fi
[ -f "$BIN" ] || { echo "Missing $BIN -- run '$BIN_HINT' first" >&2; exit 1; }
[ -f "$BUILD_DIR/$PROJECT.dtbo" ] || { echo "Missing $BUILD_DIR/$PROJECT.dtbo -- run 'make PROJECT=$PROJECT dtbo' first" >&2; exit 1; }

# Build summary (helpers/build_summary.sh), staged as ${PROJECT}_summary.txt.
# With MB_PROJECT, the staged copy also names the app and the staged .bin.
SUMMARY="$PROJECT_ROOT/build/reports/$PROJECT/summary.txt"
STAGED_SUMMARY=""
if [ -f "$SUMMARY" ]; then
    STAGED_SUMMARY="$SUMMARY"
    if [ -n "$MB_PROJECT" ]; then
        STAGED_SUMMARY="$PROJECT_ROOT/build/reports/$PROJECT/summary_$MB_PROJECT.txt"
        {
            cat "$SUMMARY"
            echo
            echo "staged:    $(basename "$BIN") as $PROJECT.bin, Microblaze app $MB_PROJECT in BRAM (bit-mb)"
            echo "           sha256 $(sha256sum "$BIN" | cut -d' ' -f1)"
        } > "$STAGED_SUMMARY"
    fi
else
    echo "No build summary ($SUMMARY), staging without one"
fi

# Group-write, so BOARD_DEST can be shared between NFS and SSH writers with
# different UIDs. Group ownership itself comes from BOARD_DEST's setgid bit.
# No group name needed here, that's on the developer to set up.
if [ -n "$BOARD_HOST" ]; then
    echo "Staging $PROJECT to $BOARD_HOST:$DEST ..."
    ssh "$BOARD_HOST" "mkdir -p '$DEST'"
    scp "$BIN" "$BOARD_HOST:$DEST/$PROJECT.bin"
    scp "$BUILD_DIR/$PROJECT.dtbo" "$INSTALL_SCRIPT" "$BOARD_HOST:$DEST/"
    # A summary left from an earlier staging would describe another bitstream
    ssh "$BOARD_HOST" "rm -f '$DEST/${PROJECT}_summary.txt'"
    [ -n "$STAGED_SUMMARY" ] && scp "$STAGED_SUMMARY" "$BOARD_HOST:$DEST/${PROJECT}_summary.txt"
    ssh "$BOARD_HOST" "chmod g+rw '$DEST'/* && chmod +x '$DEST/install_firmware.sh'"
else
    echo "Staging $PROJECT to $DEST ..."
    mkdir -p "$DEST"
    rsync -rlptDvz --chmod=Fg+rw "$BIN" "$DEST/$PROJECT.bin"
    rsync -rlptDvz --chmod=Fg+rw "$BUILD_DIR/$PROJECT.dtbo" "$INSTALL_SCRIPT" "$DEST/"
    rm -f "$DEST/${PROJECT}_summary.txt"
    [ -n "$STAGED_SUMMARY" ] && rsync -rlptDvz --chmod=Fg+rw "$STAGED_SUMMARY" "$DEST/${PROJECT}_summary.txt"
fi

[ -n "$MB_PROJECT" ] && echo "Staged $(basename "$BIN") as $PROJECT.bin (Microblaze app $MB_PROJECT in BRAM)."
echo "Staged at $DEST (install_firmware.sh refreshed alongside it)."
echo "On the board: cd $BOARD_DEST/$PROJECT && sh install_firmware.sh"
