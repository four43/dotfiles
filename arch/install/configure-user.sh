#!/bin/bash
# Personal user + sshd overrides for Seth's installs.
# Runs inside arch-chroot AFTER configure-chroot.sh has finished.
#
# Expects:
#   ROLE                — "server" or "workstation" (drives group membership)
#   /root/smiller.pub   — the user's SSH public key, staged by install-arch.sh
#                         from arch/install/files/smiller.pub
#
# Anyone using these dotfiles for someone else can delete this file (and the
# matching files/smiller.pub) — install-arch.sh skips this step if either is
# missing.

set -euo pipefail

: "${ROLE:?ROLE must be set}"

USERNAME=smiller
PUBKEY_FILE=/root/smiller.pub
SSHD_PORT=289

if [ ! -s "$PUBKEY_FILE" ]; then
    echo "ERROR: $PUBKEY_FILE is missing or empty" >&2
    exit 1
fi

# Group membership.
# - wheel: always (for sudo).
# - video/audio: workstation only (desktop session needs them).
# - docker is NOT added here — install-dev-packages.sh adds it later, once
#   the docker package is actually installed.
if [ "$ROLE" = "workstation" ]; then
    USER_GROUPS=wheel,video,audio
else
    USER_GROUPS=wheel
fi

if id -u "$USERNAME" >/dev/null 2>&1; then
    usermod -G "$USER_GROUPS" -s /bin/bash "$USERNAME"
    echo "Updated $USERNAME (groups: $USER_GROUPS)"
else
    useradd -m -G "$USER_GROUPS" -s /bin/bash "$USERNAME"
    echo "Created $USERNAME (groups: $USER_GROUPS)"
fi

# Password is used for sudo even when SSH is key-only — prompt interactively.
echo "Setting password for $USERNAME (used for sudo)..."
passwd "$USERNAME"

# Enable sudo for wheel group.
sed -i 's/^# *%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Drop the authorized_keys with strict perms (sshd refuses world-readable keys).
SSH_DIR="/home/$USERNAME/.ssh"
install -d -m 700 -o "$USERNAME" -g "$USERNAME" "$SSH_DIR"
install -m 600 -o "$USERNAME" -g "$USERNAME" "$PUBKEY_FILE" "$SSH_DIR/authorized_keys"

# sshd drop-in. Using /etc/ssh/sshd_config.d/ instead of editing the main file
# keeps the package default untouched and survives openssh upgrades cleanly.
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-overrides.conf <<EOF
Port ${SSHD_PORT}
PasswordAuthentication no
PermitRootLogin no
EOF

# Idempotent: configure-chroot.sh already enables sshd, but enabling again
# is a no-op and makes this script safe to run standalone post-install.
systemctl enable sshd

echo "Personal user setup complete:"
echo "  user: $USERNAME (groups: $USER_GROUPS)"
echo "  sshd: port $SSHD_PORT, key-only, no root login"
