# Installing Arch

Scripts I rip onto a flash drive to bring up a fresh Arch box.

## What's here

| File | Purpose |
|---|---|
| `write-usb.sh` | Build the install USB from a Linux host (downloads ISO, optional script sidecar) |
| `install-arch.sh` | Run from the booted live ISO: partitions, encrypts, pacstraps, orchestrates the chroot scripts |
| `configure-chroot.sh` | Generic in-chroot system config — timezone, locale, mkinitcpio, GRUB, services |
| `configure-user.sh` | Personal overrides — creates `smiller`, drops SSH key, sshd on port 289 |
| `files/smiller.pub` | My SSH public key, dropped in by `configure-user.sh` |
| `files/system-update.sh` | Installed as `/usr/local/bin/arch-system-update` — timeshift snapshot + pacman/yay/flatpak update |

`configure-chroot.sh` is generic enough that anyone could use it. `configure-user.sh` and `files/` are mine — delete them (or swap your own) to install for someone else.

---

## 1. Build the install USB

Run on any Linux host (your current workstation):

```sh
sudo ./write-usb.sh
```

The script will:

1. Look for the latest `archlinux-*-x86_64.iso` in `~/Downloads/`; offer to download it if missing (and verify the GPG signature when `gpg` is available).
2. List USB disks. Pick the target — you'll type the device name to confirm before anything is erased.
3. `dd` the ISO to the USB.
4. **Offer a sidecar partition.** Say yes — it creates an ext4 partition labeled `ARCHSCRIPTS` after the ISO and copies `install-arch.sh`, `configure-chroot.sh`, `configure-user.sh`, and `files/` into it. This is how the scripts ride along to the target machine without needing network on the live ISO.
5. **Optionally copy SSH keys** into a `ssh/` directory on the sidecar. Useful for cloning private repos from the live ISO.

You can skip the sidecar and instead `git clone` this repo from inside the live ISO, but the sidecar approach is faster and works without network during install.

> **Before building the USB**, make sure `arch/install/files/smiller.pub` is your current public key. Without it, the install runs fine but skips the user setup step.

---

## 2. Boot from the USB

1. Plug the USB into the target machine.
2. Boot to the firmware boot menu (commonly F12 / F10 / Esc, motherboard-dependent) and pick the USB.
3. UEFI mode only — `install-arch.sh` will refuse to run on a BIOS-booted system.
4. You'll land at a `root@archiso ~ #` prompt.

If you need WiFi before the install:

```sh
iwctl
# inside iwctl:
station wlan0 scan
station wlan0 get-networks
station wlan0 connect <SSID>
exit
# verify:
ping -c 2 archlinux.org
```

Ethernet usually just works.

---

## 3. Run the install

Find the sidecar partition (it's labeled `ARCHSCRIPTS`):

```sh
lsblk -o NAME,LABEL,SIZE,TYPE
mount /dev/disk/by-label/ARCHSCRIPTS /mnt
cd /mnt/install
./install-arch.sh
```

The installer prompts for:

- **Target disk** (the internal drive — *not* the USB)
- **Hostname, timezone, locale, keymap**
- **Role**: `workstation` (KDE + sddm + dev-friendly packages) or `server` (headless, no desktop, no bluetooth)
- **Btrfs quotas** (recommended)
- **LUKS passphrase** — leave empty at both prompts to skip encryption entirely (plaintext disk, fully unattended boot)
- **TPM2 auto-unlock** (only offered when encryption is on and a TPM2 device is present) — for headless servers that should power-cycle without a passphrase

When it finishes:

```sh
exit            # leave any chroot if you're still in one
umount -R /mnt  # if /mnt was the sidecar, swap to the new system's mount accordingly
reboot
```

Remove the USB during reboot.

---

## 4. First boot

- **No encryption / TPM2 auto-unlock**: machine boots straight through.
- **LUKS, no TPM2**: enter the passphrase at the GRUB prompt.

Then log in:

- **`smiller`** with the password you set during install. SSH in over port 289 with your key from another machine: `ssh -p 289 smiller@<host>`.
- Root password works at the console only — `PermitRootLogin no` is set in the sshd drop-in.

To run a full system update (timeshift snapshot + pacman, plus yay/flatpak when present):

```sh
arch-system-update
```

### Workstation only — install dev tooling

The base install is intentionally minimal. Pull in dev tools, AUR packages, and flatpaks as your user:

```sh
git clone <your dotfiles remote> ~/projects/dotfiles
~/projects/dotfiles/arch/install-dev-packages.sh
```

This also adds you to the `docker`, `video`, and `audio` groups.

---

## Recovery notes

- **Forgot the LUKS passphrase**: there's no recovery. The TPM2 enrollment is a *second* unlock method, not a replacement — without the passphrase to back it up, a PCR change (firmware update, Secure Boot toggle) bricks the disk.
- **TPM2 unlock stops working after a firmware/Secure Boot change**: boot with the passphrase, then re-enroll with `sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/<luks-partition>`.
- **Locked out of SSH on port 289**: log in at the console as `smiller`, check `/etc/ssh/sshd_config.d/00-overrides.conf`, fix, `systemctl restart sshd`.
