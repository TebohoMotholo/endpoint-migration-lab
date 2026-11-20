#!/usr/bin/env bash
# Collects Proxmox host evidence. Read-only.
# Run on: the Proxmox host shell (web UI, node, Shell), as root:
#   bash collect-proxmox-evidence.sh
# Then download the .tar.gz it prints (WinSCP, or copy the text from the Shell).

set -u
OUT="/root/evidence-proxmox-$(date +%Y%m%d-%H%M)"
mkdir -p "$OUT"

save() { # save NAME COMMAND...
  local name="$1"; shift
  { echo "# $name"; echo "# Command: $*"; echo "# Collected: $(date -Is) on $(hostname)"; echo; bash -c "$*" 2>&1; } > "$OUT/$name.txt"
  echo "OK    $name"
}

save 01-version        "pveversion -v | head -20"
save 02-node           "lscpu | grep -E 'Model name|^CPU\(s\)'; free -h; uptime"
save 03-vms            "qm list"
save 04-containers     "pct list"
save 05-vm-configs     "for id in \$(qm list | awk 'NR>1{print \$1}'); do echo \"== VM \$id\"; qm config \$id | grep -E '^(name|cores|memory|net|scsi|tpmstate|bios|machine|onboot|startup)'; done"
save 06-ct-configs     "for id in \$(pct list | awk 'NR>1{print \$1}'); do echo \"== CT \$id\"; pct config \$id | grep -E '^(hostname|cores|memory|net|rootfs|onboot)'; done"
save 07-network        "cat /etc/network/interfaces; echo; ip -br a; echo; ip r"
save 08-storage        "pvesm status; echo; cat /etc/pve/storage.cfg"
save 09-disks          "lsblk -o NAME,SIZE,MODEL,TRAN,TYPE,FSTYPE,MOUNTPOINT; echo; lvs; echo; df -h /"
save 10-backup-jobs    "cat /etc/pve/jobs.cfg 2>/dev/null || cat /etc/pve/vzdump.cron"
save 11-backups        "ls -lh /mnt/pve/hdd-backup/dump 2>/dev/null | tail -40"
save 12-repos          "cat /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | grep -v '^#'"
save 13-time           "timedatectl"

tar -czf "$OUT.tar.gz" -C "$(dirname "$OUT")" "$(basename "$OUT")"
echo
echo "Done. Send this file: $OUT.tar.gz"
