#!/bin/bash
# Install NVMe System Status MOTD and Send Wall Notice

echo "=== Installing NVMe System Status MOTD ==="
echo ""

# Make the MOTD script executable
chmod +x system-status-motd.sh

# Copy to /etc/update-motd.d/ for automatic display on login
echo "Installing MOTD script..."
sudo cp system-status-motd.sh /etc/update-motd.d/99-nvme-status
sudo chmod +x /etc/update-motd.d/99-nvme-status

echo "✓ MOTD installed at /etc/update-motd.d/99-nvme-status"
echo ""

# Disable some default MOTD scripts to reduce clutter (optional)
echo "Disabling verbose default MOTD scripts..."
if [ -f /etc/update-motd.d/10-help-text ]; then
    sudo chmod -x /etc/update-motd.d/10-help-text
    echo "  ✓ Disabled 10-help-text"
fi

if [ -f /etc/update-motd.d/50-motd-news ]; then
    sudo chmod -x /etc/update-motd.d/50-motd-news  
    echo "  ✓ Disabled 50-motd-news"
fi

# Test the MOTD
echo ""
echo "=== Testing MOTD (this is what users will see) ==="
echo ""
/etc/update-motd.d/99-nvme-status

# Send wall message about the system configuration
echo ""
echo "=== Sending wall notification to all logged-in users ==="
echo ""

WALL_MSG="
╔════════════════════════════════════════════════════════════════╗
║     NVMe System Configuration Update - October 18, 2025        ║
╚════════════════════════════════════════════════════════════════╝

ATTENTION: The system NVMe drive configuration has been analyzed
and optimized.

KEY FINDINGS:
• Primary drive (nvme0 - Intel 660P): Hardware limited to 9 queues
  - Has IRQ concentration (~73% on one queue) due to 16 MSI-X limit
  - Optimized within hardware constraints (read-ahead reduced)
  
• Fast storage (nvme1 - WD Black): Excellent performance capability
  - 65 MSI-X vectors supporting 49 queues
  - TLC NAND (faster than QLC)
  - Ready for high-performance workloads

• Backup OS available on /dev/sdd2
  - Hold SHIFT at boot to access GRUB menu
  - Select 'Ubuntu 22.04.5 LTS (on /dev/sdd2)' for backup system

RECOMMENDATIONS:
1. Use nvme0 (primary) for: Daily OS tasks, applications
2. Use nvme1 (fast) for: Heavy I/O work (dev, video, VMs, DBs)
3. Mount nvme1 at /mnt/fast for performance-critical projects

BOOT CONFIGURATION:
• EFI stub fixed - now points to correct system (nvme0)
• Kernel parameter applied: nvme.write_queues=16
• Dual-boot GRUB menu configured correctly

For full documentation, see:
  ~/programs/vscode_performance_fix_20251018_032616/
  FINAL_COMPLETE_SYSTEM_ANALYSIS.md

Status: All optimizations applied successfully ✓
Next login will show system status automatically.
"

# Send to wall
echo "$WALL_MSG" | sudo wall

echo ""
echo "✓ Wall message sent to all users"
echo ""
echo "=== Installation Complete ==="
echo ""
echo "What happens now:"
echo "  1. Every new terminal session will show the system status"
echo "  2. All currently logged-in users received a wall notification"
echo "  3. MOTD will update automatically on each login"
echo ""
echo "To test: Open a new terminal or SSH session"
echo "To disable: sudo chmod -x /etc/update-motd.d/99-nvme-status"
echo ""
