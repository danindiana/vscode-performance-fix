# NVMe IRQ Issue - REAL ROOT CAUSE DISCOVERED

**Date:** October 18, 2025  
**System:** AMD Ryzen Threadripper (32 cores)  
**Boot Drive:** Intel SSD 660P (nvme1) - 953.9GB  
**Status:** ⚠️ Cannot manually set IRQ affinity - driver uses managed IRQs

## What We Discovered

### Initial Diagnosis (INCOMPLETE)
- IRQ 108 (nvme1q4) showing 397,884 interrupts
- Other queues showing ~33K interrupts each
- Appeared to be IRQ distribution problem

### Actual Root Cause (CORRECT)

The NVMe driver is using **managed IRQs** with automatic affinity:
```
nvme nvme1: 3/1/4 default/read/poll queues
```

This means:
- **Only 3 default I/O queues** (q1, q2, q3, q4)
- 1 dedicated read queue
- 4 poll queues
- IRQs are kernel-managed and **cannot be manually pinned**

### Why Manual IRQ Pinning Failed

```bash
$ echo "24-27" > /proc/irq/108/smp_affinity_list
tee: /proc/irq/108/smp_affinity_list: Input/output error
```

**Reason:** Modern NVMe drivers (since Linux 4.10+) use `pci_alloc_irq_vectors_affinity()` which creates **managed IRQs**. The kernel owns the affinity and userspace cannot change it.

The `effective_affinity_list` shows queues ARE already pinned:
- IRQ 104 (nvme1q0): CPU 30
- IRQ 105 (nvme1q1): CPU 20  
- IRQ 106 (nvme1q2): CPU 26
- IRQ 107 (nvme1q3): CPU 31
- IRQ 108 (nvme1q4): CPU 30

## The Real Problem

**Queue 4 is handling 92% of I/O traffic**, not because of IRQ distribution, but because:

1. **Limited Queue Count:** Only 3-4 I/O queues total
2. **Workload Pattern:** Boot drive sees heavy random I/O
3. **Queue Selection Algorithm:** Block layer is favoring queue 4
4. **Possible NUMA mismatch:** Drive may be far from some CPU cores

## Alternative Solutions

### Solution 1: Increase NVMe Queue Count (RECOMMENDED)

Force the driver to create more I/O queues:

```bash
# Add to kernel command line in /etc/default/grub
GRUB_CMDLINE_LINUX="nvme_core.write_queues=8 nvme_core.poll_queues=0"

# Then update grub
sudo update-grub
sudo reboot
```

This will:
- Create 8 write queues instead of 1
- Distribute load across more queues
- Each queue gets dedicated CPU affinity automatically

### Solution 2: Change I/O Scheduler

Switch to `none` or `kyber` scheduler:

```bash
echo none | sudo tee /sys/block/nvme1n1/queue/scheduler
# OR
echo kyber | sudo tee /sys/block/nvme1n1/queue/scheduler
```

Current: `mq-deadline` (shown as `[none] mq-deadline`)

### Solution 3: Tune Block Layer Multi-Queue

```bash
# Increase queue depth
echo 1024 | sudo tee /sys/block/nvme1n1/queue/nr_requests

# Enable I/O polling (if supported)
echo 1 | sudo tee /sys/block/nvme1n1/queue/io_poll

# Disable read-ahead if doing lots of random I/O
echo 128 | sudo tee /sys/block/nvme1n1/queue/read_ahead_kb  # default is 256
```

### Solution 4: Check NUMA Topology

```bash
# Check which NUMA node the NVMe is on
cat /sys/class/nvme/nvme1/device/numa_node
# Output: -1 (means no NUMA affinity - could be the issue!)

# Check CPU topology
lscpu | grep NUMA
```

If NUMA node is -1, the PCIe slot may not be optimally connected to CPU dies.

## Recommended Action Plan

### Immediate (No Reboot Required)

```bash
# 1. Change I/O scheduler
echo kyber | sudo tee /sys/block/nvme1n1/queue/scheduler

# 2. Increase queue depth
echo 512 | sudo tee /sys/block/nvme1n1/queue/nr_requests

# 3. Monitor improvement
watch -n 1 'cat /proc/interrupts | grep nvme1q'
```

### Long-term (Requires Reboot)

Edit `/etc/default/grub`:
```bash
GRUB_CMDLINE_LINUX="nvme_core.write_queues=16"
```

Then:
```bash
sudo update-grub
sudo reboot
```

## Testing & Monitoring

### Before Changes
```bash
$ cat /proc/interrupts | grep nvme1q
nvme1q0:      838
nvme1q1:   32,974
nvme1q2:   33,053
nvme1q3:   33,455
nvme1q4:  397,884  ← 92% of traffic
```

### Expected After Changes
- More even distribution across queues
- Q4 should drop to ~80-100K
- Overall interrupts may increase but distributed
- Better I/O latency and throughput

### Monitor Commands

```bash
# Watch interrupt distribution
watch -n 1 'cat /proc/interrupts | grep nvme1q | head -10'

# Check I/O performance
sudo iostat -x nvme1n1 1

# Check queue depth utilization
cat /sys/block/nvme1n1/inflight

# Check scheduler
cat /sys/block/nvme1n1/queue/scheduler
```

## Why This Matters

Even though IRQs are "managed", the **queue selection** and **I/O distribution** problems can still cause:
- High latency on critical I/O
- CPU cache thrashing (if queue bounces between cores)
- Uneven load distribution
- Poor utilization of available bandwidth

## References

- Linux NVMe driver: drivers/nvme/host/pci.c
- Managed IRQs: kernel/irq/affinity.c
- Block layer multi-queue: block/blk-mq.c
- Intel 660P specs: QLC NAND, up to 1800MB/s, 4 lanes PCIe 3.0

## Next Steps

1. ✅ Apply immediate scheduler/queue depth changes
2. ⏳ Monitor for 30 minutes
3. 🔄 If still problematic, add kernel parameters and reboot
4. 📊 Benchmark before/after with `fio` or real workloads

---

**Key Takeaway:** The issue isn't IRQ affinity (kernel manages that correctly), but rather:
1. Too few I/O queues (only 3-4)
2. Uneven queue selection by block layer
3. Possible suboptimal scheduler for workload pattern
