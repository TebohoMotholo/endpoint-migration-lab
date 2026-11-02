# 02. pfSense firewall and VPN

## Goal

One router and firewall between the lab and the outside world. All lab traffic, including traffic to Microsoft 365, leaves through it.

## VM settings

| Setting | Value |
|---|---|
| CPU / RAM / disk | 2 cores, 2 GB, 16 GB |
| net0 | VirtIO on `vmbr0` (WAN) |
| net1 | VirtIO on `vmbr1` (LAN) |
| Start at boot | Yes, order 1 |

## Build steps

1. Install pfSense CE, Auto (UFS), GPT. Remove the ISO after install.
2. Assign `vtnet0` as WAN and `vtnet1` as LAN. Check each MAC address against net0 and net1 in Proxmox so they are not swapped.
3. LAN: `10.10.10.1/24`, DHCP **off** (DC01 runs DHCP for the lab).
4. Web wizard from a lab VM at `https://10.10.10.1`:
   - DNS servers `1.1.1.1` and `8.8.8.8`, untick "Override DNS"
   - WAN: untick **Block RFC1918 private networks**, because the WAN itself sits on a private network
5. System, Advanced, Networking: tick **Disable hardware checksum offloading** (needed with VirtIO NICs).
6. Static WAN address: add an upstream gateway explicitly (see problems below).

## WireGuard (remote admin)

1. Install the WireGuard package (System, Package Manager).
2. Tunnel on UDP 51820, interface address `10.20.20.1/24`.
3. Assign `tun_wg0` as interface `WG`.
4. Rules: WAN pass UDP 51820 to WAN address; WG pass to LAN net.
5. One peer per device, Allowed IPs `10.20.20.x/32`.
6. Client config sends only `10.10.10.0/24` through the tunnel (split tunnel).

Status: tunnel and package configured. External access still needs port forwarding on the upstream router and a check for CGNAT, so it is parked for now.

## Verify

From the pfSense shell (option 8):

```sh
ifconfig vtnet0 | grep inet
netstat -rn | head -8          # a 'default' route must exist
ping -c 2 <upstream-gateway>
ping -c 2 1.1.1.1
nslookup pkg.pfsense.org
```

## Problems hit

| Symptom | Cause | Fix |
|---|---|---|
| `No route to host` from pfSense, DNS SERVFAIL | Static WAN address set without an upstream gateway | Added the gateway under Interfaces, WAN, and selected it |
| Package install: "Another instance of pfSense-upgrade is running" | Install clicked twice, and no internet so the first job hung | Fixed the gateway, rebooted pfSense, installed once |
| Lab VM had no internet | VM NIC on the wrong bridge | Every lab NIC on `vmbr1`, only pfSense WAN on `vmbr0` |

## Rollback

Proxmox snapshot of the pfsense VM before any package or rule change (`before-wireguard`).
