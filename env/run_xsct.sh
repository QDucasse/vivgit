#!/bin/bash
set -e

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

xilinx_env Vitis
exec xsct "$@"