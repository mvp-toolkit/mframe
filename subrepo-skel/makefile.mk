# This Makefile is included by MFrame. It is recommended to prefix variables and
# targets with something unique to this subrepo, to avoid conflicts with
# Makefiles from other subrepos.

# subrepo directory:
#${NAME}_dir := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# called by MFrame when this subrepo is cloned:
_${NAME}-cloned:
	@true

# called by MFrame just before this subrepo is removed:
_${NAME}-remove:
	@true

# remove the leading _ to unhide this target:
_${NAME}-help:
	@$(if $(inc),true,echo "Usage: make <target>" && echo)
	@echo "Targets provided by \"${NAME}\":"
	@echo ""
	@echo "  ${NAME}-help       this help"
	@echo ""

