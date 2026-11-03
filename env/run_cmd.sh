#!/bin/bash
set -e

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Vitis environment (toolchains for the Microblaze builds)
xilinx_env Vitis

# Execute the tool from PATH
exec "$@"