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

source "$BASE/../share/dotenv/api.bash"

function dotenv-profile {
	local PROFILE="$1"
	if [ -z "$PROFILE" ]; then
		for PROFILE in "$DOTENV_PROFILES"; do
			echo "$PROFILE"
		done
	else
		echo "Kapouet"
	fi
}

# EOF - vim: ts=4 sw=4 noet 
