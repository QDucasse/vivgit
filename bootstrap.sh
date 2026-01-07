#!/bin/bash
set -e

PROJECT_ROOT=$(pwd)

# Directories to create
dirs=("bd" "sim" "constraints" "rtl" "src" "ip")

echo "Creating project directories..."
for d in "${dirs[@]}"; do
    mkdir -p "$PROJECT_ROOT/$d"
done

# Copy Makefile from bootstrap
echo "Copying Makefile..."
cp -v "$PROJECT_ROOT/scripts/bootstrap/Makefile" "$PROJECT_ROOT/Makefile"

# Copy .gitignore
echo "Copying .gitignore..."
cp -v "$PROJECT_ROOT/scripts/.gitignore" "$PROJECT_ROOT/.gitignore"

echo "Project structure initialized."
echo "Continue with 'git init', and consider adding vivgit as a submodule."
echo "Create a new project with 'make PROJECT=<name> new'."