# NVMe Performance Issue - Summary & Action Items

**Date:** October 18, 2025  
**Investigation:** IRQ distribution and boot drive performance  

## What We Found

### Initial Observation
- nvme1q4 (IRQ 108) handling 397,884 interrupts (92% of all I/O)
- Other queues handling ~33K interrupts each
- Suspected IRQ starvation/contention

### Root Cause Discovery
**The issue is NOT traditional IRQ starvation.** Modern NVMe drivers use:
- **Managed IRQs** - kernel controls affinity, userspace cannot override
- **Limited queue count** - Only 3-4 I/O queues on Intel 660P
- **Uneven queue selection** - Block layer favoring one queue

### Why Manual IRQ Pinning Failed
```
$ echo "24-27" > /proc/irq/108/smp_affinity_list
tee: Input/output error
```
Managed IRQs are read-only from userspace. The kernel already pins them optimally.

## What We Applied (Immediate Fixes)

✅ **Changed I/O scheduler to 'none'** - bypasses scheduler overhead  
✅ **Reduced read-ahead to 128KB** - better for random I/O  
⚠️  **Could not increase queue depth** - driver limited to 255  

## Remaining Options

### Option A: Increase NVMe Queue Count (BEST - Requires Reboot)

Add to `/etc/default/grub`:
```bash
GRUB_CMDLINE_LINUX="nvme_core.write_queues=16"
```

Then:
```bash
sudo update-grub
sudo reboot
```

**Benefits:**
- Creates 16 write queues instead of 1-3
- Automatic CPU affinity per queue
- Better load distribution
- Should reduce Q4 load from 92% to ~15-20%

### Option B: Monitor and Accept Current State

The system may already be optimized. Monitor with:
```bash
watch -n 1 'cat /proc/interrupts | grep nvme1q'
```

If performance is acceptable, no further changes needed.

### Option C: Hardware Considerations

Check if NVMe is in optimal PCIe slot:
```bash
# Check NUMA node (-1 means no NUMA affinity)
cat /sys/class/nvme/nvme1/device/numa_node

# Check PCIe link speed/width
sudo lspci -vv -s 0e:00.0 | grep -i "lnk\|speed\|width"
```

Intel 660P is PCIe 3.0 x4. Ensure it's in a full x4 slot, not x2.

## Performance Impact Assessment

### Before Any Changes
- nvme1q4: 397,884 interrupts
- Heavy load concentrated on single queue
- Potential I/O latency spikes

### After Immediate Changes
- Scheduler overhead removed (none vs mq-deadline)
- Read-ahead optimized for workload
- Should see slight improvement

### After Kernel Parameter Changes (if applied)
- Expected: 10-15x more queues
- Expected: 80-90% reduction in per-queue load
- Expected: Better I/O distribution

## Decision Point

**Do you experience actual performance problems?**

- **YES** → Apply Option A (kernel parameter + reboot)
- **NO** → Monitor current state, changes already applied may be sufficient
- **UNSURE** → Run benchmarks before/after

## Benchmark Commands

```bash
# Test random read IOPS
sudo fio --name=random-read --ioengine=libaio --rw=randread --bs=4k --size=1G --numjobs=4 --runtime=30 --time_based --direct=1 --filename=/dev/nvme1n1p1

# Test sequential write throughput
sudo fio --name=seq-write --ioengine=libaio --rw=write --bs=128k --size=1G --numjobs=1 --runtime=30 --time_based --direct=1 --filename=/tmp/test.dat

# Monitor I/O latency
sudo iostat -x nvme1n1 1 30
```

## Files Created

1. `fix_nvme_irq_starvation.sh` - Original attempt (deprecated)
2. `fix_nvme_irq_starvation_v2.sh` - irqbalance version (deprecated)
3. `NVME_IRQ_STARVATION_ANALYSIS.md` - Initial analysis (partially correct)
4. `NVME_REAL_ROOT_CAUSE.md` - Correct root cause analysis ⭐
5. `apply_nvme_immediate_fixes.sh` - Applied fixes ✅
6. `NVME_SUMMARY.md` - This file

## Recommendation

### Immediate: ✅ DONE
- Scheduler optimized
- Read-ahead tuned
- Monitor for improvement

### Next Step: YOUR DECISION
If you experience:
- VSCode lag
- File operation delays
- System stuttering
- High I/O wait times

Then → **Apply Option A** (kernel parameter for more queues + reboot)

Otherwise → Current optimization may be sufficient!

## Monitoring

Run this to watch interrupt distribution:
```bash
watch -n 2 'cat /proc/interrupts | grep nvme1q | head -8'
```

Look for:
- Q4 interrupt count still growing much faster than others → Need more queues
- All queues relatively balanced → Current config is working

---

**Status:** Immediate optimizations applied, monitoring recommended  
**Risk:** Low - changes are temporary and safe  
**Next Action:** Monitor for 30-60 minutes, then decide on kernel parameter change
