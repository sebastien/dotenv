#!/usr/bin/env bash
#
#   __          __
#  /\ \        /\ \__
#  \_\ \    ___\ \ ,_\    __    ___   __  __
#  /'_` \  / __`\ \ \/  /'__`\/' _ `\/\ \/\ \
# /\ \L\ \/\ \L\ \ \ \_/\  __//\ \/\ \ \ \_/ |
# \ \___,_\ \____/\ \__\ \____\ \_\ \_\ \___/
#  \/__,_ /\/___/  \/__/\/____/\/_/\/_/\/__/
#
# -----------------------------------------------------------------------------

BASE=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")

# === API =====================================================================
# Loads the dotenv API functions

source "$BASE/api.bash"

function dotenv-profile {
	local PROFILE="$1"
	local DIR
	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_error "Environemnt variable DOTENV_PROFILES not defined"
	elif [ -z "$PROFILE" ]; then
		dotenv_profile_list
	else
		DIR="$DOTENV_PROFILES/$PROFILE"
		if [ ! -d "$DIR" ]; then
			dotenv_info "profile \"$PROFILE\" created at: $DIR"
			mkdir -p "$DIR"
		else
			for FILE in $(dotenv_listdir "$DIR"); do
				echo "$FILE"
			done
		fi
	fi
}

function dotenv-profile-apply {
	local PROFILE="$DOTENV_PROFILES/$1"
	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_error "Environemnt variable DOTENV_PROFILES not defined"
	elif [ ! -e "$PROFILE" ]; then
		dotenv_info "Profile \"$1\" does not exist"
		dotenv_profile_list
	else
		dotenv_profile_apply $1
	fi
}

function dotenv-managed {
	if [ ! -e "$DOTENV_MANAGED" ]; then
		dotenv_info "No file managed by dotenv yet."
		# TODO: Recommend steps to manage files
	else
		dotenv_managed_list
	fi
}

function dotenv-template {
	local TEMPLATE="$1"
	local DIR
	if [ -z "$DOTENV_TEMPLATES" ]; then
		dotenv_error "Environemnt variable DOTENV_TEMPLATES not defined"
	elif [ -z "$TEMPLATE" ]; then
		dotenv_template_list
	else
		DIR="$DOTENV_TEMPLATES/$TEMPLATE"
		if [ ! -d "$DIR" ]; then
			dotenv_info "template \"$TEMPLATE\" created at: $DIR"
			mkdir -p "$DIR"
		else
			for FILE in $(dotenv_listdir "$DIR"); do
				echo "$FILE"
			done
		fi
	fi
}

# TODO: Should be dotenv-template-merge
function dotenv-merge {
	local PARENT="$1"
	local TEMPLATE="$2"
	if [ -z "$PARENT" ] && [ -z "$TEMPLATE" ]; then
		dotenv_error "dotenv-merge PARENT TEMPLATE"
	elif [ -z "$PARENT" ]; then
		dotenv_error "PARENT is expected"
	elif [ -z "$TEMPLATE" ]; then
		dotenv_error "TEMPLATE is expected"
	elif [ ! -e "$DOTENV_TEMPLATES/$PARENT" ]; then
		dotenv_error "PARENT \"$PARENT\" not found at $DOTENV_TEMPLATE/$PARENT"
		dotenv_info  "Available templates:"
		for FILE in $(dotenv-template); do
			echo " - $FILE"
		done
	else
		if [ ! -e "$DOTENV_TEMPLATES/$TEMPLATE" ]; then
			mkdir "$DOTENV_TEMPLATES/$TEMPLATE"
		fi
		dotenv_template_link_files "$PARENT" "$DOTENV_TEMPLATES/$TEMPLATE"
	fi
}

# TODO: Should be dotenv-template-apply
function dotenv-apply {
## Applies the given TEMPLATE to the given PROFILE=default.
	#dotfile_template_apply ~/.dotenv/templates/ffunction/hgrc.tmpl ~/.dotenv/profiles/sebastien/config.sh
	#dotfile_template_assemble ~/.dotenv/templates/ffunction/hgrc.tmpl ~/.dotenv/profiles/sebastien
	local TEMPLATE="$1"
	local PROFILE="$2"
	if [ -z "$PROFILE" ]; then
		PROFILE="default"
	fi
	if [ -z "$TEMPLATE" ]; then
		dotenv_error "dotenv-apply TEMPLATE PROFILE"
	elif [ -z "$TEMPLATE" ]; then
		dotenv_error "TEMPLATE is expected"
	elif [ ! -e "$DOTENV_TEMPLATES/$TEMPLATE" ]; then
		dotenv_error "TEMPLATE \"$TEMPLATE\" not found at $DOTENV_TEMPLATE/$TEMPLATE"
		dotenv_info  "Available templates:"
		for PROF in $(dotenv-template); do
			echo " - $PROF"
		done
	else
		# We create the profile if it does not exist
		if [ ! -e "$DOTENV_PROFILES/$PROFILE" ]; then
			mkdir -p "$DOTENV_PROFILES/$PROFILE"
		fi
		# We generate or update the configuration file
		local CONFIG_SH="$DOTENV_PROFILES/$PROFILE/config.sh"
		local CONFIG_DELTA=$(dotenv_configuration_delta "$DOTENV_TEMPLATES/$TEMPLATE" "$CONFIG_SH")
		if [ ! -z "$CONFIG_DELTA" ]; then
			echo "$CONFIG_DELTA" >> "$CONFIG_SH"
			$EDITOR "$CONFIG_SH"
		fi
		# Now we apply the files of the given template to the profile
		# directory.
		dotenv_info "$PROFILE ←― $TEMPLATE"
		dotenv_template_link_files "$TEMPLATE" "$DOTENV_PROFILES/$PROFILE"
	fi
}


# EOF - vim: ts=4 sw=4 noet 
