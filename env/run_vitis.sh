#!/bin/bash
set -e

: "${XILINX_ROOT:?XILINX_ROOT not set}"
: "${XILINX_VERSION:?XILINX_VERSION not set}"

. "$XILINX_ROOT/Vitis/$XILINX_VERSION/settings64.sh"

# In case of libssl not found, see https://adaptivesupport.amd.com/s/article/000036395?language=en_US
export LD_LIBRARY_PATH="$XILINX_ROOT/Vitis/$XILINX_VERSION/tps/lnx64/cmake-3.24.2/libs/Rhel/9":$LD_LIBRARY_PATH

exec vitis -s "$@"