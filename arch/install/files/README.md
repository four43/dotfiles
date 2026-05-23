# install/files/

Asset files staged into the new system during install.

## `smiller.pub`

The SSH public key dropped into `~smiller/.ssh/authorized_keys` by
`configure-user.sh`.

If this file is missing or empty, `install-arch.sh` skips the personal
user-setup step entirely (warns and moves on). Anyone using these dotfiles
for someone else's install can delete `configure-user.sh` and this directory
to skip user provisioning, or replace `smiller.pub` with their own key and
edit `configure-user.sh` to use a different username.

To drop in the key:

```sh
cp ~/.ssh/id_ed25519.pub arch/install/files/smiller.pub
```

## `system-update.sh`

Helper script installed to `/usr/local/bin/arch-system-update` on the new
system. Runs timeshift snapshot + pacman/yay/flatpak updates. Skipped if
missing.
