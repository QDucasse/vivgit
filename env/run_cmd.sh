#!/bin/bash
set -e

: "${XILINX_ROOT:?XILINX_ROOT not set}"
: "${XILINX_VERSION:?XILINX_VERSION not set}"

# Source Vitis environment
. "$XILINX_ROOT/Vitis/$XILINX_VERSION/settings64.sh"

# Execute the tool from PATH
exec "$@"