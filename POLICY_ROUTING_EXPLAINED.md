# Policy-Based Routing - Multi-NIC Configuration

**Date**: 2025-10-18  
**Solution**: Source-based policy routing without bonding  
**Purpose**: Use all 3 NICs without asymmetric routing issues

---

## Problem Solved

**Original Issue**: Multipath routing caused asymmetric traffic flow:
- Outbound packets on enp3s0f1 (192.168.1.113)
- Inbound packets on enp3s0f0 (192.168.1.64)
- Result: TCP retransmits, 10-second freezes, Chrome renderer spikes

**Solution**: Policy-based routing ensures symmetric traffic:
- Each NIC handles BOTH TX and RX for its own IP
- No traffic crosses between NICs
- No asymmetric routing

---

## Configuration Overview

### Network Interfaces

| Interface | Type | IP | Priority | Use Case |
|-----------|------|-----|----------|----------|
| **enp3s0f0** | Intel X540 10G Port 0 | 192.168.1.64 | **PRIMARY** (metric 100) | Default traffic, most applications |
| **enp3s0f1** | Intel X540 10G Port 1 | 192.168.1.113 | **SECONDARY** (metric 200) | Specific apps, offload traffic |
| **enp9s0** | Onboard Realtek | 192.168.1.85 | **TERTIARY** (metric 300) | Background tasks, fallback |

### Routing Tables

```bash
# Main routing table (new connections use PRIMARY)
default via 192.168.1.254 dev enp3s0f0 metric 100  # <-- LOWEST = HIGHEST PRIORITY
default via 192.168.1.254 dev enp3s0f1 metric 200
default via 192.168.1.254 dev enp9s0 metric 300

# Policy routing tables (per-NIC)
Table 100: enp3s0f0 traffic (FROM 192.168.1.64)
Table 101: enp3s0f1 traffic (FROM 192.168.1.113)
Table 102: enp9s0 traffic (FROM 192.168.1.85)
```

### Policy Rules

```bash
ip rule show
100: from 192.168.1.64 lookup 100    # Traffic FROM .64 uses table 100 (enp3s0f0)
101: from 192.168.1.113 lookup 101   # Traffic FROM .113 uses table 101 (enp3s0f1)
102: from 192.168.1.85 lookup 102    # Traffic FROM .85 uses table 102 (enp9s0)
```

---

## How It Works

### 1. New Connections (Outbound)

When an application creates a **new connection** without specifying a source IP:

1. Kernel checks main routing table
2. Finds 3 default routes with different metrics
3. **Chooses lowest metric** = enp3s0f0 (metric 100)
4. Uses source IP 192.168.1.64
5. Policy rule kicks in: "FROM 192.168.1.64 use table 100"
6. Table 100 routes via enp3s0f0
7. **Result**: Both TX and RX on enp3s0f0 ✅

### 2. Existing Connections (Reply Traffic)

When a **reply packet** arrives:

1. Packet arrives on enp3s0f0 (for example)
2. Destination IP: 192.168.1.64
3. Kernel looks up connection tracking
4. Finds existing connection with source 192.168.1.64
5. Replies go out via enp3s0f0 (same interface)
6. **Result**: Symmetric routing ✅

### 3. Application-Specific Routing

To use a **specific NIC** for an application:

```bash
# Use SECONDARY NIC (enp3s0f1) for a download
wget --bind-address=192.168.1.113 http://example.com/largefile.iso

# Use TERTIARY NIC (enp9s0) for background sync
rsync --bind-address=192.168.1.85 /data/ remote:/backup/

# Chrome can't specify bind address, so it uses PRIMARY by default
# (This is what you want for responsiveness)
```

When app binds to `.113`:
1. Outbound packet has source IP 192.168.1.113
2. Policy rule: "FROM 192.168.1.113 use table 101"
3. Table 101 routes via enp3s0f1
4. Reply comes back to 192.168.1.113
5. Goes out via enp3s0f1
6. **Result**: All traffic for this connection stays on enp3s0f1 ✅

---

## Benefits Over Multipath Routing

| Feature | Multipath (OLD) | Policy Routing (NEW) |
|---------|----------------|---------------------|
| Asymmetric routing | ❌ Yes (causes freezes) | ✅ No (symmetric) |
| TCP performance | ⚠️ Unpredictable | ✅ Consistent |
| Connection stalls | ❌ Yes (retransmits) | ✅ No |
| IRQ distribution | ⚠️ Random | ✅ Predictable |
| CPU overhead | ⚠️ High (routing decisions) | ✅ Low (policy rules) |
| Application control | ❌ None | ✅ Can choose NIC |
| Fault tolerance | ✅ Yes | ✅ Yes (metric fallback) |

---

## Testing & Verification

### Verify Symmetric Routing

```bash
# Test each NIC routes through itself
ip route get 8.8.8.8 from 192.168.1.64    # Should show: dev enp3s0f0 table 100
ip route get 8.8.8.8 from 192.168.1.113   # Should show: dev enp3s0f1 table 101
ip route get 8.8.8.8 from 192.168.1.85    # Should show: dev enp9s0 table 102
```

Expected output:
```
8.8.8.8 from 192.168.1.64 via 192.168.1.254 dev enp3s0f0 table 100
8.8.8.8 from 192.168.1.113 via 192.168.1.254 dev enp3s0f1 table 101
8.8.8.8 from 192.168.1.85 via 192.168.1.254 dev enp9s0 table 102
```

✅ **Each NIC routes through itself - NO ASYMMETRY!**

### Monitor Traffic Per NIC

```bash
# Watch PRIMARY NIC traffic (most traffic here)
sudo iftop -i enp3s0f0 -n -P

# Watch SECONDARY NIC traffic (application-specific)
sudo iftop -i enp3s0f1 -n -P

# Watch TERTIARY NIC traffic (background/fallback)
sudo iftop -i enp9s0 -n -P
```

### Test Default Route

```bash
# New connections use PRIMARY (lowest metric)
for i in {1..10}; do 
    ip route get 8.8.8.8 | head -1
    sleep 1
done
```

Expected: All show `dev enp3s0f0` (PRIMARY)

### Test Application-Specific Binding

```bash
# Force traffic through SECONDARY NIC
curl --interface enp3s0f1 https://ipinfo.io/ip
# Should return: 192.168.1.113 (SECONDARY IP)

# Force traffic through TERTIARY NIC
curl --interface enp9s0 https://ipinfo.io/ip
# Should return: 192.168.1.85 (TERTIARY IP)

# Default (no --interface)
curl https://ipinfo.io/ip
# Should return: 192.168.1.64 (PRIMARY IP)
```

---

## Use Cases

### PRIMARY NIC (enp3s0f0 - 192.168.1.64)

**Default for everything**:
- Chrome/Firefox browsing
- VSCode updates
- SSH sessions
- Video streaming
- General desktop apps

**Why**: Lowest metric means all new connections prefer this NIC

### SECONDARY NIC (enp3s0f1 - 192.168.1.113)

**Offload heavy traffic**:
- Large downloads (bind wget/curl to 192.168.1.113)
- Docker container traffic (configure Docker to use this IP)
- VM network traffic (configure VMs to use this NIC)
- Steam game downloads (if Steam supports binding)

**Why**: Keeps heavy downloads from affecting desktop responsiveness

### TERTIARY NIC (enp9s0 - 192.168.1.85)

**Background tasks**:
- Automated backups (rsync --bind-address)
- Cloud sync (if app supports binding)
- Network monitoring tools
- Testing/development

**Why**: Lowest priority means it doesn't interfere with primary work

---

## Application Binding Examples

### wget (Large Downloads)

```bash
# Use SECONDARY NIC for large download
wget --bind-address=192.168.1.113 https://example.com/ubuntu.iso

# Background download on TERTIARY NIC
wget --bind-address=192.168.1.85 https://example.com/dataset.tar.gz
```

### curl

```bash
# Use SECONDARY NIC
curl --interface enp3s0f1 https://example.com/api

# Use TERTIARY NIC
curl --interface enp9s0 https://example.com/backup
```

### rsync (Backups)

```bash
# Backup on TERTIARY NIC (doesn't affect desktop)
rsync -av --bind-address=192.168.1.85 /data/ remote:/backup/
```

### Docker (Containers)

Edit `/etc/docker/daemon.json`:
```json
{
  "ip": "192.168.1.113",
  "default-address-pools": [
    {
      "base": "172.18.0.0/16",
      "size": 24
    }
  ]
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

**Result**: All Docker container traffic uses SECONDARY NIC

### SSH (Multiple Sessions)

```bash
# Default SSH (PRIMARY NIC)
ssh user@remote

# SSH via SECONDARY NIC
ssh -b 192.168.1.113 user@remote

# SSH via TERTIARY NIC
ssh -b 192.168.1.85 user@remote
```

---

## Troubleshooting

### Check Active Policy Rules

```bash
ip rule show
```

Should show:
```
100: from 192.168.1.64 lookup 100
101: from 192.168.1.113 lookup 101
102: from 192.168.1.85 lookup 102
```

### Check Routing Tables

```bash
# PRIMARY table
ip route show table 100

# SECONDARY table
ip route show table 101

# TERTIARY table
ip route show table 102
```

Each should show default route via its own interface.

### Check Interface Status

```bash
ip addr show | grep -E "state|inet "
```

All 3 NICs should be `state UP` with their respective IPs.

### Test Connectivity Per NIC

```bash
# Ping via PRIMARY
ping -I enp3s0f0 -c 3 8.8.8.8

# Ping via SECONDARY
ping -I enp3s0f1 -c 3 8.8.8.8

# Ping via TERTIARY
ping -I enp9s0 -c 3 8.8.8.8
```

All should succeed.

### Check for Asymmetric Routing

```bash
# Monitor traffic on all NICs simultaneously
sudo tcpdump -i any -n -c 100 host 192.168.1.64 or host 192.168.1.113 or host 192.168.1.85
```

Look for:
- ❌ BAD: Outbound on enp3s0f1, inbound on enp3s0f0
- ✅ GOOD: Outbound and inbound on **same interface**

---

## Performance Expectations

### With Policy Routing (Current)

- ✅ **No 10-second freezes** (symmetric routing)
- ✅ **Consistent Chrome performance** (single IP)
- ✅ **Lower CPU overhead** (policy rules, not routing decisions)
- ✅ **Predictable IRQ distribution** (traffic stays on assigned NIC)
- ✅ **Application control** (can offload heavy traffic)

### Network Bandwidth Potential

| Scenario | Bandwidth | NICs Used |
|----------|-----------|-----------|
| Single download (default) | ~10 Gbps | PRIMARY only |
| Chrome + wget on SECONDARY | ~20 Gbps | PRIMARY + SECONDARY |
| Chrome + wget + rsync | ~25 Gbps | All 3 NICs |

**Note**: Router must handle 3 simultaneous connections at high speed.

---

## Making Configuration Permanent

The script `configure_policy_routing.sh` applies settings immediately but they're **NOT persistent across reboots**.

To make permanent, create systemd service (see `POLICY_ROUTING_SERVICE.md`).

---

## Revert to Single NIC (If Needed)

If you want to go back to single-NIC configuration:

```bash
# Disable SECONDARY and TERTIARY
sudo ip link set enp3s0f1 down
sudo ip link set enp9s0 down

# Remove policy rules
sudo ip rule del from 192.168.1.113 table 101
sudo ip rule del from 192.168.1.85 table 102

# Remove routing tables
sudo ip route flush table 101
sudo ip route flush table 102
```

---

## Summary

**What We Achieved**:
- ✅ All 3 NICs active with 3 different IPs
- ✅ NO asymmetric routing (each NIC handles its own traffic)
- ✅ Priority order: enp3s0f0 (1st) → enp3s0f1 (2nd) → enp9s0 (3rd)
- ✅ Application control (can choose which NIC to use)
- ✅ Fault tolerance (automatic failover via metrics)
- ❌ NO bonding (not needed, router doesn't support LACP anyway)

**How It's Different From Multipath**:
- Multipath: Kernel randomly distributes traffic → asymmetric routing → freezes ❌
- Policy routing: Each NIC handles its own IP → symmetric routing → smooth ✅

**User Experience**:
- Desktop apps use PRIMARY by default (most responsive)
- Heavy downloads can use SECONDARY (offload traffic)
- Background tasks can use TERTIARY (no interference)
- System automatically falls back if a NIC fails
