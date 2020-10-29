##
# Macros & Variables

MODULES_TMP = $(ROOT_DIR)/.git/tmp/mframe

# show module-cfgadd target only if it's defined by the app makefile:
define MODULES_CFGADD_HELP
$(if $(call mf_is_target,module-cfgadd),echo "  module-cfgadd id=...                 merge module configs",true)
endef

# show module-cfgrem target only if it's defined by the app makefile:
define MODULES_CFGREM_HELP
$(if $(call mf_is_target,module-cfgrem),echo "  module-cfgrem id=...                 remove module configs",true)
endef

# run a bash function, defined in 'modules.sh':
define MODULES_RUN
export ROOT_DIR="$(ROOT_DIR)" \
MF_DIR="$(MF_DIR)" \
MODULES_DIR="$(MODULES_DIR)" \
MODULES_GIT="$(MODULES_GIT)" \
MODULES_TMP="$(MODULES_TMP)" \
MODULES_TPL="$(MODULES_TPL)" \
MODULES_PFX="$(MODULES_PFX)" \
MODULE_ID="$(id)" \
MODULE_V="$(v)" \
&& source $(MF_DIR)/modules.sh && mframe_modules
endef

MODULE_PARAMS = repo=$(repo) name=$(name)

##
# Targets

.PHONY: module-help module module-clone module-pull module-pull-all \
	module-push module-push-all module-remove	module-logs module-status \
	module-info module-gitrepo-reset

module-help:
	@$(if $(inc),true,echo "Usage: make <target>" && echo)
	@echo "Module management targets:"
	@echo
	@echo "  The \"id\" parameter below can be a repository URL, a module name or a"
	@echo "  local directory (for a cloned module)."
	@echo
	@echo "  module id=...                        create a new module"
	@echo "  module-clone id=... [v=latest]       clone an existing module"
	@echo "  module-pull id=...                   pull a module's upstream changes"
	@echo "  module-pull-all                      pull upstream changes for all modules"
	@echo "  module-push id=...                   push a module's changes upstream"
	@echo "  module-push-all                      push changes upstream for all modules"
	@echo "  module-remove id=...                 remove a module"
	@$(call MODULES_CFGADD_HELP)
	@$(call MODULES_CFGREM_HELP)
	@echo "  module-status [id=...]               show brief status info"
	@echo "  module-info [id=...]                 show detailed info"
	@echo "  module-gitrepo-reset [id=...]        reset .gitrepo files"
	@echo

# create a new module:
module:
	@$(call MODULES_RUN) create

# install a module:
module-clone:
	@$(call MODULES_RUN) clone

# run the module's cloned hook:
_module-cloned:
	@$(if $(call mf_is_target,_$(name)-cloned),$(MAKE) _$(name)-cloned,true)

# update a module:
module-pull:
	@$(call MODULES_RUN) pull

# update all modules:
module-pull-all:
	@$(call MODULES_RUN) pull_all

# publish a module:
module-push:
	@$(call MODULES_RUN) push

# publish all modules:
module-push-all:
	@$(call MODULES_RUN) push_all

# remove a module:
module-remove:
	@$(call MODULES_RUN) remove

# run the module's remove hook:
_module-remove:
	@$(if $(call mf_is_target,_$(name)-remove),$(MAKE) _$(name)-remove,true)

# run module-cfgadd, if defined:
_module-cfgadd:
	@$(if $(call mf_is_target,module-cfgadd),$(MAKE) module-cfgadd $(MODULE_PARAMS),true)

# run module-cfgrem, if defined:
_module-cfgrem:
	@$(if $(call mf_is_target,module-cfgrem),$(MAKE) module-cfgrem $(MODULE_PARAMS),true)

# show brief status info:
module-status:
	@$(call MODULES_RUN) status

# show detailed info:
module-info:
	@$(call MODULES_RUN) info

# reset .gitrepo files:
module-gitrepo-reset:
	@$(call MODULES_RUN) gitrepo_reset

# module lifecycle hooks:

_module-created-hook:
	@$(if $(call mf_is_target,_module-created),$(MAKE) _module-created $(MODULE_PARAMS),true)

_module-cloned-hook:
	@$(if $(call mf_is_target,_module-cloned),$(MAKE) _module-cloned $(MODULE_PARAMS),true)

_module-pulled-hook:
	@$(if $(call mf_is_target,_module-pulled),$(MAKE) _module-pulled $(MODULE_PARAMS),true)

_module-pulled-all-hook:
	@$(if $(call mf_is_target,_module-pulled-all),$(MAKE) _module-pulled-all $(MODULE_PARAMS),true)

_module-pushed-hook:
	@$(if $(call mf_is_target,_module-pushed),$(MAKE) _module-pushed $(MODULE_PARAMS),true)

_module-pushed-all-hook:
	@$(if $(call mf_is_target,_module-pushed-all),$(MAKE) _module-pushed-all $(MODULE_PARAMS),true)

_module-removed-hook:
	@$(if $(call mf_is_target,_module-removed),$(MAKE) _module-removed $(MODULE_PARAMS),true)
