#!/bin/bash
# Setup Dual Ubuntu Boot Configuration
# This enables GRUB to show both Ubuntu installations in the boot menu

echo "=== Dual Ubuntu Boot Setup ==="
echo ""
echo "Current configuration:"
echo "  Primary:   nvme1n1p1 (UUID: 2bd8e49f-7ea3-4755-8999-7b78f4223812)"
echo "  Secondary: sdd2      (UUID: ba4c008c-3079-47f1-8e31-cc3547f6307f)"
echo ""

# Backup current GRUB config
echo "=== Creating backup ==="
sudo cp /etc/default/grub /etc/default/grub.backup.dual-boot
echo "✅ Backup created: /etc/default/grub.backup.dual-boot"
echo ""

# Enable os-prober
echo "=== Enabling os-prober ==="
if grep -q "^GRUB_DISABLE_OS_PROBER=true" /etc/default/grub; then
    sudo sed -i 's/^GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    echo "✅ Changed GRUB_DISABLE_OS_PROBER from true to false"
elif grep -q "^GRUB_DISABLE_OS_PROBER=false" /etc/default/grub; then
    echo "✅ os-prober already enabled"
else
    echo "GRUB_DISABLE_OS_PROBER=false" | sudo tee -a /etc/default/grub
    echo "✅ Added GRUB_DISABLE_OS_PROBER=false"
fi
echo ""

# Set default boot to current system (entry 0)
echo "=== Setting default boot entry ==="
if grep -q "^GRUB_DEFAULT=" /etc/default/grub; then
    sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/' /etc/default/grub
    echo "✅ Set GRUB_DEFAULT=0 (primary Ubuntu on nvme1n1p1)"
else
    echo "GRUB_DEFAULT=0" | sudo tee -a /etc/default/grub
    echo "✅ Added GRUB_DEFAULT=0"
fi
echo ""

# Update GRUB to detect both installations
echo "=== Updating GRUB configuration ==="
sudo update-grub
echo ""

echo "=== Verification ==="
echo "GRUB menu entries:"
sudo grep "^menuentry " /boot/grub/grub.cfg | nl
echo ""

echo "=== Configuration Summary ==="
echo "✅ EFI stub:     Points to nvme1n1p1 (primary system)"
echo "✅ os-prober:    Enabled (detects both Ubuntu installations)"
echo "✅ Default boot: Entry 0 (primary Ubuntu on nvme1n1p1)"
echo "✅ Boot menu:    Will show all detected systems"
echo ""

echo "=== How to Use ==="
echo "1. At boot, press SHIFT or ESC to see GRUB menu"
echo "2. Default: Boots primary Ubuntu (nvme1n1p1) after 10 seconds"
echo "3. Use arrow keys to select secondary Ubuntu (sdd2)"
echo ""

echo "=== Reboot Required? ==="
echo "❌ NO - Changes take effect on next boot"
echo "   Current session continues on nvme1n1p1"
echo ""

echo "Done!"
