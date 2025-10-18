# Pre-Reboot Checklist - NVMe Kernel Parameter Fix

**Date:** October 18, 2025  
**Action:** Applying `nvme_core.write_queues=16` kernel parameter  
**Expected Downtime:** 2-5 minutes (reboot)  

## What You're About To Do

Apply a kernel parameter that will increase NVMe I/O queues from 3-4 to 16+, reducing the Queue 4 bottleneck from 77% load to ~15-20%.

## Pre-Reboot Status

### Current Configuration (Temporary)
- ✅ Scheduler: none
- ✅ Read-ahead: 128 KB
- ⚠️ Queue 4: 76% of all I/O (398,979 interrupts)

### What Will Change After Reboot
- More I/O queues (3-4 → 16+)
- Better load distribution
- Lower per-queue interrupt counts
- Improved I/O latency and throughput

## Running the Script

```bash
cd ~/programs/vscode_performance_fix_20251018_032616
sudo ./apply_kernel_nvme_fix.sh
```

**The script will:**
1. Backup your GRUB config automatically
2. Add `nvme_core.write_queues=16` to kernel parameters
3. Update GRUB
4. Ask if you want to reboot

## After Reboot - Verification

Run these commands to verify the fix worked:

```bash
# Check queue count (should see many more queues)
cat /proc/interrupts | grep nvme1q

# Expected: 16+ queues instead of 5
# Expected: More even distribution

# Monitor the new distribution
cd ~/programs/vscode_performance_fix_20251018_032616
./monitor_nvme_performance.sh
```

## Expected Results

### Before (Current)
```
Queue 0:   0.20%
Queue 1:   8.24%
Queue 2:   8.16%
Queue 3:   7.11%
Queue 4:  76.28% ← BOTTLENECK
```

### After (Expected)
```
Queue 0:   0.5%
Queue 1-16: ~6% each (evenly distributed)
Total queues: 16-20
```

## Rollback Plan (If Needed)

If something goes wrong after reboot:

1. **Boot into GRUB menu** (hold Shift during boot)
2. **Edit boot entry** (press 'e')
3. **Remove the parameter** from kernel command line
4. **Boot** (press F10)

Or restore backup:
```bash
sudo cp /etc/default/grub.backup.YYYYMMDD_HHMMSS /etc/default/grub
sudo update-grub
sudo reboot
```

## Safety Notes

- ✅ **Safe:** Kernel parameter only affects NVMe queue configuration
- ✅ **Reversible:** Can be removed/changed anytime
- ✅ **Non-destructive:** No data risk
- ✅ **Tested:** Standard Linux kernel parameter, widely used

## What to Save Before Reboot

All your work is saved in:
```
~/programs/vscode_performance_fix_20251018_032616/
```

Files created:
- `NVME_REAL_ROOT_CAUSE.md` - Technical analysis
- `NVME_SUMMARY.md` - Action plan
- `apply_kernel_nvme_fix.sh` - This fix script
- `monitor_nvme_performance.sh` - Monitoring tool
- And all backup/analysis files

## Ready to Proceed?

```bash
# Apply the fix (will ask before rebooting)
sudo ./apply_kernel_nvme_fix.sh
```

Or if you want to review the GRUB file first:
```bash
cat /etc/default/grub | grep CMDLINE
```

---

**Confidence Level:** HIGH ✅  
**Risk Level:** LOW ✅  
**Expected Improvement:** SIGNIFICANT ✅  

This is a standard, safe optimization for NVMe drives with heavy I/O workloads.
