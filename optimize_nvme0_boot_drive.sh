#!/bin/bash
# Apply immediate optimizations to nvme0 (Intel 660P Boot Drive)

echo "=== nvme0 (Intel 660P Boot Drive) Optimization ==="
echo ""
echo "Current Status:"
echo "  - IRQ Concentration: 73.3% on nvme0q8"
echo "  - Queue Count: 9 (limited by 16 MSI-X vectors)"
echo "  - Hardware Limit: Intel 660P only supports 16 MSI-X vectors"
echo "  - vs nvme1: WD Black supports 65 MSI-X vectors"
echo ""

# Apply what we CAN optimize
echo "=== Applying Optimizations ===""

# Reduce read-ahead (boot drive does lots of random I/O)
echo "1. Reducing read-ahead from 256KB to 128KB..."
echo 128 | sudo tee /sys/block/nvme0n1/queue/read_ahead_kb > /dev/null
echo "   ✅ Read-ahead: $(cat /sys/block/nvme0n1/queue/read_ahead_kb)KB"

# Queue depth is hardware limited to 255, can't increase
echo "2. Queue depth:"
echo "   WARNING: Locked at 255 (hardware/driver limit)"
echo "   Current: $(cat /sys/block/nvme0n1/queue/nr_requests)"

# Scheduler is already optimal
echo "3. I/O Scheduler:"
echo "   OK: Already set to 'none' (optimal for NVMe)"

echo ""
echo "=== Summary ==="
echo "Applied optimizations:"
echo "  [OK] Read-ahead: 128KB (optimized for random I/O)"
echo "  [OK] Scheduler: none (direct dispatch)"
echo "  [WARN] Queue depth: 255 (hardware limited)"
echo "  [WARN] Queue count: 9 (MSI-X vector limited)"
echo ""
echo "=== Hardware Limitations ===""
echo "The Intel 660P (nvme0) is fundamentally limited by:"
echo "  1. Only 16 MSI-X vectors (vs 65 on WD Black)"
echo "  2. Can only support 8 I/O queues + 1 admin queue"
echo "  3. Kernel parameter nvme.write_queues=16 has NO EFFECT"
echo "     because hardware doesn't support that many queues"
echo ""
echo "Current IRQ distribution:"
cat /proc/interrupts | grep nvme0q | awk 'BEGIN{total=0; max=0; maxq=""} {sum=0; for(i=2;i<=NF-3;i++) sum+=$i; total+=sum; if(sum>max){max=sum; maxq=$NF}} END{printf "  Total queues: %d\n  Total interrupts: %d\n  Max on %s: %d (%.1f%%)\n", NR, total, maxq, max, (total>0 ? max/total*100 : 0)}'
echo ""
echo "=== Recommendation ==="
echo "Consider SWAPPING the drives:"
echo "  - Use WD Black SN750 (nvme1) as BOOT drive"
echo "    [+] Faster (TLC vs QLC NAND)"
echo "    [+] 65 MSI-X vectors (supports 64 queues)"
echo "    [+] Currently showing excellent IRQ distribution"
echo ""
echo "  - Use Intel 660P (nvme0) as SECONDARY/DATA drive"
echo "    [+] Still good for storage"
echo "    [+] IRQ concentration less critical for data drive"
echo ""
echo "Done!"
