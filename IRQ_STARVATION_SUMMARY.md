# IRQ Starvation Scenarios Found on This System

**Analysis Date:** October 18, 2025  
**System:** AMD Threadripper 32-core

---

## Quick Summary

Found **4 IRQ starvation scenarios** during system-wide scan:

| # | Device | Severity | Concentration | Fixable? | Action Required |
|---|--------|----------|---------------|----------|-----------------|
| 1 | **NVIDIA GPUs** | 🔴 SEVERE | 88% | ⚠️ Limited | Monitor first |
| 2 | **10G Network (enp3s0f0)** | 🟡 WARNING | 57% | ✅ **YES** | **Fix Now** |
| 3 | **NVMe0 Boot Drive** | 🟡 WARNING | 61% | ❌ No | Accept (HW limit) |
| 4 | **USB Controllers** | 🔴 SEVERE | 99% | ⚠️ Limited | Accept (low impact) |

---

## Details

### 1. 🔴 NVIDIA GPUs - 88% Concentration

**Status:** SEVERE (but may not be problematic)

**Problem:**
- RTX 3080: 467K interrupts on CPU12 (88% of total GPU interrupts)
- RTX 3060: 53K interrupts on CPU23 (62% concentration)
- NVIDIA driver uses single MSI vector per GPU (no MSI-X)
- All GPU operations funnel through one IRQ

**Impact:**
- CPU12 becomes hotspot during GPU rendering/CUDA
- May cause stuttering in GPU-intensive apps
- Chrome/VSCode GPU acceleration affected

**Solution Options:**
1. **Monitor first** - Check if CPU12 is actually saturated:
   ```bash
   mpstat -P 12,23 1  # Watch during GPU workload
   ```

2. **Try IRQ affinity changes** (may not work if managed):
   ```bash
   sudo bash -c "echo 0,16 > /proc/irq/229/smp_affinity_list"
   ```

3. **Accept** - If CPU usage stays below 80%, not a problem

**Recommendation:** 🔍 **Monitor first, act only if CPU hotspots observed**

---

### 2. 🟡 10G Network (enp3s0f0) - 57% Concentration

**Status:** WARNING (easily fixable!)

**Problem:**
- Only 4 queues active (out of 32 available)
- TxRx-2 handling 57% of all network traffic
- Single queue bottleneck for 10G throughput

**Impact:**
- Network may not reach full 10G speed
- Latency spikes under high load
- Poor multi-core utilization

**Solution:** ✅ **FIXABLE - Increase queue count**
```bash
chmod +x fix_network_irq_distribution.sh
sudo ./fix_network_irq_distribution.sh
```

This will:
- Increase from 4 to 8 queues (or 16 for max performance)
- Distribute traffic across more CPUs
- Make changes persistent across reboots

**Expected Result:**
- Concentration drops from 57% to ~12-15%
- Better network throughput
- Improved multi-core utilization

**Recommendation:** ✅ **FIX NOW** (high ROI, easy fix)

---

### 3. 🟡 NVMe0 Boot Drive - 61% Concentration

**Status:** WARNING (hardware limited, already optimized)

**Problem:**
- nvme0q8 handling 65K interrupts (61% of total)
- Intel 660P limited to 16 MSI-X vectors (max 9 queues)
- Cannot increase queue count further
- QLC NAND slower than TLC

**Impact:**
- Boot drive I/O limited
- Random I/O particularly affected
- Some applications may see disk latency

**Already Applied:**
- ✅ I/O scheduler: `none`
- ✅ Read-ahead: 128KB (optimized for random I/O)
- ✅ Queue depth: 255
- ✅ Kernel parameters applied

**Solution:**
Cannot be improved further without hardware replacement.

**Recommendation:** ⚠️ **Accept hardware limitation**

Consider upgrading to:
- WD Black SN850X (TLC, 65 MSI-X vectors)
- Samsung 990 PRO (TLC, 32+ queues)

---

### 4. 🔴 USB Controllers - 99% Concentration

**Status:** SEVERE concentration, but LOW IMPACT

**Problem:**
- xHCI controller: 36K interrupts, 99% on single queue
- USB keyboard/mouse generating frequent polling interrupts
- All HID devices share same controller IRQ

**Impact:**
- Minimal (USB is low-bandwidth ~1.5 Mbps for HID)
- Only affects responsiveness under extreme CPU load
- Micro-stuttering possible if CPU saturated

**Solution Options:**
1. **USB IRQ coalescing** (may increase latency):
   ```bash
   echo 1 | sudo tee /sys/module/usbcore/parameters/irq_coalesce
   ```

2. **Redistribute devices** - Plug keyboard/mouse into different USB ports (different controllers)

3. **Accept** - Total IRQ count is low (~36K vs 682K for GPU)

**Recommendation:** ✅ **Accept** - Low impact, not worth optimizing

---

## Priority Actions

### 🔥 Do Now (High ROI, Easy)
1. **Fix network adapter queue distribution**
   ```bash
   sudo ./fix_network_irq_distribution.sh
   ```
   - **Impact:** Major improvement in 10G network performance
   - **Difficulty:** Easy (one script)
   - **Time:** 2 minutes

### 🔍 Monitor (May Need Action Later)
2. **Watch GPU IRQ CPU usage**
   ```bash
   mpstat -P 12,23 1  # During gaming/rendering
   ```
   - **If CPU >80%:** Try IRQ affinity changes
   - **If CPU <80%:** No action needed

### ⚠️ Accept (Hardware Limits)
3. **NVMe0 boot drive** - Hardware limited, already optimized
4. **USB controllers** - Normal behavior, low impact

---

## Monitoring Commands

### Real-time IRQ distribution
```bash
watch -n 1 'cat /proc/interrupts | grep -E "CPU0|nvidia|nvme|enp3s0f0|xhci"'
```

### System-wide IRQ analysis
```bash
./analyze_all_irq_starvation.sh
```

### Network queue status
```bash
network-queue-status  # After running fix script
```

### GPU IRQ CPU usage
```bash
mpstat -P 12,23,25 1
```

---

## Files Created

1. **analyze_all_irq_starvation.sh** - Comprehensive IRQ analysis across all devices
2. **fix_network_irq_distribution.sh** - Fix 10G network queue distribution
3. **SYSTEM_WIDE_IRQ_ANALYSIS.md** - Detailed analysis document
4. **IRQ_STARVATION_SUMMARY.md** - This file

---

## Expected Results After Fixes

| Device | Before | After Fix | Improvement |
|--------|--------|-----------|-------------|
| Network (enp3s0f0) | 57% on 4 queues | ~12% on 8 queues | **Major ✓** |
| NVIDIA GPUs | 88% | Monitor, may improve | TBD |
| NVMe0 | 61% | 61% (HW limit) | None |
| USB | 99% | 99% (acceptable) | N/A |

---

## Next Steps

1. **Immediate:** Run `sudo ./fix_network_irq_distribution.sh`
2. **Monitor:** Check GPU IRQ CPU usage during workloads
3. **Consider:** SSD upgrade if nvme0 performance is bottleneck
4. **Document:** Update MOTD if network fix significantly improves performance

---

*Analysis completed: October 18, 2025*  
*Primary recommendation: Fix network adapter queues immediately*
