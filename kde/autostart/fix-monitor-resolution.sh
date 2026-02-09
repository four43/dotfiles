#!/bin/bash
# Fix monitor resolutions on login
# Ensures monitors have correct resolution after waking from DPMS sleep
# Only runs on aurora (desktop with three monitors)

if [[ "$(hostname)" != "aurora" ]]; then
    exit 0
fi

kscreen-doctor output.DP-3.mode.2560x1440@164.80
kscreen-doctor output.DP-4.mode.2560x1440@164.80
kscreen-doctor output.DP-5.mode.2560x1440@164.80
