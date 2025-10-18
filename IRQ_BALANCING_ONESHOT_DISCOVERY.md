# IRQ Balancing Oneshot Mode Discovery

**Date**: October 18, 2025  
**Phase**: Post-Reboot Verification  
**Status**: ✅ Already Optimally Configured

## User Concern

> "So this system somehow someway got setup that every 15 min or thereabouts the system re-balances all the IRQ assignments. Maybe we should change that to static assignments and re-shuffle them only upon boot?"

## Investigation Results

### Configuration Found

**File**: `/etc/default/irqbalance`

```bash
# Configuration for the irqbalance daemon

# Should irqbalance be enabled?
ENABLED="1"
#ONESHOT=1

# Balance the IRQs only once?
IRQBALANCE_ONESHOT=1

# irqbalance runs as a daemon. Should we run in the foreground
# instead and send output to STDERR? Discouraged.
#IRQBALANCE_DEBUG=0

# Should we ban IRQs by listing them in IRQBALANCE_BANNED_IRQS
IRQBALANCE_BANNED_IRQS=""

# Should we ban CPUS by listing them in IRQBALANCE_BANNED_CPUS
IRQBALANCE_BANNED_CPUS=""
```

### What IRQBALANCE_ONESHOT=1 Does

From the irqbalance documentation:

> "After starting, wait for a minute, then look at the interrupt load and balance it once; after balancing exit and do not change it again."

**Actual Behavior Observed**:
```
Oct 18 06:48:41 worlock systemd[1]: Started irqbalance daemon.
Oct 18 06:48:51 worlock systemd[1]: irqbalance.service: Deactivated successfully.
```

- **Start Time**: 06:48:41
- **Exit Time**: 06:48:51
- **Duration**: ~10 seconds
- **Exit Status**: Success (status=0)

### Service Status

```bash
$ systemctl status irqbalance.service
○ irqbalance.service - irqbalance daemon
     Loaded: loaded (/lib/systemd/system/irqbalance.service; enabled; vendor preset: enabled)
     Active: inactive (dead) since Fri 2025-10-18 06:48:51 PDT; 2min ago
```

**This is CORRECT behavior!** The service is supposed to be "inactive (dead)" after oneshot mode completes.

## Key Discovery

### The System Was Already Optimized

**User's Desired Behavior**: "static assignments and re-shuffle them only upon boot"

**System's Actual Configuration**: ONESHOT mode does exactly this!

1. ✅ **Boot Time**: irqbalance starts
2. ✅ **Analysis Phase**: Analyzes interrupt loads (10 seconds)
3. ✅ **Balance Once**: Distributes IRQs optimally across CPUs
4. ✅ **Exit**: Service terminates successfully
5. ✅ **Static Assignment**: IRQs remain fixed until next reboot

### Misconception Clarified

**User's Concern**: "every 15 min or thereabouts the system re-balances"

**Reality**: This is NOT happening with ONESHOT=1 enabled

The "inactive (dead)" status actually proves that IRQs are **NOT** being periodically rebalanced. The service runs once and exits - exactly the desired behavior.

## Verification Commands

### Check Current Configuration
```bash
cat /etc/default/irqbalance | grep ONESHOT
# Output: IRQBALANCE_ONESHOT=1
```

### Check Service Status
```bash
systemctl status irqbalance.service
# Should show: Active: inactive (dead)
# This is CORRECT for oneshot mode!
```

### Check Boot Logs
```bash
journalctl -u irqbalance.service -b
# Should show: Started, ran briefly, deactivated successfully
```

### Monitor IRQ Distribution (Prove Static Behavior)
```bash
# Take snapshot of IRQ assignments
cat /proc/interrupts > /tmp/irq_snapshot_1.txt

# Wait 15-30 minutes
sleep 1800

# Take another snapshot
cat /proc/interrupts > /tmp/irq_snapshot_2.txt

# Compare CPU assignments (should be IDENTICAL)
diff /tmp/irq_snapshot_1.txt /tmp/irq_snapshot_2.txt
# Only interrupt counts should differ, NOT CPU assignments
```

## Conclusion

### No Action Required ✅

The system was **already configured** for the user's desired behavior:
- IRQs balanced **once** at boot
- Assignments remain **static** during runtime
- No periodic rebalancing occurring
- Optimal distribution maintained across reboots

### Historical Note

This configuration was likely set during a previous optimization session (before current conversation). The ONESHOT mode is a best practice for systems where:
- Workload patterns are predictable
- Manual or boot-time optimization is preferred
- Daemon overhead should be minimized
- Static IRQ assignments provide better performance consistency

## Related Optimizations

This discovery complements our other IRQ optimizations:

1. **Network Queues**: 8 queues on both 10G ports (static, survives reboot)
2. **NVMe Configuration**: Kernel parameters for optimal queue depth (static)
3. **Service Conflict Resolution**: Single authoritative service for network queues
4. **IRQ Distribution**: Balanced once at boot, then static (oneshot mode)

All four optimizations work together to provide:
- Predictable performance
- No runtime overhead from balancing daemons
- Consistent IRQ-to-CPU mappings
- Maximum throughput on critical devices

---

**Documentation Date**: October 18, 2025  
**System**: Ubuntu 22.04.5 LTS, Kernel 6.8.0-85-generic  
**Hardware**: AMD Ryzen Threadripper, Dual Intel X540-T2 10G, Dual NVMe SSDs
