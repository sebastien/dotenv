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
# Dotenv shell API implementation
# -----------------------------------------------------------------------------

export DOTENV_API="0.0.0"

TEMPLATE_NAME=dotenv.templates
CONFIG_NAME=dotenv.config
DOTENV_USER_HOME=$HOME
DOTENV_HOME=$HOME/.dotenv
DOTENV_TEMPLATES=$DOTENV_HOME/templates
DOTENV_PROFILES=$DOTENV_HOME/profiles
DOTENV_BACKUP=$DOTENV_HOME/backup
DOTENV_MANAGED=$DOTENV_HOME/managed
DOTENV_ACTIVE=$DOTENV_HOME/active
DOTENV_MANIFEST=$DOTENV_HOME/manifest

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

function dotenv_assert_active_profile {
## Asserts that there is an active profile
	if [ ! -e "$DOTENV_ACTIVE" ]; then
		dotenv_fail "Active profile is required: dotenv PROFILE"
	fi
}

function dotenv_assert_file_is_dotfile {
## Asserts that the given file is a dotfile
	local FILE="$1"
	if [ "$(dotenv_file_is_dotfile "$FILE")" != "OK" ]; then
		# We fail if we don't have a dotfile
		dotenv_fail "Expected a dotfile ($DOTENV_USER_HOME/.*), got: $FILE"
	fi
}

function dotenv_assert_file_is_managed {
## Asserts that the given file is a dotfile
	local FILE="$1"
	if [ "$(dotenv_file_has_prefix "$FILE" "$DOTENV_MANAGED/")" != "OK" ]; then
		# We fail if we don't have a dotfile
		dotenv_fail "Expected a dotenv managed path ($DOTENV_MANAGED/*), got: $FILE"
	fi
}

# -----------------------------------------------------------------------------
#
# PROFILES
#
# -----------------------------------------------------------------------------


function dotenv_profile_configure {
	$EDITOR "$DOTENV_ACTIVE/$CONFIG_NAME"
	dotenv_profile_apply "$(dotenv_profile_active)"
}

function dotenv_profile_create {
## Creates the profile with the given name if not already there
	local PROFILE_NAME="$1"
	if [ -z "$PROFILE_NAME" ]; then
		PROFILE_NAME="default"
	fi
	local PROFILE_PATH="$DOTENV_PROFILES/$PROFILE_NAME"
	if [ ! -d "$PROFILE_PATH" ]; then
		dotenv_info "Created profile: $PROFILE_NAME"
		mkdir -p "$PROFILE_PATH"
	fi
}

function dotenv_profile_active {
	if [ -e "$DOTENV_ACTIVE" ]; then
		dotenv_output "$(basename "$(readlink "$DOTENV_ACTIVE")")"
	else
		dotenv_fail "dotenv/profile: No active profile"
	fi
}

function dotenv_profile_manifest_raw {
## Returns the list of files from the manifest
	local FILE
	local PROFILE="$1"
	local PROFILE_PATH
	local TEMPLATE
	# We normalize the profile name and path, to make sure
	# we can resolve to an actual file/directory.
	if [ -z "$PROFILE" ]; then
		PROFILE=$(dotenv_profile_active)
	fi
	if [ -z "$PROFILE" ]; then
		dotenv_fail "No profile selected"
	elif [ "$(dirname "$PROFILE")" == "." ]; then
		if [ -e "$DOTENV_TEMPLATES/$PROFILE" ]; then
			PROFILE_PATH="$DOTENV_TEMPLATES/$PROFILE"
		elif [ -e "$DOTENV_PROFILES/$PROFILE" ]; then
			PROFILE_PATH="$DOTENV_PROFILES/$PROFILE"
		fi
	fi
	if [ -z "$PROFILE_PATH" ]; then
		dotenv_fail "Profile does not exist in $DOTENV_PROFILES or $DOTENV_TEMPLATES: $PROFILE"
	fi
	# Now, if the profile has a template file, we recurse
	local TEMPLATE_FILE="$PROFILE_PATH/$TEMPLATE_NAME"
	if [ -e "$TEMPLATE_FILE" ]; then
		while read -r TEMPLATE; do
			dotenv_profile_manifest_raw "$TEMPLATE"
		done < "$TEMPLATE_FILE"
	fi
	# And now we output the files by profile
	find -L "$PROFILE_PATH" -name "*" -not -type d -not -name "$CONFIG_NAME" -not -name "$TEMPLATE_NAME" | while read -r FILE; do
		local FILE_NAME=${FILE#$PROFILE_PATH/}
		echo "$FILE_NAME|$FILE"
	done
}

function dotenv_profile_manifest_build {
## Creates links to all the files in the manifest into $DOTENV_MANIFEST.
## This makes sure that all files are linked from the available templates.
	# We clean the existing manifest file
	if [ -d "$DOTENV_MANIFEST" ]; then
		find "$DOTENV_MANIFEST" -type l -exec unlink '{}' ';'
		dotenv_dir_clean "$DOTENV_MANIFEST"
	fi
	# We create the manifest
	if [ ! -d "$DOTENV_MANIFEST" ]; then
		mkdir -p "$DOTENV_MANIFEST"
	fi
	local FILE
	for FILE in $(dotenv_profile_manifest_raw "$1"); do
		local FILE_ORIGIN="${FILE#*|}"
		local FILE_NAME=${FILE%|*}
		local FILE_SOURCE=${FILE_ORIGIN%*/$FILE_NAME}
		dotenv_dir_copy_parents "$FILE_SOURCE"/ "$DOTENV_MANIFEST"/ "$FILE_NAME"
		ln -sfr "$FILE_ORIGIN" "$DOTENV_MANIFEST/$FILE_NAME"
	done
}

function dotenv_profile_manifest {
## Lists the files defined in the given `profile`.
##
## @param PROFILE
	# NOTE: We make sure to filter out the dotenv configuration files
	dotenv_profile_manifest_raw "$1" |  cut -d'|' -f1 | grep -e '^dotenv\.' -v | sed 's/\.pre\..//g;s/\.post\..//g;s|.pre||g;s|.post||g;s|.tmpl||g' | sort | uniq
}

function dotenv_profile_list {
	local ALL
	local NAME
	local ACTIVE
	if [ -z "$DOTENV_PROFILES" ]; then
		dotenv_error "Environemnt variable DOTENV_PROFILES not defined"
	elif [ "$ALL" = "$DOTENV_PROFILES/*" ]; then
		dotenv_info "No templates defined in $DOTENV_PROFILES"
	else
		ALL=$(dotenv_dir_list "$DOTENV_PROFILES")
		ACTIVE=$(readlink -f "$DOTENV_ACTIVE")
		for NAME in $ALL; do
			if [ "$NAME" == "$ACTIVE" ]; then
				echo -n "▶"
			else
				echo -n " "
			fi
			basename "$NAME"
		done
	fi
}

function dotenv_profile_revert {
## Reverts the currently applied profile, cleaning up the managed
## folder and resotring any existing backup.
	# We start by reverting any already managed file
	local FILE
	# FIXME: Not good
	if [ -e "$DOTENV_MANAGED" ]; then
		local FILES_MANAGED
		FILES_MANAGED="$(find "$DOTENV_MANAGED" -name "*" -not -type d)"
		# We revert any managed file
		dotenv_managed_revert "$FILES_MANAGED"
		# Now we can safely remove all the managed files
		for FILE in $FILES_MANAGED; do
			unlink "$FILE"
		done
		# And clean up the directory
		dotenv_dir_clean "$DOTENV_MANAGED"
		# Which should now be clean.
		if [ -d "$DOTENV_MANAGED" ]; then
			dotenv_error "Managed directory still present after revert: $DOTENV_MANAGED"
			exit 1
		fi
	fi
	# We've reverted the active profile, so we can remove the link.
	if [ -e "$DOTENV_ACTIVE" ]; then
		unlink "$DOTENV_ACTIVE"
	fi
	# We restore backed up files so that the profile is in the 
	# same state it was before dotenv was run.
	dotenv_backup_restore
	if [ -d "$DOTENV_BACKUP" ]; then
		dotenv_error "Backup directory still present after restore: $DOTENV_BACKUP"
		exit 1
	fi
}

function dotenv_profile_apply {
## Applies the given `profile`, which must exist.
## @param profile
	# We revert any previously applied profile
	local FILE
	local PROFILE="$1"
	if [ -z "$PROFILE" ]; then
		PROFILE=$(dotenv_profile_active)
	fi
	if [ -z "$PROFILE" ]; then
		dotenv_fail "dotenv/apply: No active profile"
	elif [ ! -e "$DOTENV_PROFILES/$PROFILE" ]; then
		dotenv_fail "dotenv/apply: Profile does not exist: $DOTENV_PROFILES/$PROFILE"
	fi
	# Do we need to revert the previous profile?
	if [ "$(readlink -f "$DOTENV_PROFILES/$PROFILE")" != "$(readlink -f "$DOTENV_ACTIVE")" ]; then
		dotenv_profile_revert
		ln -sfr "$DOTENV_PROFILES/$PROFILE" "$DOTENV_ACTIVE"
	fi
	# We build the manifest cache for this profile
	dotenv_profile_manifest_build "$PROFILE"
	# Now we iterate on all the files that are part of the current profile
	for FILE in $(dotenv_profile_manifest "$PROFILE"); do
		local FILE_NAME=${FILE#$DOTENV_PROFILES/$1/}
		local FILE_INSTALLED=$DOTENV_USER_HOME/.$FILE_NAME
		dotenv_managed_make "$FILE_INSTALLED"
		dotenv_managed_install "$FILE_INSTALLED"
	done
}

function dotenv_backup_file {
## @param FILE* the files to backup
## Backs up the given file by **moving** them to `$DOTENV_BACKUP`.
	local FILE
	for FILE in "$@"; do
		dotenv_assert_file_is_dotfile "$FILE"
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local PARENT_NAME;PARENT_NAME=$(dirname "$FILE_NAME")
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
			if [ "$PARENT_NAME" != "." ] && [ ! -d "$FILE_BACKUP_PARENT" ]; then
				cp --attributes-only "$(dirname "$FILE")" "$FILE_BACKUP_PARENT"
			fi
		fi
		# And now we can backup the file
		mv "$FILE" "$FILE_BACKUP"
	done
}

function dotenv_backup_restore {
## Moves back every single file in $DOTENV_BACKUP to its original location
## in $DOTENV_USER_HOME. Empty directories will be pruned, which should
## result in $DOTENV_BACKUP to not exit at the end.
	local FILE
	if [ -d "$DOTENV_BACKUP" ]; then
		# For each file in the backup directory
		find "$DOTENV_BACKUP" -name "*" -not -type d | while read -r FILE; do
			# We determine the target directory
			local TARGET=$DOTENV_USER_HOME/.${FILE#$DOTENV_BACKUP/}
			local TARGET_DIR;TARGET_DIR=$(dirname "$TARGET")
			if [ ! -d "$TARGET_DIR" ]; then
				# TODO: We should actually copy the permissions
				mkdir -p "$TARGET_DIR"
			fi
			# If the target is a directory, we remove it when empty
			if [ -d "$TARGET" ]; then
				dotenv_dir_clean "$TARGET"
			fi
			# We move back the backed up file to its original location
			if [ ! -e "$TARGET" ]; then
				dotenv_info " = ~${TARGET#$DOTENV_USER_HOME}"
				mv "$FILE" "$TARGET"
			else
				dotenv_error "Cannot restore backup: $FILE"
				if [ -d "$TARGET" ]; then
					dotenv_error "Target directory is not empty: $TARGET"
				else
					dotenv_error "Target already exists: $TARGET"
				fi
			fi
		done
		# We remove empty directories from the backup
		dotenv_dir_clean "$DOTENV_BACKUP"
		if [ -e "$DOTENV_BACKUP" ] ; then
			dotenv_error "Could not fully restore backup, some files already exist."
			exit 1
		fi
	fi
}

# -----------------------------------------------------------------------------
#
# MANAGING FILES
#
# -----------------------------------------------------------------------------

function dotenv_managed_list {
## Lists the files currently managed by the active profile.
	local FILE
	if [ -e "$DOTENV_MANAGED" ]; then
		find "$DOTENV_MANAGED" -name "*" -not -type d | while read -r FILE; do
			local FILE_NAME=${FILE#$DOTENV_MANAGED/}
			local ACTUAL_TARGET;ACTUAL_TARGET=$(readlink -f "$DOTENV_USER_HOME/.$FILE_NAME")
			local EXPECTED_TARGET;EXPECTED_TARGET=$(readlink -f "$DOTENV_MANAGED/$FILE_NAME")
			local INSTALLED="$DOTENV_USER_HOME/.$FILE_NAME"
			local STATUS=" ✓ "
			if [ "$ACTUAL_TARGET" != "$EXPECTED_TARGET" ]; then
				STATUS="   "
			fi
			# We show the actual origin of the file
			local MANAGED;MANAGED=$(readlink -f "$DOTENV_MANAGED/$FILE_NAME")
			local FRAGMENTS;FRAGMENTS=$(dotenv_file_fragment_types "$DOTENV_USER_HOME/.$FILE_NAME")
			# TODO: We should output the paths relative to ~
			echo "$STATUS→$INSTALLED→$MANAGED→$FRAGMENTS"
		done
	fi
}

function dotenv_managed_list_installed {
## Lists the managed files (from `$DOTENV_MANAGED/*`) that are actually
## installedin in `$DOTENV_USER_HOME/.*`.
	local FILE
	local FILE_NAME
	local ACTUAL_TARGET
	local EXPECTED_TARGET
	if [ -e "$DOTENV_MANAGED" ]; then
		find "$DOTENV_MANAGED" -name "*" -not -type d | while read -r FILE; do
			FILE_NAME="${FILE#$DOTENV_MANAGED/}"
			ACTUAL_TARGET=$(readlink -f "$DOTENV_USER_HOME/.$FILE_NAME")
			EXPECTED_TARGET=$(readlink -f "$DOTENV_MANAGED/$FILE_NAME")
			if [ "$ACTUAL_TARGET" == "$EXPECTED_TARGET" ]; then
				echo "$DOTENV_USER_HOME/.$FILE_NAME"
			fi
		done
	fi
}

# NOTE: This function is complex and critical, it must be edited with care.
function dotenv_managed_add {
## @param FILES the files to be managed
## Adds the given FILES as managed files. This requires an active profile.
	dotenv_assert_active_profile
	if [ ! -e "$DOTENV_MANAGED" ]; then
		mkdir -p "$DOTENV_MANAGED"
	fi
	local FILE
	for FILE in "$@"; do
		# We ensure the file is a dotfile
		dotenv_assert_file_is_dotfile "$FILE"
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_BACKUP="$DOTENV_BACKUP/$FILE_NAME"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		local FILE_ACTIVE="$DOTENV_ACTIVE/$FILE_NAME"
		local FILE_ACTIVE_FRAGMENTS
		if [ -d "$FILE" ]; then
			dotenv_fail "dotenv can only managed files, not directories: $FILE"
		fi
		# NOTE: This might be better using a function call
		FILE_ACTIVE_FRAGMENTS=$(dotenv_file_fragment_list "$FILE_MANAGED")
		# Is the file already managed?
		if [ -e "$FILE_MANAGED" ]; then
			# If the file is already managed, we can try to backup the 
			# file and deploy our managed version.
			if [ "$(readlink "$FILE")" == "$FILE_MANAGED" ]; then
				dotenv_error "File is already managed : $FILE ← $FILE_MANAGED"
			else
				dotenv_error "File conflicts with managed file: $FILE_MANAGED $(readlink "$FILE")"
			fi
		# Is there a file in the active profile?
		elif [ -e "$FILE_ACTIVE" ]; then
			# The file is not managed yet (which means something failed before)
			# so we re-apply the rules to create the managed file (if any)
			dotenv_info "File already exists in active profile: $FILE → $FILE_ACTIVE"
		# Is there any fragment in the active profile, but not the file itself?
		elif [ "$FILE_ACTIVE_FRAGMENTS" != "" ]; then
			# It's the same as above, but with a file that only has fragments
			# ie `NAME.pre` but not `NAME`.
			dotenv_info "File already exists with fragments in active profile: $FILE → $FILE_ACTIVE_FRAGMENTS"
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
			local FILE_CANONICAL
			FILE_CANONICAL=$(readlink -f "$FILE")
			if [ -d "$FILE_CANONICAL" ]; then
				dotenv_error "Given file is a directory. Dotenv can only manage files."
				exit 1
			else
				# We create a copy of the canonical file.
				dotenv_dir_copy_parents "$DOTENV_USER_HOME/." "$DOTENV_ACTIVE/" "$FILE_NAME"
				dotenv_file_copy "$FILE" "$FILE_ACTIVE"
				# We recreate the managed file (in case there are fragments/templates)
				dotenv_managed_make "$FILE"
				# We finally create a symlink between the managed path and the HOME.
				# This will take care of backing up the original file.
				dotenv_managed_install "$FILE"
			fi
		fi
	done
}

# TODO: This is actually revert in the command line API
function dotenv_managed_remove {
	# NOTE: The caveat for this is that if you remove all the managed
	# files like config/nvim/* but that config/nvim is a symlink and
	# backed up as such (.dotenv/backups/config/nvim), then the
	# original won't be restored.
	local FILE
	local FILE_NAME
	local FILES="$*"
	# If there's no argument, then we revert all the managed files
	if [ -z "$FILES" ]; then
		FILES=$(dotenv_managed_list_installed)
	fi
	for FILE in $FILES; do
		FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_MANAGED="${DOTENV_MANAGED}/$FILE_NAME"
		local FILE_BACKUP="${DOTENV_BACKUP}/$FILE_NAME"
		if [ -e "$FILE_BACKUP" ]; then
			# Do we have a backup for the file? That's the expected
			# behaviour.
			dotenv_managed_revert "$FILE_MANAGED"
		elif [ -e "$FILE_MANAGED" ]; then
			# We don't have backup, but we should have the managed
			# file, which we can move back
			 dotenv_managed_revert "$FILE_MANAGED"
		else
			dotenv_error "No backup ($FILE_BACKUP) or managed file ($FILE_MANAGED) for: $FILE"
		fi
		# We make sure that if there's no specific backup for this
		# file that we clean up empty directories and restore parent
		# backed up symlinks.
		_dotenv_managed_revert_cleaner "$DOTENV_USER_HOME/." "$FILE"
	done
}

function _dotenv_managed_revert_cleaner {
## A helper function that will remove empty directories in the given
## FILE up to BASE. Empty directories will be removed, and if there is
## a backed up equivalent of FILE, it will be restored.
##
## This makes sure that when all the managed files have been removed in 
## a subdirectory that any backed up parent is actually restored.
##
## @param BASE
## @param FILE
	local BASE="$1"
	local FILE="${2%*/}"
	local FILE_NAME=${FILE#$BASE}
	if [ "$FILE" == "$FILE_NAME" ] || [ -z "$FILE" ] || [ "$FILE" == "$BASE" ] || [ "$FILE" == "/" ]; then
		FILE="$FILE"
	else
		local PARENT;PARENT=$(dirname "$FILE")
		if [ -e "$FILE" ] && [ -n "$(dotenv_dir_is_empty "$FILE")" ]; then
			rmdir "$FILE"
		fi
		local FILE_BACKUP=$DOTENV_BACKUP/$FILE_NAME
		if [ ! -e "$FILE" ] && [ ! -L "$FILE" ]; then
			if [ -e "$FILE_BACKUP" ] || [ -L "$FILE_BACKUP" ]; then
				# TODO: We might want to call dotenv_backup_restore
				dotenv_info " = $FILE"
				mv "$FILE_BACKUP" "$FILE"
				PARENT="$BASE"
			fi
		fi
		_dotenv_managed_revert_cleaner "$BASE" "$PARENT"
	fi
}

function dotenv_managed_make {
## Looks for each of the given `FILE`s in the active profile, and links
## the file or assembles its fragments into `~/.dotenv/managed`, output.
##
## NOTE: The profile's manifest should be built at that stage.
##
## @param  FILES ― these paths are relative to home
## @output The path for each managed file corresponding to the given path
	dotenv_assert_active_profile
	local FILE
	for FILE in "$@"; do
		dotenv_assert_file_is_dotfile "$FILE"
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_TARGET="$DOTENV_USER_HOME/.$FILE_NAME"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		local FILE_MANIFEST="$DOTENV_MANIFEST/$FILE_NAME"
		local FILE_FRAGMENTS
		FILE_FRAGMENTS="$(dotenv_file_fragment_types "$FILE_TARGET")"
		if [ -e "$FILE" ]; then
			# The file already exists, so we resolve it to its canoncial reference
			FILE=$(readlink -f "$FILE")
		elif [ -z "$FILE_FRAGMENTS" ]; then
			# There is on fragment, nor managed version, nor existisng file
			dotenv_fail "$FILE does not exist in active profile: $FILE_MANIFEST"
		fi
		if [ ! -e "$FILE_MANIFEST" ] && [ -z "$FILE_FRAGMENTS" ]; then
			dotenv_fail "dotenv/make: File or fragments not found in active profile: $FILE_MANIFEST"
		fi
		# We make sure to remove the managed file, as we're going to rebuild
		# it. It might be a symlink or a regular file.
		if [ -e "$FILE_MANAGED" ]; then
			chmod u+w "$FILE_MANAGED"
			unlink "$FILE_MANAGED"
		fi
		# If there is only one regular file as a fragment, we symlink from
		# the active profile to the managed.
		dotenv_dir_copy_parents "$DOTENV_MANIFEST/" "$DOTENV_MANAGED/" "$FILE_NAME" 
		if [ "$FILE_FRAGMENTS" == "f" ]; then
			# NOTE: We don't use the FILE_MANIFEST as it might not exist if the
			# file is from a template.
			ln -sfr "$(readlink -f "$FILE_MANIFEST")" "$FILE_MANAGED"
		# Otherwise we assemble it
		else
			# TODO: Copy/apply file attributes
			dotenv_file_assemble "$FILE_TARGET"  > "$FILE_MANAGED"
		fi
	done
}

function dotenv_managed_cat {
## Outputs the current value of the managed dotfile `DOTFILE`. 
##
## @param DOTFILE ― the path to the *dotfile*, which must be relative
#         to `$DOTENV_MANAGED`
	dotenv_assert_active_profile
	for FILE in "$@"; do
		dotenv_assert_file_is_dotfile "$FILE"
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		# TODO: What to do if the file is not active?
		if [ -e "$FILE_MANAGED" ]; then
			cat "$FILE_MANAGED"
		fi
	done
}

function dotenv_managed_install {
## Takes a file readily available in $DOTENV_MANAGED and installs it
## in $DOTENV_USER_HOME. This requires that there is no existing backup
## for the given file.
##
## @param FILES ― relative to $DOTENV_USER_HOME that needs to be applied
##        from the $DOTENV_MANAGED directory.
##
	dotenv_assert_active_profile
	local FILE
	local FILES=$*
	if [ -z "$FILES" ]; then
		for FILE in $(dotenv_profile_manifest); do
			FILES="$FILES $DOTENV_USER_HOME/.$FILE"
		done
	fi
	for FILE in $FILES; do
		dotenv_assert_file_is_dotfile "$FILE"
		local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
		local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
		local FILE_ACTIVE="$DOTENV_ACTIVE/$FILE_NAME"
		local FILE_BACKUP
		local FILE_ORIGIN;FILE_ORIGIN=$(dotenv_file_origin "$DOTENV_USER_HOME" "$FILE")
		if [ ! -e "$FILE_MANAGED" ]; then
			dotenv_fail "Managed file does not exist: $FILE_MANAGED"
		fi
		if [ ! -e "$FILE" ]; then
			# If the file does not exist, we simply install it
			dotenv_info " + $FILE"
			_dotenv_managed_install "$FILE"
		elif [ "$(readlink -f "$FILE")" == "$(readlink -f "$FILE_MANAGED")" ]; then
			# If the file is already managed, we don't have anything to do
			# the old one.
			FILE="$FILE"
		else
			# TODO: We should check if both files are the same or not
			# We backup the original dotfile
			if [ "$FILE" != "$FILE_ORIGIN" ]; then
				# The file we're going to replace is contained in a symlinked
				# directory, so we need to move the whole thing and recreate
				# the same structure locally.
				#
				# For instance:
				#
				# ~/.vim                  SYMLINK TO  ~/.dofiles/vim
				# ~/.vim/scripts/init.vim         IS ACTUALLY ~/.dotfiles/vim/scripts/init.vim
				#
				# installing ~/.vim/scripts/init.vim will:
				#
				# 1) Backup ~/.vim to ~/.dotenv/backups/vim
				# 2) Unlink ~/.vim
				# 3) Install the managed version
				FILE_BACKUP="$DOTENV_BACKUP/${FILE_ORIGIN#$DOTENV_USER_HOME/.}"
				if [ -e "$FILE_BACKUP" ]; then
					dotenv_fail "Symlink already exists in the backup: $FILE_BACKUP"
				fi
				# We backup the origin (which is a symlink)
				dotenv_backup_file "$FILE_ORIGIN"
				# We remove the origin, as we don't need it anymore
				dotenv_file_remove "$FILE_ORIGIN"
			else
				FILE_BACKUP="$DOTENV_BACKUP/$FILE_NAME"
				if [ -e "$FILE_BACKUP" ]; then
					dotenv_fail "File already exists in the backup: $FILE_BACKUP"
				fi
				dotenv_backup_file "$FILE"
				dotenv_file_remove "$FILE"
			fi
			dotenv_info " < $FILE"
			_dotenv_managed_install "$FILE"
		fi
	done
}

# NOTE: This is a HELPER function
function _dotenv_managed_install {
## @helper
## @param FILE the $DOTENV_USER_HOME file that will be updated with the
##        corresponding $DOTENV_MANAGED file.
##
## This creates a symlink for the given FILE between $DOTENV_MANAGED 
## and $DOTENV_USER_HOME, and creating parent directories (with permissions)
## as necessary.
	local FILE="$1"
	local FILE_NAME="${FILE#$DOTENV_USER_HOME/.}"
	local FILE_MANAGED="$DOTENV_MANAGED/$FILE_NAME"
	if [ "$FILE" == "$DOTENV_USER_HOME" ]; then
		# Nothing to do in that case 
		FILE="$FILE"
	elif [ ! -z "$FILE_NAME" ]; then
		local PARENT_NAME;PARENT_NAME=$(dirname "$FILE")
		# We ensure that the parent exists
		if [ ! -z "$PARENT_NAME" ]; then
			_dotenv_managed_install "$PARENT_NAME"
		fi
		# Is the managed file a directory?
		if [ -d "$FILE_MANAGED" ]; then
			if [ ! -e "$FILE" ]; then
				# NOTE: We don't need -p here as we've recursed on the parent
				# already
				dotenv_dir_copy_structure "$DOTENV_MANAGED/" "$DOTENV_USER_HOME/." "$FILE_NAME"
			fi
		else
			# Here the managed version is a file.
			if [ ! -e "$FILE" ]; then
				# If there's no target file, we link it
				if [ ! -e "$FILE_MANAGED" ]; then
					dotenv_fail "dotenv/install: Managed file does not exist: $FILE_MANAGED"
				else
					ln -sfr "$FILE_MANAGED" "$FILE"
				fi
			elif [ "$(readlink "$FILE")" != "$FILE_MANAGED" ]; then
				# If there's a file and it's not a link to our
				# managed file, we back it up.
				dotenv_info "Backing up existing file $FILE to $FILE.bak"
				# TODO: Improve this with suffixes if backups already
				# present.
				mv "$FILE" "$FILE".bak
				ln -sfr "$FILE_MANAGED" "$FILE"
			fi
		fi
	fi
}

function dotenv_managed_revert {
## Iterates on the given `FILE`s or all the files in the $DOTENV_MANAGED directory.
## For each of these `FILE:
##
## - The installed version in `~/.FILE` will be restored with a backup (if any)
## - The managed file will be unlinked (but will remain in the profile)
##
## Note that each file is going to be considered to "$DOTENV_MANAGED", so you
## can't directly given dotfiles.
##
## This requires the target file to point back to the same file as the managed
## file. If not, this means the file was changed and the process will fail.
	local FILE
	local FILES="$*"
	if [ -d "$DOTENV_MANAGED" ]; then
		for FILE in $FILES; do
			if [ "$(dotenv_file_is_dotfile "$FILE")" == "OK" ];  then
				FILE=$DOTENV_MANAGED/${FILE#$DOTENV_USER_HOME/.}
			fi
			dotenv_assert_file_is_managed "$FILE"
			# TARGET is the dotfile path in the user's home
			local FILE_NAME=${FILE#$DOTENV_MANAGED/}
			local TARGET=$DOTENV_USER_HOME/.$FILE_NAME
			local FILE_MANAGED=$DOTENV_MANAGED/$FILE_NAME
			local FILE_BACKUP=$DOTENV_BACKUP/$FILE_NAME
			if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
				# The target already exists, so we check that its origin
				# is what we expect (ie, it is managed)
				ACTUAL_ORIGIN=$(readlink -f "$TARGET")
				EXPECTED_ORIGIN=$(readlink -f "$FILE_MANAGED")
				if [ "$ACTUAL_ORIGIN" != "$EXPECTED_ORIGIN" ]; then
					# TODO: Improve error message
					dotenv_error "dotenv/revert: Managed file \"$TARGET\" should point to \"$EXPECTED_ORIGIN\""
					dotenv_error "but instead points to \"$ACTUAL_ORIGIN\""
					# NOTE: We don't unlink the file there.
				else
					# This is where we effectively remove the installed
					# file and restore the backup (if any).
					unlink "$TARGET"
					if [ -e "$FILE_BACKUP" ] || [ -L "$FILE_BACKUP" ]; then
						# TODO: Should have a restore backup function
						dotenv_info " = $TARGET"
						mv "$FILE_BACKUP" "$TARGET"
						dotenv_dir_clean "$(dirname "$FILE_BACKUP")"
					fi
				fi
				# We clean the target directory.
				if [ "$(dirname "$TARGET")" != "$DOTENV_USER_HOME" ]; then
					dotenv_dir_clean "$(dirname "$TARGET")"
				fi
			fi
		done
		# TODO: Remove empty directories on the target side
		# We remove empty directories
		dotenv_dir_clean "$DOTENV_MANAGED"
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
		find "$1" -name "*.tmpl" -exec cat '{}' ';' | grep -o -e '\${[A-Z_]+}' | tr -d '{}$' | sort | uniq
	fi
}

function dotenv_configuration_variables {
## Lists the configuration variables defined in the given file
	egrep -o '^\s*[A-Z_]+\s*=' < "$1" | tr -d '= ' | sort | uniq
}

function dotenv_configuration_create {
## Outputs a new configuration file for the template files in the given $DIRECTORY
	echo "# Configuration extracted from template ${1#$DOTENV_TEMPLATES/} on $(date +'%F')"
	echo "# Edit this file and fill in the variables"
	local VARIABLE
	for VARIABLE in $(dotenv_configuration_extract "$1"); do
		echo "$VARIABLE="
	done
	echo "# EOF"
}

function dotenv_configuration_delta {
## Outputs a user-editable delta to update their configuration file. Takes
## a directory containing the TEMPLATE files and the CONFIG file
## defining the variables.
	local DIR_VARS;DIR_VARS=$(dotenv_configuration_extract "$1")
	local CUR_VARS=""
	if [ -e "$2" ]; then
		CUR_VARS=$(dotenv_configuration_variables "$2")
	fi
	local DIR_TMP;DIR_TMP="$(mktemp)"
	local CUR_TMP;CUR_TMP="$(mktemp)"
	echo "$DIR_VARS" > "$DIR_TMP"
	echo "$CUR_VARS" > "$CUR_TMP"
	local MISSING;MISSING=$(diff "$DIR_TMP" "$CUR_TMP" | grep '< ' | cut -d' ' -f 2)
	local EXTRA;EXTRA=$(diff "$DIR_TMP" "$CUR_TMP" | grep '> ' | cut -d' ' -f 2)
	rm "$DIR_TMP" "$CUR_TMP"
	if [ ! -z "$MISSING" ] || [ ! -z "$EXTRA" ]; then
		echo "# ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――"
		echo "# Configuration updated from template ${1#$DOTENV_TEMPLATES/} on $(date +'%F')"
		echo "# The following variables are new:"
		local VARIABLE
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

function dotenv_template_apply {
## Applies the given TEMPLATE to the given PROFILE=default.
	#dotfile_template_apply ~/.dotenv/templates/ffunction/hgrc.tmpl ~/.dotenv/profiles/sebastien/config.dotenv.sh
	#dotfile_template_assemble ~/.dotenv/templates/ffunction/hgrc.tmpl ~/.dotenv/profiles/sebastien
	local TEMPLATE="$1"
	local PROFILE="$2"
	if [ -z "$PROFILE" ]; then
		PROFILE="default"
	fi
	if [ -z "$TEMPLATE" ]; then
		dotenv_error "dotenv_template_apply TEMPLATE PROFILE"
	elif [ -z "$TEMPLATE" ]; then
		dotenv_error "TEMPLATE is expected"
	elif [ ! -e "$DOTENV_TEMPLATES/$TEMPLATE" ]; then
		dotenv_error "TEMPLATE \"$TEMPLATE\" not found at $DOTENV_TEMPLATES/$TEMPLATE"
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
		local CONFIG_DELTA;CONFIG_DELTA=$(dotenv_configuration_delta "$DOTENV_TEMPLATES/$TEMPLATE" "$CONFIG_DOTENV")
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

function dotenv_template_merge {
	local PARENT="$1"
	local TEMPLATE="$2"
	if [ -z "$PARENT" ] && [ -z "$TEMPLATE" ]; then
		dotenv_error "dotenv_template_merge PARENT TEMPLATE"
	elif [ -z "$PARENT" ]; then
		dotenv_error "PARENT is expected"
	elif [ -z "$TEMPLATE" ]; then
		dotenv_error "TEMPLATE is expected"
	elif [ ! -e "$DOTENV_TEMPLATES/$PARENT" ]; then
		dotenv_error "PARENT \"$PARENT\" not found at $DOTENV_TEMPLATES/$PARENT"
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
	local FILE
	local SUFFIX
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
		local DEST_FILE="$TARGET/$SUFFIX"
		if [ ! -z "$SUFFIX" ]; then
			# We get the parent directory and create it if necessessary
			local TARGET_PARENT;TARGET_PARENT=$(dirname "$DEST_FILE")
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
	local DIRPATH;DIRPATH=$(readlink -f "$1")
	local SUFFIX=${DIRPATH#$DOTENV_USER_HOME}
	if [ -d "$DIRPATH" ] && [ "$SUFFIX" != "" ] && [ "$SUFFIX" != "/" ]; then
		find "$DIRPATH" -depth -type d -empty -exec rmdir '{}' ';'
	fi
}

function dotenv_dir_is_empty {
	if [ -e "$1" ] && [ -n "$(find "$1" -prune -empty 2> /dev/null)" ]; then
		echo "EMPTY"
	fi
}


function dotenv_dir_copy_parents {
## Copies the struture of the parent directory of the given
## FILE relative to the SOURCE in DESTINATION
##
## @param SOURCE ― the source directory
## @param DESTINATION ― the directory in which the parents
##        will be copied
## @param FILE ― the path of the file relative to SOURCE
	local PARENT_NAME
	PARENT_NAME=$(dirname "$3")
	if [ "$PARENT_NAME" != "." ]; then
		dotenv_dir_copy_structure "$1" "$2" "$PARENT_NAME"
	elif [ ! -d "$2" ]; then
		mkdir "$2"
	fi
}

function dotenv_dir_copy_structure {
## @param SOURCE_PREFIX
## @param DESTINATION_PREFIX
	local SOURCE_PREFIX="$1"
	local DESTINATION_PREFIX="$2"
	local FILE_NAME="$3"
	local PARENT_NAME;PARENT_NAME=$(dirname "$3")
	local SOURCE="$SOURCE_PREFIX$FILE_NAME"
	local DESTINATION="$DESTINATION_PREFIX$FILE_NAME"
	local SOURCE_CANONICAL
	if [ ! -e "$SOURCE" ]; then
		dotenv_fail "Source path does not exist: $SOURCE"
	else
		SOURCE_CANONICAL=$(readlink -f "$SOURCE")
		if [ ! -d "$SOURCE_CANONICAL" ]; then
			dotenv_fail "Source is not a directory: $SOURCE → $SOURCE_CANONICAL"
		fi
		if [ "$PARENT_NAME" != "." ]; then
			dotenv_dir_copy_structure "$1" "$2" "$PARENT_NAME"
		fi
		# The source is a directory, so we make sure that the destination
		# exists and is a directory as well.
		if [ ! -d "$DESTINATION" ]; then
			dotenv_file_remove "$DESTINATION"
			mkdir -p "$DESTINATION"
			chmod --reference "$SOURCE_CANONICAL" "$DESTINATION"
			chown --reference "$SOURCE_CANONICAL" "$DESTINATION"
			# TODO: We should also copy the xattrs, if possible
		fi
	fi
}

function dotenv_file_copy {
## @param SOURCE
## @param DESTINATION
## Copies the given file and its directory
	local SOURCE="$1"
	local DESTINATION="$2"
	dotenv_assert_file_is_dotfile "$SOURCE"
	local FILE_NAME=${SOURCE#$DOTENV_USER_HOME/.}
	SOURCE="$DOTENV_USER_HOME/.$FILE_NAME"
	if [ ! -e "$SOURCE" ]; then
		dotenv_fail "Source file does not exist: $SOURCE"
	elif [ -d "$SOURCE" ];  then
		dotenv_fail "Trying to copy a directory to a file: $SOURCE"
	else
		dotenv_dir_copy_parents "$DOTENV_USER_HOME/." "$DOTENV_MANAGED/" "$FILE_NAME"
		if [ -d "$DESTINATION" ]; then
			dotenv_fail "Trying to copy file $SOURCE over directory $DESTINATION"
		else
			dotenv_file_remove "$DESTINATION"
			# NOTE: We don't want to use `cp` because we don't want to preserve
			# symlinks. We want an actual file.
			cat "$SOURCE" > "$DESTINATION"
			cp --attributes-only "$SOURCE" "$DESTINATION"
		fi
	fi
}

function dotenv_file_is_dotfile {
## @param FILE
## Echoes "OK" if the given file is a dotfile
	if [ "$(dotenv_file_has_prefix "$1" "$DOTENV_HOME/")" != "OK" ]; then
		dotenv_file_has_prefix "$1" "$DOTENV_USER_HOME/."
	fi
}

function dotenv_file_has_prefix {
## @param FILE
## @param PREFIX
## Echoes "OK" if the given FILE has the given PREFIX
	if [ "$1" == "$2${1#$2}" ]; then
		echo -n "OK"
	fi
}

function dotenv_file_pre_list {
## Lists the `.pre.*` fragments for the given file, if any. The files
## need to exist to be listed.
	local PRE
	for PRE in $1.pre $1.pre.*; do
		if [ -e "$PRE" ]; then
			echo "PRE"
		fi
	done
}

function dotenv_file_post_list {
## Lists the `.post.*` fragments for the given file, if any. The files need
## to exists to be listed.
	local POST
	for POST in $1.post $1.post.*; do
		if [ -e "$POST" ]; then
			echo "$POST"
		fi
	done
}

function dotenv_file_fragment_list {
## @param FILE ― when FILE is a dotfile, it will look in the current profile's
##        raw manifest and extract the list of file fragments through the
##        templates.
## Lists the file fragments used to assemble the given file. This looks
## for  `*.pre.*` and `*.post.*` files and outputs them in order.
	
	local FILE="$1"
	if [ "$(dotenv_file_has_prefix "$FILE" "$DOTENV_HOME")" != "OK" ] && [ "$(dotenv_file_is_dotfile "$FILE")" == "OK" ]; then
		# If the given FILE is a *dotfile* then we look in the
		# complete raw manifest and extract the list of actual templates
		local FILE_NAME=${1#$DOTENV_USER_HOME/.}
		local FILE_FRAGMENTS
		FILE_FRAGMENTS=$(dotenv_profile_manifest_raw | grep "$FILE_NAME" | cut -d'|' -f2 | sed 's/\.pre\..//g;s/\.post\..//g;s|.pre||g;s|.post||g;s|.tmpl||g')
		for FILE in $FILE_FRAGMENTS; do
			dotenv_file_fragment_list "$FILE"
		done
	else
		dotenv_file_pre_list  "$FILE"
		if [ -e "$FILE" ]; then
			echo "$FILE"
		fi
		if [ -e "$FILE.tmpl" ]; then
			echo "$FILE.tmpl"
		fi
		dotenv_file_post_list "$FILE"
	fi
}

function dotenv_file_fragment_types {
## Returns a string combining the different types of fragments that 
## create the given file. Template fragments will produce a `T`, 
## while file fragments will produce an `f`.
	local FRAGMENT
	local FILE="$1"
	if [ "$(dotenv_file_is_dotfile "$FILE")" != "OK" ]; then
		FILE="$DOTENV_ACTIVE/${FILE#$DOTENV_USER_HOME/.}"
	fi
	for FRAGMENT in $(dotenv_file_fragment_list "$FILE"); do
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
	local FRAGMENT
	for FRAGMENT in $(dotenv_file_fragment_list "$1"); do
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

function dotenv_file_remove {
## @param FILE the file or link to be removed
	if [ -L "$1" ]; then
		unlink "$1"
	elif [ -f "$1" ]; then
		chmod u+w "$1" ; unlink "$1"
	fi
}

function dotenv_file_origin {
## Retrieves the origina for the given FILE, stopping at BASE. 
## The **origin** is going to be the FILE unless the FILE is 
## contained in a symlinked directory up to BASE. In this case,
## the symlinked closest to BASE will be returned.
##
## @param BASE 
## @param FILE
## @param ORIGIN
	local BASE="${1%*/}"
	local FILE="$2"
	local ORIGIN="$3"
	local PARENT;PARENT=$(dirname "$FILE")
	if [ -z "$ORIGIN" ] || [ -L "$FILE" ]; then
		ORIGIN="$FILE"
	fi
	if [ "$PARENT" == "." ] || [ "$PARENT" == "/" ] || [ "$FILE" == "$BASE" ]; then
		echo "$ORIGIN"
	else
		dotenv_file_origin "$BASE" "$PARENT" "$ORIGIN"
	fi
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
		CONFIG="$DOTENV_ACTIVE/$CONFIG_NAME"
	fi
	if [ ! -e "$CONFIG" ]; then
		dotenv_fail "Configuration file $CONFIG does not exist"
	else
		# First, we get the list of fields from the $CONFIG file, which
		# is supposed to be a shell script.
		local FIELDS;FIELDS=$(grep -E "^(export\\s*)?[A-Z_]+\\s*=" "$CONFIG" | cut -d= -f1 | xargs echo)
		# FIXME: We might want to backup the environment
		# Now we source the data file. If this goes wrong, the script is
		# probably going to stop.
		# shellcheck source=/dev/null
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
		sed "$SEDEXPR" < "$FILE"
	fi
}

# EOF
