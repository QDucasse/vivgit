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

From there, build the project and run synthesis/implementation (each step re-runs the ones before it, so `impl` alone takes you from block design to bitstream):

```bash
make PROJECT=<name> project   # creates/refreshes the .xpr from the block design
make PROJECT=<name> synth     # project + synthesis
make PROJECT=<name> impl      # synth + implementation, produces .xsa/.bit/.bin
```

To make changes in the Vivado GUI (editing the block design, adding IP, ...), open the `.xpr` under `build/<name>/` directly. Once you're happy with the changes, sync them back into the versioned `.tcl` before committing:

```bash
make PROJECT=<name> update
```

Note that `project`/`synth`/`impl` already do this automatically before running (pass `NO_UPDATE=1` to skip it if you only want to rebuild from what's already committed).

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
| `new`          | Creates a new block design from the Zynq template in the BSP                                                     | shell  |
| `project`      | Updates the `.tcl` from GUI changes (unless `NO_UPDATE=1`), then (re)creates the Vivado project (`.xpr`) from it | vivado |
| `synth`        | Runs `project`, then performs synthesis for the project                                                          | vivado |
| `impl`         | Runs `synth`, then performs implementation, generates `.xsa`, `.bit` and `.bin` (optional `IMPL_STRATEGY`)       | vivado |
| `update`       | Updates the `.tcl` block design script with the changes made in the GUI, without touching the project            | vivado |
| `sim`          | Runs behavioral simulation for a given testbench (`TB`), dumps a `.vcd`                                          | vivado |
| `sdt`          | Generates the `sdt` from the `.xsa`                                                                              | xsct   |
| `boot`         | Generates the `BOOT.BIN` from the `.xsa` and associated petalinux build (`PLNX_PROJECT`)                         | xsct   |
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
| `NO_UPDATE`      | `0`                             | `project`                   | Set to `1` to skip propagating GUI block design changes before (re)creating the project              |
| `IMPL_STRATEGY` | *(unset, keeps current)*         | `impl`                      | Overrides the `impl_1` run's strategy before launching (e.g. `Performance_ExplorePostRoutePhysOpt`)  |
| `TB`            | *(required for `sim`)*           | `sim`                       | Name of the testbench module to simulate                                                             |
| `NJOBS`         | `8`                              | `synth`, `impl`             | Number of parallel jobs used by `launch_runs`                                                        |
| `PART_NAME`     | `xczu7ev-ffvc1156-2-e`           | `project`                   | Target FPGA part                                                                                     |
| `BOARD_NAME`    | `xilinx.com:zcu104:part0:1.1`    | `project`                   | Target board part                                                                                    |
| `BOARD_DTS`     | `zcu104-revc`                    | `sdt`                       | Board DTS name passed to `sdtgen`                                                                    |
| `PLNX_PROJECT`  | *(required for `boot`)*          | `boot`                      | Path to the associated PetaLinux project (for `u-boot.elf`, `bl31.elf`, `system.dtb`)                |
| `BOARD_DEST`    | *(required for `deploy`)*        | `deploy`                    | Destination directory for staged firmware (local path, or path on `BOARD_HOST`)                      |
| `BOARD_HOST`    | *(unset, stages locally)*        | `deploy`                    | `user@host` to stage over SSH instead of a local path                                                |
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

TODO:


## Microblaze

TODO:

### Misc


Note that each tool has its command wrapped in a given script in `env/`, this simplifies the environment variables passing from `make` to the end programs.