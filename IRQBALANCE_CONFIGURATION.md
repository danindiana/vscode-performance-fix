# IRQBalance Configuration: Dynamic vs Static

**Date:** October 18, 2025  
**Issue:** IRQBalance rebalancing IRQs every 10 minutes, potentially interfering with manual optimizations

---

## 🔍 Discovery

User observation: *"So this system somehow someway got setup that every 15 min or thereabouts the system re-balances all the IRQ assignments."*

Investigation revealed `irqbalance` daemon running with 600-second (10 minute) interval.

---

## Current Configuration

### IRQBalance Status
```bash
$ systemctl status irqbalance.service
Active: active (running) since Sat 2025-10-18 05:20:24 CDT
Process: /usr/sbin/irqbalance --foreground --interval=600
```

### Configuration File
**Location:** `/etc/default/irqbalance`

**Current Setting:**
```bash
IRQBALANCE_ARGS="--interval=600"
```

**Default Behavior:**
- Rebalances IRQs every 600 seconds (10 minutes)
- Analyzes interrupt load across CPUs
- Redistributes IRQs to balance load
- Can override manual IRQ assignments

---

## 📊 Impact Analysis

### What IRQBalance Does

**Positive:**
- Automatically distributes IRQ load across CPUs
- Prevents single CPU from becoming IRQ hotspot
- Adapts to changing workload patterns
- Works well with managed IRQs (NVMe, modern NICs)

**Potential Issues:**
- May revert manual IRQ optimizations
- Continuous rebalancing adds overhead
- Non-deterministic IRQ placement
- Can interfere with CPU isolation strategies

### Impact on Our Optimizations

**What IRQBalance DOES affect:**
- ⚠️ NVMe IRQ distribution (may redistribute across CPUs)
- ⚠️ Network IRQ distribution (may move queues between CPUs)
- ⚠️ GPU IRQ placement (may reassign to different CPUs)

**What IRQBalance DOES NOT affect:**
- ✓ Network queue count (8 queues stays 8 queues)
- ✓ NVMe queue count (49 queues stays 49 queues)
- ✓ I/O scheduler settings
- ✓ Read-ahead settings
- ✓ Queue depth settings

**Key Insight:** IRQBalance redistributes IRQs among existing queues but doesn't change the queue count or other optimizations.

---

## 🎯 Configuration Options

### Option 1: ONESHOT Mode (RECOMMENDED)

**What it does:**
- Balance IRQs once at boot time
- After ~60 seconds, daemon exits
- IRQ assignments remain static until next reboot

**Advantages:**
- ✓ Initial optimal distribution at boot
- ✓ Static assignments during runtime
- ✓ Manual optimizations preserved
- ✓ Predictable IRQ placement
- ✓ No ongoing rebalancing overhead

**Disadvantages:**
- ⚠️ No adaptation to changing workloads
- ⚠️ If workload shifts dramatically, IRQs won't rebalance

**Configuration:**
```bash
# /etc/default/irqbalance
IRQBALANCE_ONESHOT=1
IRQBALANCE_ARGS=""
```

**When to use:**
- Workloads are relatively static
- Manual IRQ tuning is important
- Predictable performance is priority
- You have CPU isolation requirements

---

### Option 2: Disable IRQBalance Completely

**What it does:**
- Stop and disable irqbalance service
- No automatic balancing at all
- All IRQ assignments remain as initialized by kernel

**Advantages:**
- ✓ Complete control over IRQ placement
- ✓ Zero interference with manual settings
- ✓ No daemon overhead

**Disadvantages:**
- ⚠️ No automatic balancing at boot
- ⚠️ Poor initial distribution possible
- ⚠️ Must manually manage all IRQ assignments
- ⚠️ CPU hotspots can develop

**Configuration:**
```bash
sudo systemctl stop irqbalance.service
sudo systemctl disable irqbalance.service
```

**When to use:**
- Real-time applications
- Strict CPU isolation needed
- Complete manual IRQ management
- Very specific performance requirements

---

### Option 3: Increase Interval

**What it does:**
- Keep dynamic balancing but less frequent
- Rebalance every 30min, 1hr, or 2hr instead of 10min

**Advantages:**
- ✓ Still adapts to workload changes
- ✓ Less frequent interference
- ✓ Reduced daemon overhead

**Disadvantages:**
- ⚠️ Still rebalances periodically
- ⚠️ Can still override manual settings
- ⚠️ Less responsive to load changes

**Configuration:**
```bash
# /etc/default/irqbalance
IRQBALANCE_ARGS="--interval=3600"  # 1 hour
```

**When to use:**
- Workloads change throughout the day
- Want some automatic balancing
- Can tolerate occasional rebalancing

---

### Option 4: Keep Current (600 second interval)

**What it does:**
- No changes, rebalance every 10 minutes

**Advantages:**
- ✓ Responsive to workload changes
- ✓ Prevents CPU hotspots

**Disadvantages:**
- ⚠️ Frequent rebalancing
- ⚠️ May interfere with optimizations

**When to use:**
- Highly variable workloads
- No manual IRQ tuning
- Standard server workload

---

## 🔬 Testing IRQBalance Behavior

### Monitor IRQ Assignments Over Time

```bash
# Watch specific IRQs (NVMe, Network)
watch -n 5 'cat /proc/interrupts | grep -E "nvme0q8|nvme1q0|enp3s0f0-TxRx-2"'
```

**What to observe:**
- IRQ numbers stay the same (queue count doesn't change)
- CPU columns may shift (IRQ moved between CPUs)
- Interrupt counts continue increasing

### Check IRQBalance Process

```bash
# See if daemon is running
ps aux | grep irqbalance

# ONESHOT mode: Process exits after ~60 seconds
# Normal mode: Process stays running
```

### View IRQBalance Logs

```bash
# Real-time logs
journalctl -u irqbalance.service -f

# Recent activity
journalctl -u irqbalance.service --since "10 minutes ago"
```

**Log indicators:**
```
Oct 18 05:20:24 worlock systemd[1]: Started irqbalance daemon.
Oct 18 05:21:30 worlock systemd[1]: irqbalance.service: Succeeded.  # ONESHOT exit
```

---

## 🎯 Recommendation for This System

### Analysis

**System Profile:**
- AMD Threadripper (32 cores) - plenty of CPU capacity
- Multiple high-performance devices (NVMe, 10G NICs, GPUs)
- Manual optimizations applied (network queues, NVMe settings)
- Relatively static workload (development/workstation)

**Current Status:**
- NVMe: 49 queues on nvme1, 9 queues on nvme0
- Network: 8 queues per 10G port
- IRQBalance: Running with 600-second interval

**Concerns:**
- IRQBalance may redistribute optimized IRQs
- 10-minute rebalancing seems unnecessary for static workload
- Want predictable performance

### Recommended Configuration: **ONESHOT MODE**

**Rationale:**
1. ✓ Get initial optimal distribution at boot
2. ✓ Preserve manual network queue optimization
3. ✓ Static IRQ placement for predictable performance
4. ✓ No ongoing daemon overhead
5. ✓ 32 cores provide plenty of IRQ capacity

**Implementation:**
```bash
chmod +x configure_irqbalance_oneshot.sh
sudo ./configure_irqbalance_oneshot.sh
# Choose option [1]
```

**Expected Behavior:**
- At boot: IRQBalance analyzes system, balances IRQs optimally
- After ~60 seconds: Daemon exits
- During runtime: IRQ assignments remain static
- Network optimizations: Preserved (8 queues stay on same CPUs)
- NVMe distribution: Static (good for benchmarking)

---

## 📋 Implementation Steps

### 1. Baseline Current State

```bash
# Capture current IRQ distribution
sudo cat /proc/interrupts > /tmp/irq-before-oneshot.txt

# Note current network queue status
sudo ethtool -l enp3s0f0 > /tmp/network-before-oneshot.txt

# Check NVMe queue distribution
./analyze_all_irq_starvation.sh > /tmp/nvme-before-oneshot.txt
```

### 2. Apply ONESHOT Configuration

```bash
chmod +x configure_irqbalance_oneshot.sh
sudo ./configure_irqbalance_oneshot.sh
```

Select option [1] for ONESHOT mode.

### 3. Wait for ONESHOT to Complete

```bash
# Watch daemon process (should exit after ~60 seconds)
watch -n 5 'ps aux | grep irqbalance'

# Monitor service status
journalctl -u irqbalance.service -f
```

### 4. Verify Configuration

```bash
# Check service completed successfully
systemctl status irqbalance.service

# Capture new IRQ distribution
sudo cat /proc/interrupts > /tmp/irq-after-oneshot.txt

# Compare before/after
diff /tmp/irq-before-oneshot.txt /tmp/irq-after-oneshot.txt
```

### 5. Monitor Stability

```bash
# Wait 15 minutes, then check IRQs haven't changed
sleep 900
sudo cat /proc/interrupts > /tmp/irq-after-15min.txt
diff /tmp/irq-after-oneshot.txt /tmp/irq-after-15min.txt

# Should show minimal differences (only interrupt counts, not CPU assignments)
```

---

## 🔍 Verification Checklist

After applying ONESHOT mode:

- [ ] irqbalance process exits after ~60 seconds
- [ ] Service status shows "Succeeded" or "inactive (dead)"
- [ ] Network still has 8 queues: `ethtool -l enp3s0f0`
- [ ] NVMe still has correct queue count: `./nvme-status`
- [ ] IRQ assignments remain static (check after 15 min)
- [ ] No performance degradation observed
- [ ] System boots correctly with ONESHOT enabled

---

## 🛡️ Rollback Plan

If ONESHOT mode causes issues:

### Quick Rollback
```bash
# Restore previous configuration
sudo cp /etc/default/irqbalance.backup-oneshot /etc/default/irqbalance

# Restart with old settings
sudo systemctl restart irqbalance.service
```

### Alternative: Increase Interval Instead
```bash
# Set to 1 hour instead of ONESHOT
sudo ./configure_irqbalance_oneshot.sh
# Choose option [3], enter 3600
```

### Nuclear Option: Disable Completely
```bash
sudo systemctl stop irqbalance.service
sudo systemctl disable irqbalance.service
```

---

## 📊 Comparison Table

| Mode | Rebalance Frequency | Manual Control | Workload Adaptation | Overhead | Predictability |
|------|-------------------|----------------|--------------------|-----------|----|
| **ONESHOT** | Once at boot | ✓ High | ❌ None | Minimal | ✓ High |
| **Disabled** | Never | ✓ Complete | ❌ None | None | ✓ Very High |
| **1 hour** | Every hour | ⚠️ Medium | ⚠️ Slow | Low | ⚠️ Medium |
| **10 min (current)** | Every 10 min | ❌ Low | ✓ Fast | Medium | ❌ Low |
| **Default (10 sec)** | Every 10 sec | ❌ Very Low | ✓ Very Fast | High | ❌ Very Low |

---

## 🎯 Final Recommendation

**For this system: ONESHOT mode**

**Reasoning:**
1. Workload is relatively static (workstation/development)
2. Manual optimizations important (network queues, NVMe)
3. 32 cores provide excellent IRQ capacity
4. Predictable performance desired
5. No need for dynamic rebalancing

**Implementation:**
```bash
sudo ./configure_irqbalance_oneshot.sh  # Option [1]
```

**Monitoring:**
- Check service exits after boot: `systemctl status irqbalance`
- Verify IRQs stay static: `watch -n 60 './analyze_all_irq_starvation.sh'`
- Monitor performance: No degradation expected

---

**Status:** Analysis complete, recommendation provided  
**Next Step:** Apply ONESHOT configuration  
**Expected Outcome:** Static IRQ assignments, preserved optimizations

---

*Documented: October 18, 2025*  
*Configuration: ONESHOT mode recommended*  
*Rationale: Static workload, manual optimizations, predictable performance*
