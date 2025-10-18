# Reboot Test Results - Policy Routing Persistence

**Date**: October 18, 2025, 4:05 PM CDT  
**Test**: First reboot after implementing policy routing persistence

---

## Test Results Summary

### ✅ What Worked
1. **Service started successfully**: Policy-routing.service ran on boot
2. **Service timing**: Started at 15:07:26 (1 second after NetworkManager)
3. **Policy rules created**: Rules 100, 101, 102 were in place
4. **All NICs came up**: All 3 NICs active with correct IPs
5. **Script is idempotent**: No errors when run multiple times

### ❌ What Didn't Work Initially
1. **NetworkManager re-added multipath routing**: After policy-routing service ran
2. **Asymmetric routing resumed**: Traffic using wrong NICs
3. **Timing issue**: Service ran too quickly after NetworkManager

### 🔧 Root Cause
**NetworkManager was still configuring routes AFTER the policy-routing service completed.**

The service ran at 15:07:26, only 1 second after NetworkManager started (15:07:25). NetworkManager takes time to fully configure all NICs, and it re-applied multipath routing after our service finished.

---

## Evidence of the Problem

### Multipath Routing Was Re-added
```bash
$ ip route show | grep nexthop
        nexthop via 192.168.1.254 dev enp3s0f0 weight 3 
        nexthop via 192.168.1.254 dev enp3s0f1 weight 2
```

### Routing Tables Using Wrong NICs
```bash
# Traffic FROM .64 should use enp3s0f0, but was using enp3s0f1
$ ip route get 8.8.8.8 from 192.168.1.64
8.8.8.8 from 192.168.1.64 via 192.168.1.254 dev enp3s0f1 uid 1000

# Traffic FROM .113 should use enp3s0f1, but was using enp3s0f0  
$ ip route get 8.8.8.8 from 192.168.1.113
8.8.8.8 from 192.168.1.113 via 192.168.1.254 dev enp3s0f0 uid 1000

# Traffic FROM .85 should use enp9s0, but was using enp3s0f0
$ ip route get 8.8.8.8 from 192.168.1.85
8.8.8.8 from 192.168.1.85 via 192.168.1.254 dev enp3s0f0 uid 1000
```

### Manual Script Run Fixed It
Running the configuration script manually immediately fixed the routing:
```bash
$ sudo ./configure_policy_routing.sh
# ... script output ...

$ ip route get 8.8.8.8 from 192.168.1.64
8.8.8.8 from 192.168.1.64 via 192.168.1.254 dev enp3s0f0 table 100 uid 1000 ✅

$ ip route get 8.8.8.8 from 192.168.1.113
8.8.8.8 from 192.168.1.113 via 192.168.1.254 dev enp3s0f1 table 101 uid 1000 ✅

$ ip route get 8.8.8.8 from 192.168.1.85
8.8.8.8 from 192.168.1.85 via 192.168.1.254 dev enp9s0 table 102 uid 1000 ✅

$ ip route show | grep nexthop
# (no output - multipath removed) ✅
```

---

## The Fix

### Service File Changes

**Original service timing**:
```ini
[Unit]
After=network-online.target
```

**Updated service timing**:
```ini
[Unit]
After=network-online.target NetworkManager.service systemd-networkd.service
```

**Added delay**:
```ini
[Service]
ExecStartPre=/bin/sleep 5
ExecStart=/home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh
```

### Why This Works

1. **Explicit dependency**: Service now waits for NetworkManager to START (not just network-online)
2. **5-second delay**: Gives NetworkManager time to fully configure all NICs
3. **Service still runs**: After NetworkManager is completely done, policy routing overrides multipath

### Files Updated
- `/home/jeb/programs/vscode_performance_fix_20251018_032616/policy-routing.service` (source)
- `/etc/systemd/system/policy-routing.service` (installed copy)

---

## Technical Details

### Boot Sequence Timeline

**Before Fix**:
```
15:07:25 - NetworkManager.service starts
15:07:26 - network-online.target reached
15:07:26 - policy-routing.service runs (1 second after NM start)
15:07:26 - policy-routing.service completes
15:07:27+ - NetworkManager finishes configuring NICs, re-adds multipath
Result: Multipath routing active, asymmetric routing resumed
```

**After Fix**:
```
15:07:25 - NetworkManager.service starts
15:07:26 - network-online.target reached
15:07:26 - NetworkManager continues NIC configuration
15:07:27+ - NetworkManager completes
15:07:28+ - policy-routing.service starts (after NM is done)
15:07:33+ - 5-second delay completes
15:07:33+ - configure_policy_routing.sh runs
15:07:34+ - policy-routing.service completes
Result: Policy routing active, symmetric routing maintained
```

### Why NetworkManager Re-added Multipath

NetworkManager by default:
1. Enables all NICs on the same subnet
2. Detects multiple default gateways
3. Creates multipath routing with weighted nexthops
4. This is NetworkManager's "smart" behavior for redundancy

Our policy routing intentionally overrides this to prevent asymmetric routing issues.

---

## Verification Commands

After the next reboot, verify with these commands:

### 1. Check Service Started AFTER NetworkManager
```bash
systemctl show -p ActiveEnterTimestamp NetworkManager.service policy-routing.service
```
Policy-routing should be several seconds after NetworkManager.

### 2. Verify No Multipath Routing
```bash
ip route show | grep nexthop
```
Should return empty (no multipath).

### 3. Check Policy Rules Active
```bash
ip rule show | grep -E "^100:|^101:|^102:"
```
Should show all three rules.

### 4. Test Each NIC Routes Correctly
```bash
ip route get 8.8.8.8 from 192.168.1.64    # Should use enp3s0f0 (table 100)
ip route get 8.8.8.8 from 192.168.1.113   # Should use enp3s0f1 (table 101)
ip route get 8.8.8.8 from 192.168.1.85    # Should use enp9s0 (table 102)
```

Each should show the correct "dev" for its source IP.

### 5. Check Service Status
```bash
sudo systemctl status policy-routing.service
```
Should show: `Active: active (exited)` with `status=0/SUCCESS`

---

## Current Status

✅ **Policy routing is working NOW** (after manual script run)  
✅ **Service file updated** with proper timing and delay  
✅ **Service reloaded** and ready for next reboot  
⏳ **Needs reboot test** to verify fix works on boot  

---

## Next Steps

1. **Reboot the system** to test the updated service
2. **Run verification commands** immediately after login
3. **Monitor for 10-15 minutes** to ensure no freezing occurs
4. **Report results** - if routing is correct on boot, the fix is complete

---

## Alternative Solutions (If Delay Isn't Enough)

If the 5-second delay isn't sufficient, we can:

### Option 1: Increase Delay
Change `ExecStartPre=/bin/sleep 5` to `/bin/sleep 10`

### Option 2: NetworkManager Dispatcher Script
Create `/etc/NetworkManager/dispatcher.d/99-policy-routing`:
```bash
#!/bin/bash
if [ "$2" = "up" ]; then
    /home/jeb/programs/vscode_performance_fix_20251018_032616/configure_policy_routing.sh
fi
```

This runs the script every time a NIC comes up.

### Option 3: Disable NetworkManager Multipath
Edit `/etc/NetworkManager/NetworkManager.conf`:
```ini
[connection]
ipv4.routes-data=''
```

This prevents NetworkManager from creating multipath routes.

---

## Summary

**Problem**: NetworkManager re-added multipath routing after policy-routing service ran  
**Cause**: Service ran too quickly (1 second) after NetworkManager started  
**Fix**: Added explicit NetworkManager dependency + 5-second delay  
**Status**: Service updated and ready for reboot test  
**Expected**: Next reboot should apply policy routing correctly  

The policy routing configuration itself works perfectly - this was purely a service timing/ordering issue.
