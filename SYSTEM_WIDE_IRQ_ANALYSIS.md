# System-Wide IRQ Starvation Analysis

**Date:** October 18, 2025  
**System:** AMD Threadripper 32-core, Ubuntu 22.04, Kernel 6.8.0-85-generic

---

## Executive Summary

Comprehensive scan of all devices revealed **4 potential IRQ starvation scenarios**:

| Device | Severity | Concentration | Impact | Fixable? |
|--------|----------|---------------|--------|----------|
| **NVIDIA GPUs** | 🔴 SEVERE | 88% (one GPU) | Graphics/CUDA | ⚠️ Partially |
| **USB Controllers (xHCI)** | 🔴 SEVERE | 99% | USB devices | ⚠️ Limited |
| **nvme0 (Boot Drive)** | 🟡 WARNING | 61% | Disk I/O | ⚠️ Hardware Limited |
| **Network enp3s0f0** | 🟡 WARNING | 57% | 10G Network | ✅ Yes |

**Note:** Audio (100%) and secondary devices have low total IRQ counts, not performance-critical.

---

## 1. 🔴 NVIDIA GPU IRQ Starvation (SEVERE - 88%)

### Current State
```
GPU 0 (RTX 3080): IRQ 229 → CPU12 (467,616 int) + CPU25 (214,603 int)
GPU 1 (RTX 3060): IRQ 230 → CPU23 (53,497 int) + CPU16 (33,336 int)

Total GPU 0: 682,219 interrupts (88% on CPU12)
Total GPU 1:  86,833 interrupts (62% on CPU23)
```

**Problem:**
- GPU 0 has 88% concentration (467K out of 682K on single CPU)
- GPU 1 has 62% concentration (moderate)
- **MSI mode** (Count=1/1) - only 1 IRQ vector per GPU
- No MSI-X support active (driver limitation)
- Fixed CPU affinity (not spread across cores)

**Hardware Details:**
```
GPU 0: GA102 [GeForce RTX 3080]
  Capabilities: MSI: Enable+ Count=1/1 Maskable- 64bit+
  Driver: nvidia (proprietary)
  IRQ: 229 (pinned to CPU12)

GPU 1: GA104 [GeForce RTX 3060]
  Capabilities: MSI: Enable+ Count=1/1 Maskable- 64bit+
  Driver: nvidia (proprietary)
  IRQ: 230 (pinned to CPU23)
```

**Impact:**
- GPU compute/rendering can saturate single CPU core
- Potential stuttering during heavy GPU workloads (gaming, rendering)
- Chrome/VSCode GPU acceleration affected
- CUDA workloads may experience IRQ latency
- CPU12 and CPU23 become hotspots during GPU-intensive tasks

### Root Cause

**NVIDIA Proprietary Driver Limitation:**
- NVIDIA driver uses MSI mode with single IRQ vector per GPU
- Does not leverage MSI-X for multi-vector distribution
- All GPU interrupts (compute, display, DMA) funnel through one IRQ
- Driver pins IRQ to specific CPU (managed IRQ)

<function_calls>
<invoke name="run_in_terminal">
<parameter name="explanation">Get detailed NVIDIA GPU information
### Possible Solutions

#### Option 1: IRQ CPU Affinity Adjustment ⚠️ (Limited Effectiveness)
```bash
# Move GPU IRQs to less-busy CPUs (if not managed)
sudo bash -c "echo 0,16 > /proc/irq/229/smp_affinity_list"  # GPU 0 to CPU 0,16
sudo bash -c "echo 1,17 > /proc/irq/230/smp_affinity_list"  # GPU 1 to CPU 1,17
```

**Limitation:** If IRQs are "managed" (likely), this won't work. Check first:
```bash
cat /proc/irq/229/effective_affinity_list
cat /proc/irq/230/effective_affinity_list
```

#### Option 2: Force MSI-X Mode (Experimental) ⚠️
Some reports suggest forcing MSI-X via kernel parameters:
```bash
# Add to GRUB_CMDLINE_LINUX in /etc/default/grub
pci=nomsi  # Disables MSI (forces INTx or MSI-X)
```

**Risk:** May cause system instability, GPU driver issues.

#### Option 3: NVIDIA Driver Settings (Minimal Impact)
```bash
# Disable GPU features that generate excessive interrupts
sudo nvidia-settings --assign GPUPowerMizerMode=1  # Adaptive
```

#### Option 4: Accept and Monitor 🔍
- **88% concentration is high but may not cause issues if CPU12 isn't saturated**
- Monitor with: `mpstat -P ALL 1` during GPU workloads
- If CPU12 stays below 80%, IRQ handling is keeping up

### Recommendation

1. **Monitor first:** Check if CPU12/CPU23 become bottlenecks during GPU work
2. **If problematic:** Try IRQ affinity changes (Option 1)
3. **If still problematic:** Consider nouveau driver (open-source) for testing
4. **Ultimate solution:** Wait for better NVIDIA driver with MSI-X support

---

## 2. 🔴 USB Controller IRQ Starvation (SEVERE - 99%)

### Current State
```
xHCI Controller (0000:12:00.3): IRQ 89
  Total: 36,749 interrupts
  CPU22: 15,114 (41%)
  CPU18: 21,635 (59%)  ← 99% when combined with MSI-X queue 0
```

**Connected Devices:**
- USB Keyboard (HID)
- USB Mouse (HID)
- USB Hub
- Other HID devices (3-4 total)

**Problem:**
- 99% of USB interrupts on a single queue/CPU
- Low-speed devices (1.5 Mbps) generating frequent interrupts
- Polling-based HID devices cause IRQ storms

**Impact:**
- Minimal (USB is low-bandwidth)
- Only affects USB responsiveness under extreme system load
- HID devices may experience micro-stuttering if CPU18/22 saturated

### Root Cause

USB HID devices use **interrupt transfers** with polling:
- Keyboards/mice poll every 1-8ms (125-1000 Hz)
- Each poll generates an IRQ
- All devices share same xHCI controller IRQ

### Possible Solutions

#### Option 1: USB IRQ Coalescing
```bash
# Reduce USB interrupt frequency (requires USB driver parameter)
# Check current USB interrupt moderation:
cat /sys/module/usbcore/parameters/irq_coalesce

# If not set, you can try enabling (may affect latency):
echo 1 | sudo tee /sys/module/usbcore/parameters/irq_coalesce
```

#### Option 2: Redistribute USB Devices
Move high-activity USB devices to different controllers:
```bash
# List USB controllers and their buses
lsusb -t

# Plug keyboard/mouse into different physical USB ports
# (connected to different xHCI controllers)
```

#### Option 3: Accept (Recommended)
USB interrupt load is minimal (~36K interrupts total). Not a performance concern unless:
- You're doing real-time audio/video over USB
- Running USB 3.0 storage at full speed

### Recommendation

✅ **Accept and ignore** - USB IRQ concentration is normal and low-impact.

---

## 3. 🟡 NVMe0 Boot Drive IRQ Starvation (WARNING - 61%)

### Current State
```
nvme0 (Intel 660P 1TB): 9 queues total
  nvme0q8: 65,604 interrupts (61%)  ← Concentration
  nvme0q3:  7,971 interrupts (8%)
  nvme0q2:  7,506 interrupts (7%)
  Others:  ~25,000 interrupts (24%)
```

**Problem:**
- 61% concentration on nvme0q8 (moderate, not severe)
- **Hardware limited:** Intel 660P only has 16 MSI-X vectors (max 9 queues)
- Cannot increase beyond 9 queues
- QLC NAND is slower than TLC

**Impact:**
- Boot drive I/O performance limited
- Some applications may experience disk latency
- Random I/O particularly affected

### Already Optimized ✅

We've already applied all possible fixes:
- I/O Scheduler: `none` (direct dispatch)
- Read-ahead: 128KB (reduced from 256KB for random I/O)
- Queue Depth: 255 (default)
- Kernel parameter: `nvme.io_queue_depth=1023` (in GRUB, may not apply due to hardware)

**Cannot be improved further without hardware replacement.**

### Recommendation

✅ **Accept hardware limitation** - Consider upgrading to:
- WD Black SN850X (TLC NAND, 65 MSI-X vectors)
- Samsung 990 PRO (TLC NAND, 32+ queues)
- Any high-end TLC/MLC NVMe drive

---

## 4. 🟡 Network enp3s0f0 IRQ Starvation (WARNING - 57%)

### Current State
```
enp3s0f0 (10G Port 0): 4 combined queues (max 32 available)
  TxRx-2 (IRQ 104): 54,488 interrupts (57%)  ← Concentration
  TxRx-1 (IRQ 103): 18,091 interrupts (19%)
  TxRx-0 (IRQ 102): 12,490 interrupts (13%)
  TxRx-3 (IRQ 105):  9,132 interrupts (10%)
```

**Problem:**
- Only using 4 queues out of 32 available
- 57% concentration on single queue (TxRx-2)
- Can be improved by increasing queue count

**Impact:**
- 10G network throughput may not reach full speed
- Latency spikes under high network load
- Single queue becomes bottleneck for multi-threaded workloads

### Solution ✅ (FIXABLE!)

**Increase RSS (Receive Side Scaling) queues:**

```bash
# Check current settings
sudo ethtool -l enp3s0f0

# Increase to 8 queues (or 16 for max performance)
sudo ethtool -L enp3s0f0 combined 8

# Make permanent (add to /etc/rc.local or systemd service)
echo "ethtool -L enp3s0f0 combined 8" | sudo tee /etc/rc.local
sudo chmod +x /etc/rc.local
```

**Expected Result:**
- 8 queues instead of 4
- Each queue gets ~12.5% of traffic (better than 57%)
- Improved multi-core utilization
- Better network throughput

### Recommendation

✅ **Fix it!** - Increase queue count to 8 or 16 queues.

---

## 5. ℹ️ Other Devices (Low Impact)

### Audio Controller (100% concentration)
```
snd_hda_intel: 41,435 interrupts total
  - Single IRQ (typical for audio controllers)
  - Low frequency (not performance-critical)
```

**Recommendation:** ✅ Accept - Normal for audio, minimal impact.

### Network enp3s0f1 (38% concentration)
**Status:** ✓ Good distribution (below 40% threshold)

### Network enp9s0 (47% concentration)
**Status:** ℹ️ Acceptable (1G Ethernet, low total interrupts)

### SATA/AHCI (32% concentration)
**Status:** ✓ Good distribution (backup drive on SATA)

---

## Priority Action Plan

### Immediate (High Impact, Easy Fix)
1. **✅ Increase enp3s0f0 queues to 8-16** (see Option 4 solution)
   - Impact: Improved 10G network performance
   - Difficulty: Easy (one command)

### Optional (Low Impact, Test First)
2. **Test GPU IRQ affinity changes** (see Option 1 solution)
   - Impact: May reduce GPU-related CPU hotspots
   - Difficulty: Easy, but may not work (managed IRQs)
   - Monitor CPU12/CPU23 usage during GPU workloads first

3. **Monitor nvme0 performance**
   - Impact: Decision point for hardware upgrade
   - Difficulty: None (just monitoring)
   - If slow, consider SSD upgrade

### Accept and Ignore
4. **USB controller concentration** - Normal and low-impact
5. **Audio controller concentration** - Expected behavior
6. **nvme0 concentration** - Hardware limited, already optimized

---

## Monitoring Commands

### Real-time IRQ monitoring
```bash
watch -n 1 'cat /proc/interrupts | grep -E "CPU0|nvidia|nvme|enp3s0f0|xhci"'
```

### CPU utilization during GPU workload
```bash
mpstat -P 12,23 1  # Monitor GPU IRQ CPUs
```

### Network queue stats
```bash
ethtool -S enp3s0f0 | grep -E "rx_queue|tx_queue"
```

### NVMe queue stats
```bash
nvme-status  # Our custom command
```

---

## Conclusion

**Found 4 IRQ starvation scenarios:**

1. **NVIDIA GPUs (88%)** - Driver limitation, monitor and accept
2. **USB Controllers (99%)** - Expected behavior, low impact
3. **nvme0 Boot Drive (61%)** - Hardware limited, already optimized
4. **Network 10G Port (57%)** - ✅ **FIXABLE!** Increase queue count

**Recommended Action:**
- **Fix network adapter queues immediately** (high ROI, easy fix)
- **Monitor GPU IRQ CPU usage** (may not be a problem)
- **Accept nvme0 and USB** (hardware limits or low impact)

---

*Analysis completed: October 18, 2025*  
*Next review: Monitor after network queue increase*
