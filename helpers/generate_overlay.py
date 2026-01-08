#!/usr/bin/env python3

# generate_overlay.py: from a given pl.dtsi (as part of the sdt), generates an overlay that
#       consists of two main sections:
#
# 1) A header and the associated bitstream (bin format) name
# \___________
# /dts-v1/;
# /plugin/;
# &fpga_full {
#   firmware-name = "proj_name.bin";
# };
#
# 2) The amba_pl components
# \___________
# &amba {
# ...
# }

import os
import re

# ---- Names
proj_name      = os.environ.get("PROJECT")

proj_root      = os.environ.get("PROJECT_ROOT")
build_dir      = f"{proj_root}/build/{proj_name}"
sdt_dir        = f"{build_dir}/{proj_name}.sdt"
dts_path       = f"{sdt_dir}/pl.dtsi"
overlay_path   = f"{build_dir}/{proj_name}_overlay.dtsi"


# ---- Extraction functions
def extract_block(text, node_name):
    # Find the node name
    pattern = re.compile(rf'{node_name}\s*{{', re.M)
    match = pattern.search(text)
    if not match:
        return None

    # Walk character by character to find the closing brace
    start = match.start()
    brace = 0
    for i in range(match.end(), len(text)):
        if text[i] == '{':
            brace += 1
        elif text[i] == '}':
            if brace == 0:
                return text[start:i+1]
            brace -= 1
    raise RuntimeError("Unbalanced braces")


# Given:
#    amba_pl { child1 { ... }; child2 { ... }; }
# Return:
#    [ 'child1 { ... }', 'child2 { ... }' ]
def extract_children(block):
    # Strip outer braces
    body = block[block.find('{')+1:block.rfind('}')]

    children = []
    i = 0

    while i < len(body):
        # Look for next child opening
        brace_pos = body.find('{', i)
        if brace_pos == -1:
            break

        # Child name starts at previous newline
        name_start = body.rfind('\n', 0, brace_pos) + 1

        brace_depth = 0
        j = brace_pos

        while j < len(body):
            if body[j] == '{':
                brace_depth += 1
            elif body[j] == '}':
                brace_depth -= 1
                if brace_depth == 0:
                    children.append(body[name_start:j+1].strip())
                    i = j + 1
                    break
            j += 1

    return children


# ---- Main process
def process_dts(dts_path):
    with open(dts_path) as f:
        text = f.read()

    amba_pl = extract_block(text, "amba_pl")
    if not amba_pl:
        raise RuntimeError("No amba_pl found")

    children = extract_children(amba_pl)

    with open(overlay_path, "w") as out:
        out.write("/dts-v1/;\n/plugin/;\n\n")

        out.write("&fpga_full {\n")
        out.write(f'\tfirmware-name = "{proj_name}.bin";\n')
        out.write("};\n\n")

        out.write("&amba {\n")
        for c in children:
            out.write("\t" + c + ";\n")
        out.write("};\n")


if __name__ == "__main__":
    process_dts(dts_path)