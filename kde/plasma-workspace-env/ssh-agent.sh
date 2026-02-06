#!/bin/bash
# KDE Plasma startup script to initialize SSH agent
# This runs early in Plasma startup and exports environment variables

# Start ssh-agent if not already running
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi

# Use ksshaskpass for SSH password prompts (works with KWallet)
export SSH_ASKPASS=/usr/bin/ksshaskpass
export SSH_ASKPASS_REQUIRE=prefer

# Export to systemd and dbus so all applications can use SSH agent
systemctl --user import-environment SSH_AUTH_SOCK SSH_AGENT_PID
dbus-update-activation-environment --systemd SSH_AUTH_SOCK SSH_AGENT_PID
