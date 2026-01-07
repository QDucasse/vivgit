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

The following `make` targets are provided:

| make command   | description                                                                            | tool   |
| -------------- | -------------------------------------------------------------------------------------- | ------ |
| `new`          | Creates a new block design from the Zynq template in the BSP                           | shell  |
| `project`      | Creates a new Vivado project (`.xpr`) from a given block design                        | vivado |
| `synth`        | Performs synthesis/implementation for the project, generates `.xsa` and `.bit`         | vivado |
| `update`       | Updates the `.tcl` script with the changes made in the GUI                             | vivado |
| `sdt`          | Generates the `sdt` from the `xsa`                                                     | xsct   |
| `boot`         | Generates the `BOOT.BIN` from the `.xsa` and associated petalinux build                | xsct   |
| `bsp`          | Generates the BSP using the `.xsa`, allowing the development of (e.g.) Microblaze apps | vitis  |


### Misc


Note that each tool has its command wrapped in a given script in `env/`, this simplifies the environment variables passing from `make` to the end programs.