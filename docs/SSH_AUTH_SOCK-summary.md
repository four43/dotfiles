# SSH_AUTH_SOCK Configuration

How SSH agent access works on this Arch + KDE Plasma host.

## Design

One systemd-user, socket-activated `ssh-agent` listening at a stable path —
`$XDG_RUNTIME_DIR/ssh-agent.socket` — shared by every user session (graphical
and SSH login).

This replaces an earlier setup that started ssh-agent from a KDE Plasma env
script at a random path and tried to broadcast that path via systemd-user env
and dbus — which left SSH login sessions without `SSH_AUTH_SOCK`.

### Exporting `SSH_AUTH_SOCK`

The socket path is stable, but it takes two mechanisms to get it into every
session, because they inherit environment differently:

- **Graphical sessions** — `environment.d` sets it. That directory is read only
  by `systemd --user`, populating the user manager's environment block (visible
  via `systemctl --user show-environment`). Plasma inherits it because Plasma is
  *launched by* the user manager.
- **SSH login sessions** — [zsh/zshenv](../zsh/zshenv) sets it. An sshd session
  is a child of sshd → PAM, not of `systemd --user`, so it never sees that
  environment block. `pam_systemd` sets `XDG_RUNTIME_DIR` and the other `XDG_*`
  vars, plus `TZ`/`EMAIL`/`LANG` and any JSON-user-record vars — but it does
  *not* import the user manager's environment.

`zshenv` rather than `zprofile`/`zshrc` because it is the only one zsh reads for
non-interactive remote commands, so `ssh <host> 'git pull'` gets an agent too.
The assignment is guarded on `SSH_AUTH_SOCK` being empty, so connecting in with
agent forwarding (`ssh -A`) keeps its own forwarded socket.

Verify with:

```sh
ssh -p 289 localhost 'echo "$SSH_AUTH_SOCK"; ssh-add -l'
```

Keys land in the agent only once something adds them (see `ssh-add-keys.sh`
below). After a graphical login they are already loaded, so SSH sessions find
them. Reboot and SSH in without logging in graphically and the agent starts
empty — `AddKeysToAgent yes` then prompts on the TTY at first use, which works
because `SSH_ASKPASS=ksshaskpass` does not reach SSH sessions either.

## Files

| File | Installed to | Purpose |
|------|--------------|---------|
| [arch/.config/environment.d/ssh_auth_sock.conf](../arch/.config/environment.d/ssh_auth_sock.conf) | `~/.config/environment.d/ssh_auth_sock.conf` | Pin `SSH_AUTH_SOCK` to the stable socket path (graphical sessions) |
| [zsh/zshenv](../zsh/zshenv) | `~/.zshenv` | Pin `SSH_AUTH_SOCK` to the same path for SSH login sessions, which `environment.d` does not reach |
| [arch/.config/environment.d/ssh_askpass.conf](../arch/.config/environment.d/ssh_askpass.conf) | `~/.config/environment.d/ssh_askpass.conf` | Use `ksshaskpass` for graphical passphrase prompts |
| [kde/autostart/ssh-add.desktop](../kde/autostart/ssh-add.desktop) → [arch/scripts/ssh-add-keys.sh](../arch/scripts/ssh-add-keys.sh) | `~/.config/autostart/ssh-add.desktop` | Preload keys at graphical login (optional; `AddKeysToAgent yes` in ssh config also lazy-adds on first use) |
| [ssh/config](../ssh/config) | `~/.ssh/config` | SSH client config; sets `AddKeysToAgent yes` |

The systemd unit `ssh-agent.socket` ships with the OpenSSH package — no custom
unit needed. Enable once with:

```sh
systemctl --user enable --now ssh-agent.socket
```
