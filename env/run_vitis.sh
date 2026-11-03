#!/bin/bash
set -e

. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

xilinx_env Vitis

# In case of libssl not found, see https://adaptivesupport.amd.com/s/article/000036395?language=en_US
# (the bundled cmake version differs between releases, hence the glob)
for libdir in "$XILINX_VITIS"/tps/lnx64/cmake-*/libs/Rhel/9; do
    if [ -d "$libdir" ]; then
        export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
done

exec vitis -s "$@"