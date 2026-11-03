# Microblaze apps with vivgit

For designs with a Microblaze-V, each app lives in its own directory `microblaze/<app>/` of the design repository and is built against a BSP that Vitis generates from the design's `.xsa`:

```bash
make PROJECT=<name> impl                           # .xsa and .bit
make PROJECT=<name> bsp                            # BSP + build/<name>/bsp.mk
make PROJECT=<name> MB_PROJECT=<app> mb            # microblaze/<app>/Makefile, then add your .c files
make PROJECT=<name> MB_PROJECT=<app> elf-mb        # microblaze/<app>/<app>.elf (.bin, .dump)
make PROJECT=<name> MB_PROJECT=<app> bit-mb        # build/<name>/<name>_<app>.bit/.bin
make PROJECT=<name> MB_PROJECT=<app> BOARD_DEST=/path/on/board deploy
```

## BSP

`bsp` builds a standalone platform for the Microblaze `MB_CPU`, with stdin/stdout on the UART `MB_UART`: the drivers of the design's IPs (`libxil`), the basic utilities (`libxilstandalone`: `xil_printf`, `Xil_In32`/`Xil_Out32`, `sleep`, caches, exceptions) and `xparameters.h`, the base addresses and settings of every peripheral. Everything the app builds need is then written to `build/<name>/bsp.mk`:

| variable        | content                                                                     |
| --------------- | --------------------------------------------------------------------------- |
| `BSP_DIR`       | the BSP's headers (`include/`), libraries (`lib/`) and specs file           |
| `BSP_LSCRIPT`   | the linker script Vitis generated from the design's memory map             |
| `MB_ARCH_FLAGS` | `-march`/`-mabi` of the Microblaze-V as configured (32/64-bit, extensions) |
| `MB_CPU`        | the Microblaze the BSP was built for                                        |

The apps only read `bsp.mk`, so rerun `bsp` after changing the Microblaze's configuration or the address map, and the apps follow. If `bsp` fails, the previous BSP and `bsp.mk` are kept.

## Apps

The `Makefile` that `mb` creates only includes `scripts/bootstrap/Makefile.microblaze`. It builds every `.c` of the app directory, and can also be run from there (`make PROJECT=<name>`, reading `config.mk` like the main `Makefile`). Per-app settings go above its `include` line:

| variable        | default                                           | description                                             |
| --------------- | ------------------------------------------------- | ------------------------------------------------------- |
| `OPT`           | `-O0 -g`                                          | Optimization and debug flags                            |
| `LSCRIPT`       | the app's `lscript.ld` if any, else `BSP_LSCRIPT` | Linker script                                           |
| `MB_ARCH_FLAGS` | from `bsp.mk`                                     | ISA flags, to override only if you know the CPU differs |

Code is compiled and linked with the same section flags as Vitis' own app builds (`-ffunction-sections -fdata-sections`, `-Wl,--gc-sections`), so only the BSP and C library functions an app calls end up in the ELF.

## Memory

The generated linker script places everything (code, data, a 1 KB stack and a 2 KB heap) in the Microblaze's local BRAM (`lmb_bram_0`), even in designs that also have DDR. A small app fits in 16 KB of BRAM; the linker reports `region 'lmb_bram_0' overflowed` otherwise. To change the layout, copy `BSP_LSCRIPT` (path in `bsp.mk`) to `microblaze/<app>/lscript.ld` and edit it, e.g. set `_HEAP_SIZE` to `0x0` when the app never calls `malloc`, or place sections in DDR (such an app can then not be used with `bit-mb`). `riscv64-unknown-elf-size` and `riscv64-unknown-elf-nm --size-sort -S` on the ELF show what takes the space.

## Running an app

The bitstream built by `impl` starts the Microblaze on a default idle loop. `bit-mb` replaces it with the app: `updatemem` writes the ELF into the Microblaze's BRAM in a copy of the bitstream, using the memory map (`.mmi`) Vivado wrote with it, without rerunning the implementation. Only the processor named `MB_CPU` is changed (e.g. a DDR4 controller's calibration MicroBlaze is left alone), and the app must be entirely in BRAM. `deploy` with `MB_PROJECT` stages that bitstream under the name the overlay expects, `<name>.bin`, and the Microblaze runs the app as soon as `install_firmware.sh` loads it.

## Moving an app from a copied Makefile

Apps created before `mb` installed a stub have a copy of `Makefile.microblaze`, often with locally edited `-march`/`-mabi` flags. Run `make PROJECT=<name> bsp` once to get `bsp.mk`, then replace the copy with the stub (`mb` does not overwrite it, so delete it first) and move any setting you changed above its `include` line.
