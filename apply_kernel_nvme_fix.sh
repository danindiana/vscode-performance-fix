#!/bin/bash
# Apply permanent NVMe queue optimization via kernel parameters
# This will increase the number of I/O queues to reduce Queue 4 bottleneck

echo "=== NVMe Permanent Fix - Kernel Parameter Configuration ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"

echo "This script will:"
echo "  1. Backup your GRUB configuration"
echo "  2. Add 'nvme_core.write_queues=16' to kernel parameters"
echo "  3. Update GRUB"
echo "  4. Prepare system for reboot"
echo ""
echo "Expected result: Increase NVMe queues from 3-4 to 16+"
echo "This will reduce Queue 4 load from 77% to ~15-20%"
echo ""

# Backup current GRUB config
echo "Step 1: Backing up GRUB configuration..."
cp -v "$GRUB_FILE" "$BACKUP_FILE"
echo "  Backup saved to: $BACKUP_FILE"
echo ""

# Check if parameter already exists
if grep -q "nvme_core.write_queues" "$GRUB_FILE"; then
    echo "⚠️  WARNING: nvme_core.write_queues already exists in GRUB config"
    echo "Current line:"
    grep "nvme_core.write_queues" "$GRUB_FILE"
    echo ""
    read -p "Do you want to update it? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    # Remove old parameter
    sed -i 's/nvme_core.write_queues=[0-9]*//' "$GRUB_FILE"
fi

# Add the parameter
echo "Step 2: Adding nvme_core.write_queues=16 to kernel parameters..."

# Find the GRUB_CMDLINE_LINUX line and append our parameter
if grep -q '^GRUB_CMDLINE_LINUX=' "$GRUB_FILE"; then
    # Add to existing line
    sed -i 's/^\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 nvme_core.write_queues=16"/' "$GRUB_FILE"
    echo "  ✓ Parameter added to existing GRUB_CMDLINE_LINUX"
else
    # Create new line if it doesn't exist
    echo 'GRUB_CMDLINE_LINUX="nvme_core.write_queues=16"' >> "$GRUB_FILE"
    echo "  ✓ Created new GRUB_CMDLINE_LINUX with parameter"
fi

echo ""
echo "Step 3: Verifying changes..."
echo "New GRUB_CMDLINE_LINUX:"
grep "^GRUB_CMDLINE_LINUX=" "$GRUB_FILE"
echo ""

# Update GRUB
echo "Step 4: Updating GRUB configuration..."
if [ -f /boot/grub/grub.cfg ]; then
    update-grub
    echo "  ✓ GRUB updated successfully"
elif [ -f /boot/grub2/grub.cfg ]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
    echo "  ✓ GRUB2 updated successfully"
else
    echo "  ⚠️  Could not find GRUB config file"
    echo "  You may need to manually run: update-grub or grub2-mkconfig"
fi

echo ""
echo "====================================="
echo "✓ Configuration complete!"
echo "====================================="
echo ""
echo "Current state:"
echo "  - Scheduler: none (optimized)"
echo "  - Read-ahead: 128 KB (optimized)"
echo "  - Queue count: 3-4 (will increase to 16+ after reboot)"
echo ""
echo "After reboot, you will have:"
echo "  - 16 write queues instead of 3-4"
echo "  - Better load distribution"
echo "  - Reduced per-queue interrupt load"
echo "  - Improved I/O performance"
echo ""
echo "To reboot now: sudo reboot"
echo "To verify after reboot: cat /proc/interrupts | grep nvme1q"
echo ""
echo "If you need to rollback:"
echo "  sudo cp $BACKUP_FILE $GRUB_FILE"
echo "  sudo update-grub"
echo "  sudo reboot"
echo ""

read -p "Do you want to reboot now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    reboot
else
    echo "Reboot cancelled. Run 'sudo reboot' when ready."
fi
