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

function command-dotenv {
# Lists the available profiles
# -l --list PROFILE

	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_fail "Environment variable DOTENV_PROFILES not defined"
	fi

	while [ "$#" -gt 0 ]
	do
		case "$1" in
		-h|--help)
			dotenv_output "TODO: Usage"
			;;
		-a|--active)
			dotenv_profile_active
			exit 0
			;;
		-l|--list)
			dotenv_profile_list
			exit 0
			;;
		-c|--create)
			dotenv_profile_create "$2"
			exit 0
			;;
		-u|--update)
			dotenv_fail "Not implemented yet"
			;;
		-r|--remove)
			if [ -d "$DOTENV_MANAGED" ]; then
				dotenv_info "Reverting applied profile"
				dotenv_profile_revert
			else
				dotenv_info "No active profile"
			fi
			exit 0
			;;
		-*)
			dotenv_fail "Invalid option '$1'. Use --help to see the valid options" >&2
			;;
		*)
			if [ -e "$DOTENV_PROFILES/$1" ]; then
				dotenv_info "Applying profile $1"
				dotenv_profile_apply "$1"
				exit 0
			else
				dotenv_error "Profile does not exist: $1. Use one of:"
				dotenv_list "$(dotenv_profile_list)"
				exit 1
			fi
			;;
		esac
		shift
	done
	if [ -d "$DOTENV_MANAGED" ]; then
		dotenv_manage_list | column -ts→
		exit 0
	elif [ ! -d "$DOTENV_PROFILES" ]; then
		dotenv_info "No profile defined in $DOTENV_PROFILES"
		dotenv_info "Use \`dotenv --create PROFILE\` to create a profile with the given name"
	elif [ ! -d "$DOTENV_ACTIVE" ]; then
		dotenv_info "No active profile, run dotenv with one of:"
		dotenv_list "$(dotenv_profile_list)"
	else
		dotenv_info "No managed files in profile $(dotenv_profile_active)"
		dotenv_info "Add files with: \`dotenv-manage FILES…\`"
		exit 0
	fi
}

function command-dotenv-manage {
# Lists the managed files
# -l --list PROFILE?
	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_fail "Environment variable DOTENV_PROFILES not defined"
	fi
	if [ "$#" -eq 0 ]; then
		command-dotenv-manage --list
		exit 0
	fi
	while [ "$#" -gt 0 ]
	do
		case "$1" in
		-h|--help)
			echo "Usage: dotenv-manage [OPTION] PROFILE|FILE…"
			echo "Lists, adds and remove files managed by dotenv"
			echo 
			echo "                       Manages the given files with dotenv"
			echo " -l, --list            Lists the files managed by the current PROFILE "
			echo " -u, --update          TODO"
			echo " -r, --remove          TODO"
			exit 0
			;;
		-l|--list)
			shift
			local ACTIVE_PROFILE="$1"
			if [ -z "$*" ]; then
				ACTIVE_PROFILE=$(dotenv_profile_active)
			fi
			dotenv_profile_managed "$ACTIVE_PROFILE" | column -ts →
			exit 0
			;;
		-u|--update)
			dotenv_fail "Not implemented yet"
			;;
		-r|--remove)
			shift
			dotenv_manage_remove "$*"
			exit 0
			;;
		-*)
			dotenv_fail "Invalid option '$1'. Use --help to see the valid options" >&2
			;;
		*)
			dotenv_manage_add "$*"
			exit 0
			;;
		esac
		shift
	done
}

# FIXME: Replaced by dotenv-manage -l
# function command-dotenv-managed {
# 	if [ -z "$DOTENV_PROFILES" ]; then
# 		dotenv_error "Environment variable DOTENV_PROFILES not defined"
# 	elif [ -z "$1" ]; then
# 		dotenv_managed_list
# 		exit 0
# 	else
# 		for FILE in $(dotenv_profile_manifest "$1"); do
# 			echo "~/${FILE#$HOME/} → ~/.${FILE#$DOTENV_PROFILES/$1/}"
# 		done
# 		exit 0
# 	fi
# }

# -----------------------------------------------------------------------------
#
# FILES & TEMPLATES
#
# -----------------------------------------------------------------------------

function dotenv-template {
	local TEMPLATE="$1"
	local DIR
	if [ -z "$DOTENV_TEMPLATES" ]; then
		dotenv_error "Environment variable DOTENV_TEMPLATES not defined"
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
function dotenv-template-merge {
	local PARENT="$1"
	local TEMPLATE="$2"
	if [ -z "$PARENT" ] && [ -z "$TEMPLATE" ]; then
		dotenv_error "dotenv-template-merge PARENT TEMPLATE"
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
function dotenv-template-apply {
## Applies the given TEMPLATE to the given PROFILE=default.
	#dotfile_template_apply ~/.dotenv/templates/ffunction/hgrc.tmpl ~/.dotenv/profiles/sebastien/config.dotenv.sh
	#dotfile_template_assemble ~/.dotenv/templates/ffunction/hgrc.tmpl ~/.dotenv/profiles/sebastien
	local TEMPLATE="$1"
	local PROFILE="$2"
	if [ -z "$PROFILE" ]; then
		PROFILE="default"
	fi
	if [ -z "$TEMPLATE" ]; then
		dotenv_error "dotenv-template-apply TEMPLATE PROFILE"
	elif [ -z "$TEMPLATE" ]; then
		dotenv_error "TEMPLATE is expected"
	elif [ ! -e "$DOTENV_TEMPLATES/$TEMPLATE" ]; then
		dotenv_error "TEMPLATE \"$TEMPLATE\" not found at $DOTENV_TEMPLATE/$TEMPLATE"
		dotenv_info  "Available templates:"
		for TMPL in $(dotenv-template); do
			echo " - $TMPL"
		done
	else
		# We create the profile if it does not exist
		if [ ! -e "$DOTENV_PROFILES/$PROFILE" ]; then
			mkdir -p "$DOTENV_PROFILES/$PROFILE"
		fi
		# We generate or update the configuration file
		local CONFIG_DOTENV="$DOTENV_PROFILES/$PROFILE/config.dotenv.sh"
		local CONFIG_DELTA=$(dotenv_configuration_delta "$DOTENV_TEMPLATES/$TEMPLATE" "$CONFIG_DOTENV")
		if [ ! -z "$CONFIG_DELTA" ]; then
			echo "$CONFIG_DELTA" >> "$CONFIG_DOTENV"
			$EDITOR "$CONFIG_DOTENV"
		fi
		# Now we apply the files of the given template to the profile
		# directory.
		dotenv_info "$PROFILE ←― $TEMPLATE"
		dotenv_template_link_files "$TEMPLATE" "$DOTENV_PROFILES/$PROFILE"
	fi
}

# EOF - vim: ts=4 sw=4 noet 
