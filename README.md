# vivgit: Reproducible Vivado versioning

This project provides a collection of TCL scripts to version a Vivado project using git. Its aim is to be used as a submodule of the actual design, like a simplified version of [Hog](https://github.com/Hog-CERN/Hog).


### Installation

Starting from an empty git project, you can add it as a submodule with:
```bash
git init
git submodule add https://github.com/QDucasse/vivgit scripts
git submodule update --init
```

You can then launch the `bootstrap.sh` script with:
```bash
./scripts/bootstrap.sh
```

That creates the main directories of the project structure, and copies `Makefile` and `.gitignore`:

```bash
.
├── bd
│   ├── bd1.tcl    # Block design
│   └── ...
├── build          # Build directory, where everything gets generated
├── constraints    # Any constraint file, organized by project
│   ├── proj1
│   │   └── timing.xdc
│   └── proj2
│       └── timing.xdc
├── ip             # Any .xci IP file
│   └── ...
├── Makefile       # THIS REPOSITORY! < Copied from scripts
├── README.md      # Readme for your project
├── rtl            # RTL files for your modules
│   ├── module1    # RTL sources
│   └── ...
├── scripts        # THIS REPOSITORY!
│   └── ...
├── .gitignore     # THIS REPOSITORY! < Copied from scripts
```


### Usage

The objective of these scripts is to be compatible with the Vivado GUI while versioning the changes. To start using `vivgit`, you can create a new project form a template, consisting only of the Zynq IP, as it is in Xilinx BSP's:

```bash
make PROJECT=<name> new
```

From there, build the project and run synthesis/implementation:

```bash
make PROJECT=<name> project   # creates/refreshes the .xpr from the block design
make PROJECT=<name> synth     # project + synthesis
make PROJECT=<name> impl      # implementation only, produces .xsa/.bit/.bin
```

`synth` re-runs `project` first, but **`impl` deliberately does not depend on `synth`**: `project` runs `create_project -force`, which recreates the project from scratch and discards any existing synthesis run. Keeping `impl` independent is what allows a different `IMPL_STRATEGY` to be tried against one synthesis result. Vivado's `launch_runs` will still re-run `synth_1` on its own if it considers it stale.

To generate a device tree overlay and load the design on a board, chain `overlay` to `dtbo`:

```bash
make PROJECT=<name> impl                     # need .xsa + .bit first
make PROJECT=<name> overlay                  # extracts amba_pl into an overlay .dtsi (depends on sdt)
make PROJECT=<name> dtbo                     # compiles the overlay into a .dtbo
```

> **Note**: The `dtbo` intentionally does not depend on `overlay` incase changes need to be done. An automated one is
> to replace occurences of `imux` (interrupt multiplexer) to the `gic` (general interrupt controller) in the ZCU104 case.

The `.bin`/`.dtbo` pair can then be staged to a board and loaded, see `deploy` below.

The following `make` targets are provided:

| make command   | description                                                                                                      | tool   |
| -------------- | ---------------------------------------------------------------------------------------------------------------- | ------ |
| `new`          | Creates `bd/<name>.tcl` from a block design template (`TEMPLATE`), never overwriting an existing one             | shell  |
| `project`      | Updates the `.tcl` from GUI changes (unless `NO_UPDATE=1`), then (re)creates the Vivado project (`.xpr`) from it | vivado |
| `synth`        | Runs `project`, then performs synthesis for the project                                                          | vivado |
| `impl`         | Performs implementation, generates `.xsa`, `.bit` and `.bin` (optional `IMPL_STRATEGY`). Does *not* re-run `synth` | vivado |
| `check-bd`     | Reports whether the project's block design matches the checked-in `bd/<name>.tcl`, without building anything     | shell  |
| `update`       | Updates the `.tcl` block design script with the changes made in the GUI, without touching the project            | vivado |
| `sim`          | Runs behavioral simulation for a given testbench (`TB`), dumps a `.vcd`                                          | vivado |
| `sdt`          | Generates the `sdt` from the `.xsa`                                                                              | xsct   |
| `boot`         | Generates the `BOOT.BIN` from the `.xsa` and prebuilt `bl31.elf`/`u-boot.elf`/`system.dtb` (`BOOT_FW_DIR`)      | xsct   |
| `bsp`          | Generates the BSP using the `.xsa`, allowing the development of (e.g.) Microblaze apps                           | vitis  |
| `overlay`      | Runs `sdt`, then generates a device-tree overlay (`_overlay.dtsi`) from the `sdt`'s `pl.dtsi`                    | shell  |
| `dtbo`         | Compiles the overlay into a `.dtbo` with `dtc`                                                                   | shell  |
| `deploy`       | Stages the project's `.bin`/`.dtbo` and `install_firmware.sh` to a board (`BOARD_DEST`, optional `BOARD_HOST`)   | shell  |
| `mb`           | Scaffolds a new Microblaze sub-project directory under `microblaze/` (`MB_PROJECT`)                              | shell  |
| `elf-mb`       | Builds the `.elf`/`.bin`/`.dump` for a Microblaze sub-project (`MB_PROJECT`)                                     | shell  |
| `clean-mb`     | Cleans the build artifacts of a Microblaze sub-project (`MB_PROJECT`)                                            | shell  |

Every target requires `PROJECT=<name>` to select which project to operate on. The following variables further configure these targets:

| variable        | default                          | used by                     | description                                                                                          |
| --------------- | -------------------------------- | --------------------------- | ---------------------------------------------------------------------------------------------------- |
| `PROJECT`       | *(required)*                     | all                         | Name of the target project                                                                           |
| `TEMPLATE`      | `zynq_ultra`                     | `new`                       | Block design template, from `scripts/bootstrap/templates/<TEMPLATE>.tcl`                             |
| `NO_UPDATE`     | `0`                              | `project`, `synth`          | Set to `1` to skip exporting the project's block design over `bd/<name>.tcl`. **Required when you hand-edited the `.tcl`**, otherwise the edit is overwritten |
| `ALLOW_STALE_BD`| `0`                              | `project`, `impl`, `check-bd` | Set to `1` to downgrade the block design staleness guard from an error to a warning                  |
| `ALLOW_MISSING_PINS` | `0`                          | `project`, `synth`          | Set to `1` to build even if the BD tcl connects pins that no longer exist (e.g. a renamed RTL port). Those connections are dropped, so this is for debugging only |
| `IMPL_STRATEGY` | *(unset, keeps current)*         | `impl`                      | Overrides the `impl_1` run's strategy before launching (e.g. `Performance_ExplorePostRoutePhysOpt`)  |
| `TB`            | *(required for `sim`)*           | `sim`                       | Name of the testbench module to simulate                                                             |
| `SIM_TIME`      | `2000 ns`                        | `sim`                       | Simulation length passed to xsim's `run` (e.g. `10 us`, or `all`)                                    |
| `NJOBS`         | `8`                              | `synth`, `impl`             | Number of parallel jobs used by `launch_runs`                                                        |
| `PART_NAME`     | `xczu7ev-ffvc1156-2-e`           | `project`                   | Target FPGA part                                                                                     |
| `BOARD_NAME`    | `xilinx.com:zcu104:part0:1.1`    | `project`                   | Target board part                                                                                    |
| `BOARD_DTS`     | `zcu104-revc`                    | `sdt`                       | Board DTS name passed to `sdtgen`                                                                    |
| `BOOT_FW_DIR`   | *(unset)*                        | `boot`                      | Directory holding prebuilt `bl31.elf`, `u-boot.elf` and `system.dtb`, e.g. a shared per-board directory |
| `PLNX_PROJECT`  | *(unset)*                        | `boot`                      | Alternative to `BOOT_FW_DIR`: a PetaLinux project, whose `images/linux` is used                      |
| `BL31_ELF`, `UBOOT_ELF`, `SYSTEM_DTB` | *(unset)*  | `boot`                      | Override a single prebuilt file                                                                      |
| `ALLOW_INCOMPLETE_BOOT` | `0`                      | `boot`                      | Set to `1` to build `BOOT.BIN` without missing prebuilt files instead of failing (it will not boot Linux) |
| `BOARD_DEST`    | *(required for `deploy`)*        | `deploy`                    | Destination directory for staged firmware (local path, or path on `BOARD_HOST`)                      |
| `BOARD_HOST`    | *(unset, stages locally)*        | `deploy`                    | `user@host` to stage over SSH instead of a local path                                                |
| `MB_CPU`        | `microblaze_riscv_0`             | `bsp`, `elf-mb`, `clean-mb` | Instance name of the Microblaze in the block design                                                  |
| `MB_UART`       | `axi_uartlite_0`                 | `bsp`                       | Instance name of the UART used for stdin/stdout                                                      |
| `MB_PROJECT`    | current directory name           | `mb`, `elf-mb`, `clean-mb`  | Name of the Microblaze sub-project                                                                   |
| `XILINX_ROOT`   | `/opt/Xilinx`                    | all (via `env/`)            | Root install directory of the Xilinx toolchain                                                       |
| `XILINX_VERSION`| `2024.2`                         | all (via `env/`)            | Xilinx toolchain version, used to source `settings64.sh`                                             |
| `PROJECT_ROOT`  | `$(CURDIR)`                      | all                         | Root of the design project (override if invoking `make` from elsewhere)                              |

Example, running implementation with an explicit strategy and 16 parallel jobs:

```bash
make PROJECT=<name> IMPL_STRATEGY=Performance_ExplorePostRoutePhysOpt NJOBS=16 impl
```

Once a `.bin`/`.dtbo` pair is generated, deploy it to a board over NFS or SSH, then install it from the board itself:

```bash
make PROJECT=<name> BOARD_DEST=/path/on/board BOARD_HOST=user@board deploy
# on the board:
cd /path/on/board/<name> && sh install_firmware.sh
```

## Generating and using a boot image

`make PROJECT=<name> boot` builds `build/<name>/<name>.boot/BOOT.BIN` for a ZynqMP. The FSBL and PMU firmware are generated from the `.xsa`, so they follow the design's PS configuration. The bitstream is not included: it is loaded at runtime (see `deploy`).

The other three parts, `bl31.elf` (Arm Trusted Firmware), `u-boot.elf` and `system.dtb`, are not design-specific and are taken prebuilt. Keep one directory per board outside the design repos, for example from a PetaLinux build or the `pre-built/linux/images/` folder of the board's AMD BSP, and point `BOOT_FW_DIR` at it:

```bash
make PROJECT=<name> BOOT_FW_DIR=/path/to/boot-fw/zcu104 boot
```

`PLNX_PROJECT=<petalinux project>` still works and uses its `images/linux`. The build stops if one of the files is missing.

`system.dtb` describes the PS side, so it has to match the design's PS configuration: rebuild it (and `BOOT.BIN`) when the PS settings in the block design change.


## Microblaze

TODO:

### Misc

#### Which way does the block design flow?

Two scripts move the block design between the versioned `.tcl` and the Vivado project, in **opposite** directions:

| script | direction | run by |
| --- | --- | --- |
| `vivado/update_bd.tcl` | project to `bd/<name>.tcl` | `update`, and `project` unless `NO_UPDATE=1` |
| `vivado/create_project.tcl` | `bd/<name>.tcl` to project | `project`, always |

So there are two distinct workflows, and picking the wrong one loses work:

1. **Changed the design in the GUI?** Open the `.xpr` under `build/<name>/`, make the changes, then export them into the versioned `.tcl` before committing:

    ```bash
    make PROJECT=<name> update
    ```

2. **Hand-edited `bd/<name>.tcl` instead?** You must pass `NO_UPDATE=1`, otherwise `project` exports the project's *older* block design over your edit and silently loses it:

    ```bash
    make PROJECT=<name> NO_UPDATE=1 synth
    ```

#### How to use RTL from another repository?

List extra source directories in an optional `rtl.ext` file at the project root, one per line, relative to the project root. Lines starting with `#` (and anything after a `#`) are comments. The directories can be anywhere in the project, typically a subdirectory of a git submodule:

```bash
git submodule add <url> ext/<repo>
```

```
# rtl.ext
ext/<repo>/rtl/<module>
ext/<repo>/rtl/<other_module>
```

`create_project.tcl` adds the `.v`/`.sv`/`.vhd` files of each listed directory the same way as `rtl/` (recursively, skipping `attic` directories), and stops with an error if a directory is missing, typically a submodule that was not initialised (`git submodule update --init`).

#### How to invoke Vivado/Vitis commands?

Note that each tool has its command wrapped in a given script in `env/`, this simplifies the environment variables passing from `make` to the end programs.

#### What's in `helpers`?

Scripts in `helpers/` are plain shell/python called straight from `make`, without a tool wrapper, since they need neither Vivado nor Vitis: `check_bd.sh` (block design staleness guard) and `generate_overlay.py` (device-tree overlay generation).