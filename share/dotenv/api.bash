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
DOTENV_USER_HOME=$HOME
DOTENV_TEMPLATES=~/.dotenv/templates
DOTENV_PROFILES=~/.dotenv/profiles
DOTENV_BACKUP=~/.dotenv/backup
DOTENV_MANAGED=~/.dotenv/managed
DOTENV_ACTIVE=~/.dotenv/active
DOTENV_CONFIG=config.dotenv.sh

# TODO: Keep track of the signatures of the deployed files

# -----------------------------------------------------------------------------
#
# UTILITIES
#
# -----------------------------------------------------------------------------

function dotenv_info {
	# TODO: Should output in green or blue
	echo "$*"
}

function dotenv_action {
## Suggests the next action to be taken by the user
	# TODO: Should output in green or blue
	echo "$*"
}

function dotenv_error {
	# TODO: Should output in red
	(>&2 echo "$*")
}

function dotenv_warning {
	# TODO: Should output in red
	(>&2 echo "$*")
}

function dotenv_list {
	for ITEM in "$@"; do
		echo "- $ITEM"
	done
}

function dotenv_fail {
	(>&2 echo "$*")
	exit 1
}

function dotenv_output {
	echo "$*"
	exit 0
}

function dotenv_assert_active {
## Asserts that there is an active profile
	if [ ! -e "$DOTENV_ACTIVE" ]; then
		dotenv_fail "No active profile"
	fi
}

# -----------------------------------------------------------------------------
#
# PROFILES
#
# -----------------------------------------------------------------------------


function dotenv_profile_create {
## Creates the profile with the given name if not already there
	local PROFILE_NAME="$1"
	if [ -z "$PROFILE_NAME" ]; then
		PROFILE_NAME="default"
	fi
	dotenv_info "Created profile: $PROFILE_NAME"
	local PROFILE_PATH="$DOTENV_PROFILES/$PROFILE_NAME"
	if [ ! -d "$PROFILE_PATH" ]; then
		mkdir -p "$PROFILE_PATH"
	fi
}

function dotenv_profile_active {
	if [ -e "$DOTENV_ACTIVE" ]; then
		dotenv_output $(basename $(readlink "$DOTENV_ACTIVE"))
	else
		dotenv_info "No active profile"
	fi
}

function dotenv_profile_manifest {
## Lists the files defined in the given `profile`.
## @param profile
find -L "$DOTENV_PROFILES/$1" -name "*" -not -type d -not -name "$DOTENV_CONFIG" -not -name "*.post" -not -name "*.pre" -not -name "*.pre.*" -not -name "*.post.*"
}

function dotenv_profile_managed {
## Lists the managed by the given profile (active profile by default)
	# TODO: Format should be
	# HOME PATH ; MANAGED PATH ; SOURCES
	# For instance
	# ~/.bashrc | ~/.dotenv/managed/bashrc | ~/.dotenv/templates/default/bashrc.pre ~/.dotenv/profiles/default/bashrc.post
	local PROFILE="$1"
	if [ -z "$PROFILE" ]; then
		dotenv_error "No active profile selected"
		exit 1
	fi
	local PROFILE_BASE="$DOTENV_PROFILES/$1/"
	for FILE in $(dotenv_profile_manifest "$1"); do
		local FILE_NAME=${FILE#$PROFILE_BASE}
		local FILE_SOURCES="${FILE}"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		if [ ! -e "$FILE_MANAGED" ]; then
			# NOTE: This happens if the managed directory has been
			# tampered with. We should probably restore the file at that
			# point.
			dotenv_warning "Missing managed file: $FILE_MANAGED"
		fi
		# TODO: What about *.pre and *.post?
		case "$FILE_NAME" in
			*.tmpl)
				echo "~/.${FILE_NAME%.tmpl}	$FILE_MANAGED	$FILE_SOURCES"
				;;
			*)
				echo "~/.$FILE_NAME	$FILE_MANAGED	$FILE_SOURCES"
				;;
		esac
	done
}

function dotenv_profile_list {
	local ALL
	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_error "Environemnt variable DOTENV_PROFILES not defined"
	elif [ "$ALL" = "$DOTENV_PROFILES/*" ]; then
		dotenv_info "No templates defined in $DOTENV_PROFILES"
	else
		ALL=$(dotenv_dir_list "$DOTENV_PROFILES")
		for NAME in $ALL; do
			basename "$NAME"
		done
	fi
}

function dotenv_profile_revert {
	# We start by reverting any already managed file
	dotenv_manage_revert
	if [ -e "$DOTENV_ACTIVE" ]; then
		unlink "$DOTENV_ACTIVE"
	fi
	if [ -d "$DOTENV_MANAGED" ]; then
		dotenv_error "managed directory still present after revert: $DOTENV_MANAGED"
		exit 1
	fi
	# We restore backed up files so that the profile is in the 
	# same state it was before dotenv was run.
	dotenv_backup_restore
	if [ -d "$DOTENV_BACKUP" ]; then
		dotenv_error "backup directory still present after restore: $DOTENV_BACKUP"
		exit 1
	fi
}

function dotenv_profile_apply {
## Applies the given `profile`, which must exist.
## @param profile
	# We revert any previously applied profile
	dotenv_profile_revert
	# Now we iterate on all the files that are part of the current profile
	for FILE in $(dotenv_profile_manifest "$1"); do
		# This defines the different paths for the file. The SUFFIX
		# is local to the profile, the $TARGET is the dotfile within
		# the DOTENV_USER_HOME directory, the FILE_MANAGED is the build file that
		# is symlinked to the DOTENV_USER_HOME and the FILE_BACKUP is the file in
		# the backup directory.
		SUFFIX=${FILE#$DOTENV_PROFILES/$1/}
		TARGET=$DOTENV_USER_HOME/.$SUFFIX
		FILE_MANAGED=$DOTENV_MANAGED/$SUFFIX
		FILE_BACKUP=$DOTENV_BACKUP/$SUFFIX
		DIR_BACKUP=$(dirname "$DOTENV_BACKUP/$SUFFIX")
		EXT="${FILE##*.}"
		# Template (*.tmpl) files have their extension removed
		if [ "$EXT" = "tmpl" ]; then
			TARGET=${TARGET%.*}
			FILE_BACKUP=${FILE_BACKUP%.*}
			FILE_MANAGED=${FILE_MANAGED%.*}
		fi
		# 1) If the TARGET exists, then we move it to the FILE_BACKUP path.
		if [ -e "$TARGET" ]; then
			# We make sure there's a directory where we can backup
			if [ ! -e "$DIR_BACKUP" ]; then
				mkdir -p "$DIR_BACKUP"
			fi
			# Symlinks are compared with the real file. If they're the
			# same, then we don't need to backup.
			if [ -L "$TARGET" ]; then
				TARGET_REAL=$(readlink -f "$TARGET")
				FILE_REAL=$(readlink -f "$FILE")
				if [ "$TARGET_REAL" != "$FILE_REAL" ]; then
					mv "$TARGET" "$FILE_BACKUP"
				fi
			else
				mv "$TARGET" "$FILE_BACKUP"
			fi
		fi
		# 2) Now that the TARGET file is backed-up (if it exists),
		#    we create the FILE_MANAGED version.
		if [ ! -e "$(dirname "$FILE_MANAGED")" ]; then
			mkdir -p "$(dirname "$FILE_MANAGED")"
		fi
		# Templates need to be assembled and expanded first, while
		# regular files can be assembled. Managed files created from templates
		# will be set to READ-ONLY, as they are generated from the config 
		# file.
		if [ "$EXT" = "tmpl" ]; then
			if [ "$(dotenv_file_fragments "$FILE")" = "" ]; then
				TEMP=$(mktemp)
				dotenv_file_assemble "$FILE" > "$TEMP"
				dotenv_tmpl_apply "$TEMP" "$DOTENV_PROFILES/$1/config.dotenv.sh" > "$FILE_MANAGED"
				unlink "$TEMP"
				chmod -w "$FILE_MANAGED"
			else
				dotenv_tmpl_apply "$FILE" "$DOTENV_PROFILES/$1/config.dotenv.sh" > "$FILE_MANAGED"
				chmod -w "$FILE_MANAGED"
			fi
			ln -sfr "$FILE_MANAGED" "$TARGET"
		else
			if [ "$(dotenv_file_fragments "$FILE")" = "" ]; then
				ln -sfr "$FILE" "$FILE_MANAGED"
			else
				dotenv_file_assemble "$FILE" > "$FILE_MANAGED"
				# The output file is going to be readonly because it's 
				# assembled.
				chmod -w "$FILE_MANAGED"
			fi
		fi
		# 3) We symlink from the FILE_MANAGED to the TARGET in the user's
		#    HOME.
		ln -sfr "$FILE_MANAGED" "$TARGET"
		dotenv_info ".$SUFFIX"
	done
	ln -sfr "$DOTENV_PROFILES/$1" "$DOTENV_ACTIVE"
}

function dotenv_backup_file {
## @param FILE* the files to backup
## Backs up the given file by moving them to `$DOTENV_BACKUP`.
	for FILE in "$@"; do
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local PARENT_NAME=$(dirname "$FILE_NAME")
		local FILE_BACKUP="$DOTENV_BACKUP/$FILE_NAME"
		local FILE_BACKUP_PARENT="$DOTENV_BACKUP/$PARENT_NAME"
		if [ -e "$FILE_BACKUP" ]; then
			# If the backup already exist, we make the process fail.
			dotenv_fail "File backup already exists: $FILE_BACKUP"
		fi
		# We create the parent directory if needed.
		if [ ! -d "$FILE_BACKUP_PARENT" ]; then
			# We create the parent directory in backup and make sure that
			# we preserve the attributes
			mkdir -p "$FILE_BACKUP_PARENT"
			cp -a $(dirname "$FILE") "$FILE_BACKUP_PARENT"
		fi
		# And now we can backup the file
		mv "$FILE" "$FILE_BACKUP"
	done
}

function dotenv_backup_restore {
## Moves back every single file in $DOTENV_BACKUP to its original location
## in $DOTENV_USER_HOME. Empty directories will be pruned, which should
## result in $DOTENV_BACKUP to not exit at the end.
	if [ -d "$DOTENV_BACKUP" ]; then
		# For each file in the backup directory
		for FILE in $(find "$DOTENV_BACKUP" -name "*" -not -type d); do
			# We determine the target directory
			TARGET=$DOTENV_USER_HOME/.${FILE#$DOTENV_BACKUP/}
			TARGET_DIR=$(dirname "$TARGET")
			if [ ! -d "$TARGET_DIR" ]; then
				mkdir -p "$TARGET_DIR"
			fi
			# We move back the backed up file to its original location
			if [ ! -e "$TARGET" ]; then
				mv "$FILE" "$TARGET"
			else
				dotenv_error "Cannot restore backup \"$FILE\", \"$TARGET\" already exists."
			fi
			dotenv_info "restored $TARGET"
		done
		# We remove empty directories from the backup
		dotenv_dir_clean "$DOTENV_BACKUP"
		if [ -e "$DOTENV_BACKUP" ] ; then
			dotenv_error "Could not fully restore backup, some files already exist:"
			exit 1
		fi
	fi
}

# -----------------------------------------------------------------------------
#
# MANAGING FILES
#
# -----------------------------------------------------------------------------

function dotenv_manage_list {
## Lists the files currently managed by dotenv
	if [ -e "$DOTENV_MANAGED" ]; then
		for FILE in $(find $DOTENV_MANAGED -name "*" -not -type d ); do
			local FILE_NAME=${FILE#$DOTENV_MANAGED/}
			local HOME_NAME=~/.$FILE_NAME
			local FILE_ACTIVE="$DOTENV_ACTIVE/$FILE_NAME"
			local FILE_FRAGMENTS=$(dotenv_file_fragments "$FILE_ACTIVE")
			echo "$FILE_FRAGMENTS"
			#echo ~/.${FILE#$DOTENV_MANAGED/}→~/${FILE#$DOTENV_USER_HOME/}→$(readlink ~/${FILE#$DOTENV_USER_HOME/})
		done
	fi
}


# NOTE: This function is complex and critical, it must be edited with care.
function dotenv_manage_add {
## Adds the given FILES as managed files. This requires an active profile.
	dotenv_assert_active
	if [ ! -e "$DOTENV_MANAGED" ]; then
		mkdir -p "$DOTENV_MANAGED"
	fi
	for FILE in "$@"; do
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_BACKUP="$DOTENV_BACKUP/$FILE_NAME"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		local FILE_ACTIVE="$DOTENV_ACTIVE/$FILE_NAME"
		# NOTE: This might be better using a function call
		local FILE_ACTIVE_FRAGMENTS=$(find "$DOTENV_ACTIVE" -name "$FILE_NAME" -name "$FILE_NAME.tmpl" -name "$FILE_NAME.pre" -name "$FILE_NAME.post" -name "$FILE_NAME.pre.*" -name "$FILE_NAME.post.*")
		# Is the file already managed?
		if [ -e "$FILE_MANAGED" ]; then
			# If the file is already managed, we can try to backup the 
			# file and deploy our managed version.
			dotenv_error "File already managed, : $FILE → $FILE_MANAGED"
			dotenv_action "Use dotenv-manage -o $FILE to backup $FILE and deploy the managed version" 
		# Is there a file in the active profile?
		elif [ -e "$FILE_ACTIVE" ]; then
			# The file is not managed yet (which means something failed before)
			# so we re-apply the rules to create the managed file (if any)
			dotenv_info "File already exists in active profile: $FILE → $FILE_ACTIVE"
			dotenv_action "Use dotenv-manage -o $FILE to backup $FILE and deploy the managed version" 
		# Is there any fragment in the active profile, but not the file itself?
		elif [ "$FILE_ACTIVE_FRAGMENTS" != "" ]; then
			# It's the same as above, but with a file that only has fragments
			# ie `NAME.pre` but not `NAME`.
			dotenv_info "File already exists in active profile: $FILE → $FILE_ACTIVE"
			dotenv_action "Use dotenv-manage -o $FILE to backup $FILE and deploy the managed version" 
		# Is there a file already in the backup?
		elif [ -e "$FILE_BACKUP" ]; then
			# If so, we need user intervention to do something with the backup
			# either delete it or restore it.
			dotenv_info "File already exists in $FILE_BACKUP."
			dotenv_action "Remove or restore the backup file and try again"
		else
			# Here we know that the file is not managed and does not exist
			# in the active profile, and has no existing backup.
			# We create the file in the active profile. We copy its contents
			local FILE_CANONICAL=$(readlink -f "$FILE")
			if [ -d "$FILE_CANONICAL" ]; then
				dotenv_error "Given file is a directory. Dotenv can only manage files."
				exit 1
			else
				# We create a copy of the canonical file. "cp -a" might
				# actually be enough.
				cat "$FILE_CANONICAL" > "$FILE_ACTIVE"
				cp --attributes-only "$FILE" "$FILE_ACTIVE"
				# We recreate the managed file (in case there are fragments/templates)
				dotenv_manage_make "$FILE"
				# We finally create a symlink between the managed path
				dotenv_manage_apply "$FILE"
			fi
		fi
	done
}

function dotenv_manage_remove {
	for FILE in $*; do
		FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		FILE_MANAGED="${DOTENV_MANAGED}/$FILE_NAME"
		FILE_BACKUP="{DOTENV_BACKUP}/$FILE_NAME"
		if [ -e "$FILE_BACKUP" ]; then
			# Do we have a backup for the file? That's the expected
			# behaviour.
			FILE="$FILE"
		elif [ -e "$FILE_MANAGED" ]; then
			# We don't have backup, but we should have the managed
			# file, which we can move back
			FILE="$FILE"
		else
			dotenv_error "No backup ($FILE_BACKUP) or managed file ($FILE_MANAGED) for: $FILE"
		fi
	done
} 

function dotenv_manage_make {
## @param FILES* these paths are relative to home
## @output:stdout The path for each managed file corresponding to the given path
##
## Looks for each of the given `FILE`s in the active profile, and links
## the file or assembles its fragments into `~/.dotenv/managed`, output.
	dotenv_assert_active
	for FILE in "$@"; do
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		local FILE_ACTIVE="$DOTENV_ACTIVE/$FILE_NAME"
		if [ -e "$FILE" ]; then
			FILE=$(readlink -f "$FILE")
		elif [ -z "$(dotenv_file_fragment_types)" ]; then
			dotenv_error "$FILE does not exist in active profile: $FILE_ACTIVE"
			exit 1
		else
			echo dotenv_file_assemble "$FILE_ACTIVE_FRAGMENTS" "$FILE_MANAGED"
		fi
		# If there is only one regular file as a fragment, we symlink from
		# the active profile to the managed.
		if [ "$(dotenv_file_fragment_types "$FILE_ACTIVE")" == "f" ]; then
			ln -sfr "$FILE_ACTIVE" "$FILE_MANAGED"
		# Otherwise we assembe it
		else
			if [ -e "$FILE_MANAGED" ]; then
				chmod u+w "$FILE_MANAGED"
				unlink "$FILE_MANAGED"
			fi
			dotenv_file_assemble "$FILE_ACTIVE" > "$FILE_MANAGED"
		fi
		echo "$FILE_MANAGED"
	done
}

function dotenv_manage_apply {
## @param FILES relative to $DOTENV_USER_HOME that needs to be applied
##        from the $DOTENV_MANAGED directory.
	dotenv_assert_active
	for FILE in "$@"; do
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		local FILE_ACTIVE="$DOTENV_ACTIVE/$FILE_NAME"

	done
}

function dotenv_manage_revert {
## Iterates on all the files in the $DOTENV_MANAGED directory. For each of this
## file, the corresponding target file installed in $DOTENV_USER_HOME will be removed.
## This requires the target file to point back to the same file as the managed
## file. If not, this means the file was changed and the process will fail.
	if [ -d "$DOTENV_MANAGED" ]; then
		for FILE in $(find "$DOTENV_MANAGED" -name "*" -not -type d); do
			TARGET=$DOTENV_USER_HOME/.${FILE#$DOTENV_MANAGED/}
			if [ -e "$TARGET" ]; then
				ACTUAL_ORIGIN=$(readlink -f "$TARGET")
				EXPECTED_ORIGIN=$(readlink -f "$FILE")
				if [ "$ACTUAL_ORIGIN" != "$EXPECTED_ORIGIN" ]; then
					# TODO: Improve error message
					dotenv_error "Managed file \"$TARGET\" should point to \"$EXPECTED_ORIGIN\""
					dotenv_error "but instead points to \"$ACTUAL_ORIGIN\""
					# NOTE: We don't unlink the file there.
				else
					unlink "$TARGET"
					unlink "$FILE"
				fi
				# We clean the target directory.
				if [ "$(dirname "$TARGET")" != "" ]; then
					dotenv_dir_clean "$(dirname "$TARGET")"
				fi
			else
				unlink "$FILE"
			fi
		done
		# TODO: Remove empty directories on the target side
		# We remove empty directories
		dotenv_dir_clean "$DOTENV_MANAGED"
		if [ -e "$DOTENV_MANAGED" ] ; then
			dotenv_error "Could not fully remove managed files, some files were altered"
			exit 1
		fi
	fi
}

# -----------------------------------------------------------------------------
#
# CONFIGURATION
#
# -----------------------------------------------------------------------------

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
## Outputs a user-editable delta to update their configuration file. Takes
## a directory containing the TEMPLATE files and the CONFIG file
## defining the variables.
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

# -----------------------------------------------------------------------------
#
# TEMPLATES HIGH-LEVEL
#
# -----------------------------------------------------------------------------

function dotenv_template_list {
	local ALL
	if [ -z "$DOTENV_TEMPLATES" ]; then
		dotenv_error "Environemnt variable DOTENV_TEMPLATES not defined"
	elif [ "$ALL" = "$DOTENV_TEMPLATES/*" ]; then
		dotenv_info "No templates defined in $DOTENV_TEMPLATES"
	else
		ALL=$(dotenv_dir_list "$DOTENV_TEMPLATES")
		for NAME in $ALL; do
			basename "$NAME"
		done
	fi
}

function dotenv_template_link_files {
## Creates symlinks between all the files defined in TEMPLATE and the
## TARGET directory. Any file that is not a symlink and already exists
## in the target will be left as-is.
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

# -----------------------------------------------------------------------------
#
# HELPER FUNCTIONS
#
# -----------------------------------------------------------------------------

function dotenv_dir_list {
	local ALL
	ALL=$(echo "$1"/*)
	if [ "$ALL" != "$1/*" ]; then
		echo "$ALL"
	fi
}

function dotenv_dir_clean {
## @param PATH
##
## Removes any empty directory at the given `PATH`
	# This makes sure that the suffix is not the home directory
	DIRPATH=$(readlink -f "$1")
	SUFFIX=${DIRPATH#$DOTENV_USER_HOME}
	if [ -d "$DIRPATH" ] && [ "$SUFFIX" != "" ] && [ "$SUFFIX" != "/" ]; then
		find "$DIRPATH" -depth -type d -empty -exec rmdir '{}' ';'
	fi
}

function dotenv_file_pre_list {
## Lists the `.pre.*` fragments for the given file, if any. The files
## need to exist to be listed.
	for PRE in $1.pre $1.pre.*; do
		if [ -e "$PRE" ]; then
			echo "PRE"
		fi
	done
}

function dotenv_file_post_list {
## Lists the `.post.*` fragments for the given file, if any. The files need
## to exists to be listed.
	for POST in $1.post $1.post.*; do
		if [ -e "$POST" ]; then
			echo "$POST"
		fi
	done
}

function dotenv_file_fragments_list {
## Lists the file fragments used to assemble the given file. This looks
## for  `*.pre.*` and `*.post.*` files and outputs them in order.
	dotenv_file_pre_list  "$1"
	if [ -e "$1" ]; then
		echo "$1"
	fi
	dotenv_file_post_list "$1"
}

function dotenv_file_fragment_types {
## Returns a string combining the different types of fragments that 
## create the given file. Template fragments will produce a `T`, 
## while file fragments will produce an `f`.
	for FRAGMENT in $(dotenv_file_fragments_list "$1"); do
		case "$FRAGMENT" in
			*.tmpl|*.tmpl.pre|*.tmpl.pre.*|*.tmpl.post|*.tmpl.post.*)
				echo -n "T"
			;;
			*)
				echo -n "f"
			;;
		esac
	done
}

function dotenv_file_assemble {
## @param FILE the path of the file fragments to assemble.
## @output:stdout The assembled file
##
## Takes a path to a `FILE` and combines any `pre` or `post` files found
## around it, making sure that any template file is expanded. The result
## is output to stdout.
	for FRAGMENT in $(dotenv_file_fragments "$1"); do
		case "$FRAGMENT" in
			*.tmpl|*.tmpl.pre|*.tmpl.pre.*|*.tmpl.post|*.tmpl.post.*)
				dotenv_tmpl_apply "$FRAGMENT"
				;;
			*)
				cat "$FRAGMENT"
				;;
		esac
	done
}

function dotenv_tmpl_apply {
## @param FILE
## @param CONFIG
## @output:stdout The template file expanded with the given `CONFIG`
##
## Takes a path to a `.tmpl` `FILE` and a path to a `CONFIG` file that defines
## environment variables that will then be replaces in the `TEMPLATE`. Any
## expression like `${NAME}` is going to be expanded with the value of
## `NAME`.
	local FILE="$1"
	local CONFIG="$2"
	if [ -z "$CONFIG" ]; then
		CONFIG="$DOTENV_ACTIVE/$DOTENV_CONFIG"
	fi
	if [ ! -e "$CONFIG" ]; then
		dotenv_error "Configuration file $CONFIG does not exist"
	else
		# First, we get the list of fields from the $CONFIG file, which
		# is supposed to be a shell script.
		local FIELDS=$(cat "$CONFIG" | egrep "^(export\s*)?[A-Z_]+\\s*=" | cut -d= -f1 | xargs echo)
		# FIXME: We might want to backup the environment
		# Now we source the data file. If this goes wrong, the script is
		# probably going to stop.
		source "$CONFIG"
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
		cat "$FILE" | sed "$SEDEXPR"
	fi
}

# EOF
