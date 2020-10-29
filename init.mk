##
# Macros & Variables

ifndef ROOT_DIR
  $(error ERROR: Variable ROOT_DIR must be defined)
endif

# MFrame root directory:
MF_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# include some useful macros:
include $(MF_DIR)/lib.mk

# path to modules directory (defaults to parent directory of MF_DIR):
ifndef MODULES_DIR
  MODULES_DIR = $(patsubst $(ROOT_DIR)/%/,%,$(dir $(MF_DIR)))
endif

# help targets defined in other installed modules:
MF_HELP_TARGETS = $(filter-out mframe-help module-help,$(filter %-help,$(call mf_targets,true)))

##
# Targets

.PHONY: mframe-help mframe-info

mframe-help:
	@$(if $(inc),true,echo "Usage: make <target>" && echo)
	@$(MAKE) module-help inc=1
	@for t in $(MF_HELP_TARGETS); do $(MAKE) $$t inc=1; done

mframe-info:
	@echo
	@echo "Configuration:"
	@echo
	@echo "  MODULES_DIR: $(MODULES_DIR)"
	@echo "  MODULES_GIT: $(MODULES_GIT)"
	@echo "  MODULES_TMP: $(MODULES_TMP)"
	@echo "  MODULES_TPL: $(MODULES_TPL)"
	@echo "  MODULES_PFX: $(MODULES_PFX)"
	@echo

# add targets for module management:
include $(MF_DIR)/modules.mk

# add targets defined in all other installed modules:
include $(wildcard $(MODULES_DIR)/*/makefile.mk)
