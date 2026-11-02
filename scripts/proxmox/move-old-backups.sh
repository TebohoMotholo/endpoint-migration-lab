#!/usr/bin/env bash
# Moves backups that ended up on the system disk to the external drive.
# Used when the Proxmox root partition reached 94%.
#
# Run on: the Proxmox host shell, as root. Safe to rerun if interrupted:
# rsync deletes each source file only after it has been copied.

set -euo pipefail
SRC="/var/lib/vz/dump/"
DST="/mnt/pve/hdd-backup/dump/"

echo "Before:"; df -h /
du -xh /var/lib/vz --max-depth=3 | sort -h | tail -10

mountpoint -q /mnt/pve/hdd-backup || { echo "External drive not mounted"; exit 1; }
mkdir -p "$DST"
rsync -ah --progress --remove-source-files "$SRC" "$DST"

apt clean
journalctl --vacuum-size=200M

echo "After:"; df -h /
