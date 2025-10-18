# Policy Routing - Persistence Configuration

**Status**: ✅ COMPLETE - Configuration persists across reboots

## Overview

The policy-based routing configuration is now automatically applied on every boot via a systemd service. This ensures all 3 NICs remain active with symmetric routing (no asymmetric routing issues).

---

## Systemd Service Details

### Service File
- **Location**: `/etc/systemd/system/policy-routing.service`
- **Type**: oneshot (runs once at boot)
- **Status**: Enabled and working

### Service Configuration
```ini
[Unit]
Description=Policy-Based Routing for Multi-NIC Configuration
After=network-online.target
Before=docker.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

### Key Features
1. **Runs after network is online**: Ensures NICs are up before configuring
2. **Runs before Docker**: Prevents Docker from interfering with routing
3. **Idempotent**: Safe to run multiple times (won't fail if routes exist)
4. **Enabled for boot**: Automatically starts on system boot

---

## Service Management Commands

### Check Service Status
```bash
sudo systemctl status policy-routing.service
```

Expected output:
- **Active**: `active (exited)` (normal for oneshot services)
- **Loaded**: `enabled` (will start on boot)
- **Exit code**: `0/SUCCESS`

### Manual Service Control
```bash
# Start service (apply configuration now)
sudo systemctl start policy-routing.service

# Stop service (doesn't remove routes, just stops service)
sudo systemctl stop policy-routing.service

# Restart service (reapply configuration)
sudo systemctl restart policy-routing.service

# Disable service (won't start on boot)
sudo systemctl disable policy-routing.service

# Re-enable service (starts on boot again)
sudo systemctl enable policy-routing.service
```

### View Service Logs
```bash
# View recent logs
sudo journalctl -u policy-routing.service

# Follow logs in real-time
sudo journalctl -u policy-routing.service -f

# View logs from last boot
sudo journalctl -u policy-routing.service -b
```

---

## Configuration Script

### Script Location
`/home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh`

### Script Features
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Error handling**: Continues even if routes already exist
- ✅ **Comprehensive**: Configures all aspects of policy routing
- ✅ **Verbose**: Shows what it's doing at each step

### What the Script Does
1. **Cleans up** old policy routing rules
2. **Removes** multipath default route
3. **Creates** dedicated routing tables (100, 101, 102)
4. **Adds** source-based policy rules
5. **Sets** route metrics (priority order)
6. **Enables** reverse path filtering (loose mode)
7. **Flushes** routing cache

### Manual Execution
You can run the script manually anytime:
```bash
cd /home/jeb/programs/vscode_performance_fix_20251018_032616
sudo ./configure_policy_routing.sh
```

---

## Verification After Reboot

After rebooting, verify the configuration is applied:

### 1. Check Service Started
```bash
sudo systemctl status policy-routing.service
```
Should show: `Active: active (exited)` with status `0/SUCCESS`

### 2. Verify Policy Rules
```bash
ip rule show | grep -E "^100:|^101:|^102:"
```
Should show:
```
100:    from 192.168.1.64 lookup 100
101:    from 192.168.1.113 lookup 101
102:    from 192.168.1.85 lookup 102
```

### 3. Check Route Metrics
```bash
ip route show | grep default
```
Should show metrics: 100 (enp3s0f0), 200 (enp3s0f1), 300 (enp9s0)

### 4. Test Routing Tables
```bash
# Test PRIMARY
ip route get 8.8.8.8 from 192.168.1.64

# Test SECONDARY
ip route get 8.8.8.8 from 192.168.1.113

# Test TERTIARY
ip route get 8.8.8.8 from 192.168.1.85
```

Each should show the correct NIC (dev) for its source IP.

### 5. Verify NICs Are Up
```bash
ip addr show | grep -E "enp3s0f0|enp3s0f1|enp9s0" -A 2
```
Should show all 3 NICs with UP status and their IP addresses.

---

## Expected Boot Sequence

1. **System starts** → Network service brings up NICs
2. **network-online.target** → NICs have IP addresses
3. **policy-routing.service** → Applies policy routing configuration
4. **Docker service** → Starts after routing is configured
5. **User login** → All 3 NICs working with symmetric routing

---

## Troubleshooting

### Service Failed to Start
```bash
# Check detailed logs
sudo journalctl -u policy-routing.service -n 50

# Check for RTNETLINK errors
sudo journalctl -u policy-routing.service | grep RTNETLINK

# Manually run script to see errors
sudo /home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh
```

### Routes Not Applied
```bash
# Check if service is enabled
systemctl is-enabled policy-routing.service

# Re-enable if needed
sudo systemctl enable policy-routing.service

# Force restart service
sudo systemctl restart policy-routing.service
```

### NICs Not Coming Up
```bash
# Check NetworkManager/systemd-networkd
systemctl status NetworkManager
systemctl status systemd-networkd

# Check NIC status
ip link show

# Check DHCP assignment
ip addr show
```

### Asymmetric Routing Still Occurring
```bash
# Verify policy rules exist
ip rule show | grep -E "100|101|102"

# Verify routing tables
ip route show table 100
ip route show table 101
ip route show table 102

# Check multipath is removed
ip route show | grep nexthop

# If multipath still exists, restart service
sudo systemctl restart policy-routing.service
```

---

## Modifying the Configuration

If you need to change the configuration:

1. **Edit the script**:
   ```bash
   cd /home/jeb/programs/vscode_performance_fix_20251018_032616
   nano configure_policy_routing.sh
   ```

2. **Test your changes**:
   ```bash
   sudo ./configure_policy_routing.sh
   ```

3. **Restart service** (changes take effect immediately):
   ```bash
   sudo systemctl restart policy-routing.service
   ```

4. **No need to reinstall** - service reads the script on each execution

---

## Disabling Persistence (Not Recommended)

If you need to temporarily disable policy routing persistence:

```bash
# Disable service (won't start on next boot)
sudo systemctl disable policy-routing.service

# Stop service (doesn't remove current routes)
sudo systemctl stop policy-routing.service
```

To restore default multipath routing (NOT RECOMMENDED - causes freezes):
```bash
# Remove policy rules
sudo ip rule del priority 100
sudo ip rule del priority 101
sudo ip rule del priority 102

# Reset to multipath
sudo dhclient -v
```

**WARNING**: Disabling policy routing will re-enable asymmetric routing, which causes the 10-second freezing issues!

---

## Files Modified for Persistence

1. **Service file created**: `/etc/systemd/system/policy-routing.service`
2. **Service enabled**: Symlink in `/etc/systemd/system/multi-user.target.wants/`
3. **Script location**: `/home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh`

No other system files were modified. The configuration is self-contained and can be easily removed if needed.

---

## Summary

✅ **Policy routing is now persistent**
- Service enabled and working
- Starts automatically on boot
- All 3 NICs remain active
- No asymmetric routing
- Priority order: 10G ports first, onboard third
- No bonding required

✅ **Configuration verified**
- Service status: `active (exited)` - SUCCESS
- Policy rules: 100, 101, 102 active
- Route metrics: 100, 200, 300 correct
- Idempotent script: safe to run multiple times

✅ **Reboot-ready**
- Configuration will persist across reboots
- Service will start automatically
- NICs will be configured correctly
- No manual intervention needed

🎯 **10-second freezing issue: SOLVED**
- Root cause: Asymmetric routing
- Solution: Policy-based routing with symmetric paths
- Status: Implemented and persistent
