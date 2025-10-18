# Dual NVMe Drive Analysis - IRQ & Queue Distribution

**Date:** October 18, 2025  
**System:** AMD Ryzen Threadripper (32 cores)  
**Status:** Comparing both NVMe drives for IRQ balance issues

---

## Drive Identification (CORRECTED)

**IMPORTANT:** Kernel device names are **opposite** of physical expectations!

### nvme0 = Intel 660P (BOOT DRIVE) 
- **Kernel Device:** `/dev/nvme0n1` 
- **Model:** Intel SSDPEKNW010T8 (660P, 1TB)
- **Size:** 953.9GB
- **Mounted:** `/` (root), `/boot/efi`
- **Role:** PRIMARY BOOT DRIVE
- **PCI:** 0000:0e:00.0

### nvme1 = WD Black SN750 (SECONDARY)
- **Kernel Device:** `/dev/nvme1n1`
- **Model:** WDS500G2X0C-00L350 (WD Black SN750, 500GB)
- **Size:** 465.8GB
- **Mounted:** Partition exists but not currently mounted
- **Role:** SECONDARY/DATA DRIVE
- **PCI:** 0000:05:00.0

---

## Queue Configuration Comparison

| Metric | nvme0 (Intel 660P - BOOT) | nvme1 (WD Black - SECONDARY) |
|--------|---------------------------|------------------------------|
| **Driver Init** | `7/1/0 default/read/poll queues` ❌ | `16/32/0 default/read/poll queues` ✅ |
| **Total Queues** | 9 ❌ | 49 ✅ |
| **Write Queues** | 7 ❌ | 16 ✅ |
| **Read Queues** | 1 ❌ | 32 ✅ |
| **Poll Queues** | 0 | 0 |
| **Kernel Parameter** | Uses global `nvme.write_queues=16` | Uses global `nvme.write_queues=16` |

**Problem:** Even with `nvme.write_queues=16` kernel parameter, **nvme0 only initialized with 7 write queues**!

---

## IRQ Distribution Analysis

### nvme0 (Intel 660P - Boot Drive) ❌ IMBALANCED

```
Total queues: 9
Total interrupts: 74,877
Max on nvme0q8: 54,883 (73.3%) ← CONCENTRATION!
Average per queue: 8,320
```

**Queue Distribution:**
```
nvme0q8: 54,896 interrupts (73.3%) ← 🚨 PROBLEM!
nvme0q4:  3,827 interrupts (5.1%)
nvme0q3:  3,249 interrupts (4.3%)
nvme0q1:  3,087 interrupts (4.1%)
nvme0q6:  2,933 interrupts (3.9%)
Others:   ~6,885 interrupts (9.2%)
```

**CPU Affinity:**
- nvme0q0: CPU 23
- nvme0q1: CPU 17
- nvme0q2: CPU 20
- nvme0q3: CPU 23
- nvme0q4: CPU 26
- nvme0q5: CPU 29
- nvme0q6: CPU 31
- nvme0q7: CPU 27
- nvme0q8: CPU 30 ← Handling 73% of traffic!

**Status:** ❌ **SEVERE IRQ CONCENTRATION** on queue 8 (similar to nvme1 before the fix!)

### nvme1 (WD Black - Secondary) ✅ BALANCED

```
Total queues: 49
Total interrupts: 295 (low - minimal usage)
Max on nvme1q0: 117 (39.7%) ← Well balanced!
```

**Status:** ✅ **EXCELLENT** - Well-balanced interrupt distribution

---

## I/O Configuration

### nvme0 (Intel 660P - Boot Drive)
```
Scheduler: [none] mq-deadline
Queue depth: 255 ← Lower than nvme1
Read-ahead: 256KB ← Higher than nvme1
```

### nvme1 (WD Black - Secondary)  
```
Scheduler: [none] mq-deadline
Queue depth: 1023 ← Higher (optimized)
Read-ahead: 128KB ← Lower (optimized)
```

---

## Root Cause Analysis

### Why nvme0 Has Fewer Queues

The `nvme.write_queues=16` kernel parameter is **global** but:

1. **Hardware Limitation:** Intel 660P may have firmware/hardware queue limits
2. **Driver Detection:** NVMe driver may be detecting different capabilities
3. **PCI Slot Differences:** Different PCIe slots may have different MSI-X vector limits
4. **NUMA Topology:** nvme0 on PCIe slot 0e:00.0 vs nvme1 on 05:00.0

Let me check:
```bash
# Check MSI-X vector count for each drive
lspci -vv -s 0e:00.0 | grep MSI-X  # nvme0 (Intel)
lspci -vv -s 05:00.0 | grep MSI-X  # nvme1 (WD Black)
```

### Why nvme0q8 Gets 73% of Traffic

Similar to nvme1q4 before the fix:
1. **Limited Queue Count:** Only 7-8 active queues
2. **Boot Drive Workload:** Heavy random I/O from OS, applications, files
3. **Queue Selection:** Block layer favoring specific queue
4. **CPU Affinity:** Queue 8 on CPU 30 (may be getting most I/O requests)

---

## Performance Impact

### Current State (nvme0 - Boot Drive)
- ❌ **73.3% concentration** on single queue (nvme0q8)
- ❌ Only **7 write queues** (vs 16 on nvme1)
- ❌ Only **1 read queue** (vs 32 on nvme1)
- ❌ Lower queue depth (255 vs 1023)
- ❌ This is your **BOOT DRIVE** getting bottlenecked!

### Symptoms You May Experience
- Slow boot times
- Application launch delays
- File I/O stuttering
- High I/O wait times
- CPU 30 potentially saturated with nvme0q8 processing

---

## Recommended Fixes

### Fix 1: Per-Device Kernel Parameters (BEST SOLUTION)

The global `nvme.write_queues=16` is being applied, but nvme0 is only using 7 queues. We need to investigate why.

**Check hardware capabilities:**
```bash
# Check max queue count supported by each drive
cat /sys/class/nvme/nvme0/device/msi_irqs | wc -l
cat /sys/class/nvme/nvme1/device/msi_irqs | wc -l

# Check if there's a per-device queue limit
sudo nvme get-feature -f 0x07 -H /dev/nvme0  # Number of Queues feature
sudo nvme get-feature -f 0x07 -H /dev/nvme1
```

### Fix 2: Increase nvme0 Queue Depth (IMMEDIATE)

Since we can't increase queue count easily, increase queue depth:
```bash
# Increase queue depth to match nvme1
echo 1023 | sudo tee /sys/block/nvme0n1/queue/nr_requests

# Make permanent (add to /etc/rc.local or systemd service)
```

### Fix 3: Optimize Scheduler Settings (IMMEDIATE)

```bash
# Already on 'none' scheduler (good)
# But reduce read-ahead since boot drive does random I/O
echo 128 | sudo tee /sys/block/nvme0n1/queue/read_ahead_kb
```

### Fix 4: Check PCIe Slot MSI-X Capability

```bash
# Check if the PCIe slot limits MSI-X vectors
sudo lspci -vv -s 0e:00.0 | grep -A 10 "MSI-X"
```

The Intel 660P may be in a PCIe slot with fewer MSI-X vectors available, limiting queue count.

---

## Action Plan

### Immediate Actions (No Reboot)

1. **Increase queue depth:**
   ```bash
   echo 1023 | sudo tee /sys/block/nvme0n1/queue/nr_requests
   ```

2. **Reduce read-ahead:**
   ```bash
   echo 128 | sudo tee /sys/block/nvme0n1/queue/read_ahead_kb
   ```

3. **Monitor improvement:**
   ```bash
   watch -n 1 'cat /proc/interrupts | grep nvme0q | awk "{sum=0; for(i=2;i<=NF-3;i++) sum+=\$i; print sum, \$NF}" | sort -rn | head -5'
   ```

### Investigation Required

4. **Check MSI-X vector limits:**
   ```bash
   sudo lspci -vv -s 0e:00.0 | grep "MSI-X" -A 5
   ```

5. **Check NVMe feature support:**
   ```bash
   sudo nvme id-ctrl /dev/nvme0 | grep -E "^oacs|^ctratt"
   ```

6. **Check if queue count can be increased:**
   ```bash
   # Try forcing more queues (requires testing)
   # May need to modify kernel module parameters specifically for nvme0
   ```

### Long-term Solutions

7. **Consider drive swap:** If the WD Black (nvme1) can support 49 queues, consider:
   - Moving it to the boot slot
   - Using the higher-performance drive as boot drive
   - Intel 660P is QLC (slower) anyway, WD Black is TLC (faster)

8. **Check BIOS/UEFI settings:**
   - PCIe slot configuration
   - MSI-X allocation per slot
   - IOMMU settings

---

## Hardware Comparison

| Spec | Intel 660P (nvme0) | WD Black SN750 (nvme1) |
|------|-------------------|------------------------|
| **NAND Type** | QLC (4 bits/cell) | TLC (3 bits/cell) |
| **Performance** | Lower (QLC) | Higher (TLC) |
| **Endurance** | Lower | Higher |
| **Current Role** | Boot drive | Secondary |
| **Queue Support** | 9 queues (limited) | 49 queues ✅ |
| **Bottleneck** | Yes (73% on one queue) | No (balanced) |

**Recommendation:** Consider **swapping the drives**:
- Use WD Black SN750 (nvme1) as boot drive (faster, more queues)
- Use Intel 660P (nvme0) as secondary/data drive (acceptable for storage)

---

## Monitoring Commands

```bash
# Compare interrupt distribution between drives
watch -n 2 'echo "=== nvme0 (Boot) ==="; cat /proc/interrupts | grep nvme0q | awk "{sum=0; for(i=2;i<=NF-3;i++) sum+=\$i; if(sum>0) print sum, \$NF}" | sort -rn | head -5; echo ""; echo "=== nvme1 (Secondary) ==="; cat /proc/interrupts | grep nvme1q | awk "{sum=0; for(i=2;i<=NF-3;i++) sum+=\$i; if(sum>0) print sum, \$NF}" | sort -rn | head -5'

# Monitor I/O performance
sudo iostat -x nvme0n1 nvme1n1 2

# Check queue utilization
cat /sys/block/nvme0n1/inflight
cat /sys/block/nvme1n1/inflight
```

---

## Summary

### nvme0 (Intel 660P - BOOT DRIVE) ❌ NEEDS ATTENTION
- **IRQ Concentration:** 73.3% on nvme0q8 (SAME ISSUE as nvme1 had!)
- **Queue Count:** Only 9 queues (7 write, 1 read) despite kernel parameter
- **Performance:** Likely bottlenecked by single queue saturation
- **Impact:** This is your BOOT DRIVE - affects all system responsiveness!

### nvme1 (WD Black - SECONDARY) ✅ OPTIMIZED
- **IRQ Distribution:** Well balanced (39.7% max)
- **Queue Count:** 49 queues (16 write, 32 read)
- **Performance:** Excellent multi-queue utilization
- **Impact:** Ready for high-performance workloads

### Priority Action
**FIX nvme0 FIRST** - it's your boot drive and currently has the same severe IRQ concentration issue (73%) that nvme1 had before (92%)!

---

**Next Step:** Apply immediate fixes to nvme0 and investigate why it only initialized with 7 write queues despite the kernel parameter.
