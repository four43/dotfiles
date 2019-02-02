#!/usr/bin/env bash
set -ex
echo "Starting polybar!"

# We have a top and bottom polybar in this theme
# primary-top, primary-bottom then for any other monitors: secondary-top, secondary-bottom

PRIMARY_DISPLAY=$(${DOTFILE_DIR}/bin/x11/primary-display)
MONITOR="${PRIMARY_DISPLAY}" polybar --config="${DOTFILE_DIR}/themes/current/polybar/config" primary-top
MONITOR="${PRIMARY_DISPLAY}" polybar --config="${DOTFILE_DIR}/themes/current/polybar/config" primary-bottom
