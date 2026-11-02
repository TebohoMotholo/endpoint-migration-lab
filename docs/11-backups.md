# 11. Backups

## Goal

Every VM can be restored after a bad change, without filling the Proxmox system disk.

## Design

| Item | Value |
|---|---|
| Target | External 1 TB drive mounted as directory storage `hdd-backup` (ext4) |
| Mode | Snapshot (VMs keep running) |
| Compression | ZSTD |
| Schedule | Weekly, Sunday 02:00 |
| Retention | Keep last 2, keep weekly 2 |
| Safety | `is_mountpoint yes`, so a missing drive fails the job instead of writing to the system disk |
| `local` storage | Backup content type removed, so it cannot be picked by mistake |

Setup script: [`scripts/proxmox/setup-backup-storage.sh`](../scripts/proxmox/setup-backup-storage.sh)

## Rules

- Back up before every risky change (sysprep, SQL install, site install, package installs on pfSense).
- Snapshots are fine for clients and pfSense. Domain controllers are backed up and restored together.
- Shut down from the web UI before unplugging the external drive.
- Test a restore of a small VM (pfSense) once, so the process is proven.

## Problem hit

The Proxmox root partition reached 94% (4 GB free). `du` showed 40 GB of backups in `/var/lib/vz/dump` and 17 GB of ISOs on the system disk. Backups were moved to the external drive with `rsync --remove-source-files`, jobs repointed, retention set, and the mount-point check added.

```bash
df -h /
du -xh /var/lib/vz --max-depth=3 | sort -h | tail -15
```
