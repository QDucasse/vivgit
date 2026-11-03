# generate_bsp.py

import vitis
import os
import shutil

# ---- Names
proj_name      = os.environ.get("PROJECT")

proj_root      = os.environ.get("PROJECT_ROOT")
build_dir      = f"{proj_root}/build/{proj_name}"
xsa_path       = f"{build_dir}/{proj_name}.xsa"
workspace_path = f"{build_dir}/{proj_name}.vitis"

platform_name  = f"{proj_name}_platform"
app_name       = f"{proj_name}_app"

# Instance names in the block design of the Microblaze and of the UART used
# for stdin/stdout (empty means default)
mb_cpu         = os.environ.get("MB_CPU") or "microblaze_riscv_0"
mb_uart        = os.environ.get("MB_UART") or "axi_uartlite_0"
domain_name    = f"standalone_{mb_cpu}"

# ---- Client setup
client = vitis.create_client()

# Delete the workspace if already exists.
if (os.path.isdir(workspace_path)):
    shutil.rmtree(workspace_path)

client.set_workspace(workspace_path)

print(xsa_path)

# ---- Platform creation
platform = client.create_platform_component(
    name=platform_name,
    hw_design=os.path.abspath(xsa_path),
    os="standalone",
    cpu=mb_cpu,
    no_boot_bsp=True
)

domain = platform.get_domain(domain_name)

domain.set_config(
    option="os",
    param="standalone_stdout",
    value=mb_uart
)

domain.set_config(
    option="os",
    param="standalone_stdin",
    value=mb_uart
)

platform.build()

# Note: The FSBL is already handled by the Zynq part, see xsct/generate_boot.tcl for more info.
#       This generates the headers and libraries.

# ---- Application component

platform_xpfm = client.find_platform_in_repos(platform_name)

app = client.create_app_component(
    name=app_name,
    platform=platform_xpfm,
    domain=domain_name,
    template="hello_world"
)

app.build()

# Note: This is used ONLY to generate linker script

# ---- Cleanup
vitis.dispose()