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

function dotenv_info {
	echo "$*"
}

function dotenv_error {
	echo "$*"
}

function dotenv_listdir {
	local ALL
	ALL=$(echo "$1"/*)
	if [ "$ALL" != "$1/*" ]; then
		echo "$ALL"
	fi
}

function dotenv_template_list {
	local ALL
	if [ -z "$DOTENV_TEMPLATES" ]; then
		dotenv_error "Environemnt variable DOTENV_TEMPLATES not defined"
	elif [ "$ALL" = "$DOTENV_TEMPLATES/*" ]; then
		dotenv_info "No templates defined in $DOTENV_TEMPLATES"
	else
		ALL=$(dotenv_listdir "$DOTENV_TEMPLATES")
		for NAME in $ALL; do
			basename "$NAME"
		done
	fi
}

function dotenv_template_link_files {
## Applies the files in the given TEMPLATE to the given DIRECTORY
	local ALL
	local TEMPLATE=$1
	local TARGET=$2
	# We list all the files in the template directory, ignoring
	# the directories
	ALL=$(find "$DOTENV_TEMPLATES/$TEMPLATE" -name "*" -not -type d)
	for FILE in $ALL; do
		if [ "${FILE##*.}" = "swp" ]; then
			SUFFIX=""
		elif [ "${FILE##*.}" = "tmpl" ]; then
			SUFFIX="${FILE#$DOTENV_TEMPLATES/$TEMPLATE/}"
			#SUFFIX="${SUFFIX%.tmpl}"
		else
			SUFFIX="${FILE#$DOTENV_TEMPLATES/$TEMPLATE/}"
		fi
		DEST_FILE="$TARGET/$SUFFIX"
		if [ ! -z "$SUFFIX" ]; then
			# We get the parent directory and create it if necessessary
			TARGET_PARENT=$(dirname "$DEST_FILE")
			if [ ! -z "$TARGET_PARENT" ] && [ ! -e "$TARGET_PARENT" ]; then
				mkdir -p "$TARGET_PARENT"
			fi
			# Now we create symlinks
			if [ ! -e "$DEST_FILE" ]; then
				# If the  file does not exist, it's trivial.
				# FIXME
				# if [ "${FILE##*.}" = "tmpl" ]; then
				# 	echo "$FILE" "―(TEMPLATE)→" "$DEST_FILE"
				# else
				ln -sfr "$FILE" "$DEST_FILE"
				dotenv_info "$DEST_FILE"
			elif [ -L "$DEST_FILE" ]; then
				# If the file does exist, it must be a symlink
				unlink "$DEST_FILE"
				ln -sfr "$FILE" "$DEST_FILE"
				dotenv_info "$DEST_FILE"
			else
				dotenv_error "$DEST_FILE already exist and is not a symlink. Keeping it as-is."
			fi
		fi
	done
}

function dotenv_profile_list {
	local ALL
	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_error "Environemnt variable DOTENV_PROFILES not defined"
	elif [ "$ALL" = "$DOTENV_PROFILES/*" ]; then
		dotenv_info "No templates defined in $DOTENV_PROFILES"
	else
		ALL=$(dotenv_listdir "$DOTENV_PROFILES")
		for NAME in $ALL; do
			basename "$NAME"
		done
	fi
}

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

function dotenv_configuration_extract {
## Extracts the configuration variables defined in the given directory
## and outputs them as a sorted list of unique strings.
	if [ -e "$1" ]; then
		# Extracts the list of configuration variables from all these files
		find "$1" -name "*.tmpl" -exec cat '{}' ';' | egrep -o '\${[A-Z_]+}' | tr -d '{}$' | sort | uniq
	fi
}

function dotenv_configuration_variables {
## Lists the configuration variables defined in the given file
	cat "$1" | egrep -o '^\s*[A-Z_]+\s*=' | tr -d '= ' | sort | uniq
}

function dotenv_configuration_create {
## Outputs a new configuration file for the template files in the given $DIRECTORY
	echo "# Configuration extracted from template ${1#$DOTENV_TEMPLATES/} on $(date +'%F')"
	echo "# Edit this file and fill in the variables"
	for VARIABLE in $(dotenv_configuration_extract "$1"); do
		echo "$VARIABLE="
	done
	echo "# EOF"
}

function dotenv_configuration_delta {
	local DIR_VARS=$(dotenv_configuration_extract "$1")
	local CUR_VARS=""
	if [ -e "$2" ]; then
		CUR_VARS=$(dotenv_configuration_variables "$2")
	fi
	local DIR_TMP="$(mktemp)"
	local CUR_TMP="$(mktemp)"
	echo "$DIR_VARS" > "$DIR_TMP"
	echo "$CUR_VARS" > "$CUR_TMP"
	local MISSING=$(diff "$DIR_TMP" "$CUR_TMP" | grep '< ' | cut -d' ' -f 2)
	local EXTRA=$(diff "$DIR_TMP" "$CUR_TMP" | grep '> ' | cut -d' ' -f 2)
	rm $DIR_TMP $CUR_TMP
	if [ ! -z "$MISSING" ] || [ ! -z "$EXTRA" ]; then
		echo "# ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――"
		echo "# Configuration updated from template ${1#$DOTENV_TEMPLATES/} on $(date +'%F')"
		echo "# The following variables are new:"
		for VARIABLE in $MISSING; do
			echo "$VARIABLE="
		done
		if [ ! -z "$EXTRA" ]; then
			echo "# The following variables are not necessary anymore:"
			for VARIABLE in $EXTRA; do
				echo "# - $VARIABLE"
			done
		fi
		echo "# ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――"
	fi
}

function dotenv_template_assemble {
# Takes a path to a `TEMPLATE` file and a `SOURCE` directory and combines
# the `TEMPLATE` with any file in `SOURCE`. This will look for all the files
# that start with the basename of `TEMPLATE` and end up with `pre` or `post`.
#
# ```
# .dotenv/templates/work/hgrc.tmpl
# .dotenv/profiles/john/hgrc.pre
# .dotenv/profiles/john/hgrc.post
# ```
# 
# ```
# dotenv_template_assemble .dotenv/templates/work/hgrc.tmpl .dotenv/profiles/john
# ```
#
# will output the following files:
#
# ```
# .dotenv/profiles/john/hgrc.pre
# .dotenv/templates/work/hgrc.tmpl
# .dotenv/profiles/john/hgrc.post
# ```
	local TEMPLATE="$1"
	local SOURCE="$2"
	if [ "${TEMPLATE##*.}" = "tmpl" ]; then
		local RADIX=$(basename "${TEMPLATE%.*}")
	else
		local RADIX=$(basename "$TEMPLATE")
	fi
	for PRE in $SOURCE/$RADIX.pre $SOURCE/$RADIX.pre.*; do
		if [ -e "$PRE" ]; then
			cat "$PRE"
		fi
	done
	if [ -e "$TEMPLATE" ]; then
		cat "$TEMPLATE"
	fi
	for POST in $SOURCE/$RADIX.post $SOURCE/$RADIX.post.*; do
		if [ -e "$POST" ]; then
			cat "$POST"
		fi
	done
}


function dotenv_template_file_apply {
# Takes a path to a `TEMPLATE` file and a path to a `DATA` file that defines
# environment variables that will then be replaces in the `TEMPLATE`. Any
# expression like `${NAME}` is going to be expanded with the value of
# `NAME`.
	local TEMPLATE="$1"
	local DATA="$2"
	if [ -z "$DATA" ]; then
		cat "$TEMPLATE"
	elif [ ! -e "$DATA" ]; then
		dotenv_error "Template data file $DATA does not exist"
	else
		# First, we get the list of fields from the $DATA file, which
		# is supposed to be a shell script.
		local FIELDS=$(cat "$DATA" | egrep "^(export\s*)?[A-Z_]+\\s*=" | cut -d= -f1 | xargs echo)
		# Now we source the data file. If this goes wrong, the script is
		# probably going to stop.
		source "$DATA"
		# Now we build a SED expression to replace the strings.
		local SEDEXPR=""
		for FIELD in $FIELDS; do
			# Technically, we should escape the field value in
			# case it contains characters that we don't want.
			local EXPR='s|${'$FIELD'}|'$(eval "echo \$$FIELD")"|g"
			if [ -z "$SEDEXPR" ]; then
				SEDEXPR=$EXPR
			else
				SEDEXPR=$SEDEXPR';'$EXPR
			fi
		done
		# Now we process the template using the sed expression that 
		# we just created.
		cat $TEMPLATE | sed "$SEDEXPR"
	fi
}


# EOF
