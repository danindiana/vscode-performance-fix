#!/bin/bash
# Fix GRUB NVMe parameter - CORRECTED VERSION
# Replace nvme.write_queues=4 with nvme_core.write_queues=16 in GRUB_CMDLINE_LINUX_DEFAULT

set -e

echo "=== NVMe GRUB Parameter Fix - CORRECTED ==="
echo ""
echo "Problem: nvme.write_queues=4 in GRUB_CMDLINE_LINUX_DEFAULT (old parameter)"
echo "Solution: Replace with nvme_core.write_queues=16 (correct parameter)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.backup.corrected.$(date +%Y%m%d_%H%M%S)"

# Backup
echo "Step 1: Backing up GRUB configuration..."
cp -v "$GRUB_FILE" "$BACKUP_FILE"
echo "  Backup saved to: $BACKUP_FILE"
echo ""

# Show current state
echo "Step 2: Current problematic line:"
grep "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE" || true
echo ""

# Fix the parameter
echo "Step 3: Replacing nvme.write_queues=4 with nvme_core.write_queues=16..."
sed -i 's/nvme\.write_queues=[0-9]*/nvme_core.write_queues=16/' "$GRUB_FILE"

echo "  ✓ Parameter replaced"
echo ""

# Verify
echo "Step 4: New line:"
grep "GRUB_CMDLINE_LINUX_DEFAULT" "$GRUB_FILE" || true
echo ""

# Update GRUB
echo "Step 5: Updating GRUB configuration..."
update-grub
echo "  ✓ GRUB updated successfully"
echo ""

echo "====================================="
echo "✓ Configuration fixed!"
echo "====================================="
echo ""
echo "Changes made:"
echo "  - nvme.write_queues=4 → nvme_core.write_queues=16"
echo "  - In GRUB_CMDLINE_LINUX_DEFAULT"
echo ""
echo "After reboot, verify with:"
echo "  cat /proc/cmdline | grep nvme"
echo "  cat /sys/module/nvme/parameters/write_queues"
echo "  cat /proc/interrupts | grep nvme1q"
echo ""
echo "Expected results after reboot:"
echo "  - write_queues parameter: 16 (not 4)"
echo "  - More NVMe queues visible in /proc/interrupts"
echo "  - Much better interrupt distribution (q4 should drop from 80% to ~15%)"
echo ""

read -p "Do you want to reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    reboot
else
    echo "Reboot cancelled. Run 'sudo reboot' when ready."
    echo ""
    echo "Rollback if needed:"
    echo "  sudo cp $BACKUP_FILE $GRUB_FILE"
    echo "  sudo update-grub"
    echo "  sudo reboot"
fi
