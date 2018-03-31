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

export DOTENV_API="0.0.0"
DOTENV_USER_HOME=~
DOTENV_TEMPLATES=~/.dotenv/templates
DOTENV_PROFILES=~/.dotenv/profiles
DOTENV_BACKUP=~/.dotenv/backup

# TODO: Keep track of the signatures of the deployed files

function dotenv_file_apply {
# Applies the file at `FROM` to the given `TO` path
# relative to the user's home. If there is an original file,
# it will be backed up.
	local FROM="$1"
	local TO="$DOTENV_USER_HOME/$2"
	if [ -e "$TO" ]; then
		dotenv_file_backup "$TO" "$DOTENV_BACKUP"
		chmod u+w "$TO"
		rm "$TO"
	fi
	if [ -e "$FROM" ]; then
		cp -a "$FROM" "$TO"
		chmod -w "$TO"
	fi
}

function dotenv_file_revert {
# Reverts the given file relative to the user's home using the
# previously backed up version.
	local FROM="$DOTENV_USER_HOME/$1"
	local TO="$DOTENV_BACKUP/$1"
	# TODO: Ensure that $FROM was not modified
	if [ -e "$TO" ]; then
		if [ -e "$FROM" ]; then
			chmod u+w "$FROM"
			rm "$FROM"
		fi
		cp -a "$TO" "$FROM"
	fi
}

function dotenv_file_backup {
	local FROM="$1"
	local TO="$2"
	if [ ! -e "$TO" ]; then
		cp -a "$FROM" "$TO"
	fi
}


# EOF
