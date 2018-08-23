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

# The paths to the dotenv files
DOTENV_PATH     =$(HOME)/.dotenv
DOTENV_ACTIVE   =$(DOTENV_PATH)/active
DOTENV_USER_HOME=$(HOME)
DOTENV_MANAGED  =$(DOTENV_PATH)/managed

# The list of active files
ACTIVE_SOURCES  =$(shell test -e $(DOTENV_ACTIVE) && find $(DOTENV_ACTIVE)/ -name "*" -not -type d)

# The list of currently managed files

# The list of
MANAGED_EXISTING =$(shell test -e $(DOTENV_MANAGED) && find $(DOTENV_MANAGED)/ -name "*" -not -type d)
MANAGED_PRODUCT  =$(patsubst %.pre,%,$(patsubst %.post,%,$(patsubst $(DOTENV_ACTIVE)/%,$(DOTENV_MANAGED)/%,$(ACTIVE_SOURCES))))
MANAGED_CRUFT    =$(filter-out $(MANAGED_PRODUCT),$(MANAGED_EXISTING))

INSTALLED_ALL    =$(MANAGED_PRODUCT:$(DOTENV_MANAGED)/%=$(DOTENV_USER_HOME)/.%)

.PHONY: info update clean

# ----------------------------------------------------------------------------
#
# TARGETS
#
# ----------------------------------------------------------------------------

info:
	@echo "Installed: $(INSTALLED_ALL)"
	@echo "Managed(to build): $(MANAGED_PRODUCT)"
	@echo "Managed(existing): $(MANAGED_EXISTING)"
	@echo Cruft: $(MANAGED_CRUFT)

update: $(MANAGED_PRODUCT)

clean: $(MANAGED_CRUFT)
	@if [ ! -z "$(MANAGED_CRUFT)" ]; then \
		rm $(MANAGED_CRUFT); \
	fi

# ----------------------------------------------------------------------------
#
# RULES
#
# ----------------------------------------------------------------------------

# Creates a symlink between a simple active file and the managed version
$(DOTENV_MANAGED)/%: $(DOTENV_ACTIVE)/%
	@dotenv --api dotenv_dir_copy_parents $(DOTENV_ACTIVE)/ $(DOTENV_MANAGED)/ $*
	@ln -sfr "$<" "$@"

# Installs the managed version into the user home
$(DOTENV_USER_HOME)/.%: $(DOTENV_MANAGED)/%
	@dotenv --api dotenv_managed_make "@"

# EOF
