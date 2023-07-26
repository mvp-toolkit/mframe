##
# Macros & Variables

# show subrepo-cfgadd target only if it's defined by the app makefile:
define MFRAME_SUBREPO_CFGADD_HELP
$(if $(call mf_is_target,subrepo-cfgadd),echo "  subrepo-cfgadd name=...                 merge subrepo configs",true)
endef

# show subrepo-cfgrem target only if it's defined by the app makefile:
define MFRAME_SUBREPO_CFGREM_HELP
$(if $(call mf_is_target,subrepo-cfgrem),echo "  subrepo-cfgrem name=...                 remove subrepo configs",true)
endef

# run a bash function, defined in 'subrepo.sh':
define MFRAME_SUBREPO_RUN
export ROOT_DIR="$(ROOT_DIR)" \
MFRAME_ROOT_DIR="$(MFRAME_ROOT_DIR)" \
MFRAME_TMP_DIR="$(MFRAME_TMP_DIR)" \
MFRAME_DIR="$(MFRAME_DIR)" \
MFRAME_GIT="$(MFRAME_GIT)" \
MFRAME_TPL="$(MFRAME_TPL)" \
MFRAME_PROJECT_NAME="$(MFRAME_PROJECT_NAME)" \
SUBREPO_NAME="$(name)" \
SUBREPO_V="$(v)" \
&& source $(MFRAME_ROOT_DIR)/subrepo.sh && mf_subrepo
endef

SUBREPO_PARAMS = repo=$(repo) name=$(name)

##
# Targets

.PHONY: subrepo-help subrepo subrepo-clone subrepo-pull subrepo-pull-all \
	subrepo-push subrepo-push-all subrepo-remove	subrepo-logs subrepo-status \
	subrepo-info subrepo-gitrepo-reset

subrepo-help:
	@$(if $(inc),true,echo "Usage: make <target>" && echo)
	@echo "Subrepo management targets:"
	@echo
	@echo "  The \"name\" parameter can also be a GIT repository URL."
	@echo
	@echo "  subrepo name=...                        create a new subrepo"
	@echo "  subrepo-clone name=... [v=latest]       clone an existing subrepo"
	@echo "  subrepo-pull name=...                   pull upstream changes"
	@echo "  subrepo-pull-all                        pull upstream changes for all subrepos"
	@echo "  subrepo-push name=...                   push changes upstream"
	@echo "  subrepo-push-all                        push changes upstream for all subrepos"
	@echo "  subrepo-remove name=...                 remove a subrepo"
	@$(call MFRAME_SUBREPO_CFGADD_HELP)
	@$(call MFRAME_SUBREPO_CFGREM_HELP)
	@echo "  subrepo-status [name=...]               show brief status info"
	@echo "  subrepo-info [name=...]                 show detailed info"
	@echo "  subrepo-gitrepo-reset [name=...]        reset .gitrepo files"
	@echo

# create a new subrepo:
subrepo:
	@$(call MFRAME_SUBREPO_RUN) create

# clone an existing subrepo:
subrepo-clone:
	@$(call MFRAME_SUBREPO_RUN) clone

# run the subrepo's cloned hook:
_subrepo-hook-cloned:
	@$(if $(call mf_is_target,_$(name)-cloned),$(MAKE) _$(name)-cloned,true)

# pull upstream changes:
subrepo-pull:
	@$(call MFRAME_SUBREPO_RUN) pull

# pull upstream changes for all subrepos:
subrepo-pull-all:
	@$(call MFRAME_SUBREPO_RUN) pull_all

# push changes upstream:
subrepo-push:
	@$(call MFRAME_SUBREPO_RUN) push

# push changes upstream for all subrepos:
subrepo-push-all:
	@$(call MFRAME_SUBREPO_RUN) push_all

# remove a subrepo:
subrepo-remove:
	@$(call MFRAME_SUBREPO_RUN) remove

# run the subrepo's remove hook:
_subrepo-hook-remove:
	@$(if $(call mf_is_target,_$(name)-remove),$(MAKE) _$(name)-remove,true)

# run subrepo-cfgadd, if defined:
_subrepo-cfgadd:
	@$(if $(call mf_is_target,subrepo-cfgadd),$(MAKE) subrepo-cfgadd $(SUBREPO_PARAMS),true)

# run subrepo-cfgrem, if defined:
_subrepo-cfgrem:
	@$(if $(call mf_is_target,subrepo-cfgrem),$(MAKE) subrepo-cfgrem $(SUBREPO_PARAMS),true)

# show brief status info:
subrepo-status:
	@$(call MFRAME_SUBREPO_RUN) status

# show detailed info:
subrepo-info:
	@$(call MFRAME_SUBREPO_RUN) info

# reset .gitrepo files:
subrepo-gitrepo-reset:
	@$(call MFRAME_SUBREPO_RUN) gitrepo_reset

# subrepo lifecycle hooks:

_subrepo-created-hook:
	@$(if $(call mf_is_target,_subrepo-created),$(MAKE) _subrepo-created $(SUBREPO_PARAMS),true)

_subrepo-cloned-hook:
	@$(if $(call mf_is_target,_subrepo-cloned),$(MAKE) _subrepo-cloned $(SUBREPO_PARAMS),true)

_subrepo-pulled-hook:
	@$(if $(call mf_is_target,_subrepo-pulled),$(MAKE) _subrepo-pulled $(SUBREPO_PARAMS),true)

_subrepo-pulled-all-hook:
	@$(if $(call mf_is_target,_subrepo-pulled-all),$(MAKE) _subrepo-pulled-all $(SUBREPO_PARAMS),true)

_subrepo-pushed-hook:
	@$(if $(call mf_is_target,_subrepo-pushed),$(MAKE) _subrepo-pushed $(SUBREPO_PARAMS),true)

_subrepo-pushed-all-hook:
	@$(if $(call mf_is_target,_subrepo-pushed-all),$(MAKE) _subrepo-pushed-all $(SUBREPO_PARAMS),true)

_subrepo-removed-hook:
	@$(if $(call mf_is_target,_subrepo-removed),$(MAKE) _subrepo-removed $(SUBREPO_PARAMS),true)
