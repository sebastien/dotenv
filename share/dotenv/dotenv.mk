#   __          __
#  /\ \        /\ \__
#  \_\ \    ___\ \ ,_\    __    ___   __  __
#  /'_` \  / __`\ \ \/  /'__`\/' _ `\/\ \/\ \
# /\ \L\ \/\ \L\ \ \ \_/\  __//\ \/\ \ \ \_/ |
# \ \___,_\ \____/\ \__\ \____\ \_\ \_\ \___/
#  \/__,_ /\/___/  \/__/\/____/\/_/\/_/\/__/
#
# -----------------------------------------------------------------------------
# This makefile makes sure that the dotenv-managed directory is always
# up-to-date with respect to the active profile. 
# -----------------------------------------------------------------------------
#
# TODO: Re-generate when configuration changes

# The paths to the dotenv files
DOTENV_HOME     =$(HOME)/.dotenv
DOTENV_ACTIVE   =$(DOTENV_HOME)/active
DOTENV_USER_HOME=$(HOME)
DOTENV_MANAGED  =$(DOTENV_HOME)/managed
DOTENV_INACTIVE =$(DOTENV_HOME)/inactive.lst
DOTENV_CONFIG   =$(DOTENV_HOME)/config.sh

# The list of ALL active profile dotfiles, including the .tmpl and pre and post
PROFILE_ALL      =$(shell test -e $(DOTENV_ACTIVE) && find $(DOTENV_ACTIVE)/ -name "*" -not -type d)
# The list of INACTIVE dotfiles, as listed in the inactive.lst file
PROFILE_INACTIVE =$(patsubst %,$(DOTENV_ACTIVE)/%,$(filter-out \#%,$(shell test -e $(DOTENV_HOME)/inactive.lst && cat $(DOTENV_HOME)/inactive.lst)))
# The list of ACTIVE dotfiles, minus the ones
PROFILE_ACTIVE   =$(filter-out $(PROFILE_INACTIVE),$(PROFILE_ALL))

MANAGED_ALL      =$(patsubst %.tmpl,%,$(patsubst %.pre,%,$(patsubst %.post,%,$(patsubst $(DOTENV_ACTIVE)/%,$(DOTENV_MANAGED)/%,$(PROFILE_ALL)))))
MANAGED_INACTIVE =$(PROFILE_INACTIVE:$(DOTENV_ACTIVE)/%=$(DOTENV_MANAGED)/%)
MANAGED_ACTIVE   =$(filter-out $(MANAGED_INACTIVE),$(MANAGED_ALL))

# The listr of EXPECTED managed file, which is derived from the active sources
MANAGED_EXISTING =$(shell test -e $(DOTENV_MANAGED) && find $(DOTENV_MANAGED)/ -name "*" -not -type d)
MANAGED_MISSING  =$(filter-out $(MANAGED_EXISTING),$(MANAGED_ACTIVE))
MANAGED_CRUFT    =$(filter-out $(MANAGED_ACTIVE),$(MANAGED_EXISTING))

# The list of currently installed files
INSTALLED_ACTIVE =$(MANAGED_ACTIVE:$(DOTENV_MANAGED)/%=$(DOTENV_USER_HOME)/.%)
INSTALLED_CRUFT  =$(MANAGED_CRUFT:$(DOTENV_MANAGED)/%=$(DOTENV_USER_HOME)/.%)

.PHONY: info update clean


# ----------------------------------------------------------------------------
#
# TARGETS
#
# ----------------------------------------------------------------------------

info:
	@echo "PROFILE"
	@echo "   ALL      : $(PROFILE_ALL)"
	@echo "   INACTIVE : $(PROFILE_INACTIVE)"
	@echo "   ACTIVE   : $(PROFILE_ACTIVE)"
	@echo "MANAGED"
	@echo "   ALL      : $(MANAGED_ALL)"
	@echo "   INACTIVE : $(MANAGED_INACTIVE)"
	@echo "   ACTIVE   : $(MANAGED_ACTIVE)"
	@echo "   EXISTING : $(MANAGED_EXISTING)"
	@echo "   MISSING  : $(MANAGED_MISSING)"
	@echo "   CRUFT    : $(MANAGED_CRUFT)"
	@echo "INSTALLED"
	@echo "   MISSING  : $(INSTALLED_MISSING)"
	@echo "   CRUFT    : $(INSTALLED_CRUFT)"

update-managed: $(MANAGED_ALL)
	
update-installed: $(INSTALLED_ACTIVE)
	

clean: $(MANAGED_CRUFT)
	@if [ ! -z "$(MANAGED_CRUFT)" ]; then \
		rm $(MANAGED_CRUFT); \
	fi

# ----------------------------------------------------------------------------
#
# RULES
#
# ----------------------------------------------------------------------------

# Installs the MANAGED VERSION into the user home
$(DOTENV_USER_HOME)/.%: $(DOTENV_MANAGED)/% $(DOTENV_MANAGED)
	@dotenv --api dotenv_managed_install "$@"

# Creates/updates the MANAGED VERSION
$(DOTENV_MANAGED)/%: $(DOTENV_ACTIVE)/% $(DOTENV_CONFIG)
	@dotenv --api dotenv_managed_make "$(DOTENV_USER_HOME)/.$*"

# === HELPERS ==================================================================
#
print-%:
	@echo "$*="
	@echo "$($*)" | xargs -n1 echo | sort -dr

# EOF
