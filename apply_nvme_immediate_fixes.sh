#!/bin/bash
# Apply immediate NVMe performance fixes (no reboot required)

echo "=== Applying NVMe Performance Fixes (No Reboot) ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

NVME_DEV="nvme1n1"  # Boot drive

echo "Target device: /dev/$NVME_DEV (Intel 660P boot drive)"
echo ""

# Current state
echo "Current configuration:"
echo "  Scheduler: $(cat /sys/block/$NVME_DEV/queue/scheduler)"
echo "  Queue depth (nr_requests): $(cat /sys/block/$NVME_DEV/queue/nr_requests)"
echo "  Read-ahead: $(cat /sys/block/$NVME_DEV/queue/read_ahead_kb) KB"
echo ""

# Fix 1: Change scheduler to kyber or none
echo "Fix 1: Changing I/O scheduler to 'none' (bypass scheduler)..."
echo none > /sys/block/$NVME_DEV/queue/scheduler
echo "  New scheduler: $(cat /sys/block/$NVME_DEV/queue/scheduler)"
echo ""

# Fix 2: Increase queue depth
echo "Fix 2: Increasing queue depth from 255 to 512..."
echo 512 > /sys/block/$NVME_DEV/queue/nr_requests
echo "  New queue depth: $(cat /sys/block/$NVME_DEV/queue/nr_requests)"
echo ""

# Fix 3: Tune read-ahead for mixed workload
echo "Fix 3: Reducing read-ahead for better random I/O..."
echo 128 > /sys/block/$NVME_DEV/queue/read_ahead_kb
echo "  New read-ahead: $(cat /sys/block/$NVME_DEV/queue/read_ahead_kb) KB"
echo ""

# Fix 4: Check and report I/O stats
echo "Current I/O statistics:"
iostat -x $NVME_DEV 1 2 | tail -3
echo ""

echo "✓ Immediate fixes applied!"
echo ""
echo "Monitor with:"
echo "  watch -n 1 'cat /proc/interrupts | grep nvme1q'"
echo "  sudo iostat -x $NVME_DEV 1"
echo ""
echo "Note: These changes are temporary and will reset on reboot."
echo "To make permanent, see NVME_REAL_ROOT_CAUSE.md"
