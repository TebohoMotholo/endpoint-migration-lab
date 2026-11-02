#!/usr/bin/env bash
# Sets up an external drive (already formatted and added as directory storage
# "hdd-backup" through the web UI: node, Disks, Directory) as the only backup target.
#
# Run on: the Proxmox host shell, as root.
# The is_mountpoint flag stops Proxmox writing backups to the system disk
# when the external drive is unplugged.

set -euo pipefail
STORE="hdd-backup"

pvesm status | grep -q "^${STORE} " || { echo "Storage ${STORE} not found"; exit 1; }

# Backups and ISOs on the external drive, with retention
pvesm set "$STORE" --content backup,iso --is_mountpoint yes --prune-backups keep-last=2,keep-weekly=2

# Stop 'local' (system disk) being offered for backups
pvesm set local --content iso,vztmpl

pvesm status
df -h / "/mnt/pve/${STORE}"
