# vivgit: all targets and defaults live in the submodule, see scripts/README.md.
# Project settings go in config.mk and config/<PROJECT>.mk, not here.
PROJECT_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
include $(PROJECT_ROOT)/scripts/bootstrap/Makefile.main
