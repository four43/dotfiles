# Btrfs Subvolume Management

## Quota Management

### Check Current Quota Status

List all qgroups and their limits:

```bash
sudo btrfs qgroup show -reF /var
```

For more detail with raw values:

```bash
sudo btrfs qgroup show --raw /var
```

### Find Subvolume IDs

```bash
sudo btrfs subvolume list /var
```

The qgroup ID format is typically `0/subvolume_id`.

### Expand a Quota

Set a new size limit (e.g., 100GB):

```bash
sudo btrfs qgroup limit 100G /var
```

Or use the qgroup ID directly:

```bash
sudo btrfs qgroup limit 100G 0/256 /var
```

### Remove Quota Limits

Remove the size limit from a subvolume:

```bash
sudo btrfs qgroup limit none /var
```

Disable quotas entirely on the filesystem:

```bash
sudo btrfs quota disable /var
```
