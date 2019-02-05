#!/usr/bin/env bash
set -ex

echo "Killing currently running polybar instances.."
pkill polybar || true

echo "Starting polybar!"
# We have a top and bottom polybar in this theme
# primary-top, primary-bottom then for any other monitors: secondary-top, secondary-bottom

PRIMARY_DISPLAY=$(${DOTFILE_DIR}/bin/x11/primary-display)

ACTIVE_INTERFACE=$(${DOTFILE_DIR}/bin/active-network-interface)

export LAN_WIRED_DEVICE=$(echo "${ACTIVE_INTERFACE}" | grep '^e') && echo "${CURRENT_INTERFACE}" || echo ""
export LAN_WIRELESS_DEVICE=$(echo "${ACTIVE_INTERFACE}" | grep '^w') && echo "${CURRENT_INTERFACE}" || echo ""
MONITOR="${PRIMARY_DISPLAY}" polybar --config="${DOTFILE_DIR}/themes/current/polybar/config" primary-top &
MONITOR="${PRIMARY_DISPLAY}" polybar --config="${DOTFILE_DIR}/themes/current/polybar/config" primary-bottom &

DISPLAY_ARR=( $(echo "${DISPLAY_ORDER}"))
for DISPLAY in "${DISPLAY_ARR[@]}"; do
    if [[ $DISPLAY != $PRIMARY_DISPLAY ]]; then
        MONITOR="${DISPLAY}" polybar --config="${DOTFILE_DIR}/themes/current/polybar/config" secondary-top &
        # MONITOR="${DISPLAY}" polybar --config="${DOTFILE_DIR}/themes/current/polybar/config" secondary-bottom &
    fi
done
