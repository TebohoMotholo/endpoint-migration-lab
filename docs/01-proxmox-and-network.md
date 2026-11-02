# 01. Proxmox host and network

## Goal

Run the whole lab on one PC without touching the existing Windows install, with an isolated lab network.

## Design decisions

- **Dual boot, separate disk.** Proxmox went on its own NVMe. Each disk keeps its own bootloader, so Windows is never at risk. The boot menu (F12) picks the OS.
- **ext4, not ZFS.** ZFS wants extra RAM and wastes space on small disks. ext4 with LVM-thin is enough for a lab.
- **Two bridges.** `vmbr0` for the outside network, `vmbr1` with no physical port for the lab. Only pfSense touches both.
- **No-subscription repository.** The enterprise repository needs a paid subscription and makes updates fail.

## Build steps

1. BIOS: enable VT-x and VT-d, UEFI boot.
2. Install Proxmox VE to the NVMe. Filesystem ext4. Static management IP outside the router's DHCP range.
3. Disable the `pve-enterprise` repositories, add `pve-no-subscription`, then update and reboot.
4. Create `vmbr1`: node, System, Network, Create, Linux Bridge. Leave IP, gateway and bridge ports empty. Apply configuration.
5. Add the second SSD as an LVM-thin pool (node, Disks, LVM-Thin).
6. Add the external drive as backup storage (see [11-backups.md](11-backups.md)).

## Upstream connection options

The host has been run behind a home router and behind a laptop using Windows Internet Connection Sharing (ICS). With ICS:

| Item | Value |
|---|---|
| Laptop Ethernet | `192.168.137.1` (set by ICS) |
| Proxmox host | `192.168.137.250/24`, gateway `192.168.137.1` |
| pfSense WAN | `192.168.137.200/24`, gateway `192.168.137.1` |

Notes from running on ICS:

- ICS must be enabled on the adapter that **has** internet (Wi-Fi), pointing at the physical Ethernet adapter. Virtual adapters (Hyper-V, VMware) in the list are the wrong choice.
- Windows Firewall on the laptop blocks ICMP by default, so a failed ping to the gateway does not mean the link is down. Check `ip neigh` on Proxmox instead.
- ICS sometimes resets after a laptop restart. Toggle it off and on with the cable plugged in.

## Verify

```bash
ip -br a                 # vmbr0 has the host address, vmbr1 is UP with no address
ip r                     # default via the upstream gateway
ping -c 3 1.1.1.1
pvesm status             # local, local-lvm, ssd pool and backup storage active
```

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| Clients got addresses from the work network | VMs attached to `vmbr0`; `vmbr1` was never created | Created `vmbr1`, moved every VM, rebuilt the network at home |
| Second SATA SSD "not detected" | It was detected (see `dmesg`); two identical SSDs made it confusing | Identified by serial number with `lsblk -o NAME,SIZE,MODEL,SERIAL` before wiping |
| Container stuck with `snapshot-delete` lock | Snapshot delete interrupted by a shutdown | `pct unlock <id>`, then removed the leftover snapshot |

## Rollback

Proxmox lives on its own disk. Removing it means setting Windows Boot Manager as default in the BIOS and wiping the NVMe.
