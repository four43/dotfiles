# SSH_AUTH_SOCK Configuration Summary

This document summarizes all files in this dotfiles repository related to SSH agent configuration on Arch Linux with KDE Plasma.

## Overview

The configuration uses the **KDE Plasma approach** to:

1. Start an SSH agent at login via KDE Plasma environment scripts
2. Export `SSH_AUTH_SOCK` and `SSH_AGENT_PID` to all applications (including GUI apps like VSCode)
3. Use KDE's `ksshaskpass` for password prompts (integrates with KWallet)
4. Load SSH keys automatically at login

---

## Active Files

### 1. KDE Plasma Environment Script

**File:** [kde/plasma-workspace-env/ssh-agent.sh](../kde/plasma-workspace-env/ssh-agent.sh)
**Installed to:** `~/.config/plasma-workspace/env/ssh-agent.sh`

Runs early during KDE Plasma startup. Starts `ssh-agent` directly and exports the environment variables to systemd and dbus so all applications can access the agent.

### 2. SSH Askpass Environment Configuration

**File:** [arch/.config/environment.d/ssh_askpass.conf](../arch/.config/environment.d/ssh_askpass.conf)
**Installed to:** `~/.config/environment.d/ssh_askpass.conf`

Sets `SSH_ASKPASS=/usr/bin/ksshaskpass` globally via systemd's environment.d mechanism. This enables KDE's graphical password prompt which integrates with KWallet.

### 3. KDE Autostart SSH Key Loader

**File:** [kde/autostart/ssh-add.desktop](../kde/autostart/ssh-add.desktop)
**Installed to:** `~/.config/autostart/ssh-add.desktop`

Desktop entry that runs during KDE autostart phase 1 to load SSH keys after the agent is started.

### 4. SSH Add Keys Script

**File:** [arch/scripts/ssh-add-keys.sh](../arch/scripts/ssh-add-keys.sh)
**Called by:** ssh-add.desktop autostart

Adds SSH keys (`id_rsa`, `id_rsa_vaisala`) to the running agent. Will prompt via ksshaskpass if keys are password-protected.

### 5. SSH Config

**File:** [ssh/ssh-config](../ssh/ssh-config)
**Installed to:** `~/.ssh/config`

SSH client configuration. Sets `AddKeysToAgent yes` for automatic key addition on first use.

---

## Execution Order

1. **System login** - `ssh_askpass.conf` loaded via environment.d
2. **Plasma starts** - `ssh-agent.sh` runs via plasma-workspace/env, starts agent
3. **KDE autostart phase 1** - `ssh-add.desktop` runs `ssh-add-keys.sh` to load keys

---

## Files Summary

| File | Purpose | Status |
|------|---------|--------|
| `ssh-agent.sh` | Start ssh-agent at Plasma startup | Active |
| `ssh_askpass.conf` | KDE password prompts via ksshaskpass | Active |
| `ssh-add.desktop` | Autostart entry for key loading | Active |
| `ssh-add-keys.sh` | Add keys to agent | Active |
| `ssh-config` | SSH client config | Active |
