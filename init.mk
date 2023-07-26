##
# Macros & Variables

ifndef ROOT_DIR
  $(error ERROR: Variable ROOT_DIR must be defined)
endif

# MFrame root directory:
MFRAME_ROOT_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# temp directory:
MFRAME_TMP_DIR = $(ROOT_DIR)/.git/tmp/mframe

# include some useful macros:
include $(MFRAME_ROOT_DIR)/lib.mk

# path to subrepos directory (defaults to parent directory of MFRAME_ROOT_DIR):
ifndef MFRAME_DIR
  MFRAME_DIR = $(patsubst $(ROOT_DIR)/%/,%,$(dir $(MFRAME_ROOT_DIR)))
endif

ifndef MFRAME_TPL
  MFRAME_TPL = empty
endif

ifndef MFRAME_PROJECT_NAME
  MFRAME_PROJECT_NAME = $(subst $(dir $(ROOT_DIR)),,$(ROOT_DIR))
endif

# help targets defined in other installed subrepos:
MFRAME_HELP_TARGETS = $(filter-out mframe-help subrepo-help,$(filter %-help,$(call mf_targets,true)))

##
# Targets

.PHONY: mframe-help mframe-info

mframe-help:
	@$(if $(inc),true,echo "Usage: make <target>" && echo)
	@$(MAKE) subrepo-help inc=1
	@for t in $(MFRAME_HELP_TARGETS); do $(MAKE) $$t inc=1; done

mframe-info:
	@echo
	@echo "Configuration:"
	@echo
	@echo "  MFRAME_DIR: $(MFRAME_DIR)"
	@echo "  MFRAME_GIT: $(MFRAME_GIT)"
	@echo "  MFRAME_TPL: $(MFRAME_TPL)"
	@echo
	@echo "  MFRAME_PROJECT_NAME: $(MFRAME_PROJECT_NAME)"
	@echo

# add targets for subrepo management:
include $(MFRAME_ROOT_DIR)/subrepo.mk

# add targets defined in all other installed subrepos:
include $(wildcard $(MFRAME_DIR)/*/makefile.mk)
