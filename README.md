# vivgit: Reproducible Vivado versioning

This project provides a collection of TCL scripts to version a Vivado project using git. Its aim is to be used as a submodule of the actual design, like a simplified version of [Hog](https://github.com/Hog-CERN/Hog).


### Installation

The expected project structure for your Vivado project is the following:

```bash
.
├── bd
│   ├── bd1.tcl    # Block design
│   └── bd2.tcl    # Block design
├── build          # Build directory, where everything gets generated
├── constraints    # Any constraint file, organized by project
│   ├── proj1
│   │   └── timing.xdc
│   └── proj2
│       └── timing.xdc
├── ip             # Any .xci IP file
├── README.md      # Readme for your project
├── rtl            # RTL files for your modules
│   ├── module1
│   └── module2
├── scripts        # THIS REPOSITORY!
│   ├── create_project.tcl
│   ├── run_synth_impl.tcl
│   └── update_bd.tcl
```

Starting from an empty git project, you can add it as a submodule with:
```bash
git init
git submodule add https://github.com/QDucasse/vivgit scripts
```

You can then copy the `.gitignore` in your root directory with:
```bash
cp scripts/.gitignore .gitignore
```

### Usage

The objective of these scripts is to be compatible with the Vivado GUI while versioning the changes. To start using the three included scripts, the only thing you need is to export your block design as a TCL file and place it under the `bd/` directory, from the Vivado GUI:

```bash
write_bd_tcl ./mybd.tcl -force
```

The repository contains three basic scripts:
- `create_project.tcl`: sets up the project based on the block design in `bd/<bd_name>.tcl`, the resulting project can be opened with vivado using the resulting `<proj_name>.xpr` in the `build/<proj_name>/` directory.
- `run_synth_impl.tcl`: launches the synthesis and implementation steps for the design, copying any generated reports into the `build/reports/` directory.
- `update_bd.tcl`: apply changes in the GUI to the `bd/<proj_name>.tcl` file.

You can now completely recreate the project with `create_project.tcl`, it gets created in `build/<proj_name>`. All scripts expect the name of the project to be supplied as argument (that corresponds to your block design as well). You can pass it with:
```bash
vivado -mode batch scripts/create_project.tcl -tclargs <proj_name>
# Or from the interactive mode
vivado -mode tcl
Vivado% set argv {"<proj_name>"}
Vivado% source scripts/create_project.tcl
```