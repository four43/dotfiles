# Windows Recovery (Dual-Boot with Arch)

When Windows won't boot and isn't a GRUB option — typically because its EFI bootloader files were removed from the shared ESP — recover with `bcdboot` from a Windows install USB. This won't touch GRUB.

## Repair

This is by far the cleanest and most reliable approach. Make a Windows 10/11 install USB on another machine (Rufus, Media Creation Tool, etc.), or see [Appendix A](#appendix-a-building-a-windows-usb-on-arch) to build one from Arch.

1. Boot from the USB
2. On the first screen, click **"Repair your computer"** (bottom-left) — **NOT** "Install now"
3. **Troubleshoot → Advanced options → Command Prompt**
4. Find the ESP volume number:

    ```
    diskpart
    list disk
    list vol
    ```

    The ESP is the ~512MB FAT32 volume (on this machine: the Crucial T700, `nvme2n1`).

5. Assign it a drive letter and rebuild the Windows boot files:

    ```
    select vol N         :: replace N with the ESP's volume number
    assign letter=S
    exit

    bcdboot C:\Windows /s S: /f UEFI
    ```

`bcdboot` writes only into `S:\EFI\Microsoft\Boot\` — your `\EFI\GRUB\` folder is untouched. Confirmed-safe on dual-boot setups.

### Avoid these — they have historically nuked Linux entries

- "Startup Repair" (the automatic one)
- Anything involving `bootrec /fixmbr` (legacy MBR stuff, irrelevant for UEFI but can confuse the firmware)

## Getting back to Arch

After `bcdboot` succeeds, reboot. `bcdboot` adds Windows as the first firmware boot entry, so the machine will come up into Windows by default. Use the **motherboard boot menu** (F8/F11/F12 depending on vendor) to pick GRUB on the first boot.

Once back in Arch, restore GRUB as the default:

```bash
sudo efibootmgr -v                 # find the new Windows entry's Boot#### number
sudo efibootmgr -o 0001,00XX       # GRUB first, then Windows
```

### Add Windows to the GRUB menu (so you don't need the F-key every time)

```bash
sudo pacman -S --needed os-prober ntfs-3g
sudo sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

In the `grub-mkconfig` output, look for `Found Windows Boot Manager on /dev/nvme2n1p1`. After that, GRUB will offer "Windows Boot Manager" as a menu entry on every boot.

Should be ~10 minutes of work total once the USB is ready.

---

## Appendix A: Building a Windows USB on Arch

Easiest path on Arch is **WoeUSB-ng** — purpose-built for this and handles the gotchas (Win10 `install.wim` is often >4GB, which breaks naive FAT32 approaches).

### 1. Get the Windows 10 ISO

From any browser on Linux, go to: <https://www.microsoft.com/en-us/software-download/windows10ISO>

Microsoft detects non-Windows browsers and gives you a direct ISO download (on Windows browsers they push you toward the Media Creation Tool, which we don't want). Pick **Windows 10 (multi-edition ISO)**, your language, and 64-bit.

### 2. Install WoeUSB-ng

From the AUR, with an AUR helper:

```bash
yay -S woeusb-ng        # or: paru -S woeusb-ng
```

Without an AUR helper:

```bash
git clone https://aur.archlinux.org/woeusb-ng.git
cd woeusb-ng
makepkg -si
```

### 3. Identify the USB drive

Plug in a USB stick (8GB minimum, 16GB recommended; will be wiped).

```bash
lsblk
```

Find the new device — likely `/dev/sda` or `/dev/sdb`. **Double-check the size matches your USB**, because the next command erases it. The three NVMe drives on this machine are `nvme0n1`, `nvme1n1`, `nvme2n1`, so the USB will be a `sdX` device.

### 4. Write the ISO

```bash
sudo woeusb --device /path/to/Win10.iso /dev/sdX --target-filesystem NTFS
```

Replace `/dev/sdX` with your USB (e.g. `/dev/sda`). The `--target-filesystem NTFS` flag handles the >4GB `install.wim` cleanly — WoeUSB sets up a small FAT32 boot partition plus an NTFS data partition. Modern UEFI firmware boots this without issue.

Takes 10-20 minutes depending on USB speed. When it says "Done," you're ready to reboot.
