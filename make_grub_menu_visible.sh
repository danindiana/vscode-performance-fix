#!/bin/bash
# Make GRUB menu always visible at boot (not hidden)

echo "Making GRUB menu visible by default..."

# Backup current config
sudo cp /etc/default/grub /etc/default/grub.backup.visible-menu

# Change GRUB_TIMEOUT_STYLE from 'hidden' to 'menu'
sudo sed -i 's/^GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub

# Update GRUB configuration
sudo update-grub

echo ""
echo "✓ GRUB menu will now show automatically at boot"
echo "✓ Will display for 10 seconds before auto-selecting Primary Ubuntu"
echo ""
echo "To revert: sudo sed -i 's/^GRUB_TIMEOUT_STYLE=menu/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub && sudo update-grub"
