#!/bin/bash
set -e

PROJECT_ROOT=$(pwd)
BOOTSTRAP_DIR="$PROJECT_ROOT/scripts/bootstrap"

# Directories to create
dirs=("bd" "sim" "constraints" "rtl" "rtl/attic" "src" "ip" "microblaze")

echo "Creating project directories..."
for d in "${dirs[@]}"; do
    mkdir -p "$PROJECT_ROOT/$d"
done

# Copies src to dst, unless dst already exists (never overwrites)
install_file() {
    local src=$1 dst=$2
    if [ -e "$PROJECT_ROOT/$dst" ]; then
        echo "Keeping existing $dst"
    else
        cp -v "$src" "$PROJECT_ROOT/$dst"
    fi
}

# The Makefile only includes scripts/bootstrap/Makefile.main, so updating the
# submodule updates the targets
install_file "$BOOTSTRAP_DIR/Makefile.stub" Makefile
install_file "$BOOTSTRAP_DIR/config.mk.example" config.mk
install_file "$PROJECT_ROOT/scripts/.gitignore" .gitignore

echo "Project structure initialized."
echo "Set your board in config.mk, then create a new project with 'make PROJECT=<name> new'."
