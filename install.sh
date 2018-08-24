#!/usr/bin/env bash
PREFIX=~/.local
BIN_FILES=$(echo bin/*)
LIB_FILES=$(echo lib/* lib/*/*.bash)
ALL_FILES="$BIN_FILES $LIB_FILES"
BASE_URL="https://raw.githubusercontent.com/sebastien/dotenv/master"

if [ ! -e "$PREFIX" ]; then
	echo "Prefix $PREFIX does not exist"
	exit 1
fi

# We dispatch the arguments
case $1 in
uninstall)
	# We uninstall all the files
	for FILE in $ALL_FILES; do
		FILE=$PREFIX/$FILE
		if [ -e "$FILE" ] || [ -L "$FILE" ]; then
			# TODO: We should clean empty directories
			echo Removing "$FILE"
			unlink "$FILE"
		fi
	done
	exit 0
	;;
install|link|*)
	# We make sure the directories exist
	if [ ! -d $PREFIX/bin ]; then
		mkdir -p $PREFIX/bin
	fi
	# We iterate on all the files an install them
	for FILE in $ALL_FILES; do
		DST=$PREFIX/$FILE
		DIR=$(dirname "$DST")
		# We create the parent directory, if needed
		if [ ! -d "$DIR" ]; then
			mkdir -p "$DIR"
		fi
		# We erase any previous file
		if [ -e "$DST" ]; then
			echo Removing previous version "$DST"
			unlink "$DST"
		fi
		# If the source file exists locally, we use it
		if [ -f "$FILE" ]; then
			SRC="$FILE"
			if [ "$1" = "link" ]; then
				echo Linking "$SRC" → "$DST"
				ln -sfr "$SRC" "$DST"
			else
				echo Copying "$SRC" → "$DST"
				cp -a "$SRC" "$DST"
			fi
		# Otherwise we need to get it from source and install it
		# as is
		else
			SRC=$BASE_URL/$FILE
			echo "Installing from remote source $SRC → $DST"
			curl "$SRC" > "$DST"
		fi
	done
	# We make sure the BIN files are executable, which
	# might not be the case if they were downloaded
	for FILE in $BIN_FILES; do
		chmod +x "$PREFIX/$FILE"
	done
esac

# EOF - vim: ts=4 sw=4 noet 
