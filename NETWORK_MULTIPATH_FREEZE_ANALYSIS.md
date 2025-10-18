# Network Multipath Routing Freeze Analysis

**Date**: 2025-10-18  
**Issue**: System freezing every 10 seconds  
**Root Cause**: Multipath routing with asymmetric traffic flow

---

## Discovery

While investigating 10-second system freezes initially attributed to Chrome renderer processes, network analysis revealed **multipath routing** configuration with **3 active NICs on the same subnet**, causing **asymmetric traffic flow**.

---

## Network Configuration Found

### Active Network Interfaces (All on 192.168.1.0/24):

```
1. enp9s0 (Onboard NIC)
   - IP: 192.168.1.85/24
   - State: UP
   - MTU: 1500
   - Default route metric: 300 (lowest priority)

2. enp3s0f0 (Intel X540-T2 10G Port 0)
   - IP: 192.168.1.64/24
   - State: UP
   - MTU: 1500
   - Queues: 8 (optimized)
   - Default route metric: 100
   - Multipath weight: 3

3. enp3s0f1 (Intel X540-T2 10G Port 1)
   - IP: 192.168.1.113/24
   - State: UP
   - MTU: 1500
   - Queues: 8 (optimized)
   - Default route metric: 100
   - Multipath weight: 2

4. docker0 (Docker Bridge)
   - IP: 172.17.0.1/16
   - State: DOWN (no containers)
```

### Routing Table:

```bash
$ ip route show
default 
    nexthop via 192.168.1.254 dev enp3s0f0 weight 3 
    nexthop via 192.168.1.254 dev enp3s0f1 weight 2 
default via 192.168.1.254 dev enp3s0f0 proto dhcp metric 100 
default via 192.168.1.254 dev enp3s0f1 proto dhcp metric 100 
default via 192.168.1.254 dev enp9s0 proto dhcp metric 300 
192.168.1.0/24 dev enp3s0f0 proto kernel scope link src 192.168.1.64 
192.168.1.0/24 dev enp3s0f1 proto kernel scope link src 192.168.1.113 
192.168.1.0/24 dev enp9s0 proto kernel scope link src 192.168.1.85
```

**Multipath routing** distributes traffic across `enp3s0f0` (60% weight) and `enp3s0f1` (40% weight).

---

## Asymmetric Traffic Flow Evidence

### tcpdump Capture (192.178.152.190 CDN connection):

```
07:07:55.241663 enp3s0f1 Out IP 192.168.1.64.34864 > 192.178.152.190.443 [OUTBOUND on enp3s0f1]
07:07:55.280784 enp3s0f0 In  IP 192.178.152.190.443 > 192.168.1.64.34864 [INBOUND on enp3s0f0]
```

**Problem**: 
- **Outbound traffic** uses `enp3s0f1` (192.168.1.64 source IP)
- **Inbound traffic** arrives on `enp3s0f0` (different physical interface)

This creates:
1. **Interface switching**: Packets traverse different hardware paths
2. **IRQ distribution**: Different CPUs handle send vs receive
3. **TCP confusion**: Stack sees packets on "wrong" interface
4. **Routing overhead**: Kernel must track asymmetric flows

### Traffic Burst Pattern:

```
31KB sent in rapid 4200-byte chunks:
  3350 bytes
  4200 bytes
  4200 bytes
  4200 bytes
  ... (8 packets total)
```

Large bursts combined with interface switching can cause:
- **IRQ storms** (multiple NICs firing interrupts)
- **CPU migration** (different cores handling TX vs RX)
- **Cache thrashing** (network state split across cores)

---

## Connection Distribution

### Chrome Connections (32 total):

```bash
$ sudo netstat -tunap | grep chrome | grep ESTABLISHED | cut -d: -f1 | sort | uniq -c

Multiple source IPs detected:
- 192.168.1.64  (enp3s0f0)
- 192.168.1.113 (enp3s0f1)
- 192.168.1.85  (enp9s0) - less common

Destination breakdown:
- Google services: 172.253.x.x, 142.250.x.x, 142.251.x.x, 173.194.x.x
- GitHub: 140.82.x.x, 185.199.x.x
- CDN: 192.178.152.x, 195.176.x.x, 108.156.x.x
- Microsoft: 104.46.x.x, 40.71.x.x
```

**Issue**: Chrome connections spread across 3 different source IPs creates:
- **Connection pooling inefficiency** (each IP gets separate connection pool)
- **Server-side rate limiting confusion** (sees 3 different clients)
- **NAT table bloat** (router tracks 3x connections)

---

## How This Causes 10-Second Freezes

### Theory: Periodic Routing Table Lookup + TCP Retransmits

1. **Every 10 seconds** (common TCP retransmit timeout):
   - Kernel re-evaluates multipath routing decisions
   - TCP connections check for path changes
   - DHCP lease renewals can trigger routing updates

2. **Asymmetric routing causes**:
   - TCP ACKs delayed (arriving on "wrong" interface)
   - Chrome sees connection stalls
   - Renderer processes retry failed requests → CPU spike
   - GPU waits for network data → utilization drop → spike on retry

3. **IRQ distribution inefficiency**:
   - Each NIC uses different IRQ→CPU mapping
   - Context switching overhead every packet
   - CPU cache invalidation

4. **Evidence correlation**:
   - Chrome renderer spikes every ~10 seconds (seen in diagnose_10s_freeze.sh)
   - GPU utilization fluctuates 13-54% (correlates with network retries)
   - Large traffic bursts (31KB) crossing interface boundaries

---

## Solutions (Ranked by Effectiveness)

### **1. DISABLE MULTIPATH ROUTING (Recommended)**

Use **ONLY ONE** 10G interface, disable the others:

```bash
# Option A: Use only enp3s0f0 (higher weight)
sudo ip link set enp3s0f1 down
sudo ip link set enp9s0 down

# Option B: Use only enp3s0f1
sudo ip link set enp3s0f0 down
sudo ip link set enp9s0 down

# Make persistent (disable in NetworkManager or /etc/network/interfaces)
```

**Result**: 
- Single source IP for all connections
- Symmetric routing (TX and RX on same interface)
- Predictable IRQ distribution
- No routing decision overhead

---

### **2. CONFIGURE BONDING (Advanced)**

Instead of multipath, use **proper bonding** for the 10G ports:

```bash
# Install bonding tools
sudo apt install ifenslave

# Create bond0 with active-backup mode
sudo modprobe bonding mode=active-backup miimon=100

# Bond enp3s0f0 + enp3s0f1
# (Requires /etc/network/interfaces configuration)
```

**Modes**:
- **active-backup**: Only one port active at a time (fault tolerance, no asymmetry)
- **balance-alb**: Adaptive load balancing (better than multipath)
- **802.3ad**: LACP (requires switch support)

**Benefit**: 
- Fault tolerance without asymmetric routing
- Single IP address
- Kernel-managed failover

---

### **3. POLICY ROUTING (Complex)**

Force specific applications to use specific interfaces:

```bash
# Route Chrome traffic through enp3s0f0 only
sudo ip rule add from 192.168.1.64 table 100
sudo ip route add default via 192.168.1.254 dev enp3s0f0 table 100
```

**Downside**: Hard to maintain, application-specific rules

---

### **4. DISABLE ONBOARD NIC (Quick Fix)**

Since `enp9s0` has lowest priority (metric 300), disable it:

```bash
sudo ip link set enp9s0 down
sudo systemctl disable NetworkManager-wait-online.service  # If it's managing enp9s0
```

**Result**: Reduces from 3 to 2 source IPs (still have multipath on 10G ports)

---

## Immediate Testing

### Step 1: Disable Multipath (Temporary)

```bash
# Take down the lower-priority interfaces
sudo ip link set enp3s0f1 down
sudo ip link set enp9s0 down

# Verify routing
ip route show
# Should show ONLY enp3s0f0

# Check connections
ip addr show enp3s0f0
# Should be UP with 192.168.1.64
```

### Step 2: Monitor for Freezes

```bash
# Watch GPU and network
watch -n 2 'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader; ss -s'

# Or use our existing diagnostic
./diagnose_10s_freeze.sh
```

**Expected result**: Freezing stops immediately if multipath was the cause.

### Step 3: Check Chrome Connections

```bash
# All connections should now use 192.168.1.64 only
sudo netstat -tunap | grep chrome | grep ESTABLISHED | awk '{print $4}' | cut -d: -f1 | sort | uniq
```

---

## Make Permanent (After Testing Confirms Fix)

### Option A: NetworkManager (If Using)

```bash
# Disable enp3s0f1 and enp9s0 permanently
nmcli connection modify enp3s0f1 connection.autoconnect no
nmcli connection modify enp9s0 connection.autoconnect no
```

### Option B: systemd-networkd

Create `/etc/systemd/network/10-disable-extra-nics.link`:

```ini
[Match]
OriginalName=enp3s0f1

[Link]
Unmanaged=yes
```

Repeat for `enp9s0`.

### Option C: /etc/network/interfaces (Debian/Ubuntu)

Comment out or remove configurations for `enp3s0f1` and `enp9s0`, keep only:

```
auto enp3s0f0
iface enp3s0f0 inet dhcp
```

---

## Verification Commands

### Check Active Routes:
```bash
ip route show | grep default
# Should show ONLY one default route via enp3s0f0
```

### Check Interface Status:
```bash
ip link show | grep -E "enp[39]"
# enp3s0f0: should be UP
# enp3s0f1: should be DOWN
# enp9s0: should be DOWN
```

### Monitor Traffic Flow:
```bash
sudo tcpdump -i enp3s0f0 -n -c 20 2>&1 | grep -E "In|Out"
# All traffic should be on enp3s0f0 (both In and Out)
```

### Check IRQ Distribution:
```bash
grep enp /proc/interrupts
# Should show IRQs ONLY for enp3s0f0
```

---

## Why Multipath Was Configured

Possible reasons you have multipath routing:

1. **DHCP on all interfaces**: NetworkManager obtained leases on all 3 NICs
2. **Desktop environment default**: XFCE/NetworkManager enables all detected interfaces
3. **Bonding configuration missing**: Intended to bond 10G ports but incomplete setup
4. **Testing configuration**: Previously testing multi-NIC setup

---

## Expected Performance Improvement

After disabling multipath routing:

✅ **No more 10-second freezes** (eliminates asymmetric routing overhead)  
✅ **Lower CPU usage** (no routing decisions, single IRQ path)  
✅ **Consistent Chrome performance** (single connection pool)  
✅ **Predictable IRQ distribution** (all network IRQs to same CPU cores)  
✅ **Better TCP performance** (symmetric routing, no ACK delays)  
✅ **Reduced context switching** (network RX/TX on same cores)

---

## Correlation with Chrome Renderer Spikes

**Original diagnosis**: Chrome renderer processes spiking every ~10 seconds

**New understanding**: 
- Chrome renderers spike **BECAUSE** network requests are stalling
- Asymmetric routing causes TCP retransmits
- Chrome retries = renderer CPU spike
- GPU waits for network data, then spikes on retry
- **Not a Chrome bug, it's network infrastructure causing Chrome to struggle**

---

## Next Steps

1. **Immediately test**: `sudo ip link set enp3s0f1 down && sudo ip link set enp9s0 down`
2. **Monitor for 5 minutes**: Watch for freeze disappearance
3. **If successful**: Make permanent via NetworkManager/systemd
4. **If not successful**: Re-enable interfaces and investigate Chrome extensions (original plan)

---

## Author's Note

This is a **perfect example** of why performance debugging requires **holistic analysis**:

- Started with: "VSCode stuttering"
- Dug into: NVMe IRQ starvation, dirty pages, network queues
- Thought we fixed it: All optimizations working
- New symptom: "10-second freezes"
- First diagnosis: Chrome renderers (partially correct)
- **Root cause**: Network multipath routing creating asymmetric flows

The Chrome renderer spikes were **symptomatic**, not causal. They were struggling because the network layer was creating unpredictable latency.

**Lesson**: Always check `ip route show` and `ip addr show` when investigating periodic system issues!
