# tmux

tmux is a terminal multiplexer: windows, split panes, and sessions that survive closing the terminal. `tmux.conf` is symlinked to `~/.tmux.conf` by dotbot.

Start it with `tmux-start` (in `bin/`), which attaches to the `main` session or creates it.

## Plugins

Plugins are managed by [TPM](https://github.com/tmux-plugins/tpm) (Tmux Plugin Manager).

 * [tmux-reset](https://github.com/hallazzang/tmux-reset) - Resets tmux to sane defaults before our config applies
 * [tmux-cpu](https://github.com/tmux-plugins/tmux-cpu) - CPU and RAM usage for the status bar
 * [tmux-battery](https://github.com/tmux-plugins/tmux-battery) - Battery status for the status bar
 * [tmux-nova](https://github.com/o0th/tmux-nova) - Status bar theme, configured with the `@nova-*` options

TPM itself comes from the AUR package `tmux-plugin-manager` (installed by `arch/install-dev-packages.sh`), which puts it at `/usr/share/tmux-plugin-manager/tpm`. The last line of `tmux.conf` runs it from there. Plugins are downloaded to `~/.tmux/plugins/`.

## Setup

```sh
yay -S tmux-plugin-manager
tmux source-file ~/.tmux.conf
```

Then press `prefix + I` (capital i) to download the plugins. The prefix is `C-a`.

## Keys

 * `prefix + r` - Reload config
 * `prefix + I` - Install plugins
 * `prefix + U` - Update plugins
 * `prefix + alt + u` - Remove plugins no longer listed in `tmux.conf`

## Troubleshooting

**Status bar looks like the plain tmux default:** TPM didn't run, so the plugins never loaded. Check that `/usr/share/tmux-plugin-manager/tpm` exists. If it doesn't, install the package (see Setup) and reload.

To load plugins in the running server without reloading the whole config:

```sh
tmux run /usr/share/tmux-plugin-manager/tpm
```

Config changes don't apply to a running tmux server until you reload (`prefix + r`) or restart it (`tmux kill-server`).
