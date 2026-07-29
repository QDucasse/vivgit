#!/bin/sh
# Runs ON the target board (needs fpgautil). Not a host-side script.
#
# Usage: install_firmware.sh
# Expects exactly one *.bin and one *.dtbo side by side with this script (see
# scripts/board/deploy.sh, which stages one project's files per directory in
# that layout). Locates itself via $0 so it works regardless of the caller's
# CWD, and picks up whatever project was staged instead of needing its name
# passed in.

FIRMWARE_DIR=/lib/firmware
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

BIN_FILE=$(ls "${SCRIPT_DIR}"/*.bin 2>/dev/null)
DTBO_FILE=$(ls "${SCRIPT_DIR}"/*.dtbo 2>/dev/null)

[ -n "$BIN_FILE" ] || { echo "No .bin file found in ${SCRIPT_DIR}" >&2; exit 1; }
[ -n "$DTBO_FILE" ] || { echo "No .dtbo file found in ${SCRIPT_DIR}" >&2; exit 1; }

BIN_COUNT=$(printf '%s\n' "$BIN_FILE" | wc -l)
DTBO_COUNT=$(printf '%s\n' "$DTBO_FILE" | wc -l)
[ "$BIN_COUNT" -eq 1 ] || { echo "Expected exactly one .bin file in ${SCRIPT_DIR}, found $BIN_COUNT" >&2; exit 1; }
[ "$DTBO_COUNT" -eq 1 ] || { echo "Expected exactly one .dtbo file in ${SCRIPT_DIR}, found $DTBO_COUNT" >&2; exit 1; }

BIN_NAME=$(basename "$BIN_FILE")
DTBO_NAME=$(basename "$DTBO_FILE")

echo "Clearing overlay..."
fpgautil -R

echo "Copying raw bitstream (${BIN_NAME}) and dt overlay (${DTBO_NAME})..."
cp "$BIN_FILE" "$DTBO_FILE" "${FIRMWARE_DIR}"
echo "Loading both..."
fpgautil -b "${FIRMWARE_DIR}/${BIN_NAME}" -o "${FIRMWARE_DIR}/${DTBO_NAME}"
