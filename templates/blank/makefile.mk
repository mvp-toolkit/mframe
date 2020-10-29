# This makefile is included by MFrame's Makefile. It is recommended to prefix
# variables and targets with this module's name, to avoid conflicts with
# makefiles from other modules.

# module directory:
#${NAME}_dir := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# called by MFrame when this module is cloned:
_${NAME}-cloned:
	@true

# called by MFrame just before this module is removed:
_${NAME}-remove:
	@true

# remove the leading _ to unhide this target:
_${NAME}-help:
	@$(if $(inc),true,echo "Usage: make <target>" && echo)
	@echo "Targets provided by the \"${NAME}\" module:"
	@echo ""
	@echo "  ${NAME}-help       this help"
	@echo ""

