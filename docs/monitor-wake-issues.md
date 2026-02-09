# Monitor Wake Issues on NVIDIA + KDE (Arch Linux)

## Problem

Some monitors are too slow to respond with their EDID (Extended Display Identification Data) when the system wakes from sleep. The GPU falls back to a safe 640x480 mode. Turning the monitor off and back on manually fixes it, but that's annoying.

## Solutions

Choose based on your specific issue:

### Solution 1: Force Resolution on Login (Recommended for Lock Screen Monitor Sleep)

**Best for**: Monitors losing resolution when they wake from DPMS sleep during lock screen

**Issue**: DPMS (Display Power Management Signaling) turns off monitors, which wake without proper EDID.

**Fix**: Run `kscreen-doctor` commands on both login and screen unlock using a D-Bus monitoring service.

The dotfiles include:
- `kde/plasma-workspace/scripts/fix-monitor-on-unlock.sh` - D-Bus monitor script that watches for unlock events
- `arch/systemd/user/fix-monitor-on-unlock.service` - Systemd service that runs the monitor script
- `kde/autostart/fix-monitor-resolution.sh` - Backup script for manual login (optional)
- `kde/autostart/fix-monitor-resolution.desktop` - Autostart entry (optional)

After running `./install`, enable the service:

```bash
systemctl --user enable fix-monitor-on-unlock.service
systemctl --user start fix-monitor-on-unlock.service
```

The service will:
1. Set correct resolution on login (graphical-session.target)
2. Monitor D-Bus for screen unlock events and fix resolution when you unlock
3. Automatically restart if it crashes

The monitors will still sleep to save power, but will have the correct resolution when you unlock.

**Note**: All scripts check hostname and only run on `aurora`. On other machines sharing these dotfiles, they will exit silently.

### Solution 2: Cache EDID and Force It at Boot

**Best for**: X11 systems where EDID is accessible via sysfs

The fix is to extract your monitor's EDID when it's working correctly and force the kernel to use that cached copy instead of querying the monitor.

#### Automated Script

Use the automated script to detect and configure all monitors:

```bash
# Run in dry-run mode to see what would happen
~/projects/four43/dotfiles/arch/scripts/fix-monitor-edid.sh --dry-run

# Run for real to extract and configure EDID
~/projects/four43/dotfiles/arch/scripts/fix-monitor-edid.sh
```

The script will:
- Detect all connected monitors
- Extract their EDID files to `/usr/lib/firmware/edid/`
- Generate the kernel parameter string
- Update `/etc/mkinitcpio.conf` with the EDID files
- Provide bootloader-specific instructions

After running, follow the printed instructions to update your bootloader and rebuild initramfs.

### Manual Method

### Step 1: Identify your display ports

```bash
for p in /sys/class/drm/*/status; do con=${p%/status}; echo -n "${con#*/card?-}: "; cat $p; done
```

### Step 2: Extract EDID from each problematic monitor (while working correctly)

```bash
sudo mkdir -p /usr/lib/firmware/edid

# For each problematic display, e.g. DP-1:
sudo cp /sys/class/drm/card1-DP-1/edid /usr/lib/firmware/edid/monitor-dp1.bin
```

### Step 3: Add kernel parameters

For **systemd-boot** (common on Arch), edit `/boot/loader/entries/arch.conf` and add to the `options` line:

```
drm.edid_firmware=DP-1:edid/monitor-dp1.bin,DP-2:edid/monitor-dp2.bin nvidia-drm.modeset=1
```

For **GRUB**, add to `GRUB_CMDLINE_LINUX` in `/etc/default/grub` and run:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

### Step 4: If using early KMS (mkinitcpio)

Add the EDID files to your initramfs in `/etc/mkinitcpio.conf`:

```
FILES=(/usr/lib/firmware/edid/monitor-dp1.bin /usr/lib/firmware/edid/monitor-dp2.bin)
```

Then regenerate:

```bash
sudo mkinitcpio -P
```

## Alternative: Xorg ModeValidation (if on X11)

Add to `/etc/X11/xorg.conf.d/10-nvidia.conf`:

```
Section "Device"
    Identifier "NVIDIA"
    Driver "nvidia"
    Option "ModeValidation" "AllowNonEdidModes, NoTotalSizeCheck"
EndSection
```

## Also Enable NVIDIA Suspend Services

```bash
sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate
```

And ensure this kernel parameter is set:

```
nvidia.NVreg_PreserveVideoMemoryAllocations=1
```

## Sources

- [NVIDIA/Troubleshooting - ArchWiki](https://wiki.archlinux.org/title/NVIDIA/Troubleshooting)
- [Kernel mode setting - ArchWiki](https://wiki.archlinux.org/title/Kernel_mode_setting)
- [How to override EDID on Linux - foosel.net](https://foosel.net/til/how-to-override-the-edid-data-of-a-monitor-under-linux/)
- [Arch Forums: Resolution lost after wake from sleep](https://bbs.archlinux.org/viewtopic.php?id=303226)
