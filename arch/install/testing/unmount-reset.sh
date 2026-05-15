# Unmount all filesystems under /mnt (recursive)
umount -R /mnt

# Deactivate the LVM volume group
vgchange -an ArchVolGroup

# Close the LUKS encrypted volume
cryptsetup close cryptlvm
