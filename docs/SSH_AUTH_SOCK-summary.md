# SSH_AUTH_SOCK Configuration Summary

This document summarizes all files in this dotfiles repository related to SSH agent configuration on Arch Linux with KDE Plasma.

## Overview

The configuration uses the **systemd user socket approach** to:

1. Start an SSH agent on demand via systemd's `ssh-agent.socket` user unit
2. Pin `SSH_AUTH_SOCK` to a stable, known path so graphical *and* SSH login
   sessions share one agent
3. Use KDE's `ksshaskpass` for password prompts (integrates with KWallet)
4. Load SSH keys automatically at graphical login

Previously this was done with a `~/.config/plasma-workspace/env/ssh-agent.sh`
script (and, before that, a `keychain.service` unit) that spawned its own agent
and pushed `SSH_AUTH_SOCK`/`SSH_AGENT_PID` into systemd and dbus. Both are gone:
they produced a *per-graphical-session* agent at a random `/tmp` path, so SSH
logins to the same machine got a different agent — or none at all.

---

## Active Files

### 1. SSH_AUTH_SOCK Environment Configuration

**File:** [arch/.config/environment.d/ssh_auth_sock.conf](../arch/.config/environment.d/ssh_auth_sock.conf)
**Installed to:** `~/.config/environment.d/ssh_auth_sock.conf`

Pins `SSH_AUTH_SOCK` to `${XDG_RUNTIME_DIR}/ssh-agent.socket`. The agent itself
is started on demand by the systemd user unit — enable it once per machine:

```sh
systemctl --user enable --now ssh-agent.socket
```

### 2. SSH Askpass Environment Configuration

**File:** [arch/.config/environment.d/ssh_askpass.conf](../arch/.config/environment.d/ssh_askpass.conf)
**Installed to:** `~/.config/environment.d/ssh_askpass.conf`

Sets `SSH_ASKPASS=/usr/bin/ksshaskpass` globally via systemd's environment.d mechanism. This enables KDE's graphical password prompt which integrates with KWallet.

### 3. KDE Autostart SSH Key Loader

**File:** [kde/autostart/ssh-add.desktop](../kde/autostart/ssh-add.desktop)
**Installed to:** `~/.config/autostart/ssh-add.desktop`

Desktop entry that runs during KDE autostart phase 1 to load SSH keys into the agent.

### 4. SSH Add Keys Script

**File:** [arch/scripts/ssh-add-keys.sh](../arch/scripts/ssh-add-keys.sh)
**Called by:** ssh-add.desktop autostart

Adds SSH keys (`id_rsa_vaisala`, then `id_rsa`) to the running agent. Will prompt
via ksshaskpass if keys are password-protected. Order matters: the agent offers
keys to a server in the order they were added, and offering too many wrong keys
first can trip `MaxAuthTries`.

### 5. SSH Config

**File:** [ssh/config](../ssh/config)
**Installed to:** `~/.ssh/config`

SSH client configuration. Sets `AddKeysToAgent yes` for automatic key addition on first use.

---

## Execution Order

1. **System login** — `environment.d` files are read by the systemd user manager,
   setting `SSH_AUTH_SOCK` and `SSH_ASKPASS`
2. **First agent use** — systemd starts `ssh-agent.service` on demand via the socket
3. **KDE autostart phase 1** — `ssh-add.desktop` runs `ssh-add-keys.sh` to load keys

Note that `environment.d` applies to systemd user units, dbus-activated apps and
the graphical session. Interactive SSH shells do not read it, but they reach the
same agent because the socket path is fixed and predictable.

---

## Files Summary

| File | Purpose | Status |
|------|---------|--------|
| `ssh_auth_sock.conf` | Pin SSH_AUTH_SOCK to systemd agent socket | Active |
| `ssh_askpass.conf` | KDE password prompts via ksshaskpass | Active |
| `ssh-add.desktop` | Autostart entry for key loading | Active |
| `ssh-add-keys.sh` | Add keys to agent | Active |
| `ssh/config` | SSH client config | Active |
| `ssh-agent.sh` | Started a per-session agent at Plasma startup | Removed |
| `keychain.service` | Preloaded keys via `keychain` at login | Removed |

---

## Troubleshooting

```sh
# Is the socket enabled and the path what you expect?
systemctl --user is-enabled ssh-agent.socket
echo "$SSH_AUTH_SOCK"     # -> /run/user/<uid>/ssh-agent.socket

# What will the user manager export at next login?
/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator

# Which keys does the agent currently hold?
ssh-add -l
```
