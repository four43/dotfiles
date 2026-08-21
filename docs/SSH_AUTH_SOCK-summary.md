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
the graphical session. SSH login shells do **not** read it — they are spawned by
`sshd`, not by the user manager — so they never see the pinned path. What they
get instead is one of:

- **Agent forwarding on** (`ForwardAgent yes`, set for `home`/`orion`/
  `ursa-minor` in [ssh/config](../ssh/config)) — `sshd` mints its own socket for
  that one connection and exports it. OpenSSH ≥ 10 puts it at
  `~/.ssh/agent/s.<rand>.sshd.<rand>`; older releases used `/tmp/ssh-*/agent.<pid>`.
- **Agent forwarding off** — nothing at all.

Neither is `${XDG_RUNTIME_DIR}/ssh-agent.socket`, so [zsh/zshenv](../zsh/zshenv)
closes the gap: if `SSH_AUTH_SOCK` is unset or is not a live socket, it falls
back to the systemd one. A set-and-live socket is left alone, so real agent
forwarding still works and devcontainers keep their bind-mounted
`/tmp/dc-ssh-agent.sock` (see
[60-devcontainer-aliases.zsh](../zsh/config/rc/60-devcontainer-aliases.zsh)).

### Why the fallback is load-bearing: tmux

`sshd` **deletes** its forwarded socket when the connection closes. A tmux
server started from an SSH login inherits that path into its own environment and
hands it to every pane it spawns, long after the connection is gone — so panes
end up pointing at a socket that no longer exists. `update-environment` (which
includes `SSH_AUTH_SOCK` by default) refreshes the *session* environment on
re-attach, but only new panes pick that up; existing panes keep the dead path,
and the server's global environment stays stale for the life of the server. The
visible symptom is a build failure rather than an ssh failure, because
`docker buildx --ssh default` stats the socket up front:

```
failed to convert agent config for ID: "default": stat /home/…/.ssh/agent/s.….sshd.… : no such file or directory
```

---

## Files Summary

| File | Purpose | Status |
|------|---------|--------|
| `ssh_auth_sock.conf` | Pin SSH_AUTH_SOCK to systemd agent socket | Active |
| `zsh/zshenv` | Fall back to the systemd socket in SSH/tmux shells | Active |
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

# Stale socket in a long-lived tmux pane? Take the session's current value:
eval "$(tmux show-environment -s SSH_AUTH_SOCK)"

# ...and stop the server handing the dead one to new panes:
tmux setenv -g SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

# What each pane shell actually inherited (values differ per pane by design):
pgrep -u "$USER" -f '^-?zsh$' |
  while read -r p; do
    printf '%-8s %s\n' "$p" "$(tr '\0' '\n' </proc/$p/environ | grep '^SSH_AUTH_SOCK=')"
  done
```
