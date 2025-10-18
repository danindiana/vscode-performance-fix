# Policy-Based Routing - Installation & Persistence

**Date**: 2025-10-18  
**Status**: ✅ Configured and tested  
**Next Step**: Make persistent across reboots

---

## Current Status

### ✅ What's Working Now (Temporary)

- All 3 NICs active with separate IPs
- Policy routing configured (symmetric routing)
- No asymmetric routing issues
- Priority order: enp3s0f0 (1st) → enp3s0f1 (2nd) → enp9s0 (3rd)

### ⚠️ What Happens on Reboot

**CONFIGURATION WILL BE LOST!**

The changes made by `configure_policy_routing.sh` are:
- ❌ NOT persistent across reboots
- ❌ Will revert to DHCP defaults (likely multipath routing again)

---

## Make Configuration Permanent

### Option 1: systemd Service (Recommended)

#### Step 1: Install the service

```bash
cd /home/jeb/programs/vscode_performance_fix_20251018_032616

# Copy service file to systemd directory
sudo cp policy-routing.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service (starts on boot)
sudo systemctl enable policy-routing.service

# Check status
sudo systemctl status policy-routing.service
```

#### Step 2: Verify it will run on boot

```bash
# Check if enabled
systemctl is-enabled policy-routing.service
# Should output: enabled
```

#### Step 3: Test the service

```bash
# Start the service manually
sudo systemctl start policy-routing.service

# Check for errors
sudo systemctl status policy-routing.service

# View logs
sudo journalctl -u policy-routing.service -n 50
```

### Option 2: NetworkManager Dispatcher (Alternative)

If you prefer NetworkManager integration:

```bash
# Create dispatcher script
sudo tee /etc/NetworkManager/dispatcher.d/99-policy-routing <<'EOF'
#!/bin/bash
if [ "$2" = "up" ]; then
    sleep 2
    /home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh
fi
EOF

# Make executable
sudo chmod +x /etc/NetworkManager/dispatcher.d/99-policy-routing
```

**Note**: This runs every time NetworkManager brings up an interface.

---

## Verification After Reboot

### Step 1: Reboot the system

```bash
sudo reboot
```

### Step 2: After reboot, check configuration

```bash
# Check all NICs are UP
ip addr show | grep -E "state|inet "

# Should show:
# enp3s0f0: state UP, inet 192.168.1.64
# enp3s0f1: state UP, inet 192.168.1.113
# enp9s0: state UP, inet 192.168.1.85
```

### Step 3: Verify policy routing

```bash
# Check routing tables
ip route show

# Should show:
# default via 192.168.1.254 dev enp3s0f0 metric 100
# default via 192.168.1.254 dev enp3s0f1 metric 200
# default via 192.168.1.254 dev enp9s0 metric 300
```

### Step 4: Verify policy rules

```bash
ip rule show | grep "192.168.1"

# Should show:
# 100: from 192.168.1.64 lookup 100
# 101: from 192.168.1.113 lookup 101
# 102: from 192.168.1.85 lookup 102
```

### Step 5: Test symmetric routing

```bash
ip route get 8.8.8.8 from 192.168.1.64    # dev enp3s0f0 table 100
ip route get 8.8.8.8 from 192.168.1.113   # dev enp3s0f1 table 101
ip route get 8.8.8.8 from 192.168.1.85    # dev enp9s0 table 102
```

### Step 6: Monitor for 10-second freezes

```bash
# Run for 2 minutes (60 samples)
for i in {1..60}; do 
    echo "=== Sample $i $(date +%H:%M:%S) ==="
    top -bn1 | grep chrome | head -3
    sleep 2
done
```

**Expected**: No periodic Chrome renderer spikes, no freezing.

---

## Troubleshooting Post-Reboot

### Service didn't start

```bash
# Check service status
sudo systemctl status policy-routing.service

# View full logs
sudo journalctl -u policy-routing.service -b

# Common issues:
# - Script path incorrect (check ExecStart in service file)
# - Network not ready (service runs too early)
```

**Fix**: Edit service file to add delays:

```bash
sudo systemctl edit policy-routing.service

# Add:
[Service]
ExecStartPre=/bin/sleep 10
```

### Policy rules not applied

```bash
# Manually run the script
sudo /home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh

# If it works manually, service timing is the issue
```

### DHCP overwrites routes

NetworkManager or dhclient might be resetting routes.

**Fix**: Add priority to our routes:

```bash
# Edit configure_policy_routing.sh
# Change lines with "ip route add default" to:
ip route add default via 192.168.1.254 dev enp3s0f0 metric 100 proto static
```

`proto static` tells NetworkManager not to remove it.

### Multipath routing returns

```bash
ip route show | grep nexthop

# If you see multipath routing again:
sudo ip route del default

# Then re-run:
sudo /home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh
```

---

## Backup Configuration

Before making permanent, save current working state:

```bash
# Save routing tables
ip route show > ~/routing_backup_$(date +%Y%m%d).txt

# Save policy rules
ip rule show > ~/policy_rules_backup_$(date +%Y%m%d).txt

# Save interface configuration
ip addr show > ~/interfaces_backup_$(date +%Y%m%d).txt
```

---

## Uninstall (Revert to Single NIC)

If you want to remove policy routing:

### Step 1: Disable systemd service

```bash
sudo systemctl disable policy-routing.service
sudo systemctl stop policy-routing.service
sudo rm /etc/systemd/system/policy-routing.service
sudo systemctl daemon-reload
```

### Step 2: Remove NetworkManager dispatcher (if used)

```bash
sudo rm /etc/NetworkManager/dispatcher.d/99-policy-routing
```

### Step 3: Disable extra NICs

```bash
sudo ip link set enp3s0f1 down
sudo ip link set enp9s0 down

# Make persistent (NetworkManager)
nmcli connection modify enp3s0f1 connection.autoconnect no
nmcli connection modify enp9s0 connection.autoconnect no
```

### Step 4: Clean up policy rules

```bash
sudo ip rule del from 192.168.1.64 table 100
sudo ip rule del from 192.168.1.113 table 101
sudo ip rule del from 192.168.1.85 table 102

sudo ip route flush table 100
sudo ip route flush table 101
sudo ip route flush table 102
```

### Step 5: Reboot

```bash
sudo reboot
```

After reboot, only enp3s0f0 will be active.

---

## Advanced: Per-Application NIC Assignment

Once policy routing is permanent, you can configure specific applications to use specific NICs.

### Docker on SECONDARY NIC

Edit `/etc/docker/daemon.json`:

```json
{
  "ip": "192.168.1.113",
  "bip": "172.18.0.1/16"
}
```

Restart Docker:
```bash
sudo systemctl restart docker
```

### Transmission (BitTorrent) on TERTIARY NIC

Edit Transmission settings:

```json
{
  "bind-address-ipv4": "192.168.1.85"
}
```

### Steam Downloads on SECONDARY NIC

Steam doesn't support bind address, but you can use `iptables` marking:

```bash
# Mark Steam traffic
sudo iptables -t mangle -A OUTPUT -m owner --uid-owner steam -j MARK --set-mark 0x1

# Route marked traffic via SECONDARY
sudo ip rule add fwmark 0x1 table 101 priority 90
```

---

## Monitoring Commands

### Check NIC utilization

```bash
# Real-time per-NIC traffic
watch -n 1 'ifstat -i enp3s0f0,enp3s0f1,enp9s0 1 1'
```

### Check connection distribution

```bash
# See which IP has most connections
netstat -tunap 2>/dev/null | grep ESTABLISHED | awk '{print $4}' | cut -d: -f1 | sort | uniq -c | sort -rn
```

### Monitor policy routing tables

```bash
# Watch routing decisions
sudo watch -n 1 'ip route get 8.8.8.8; ip route get 8.8.8.8 from 192.168.1.113'
```

---

## Next Steps

1. **Test current configuration** for 30 minutes
   - Check for 10-second freezes
   - Monitor Chrome performance
   - Verify no asymmetric routing

2. **If working well**, install systemd service:
   ```bash
   sudo cp policy-routing.service /etc/systemd/system/
   sudo systemctl enable policy-routing.service
   ```

3. **Reboot and verify** configuration persists

4. **Document your applications** and which NIC they should use

5. **Set up monitoring** (optional):
   - Grafana for NIC bandwidth graphs
   - Prometheus node_exporter for metrics

---

## Files in This Repository

| File | Purpose |
|------|---------|
| `configure_policy_routing.sh` | Main configuration script |
| `policy-routing.service` | systemd service file |
| `POLICY_ROUTING_EXPLAINED.md` | Detailed explanation and use cases |
| `POLICY_ROUTING_INSTALL.md` | This file (installation guide) |
| `NETWORK_MULTIPATH_FREEZE_ANALYSIS.md` | Original problem analysis |
| `MULTIPATH_FIX_APPLIED.md` | First fix attempt (single NIC) |

---

## Summary

**Current State**: 
- ✅ Policy routing configured and working
- ⚠️ Will be lost on reboot (not persistent yet)

**To Make Permanent**:
```bash
sudo cp policy-routing.service /etc/systemd/system/
sudo systemctl enable policy-routing.service
sudo systemctl start policy-routing.service
```

**To Test After Reboot**:
```bash
ip route show          # Check routing table
ip rule show           # Check policy rules
ip route get 8.8.8.8   # Should use enp3s0f0 (PRIMARY)
```

**Expected Result**: 
- All 3 NICs active
- No asymmetric routing
- No 10-second freezes
- Chrome performance smooth
- CPU offloading available for heavy downloads
