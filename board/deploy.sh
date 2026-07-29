#!/bin/bash
set -e

# Stages build/$PROJECT/$PROJECT.{bin,dtbo} and scripts/board/install_firmware.sh
# into $BOARD_DEST/$PROJECT/. Staging only: the actual install needs root and
# reconfigures live hardware, so it's always run by hand on the board.
#
# Required: PROJECT, PROJECT_ROOT, BOARD_DEST
# Optional: BOARD_HOST (user@host), stage over SSH instead of a local path

: "${PROJECT:?PROJECT not set}"
: "${PROJECT_ROOT:?PROJECT_ROOT not set}"
: "${BOARD_DEST:?BOARD_DEST not set (e.g. /home/user/vivproj, or a path on the remote host)}"

BUILD_DIR="$PROJECT_ROOT/build/$PROJECT"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_firmware.sh"

for f in "$BUILD_DIR/$PROJECT.bin" "$BUILD_DIR/$PROJECT.dtbo"; do
    [ -f "$f" ] || { echo "Missing $f -- run 'make PROJECT=$PROJECT impl'/'dtbo' first" >&2; exit 1; }
done

# Group-write, so BOARD_DEST can be shared between NFS and SSH writers with
# different UIDs. Group ownership itself comes from BOARD_DEST's setgid bit.
# No group name needed here, that's on the developer to set up.
if [ -n "$BOARD_HOST" ]; then
    echo "Staging $PROJECT to $BOARD_HOST:$BOARD_DEST/$PROJECT ..."
    ssh "$BOARD_HOST" "mkdir -p '$BOARD_DEST/$PROJECT'"
    scp "$BUILD_DIR/$PROJECT.bin" "$BUILD_DIR/$PROJECT.dtbo" "$INSTALL_SCRIPT" "$BOARD_HOST:$BOARD_DEST/$PROJECT/"
    ssh "$BOARD_HOST" "chmod g+rw '$BOARD_DEST/$PROJECT'/* && chmod +x '$BOARD_DEST/$PROJECT/install_firmware.sh'"
else
    echo "Staging $PROJECT to $BOARD_DEST/$PROJECT ..."
    mkdir -p "$BOARD_DEST/$PROJECT"
    rsync -rlptDvz --chmod=Fg+rw "$BUILD_DIR/$PROJECT.bin" "$BUILD_DIR/$PROJECT.dtbo" "$INSTALL_SCRIPT" "$BOARD_DEST/$PROJECT/"
fi

echo "Staged at $BOARD_DEST/$PROJECT (install_firmware.sh refreshed alongside it)."
echo "On the board: cd $BOARD_DEST/$PROJECT && sh install_firmware.sh"
