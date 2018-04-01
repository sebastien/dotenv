#!/usr/bin/env bash
PREFIX=~/.local
BIN_FILES=$(echo bin/*)
LIB_FILES=$(echo share/*/*.bash)
ALL_FILES="$BIN_FILES $LIB_FILES"
BASE="https://raw.githubusercontent.com/sebastien/dotenv/master"

if [ "$1" = "uninstall" ]; then
	for FILE in $ALL_FILES; do
		FILE=$PREFIX/$FILE
		if [ -e "$FILE" ]; then
			echo Removing "$FILE"
			unlink "$FILE"
		fi
	done
else
	if [ ! -d $PREFIX/bin ]; then
		mkdir -p $PREFIX/bin
	fi
	for FILE in $ALL_FILES; do
		DST=$PREFIX/$FILE
		DIR=$(dirname "$DST")
		if [ ! -d "$DIR" ]; then
			mkdir -p "$DIR"
		fi
		if [ -e "$DST" ]; then
			echo Removing previous version "$DST"
			unlink "$DST"
		fi
		if [ -f "$FILE" ]; then
			SRC="$FILE"
			if [ "$1" = "link" ]; then
				echo Linking "$SRC" → "$DST"
				ln -sfr "$SRC" "$DST"
			else
				echo Copying "$SRC" → "$DST"
				cp -a "$SRC" "$DST"
			fi
		else
			SRC=$BASE/$FILE
			echo "Installing from remote source $SRC → $DST"
			curl "$SRC" > "$DST"
		fi
	done
	for FILE in $BIN_FILES; do
		chmod +x "$PREFIX/$FILE"
	done
fi

# EOF - vim: ts=4 sw=4 noet 
