#!/bin/bash
# Fix Conflicting Network Optimization Services
# Resolves conflict between old 4-queue and new 8-queue optimization

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     Resolving Network Optimization Service Conflicts            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo)"
    exit 1
fi

echo "🔍 Found Conflicting Services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  OLD: network-optimization.service → Sets to 4 queues"
echo "  NEW: network-queue-optimization.service → Sets to 8 queues"
echo ""

echo "📊 Current Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ethtool -l enp3s0f0 | grep "Combined:"
echo ""

read -p "Choose action: [1] Disable old service [2] Update old service to 8 queues [3] Cancel: " choice

case $choice in
    1)
        echo ""
        echo "🛑 Disabling old network-optimization.service..."
        systemctl stop network-optimization.service
        systemctl disable network-optimization.service
        systemctl mask network-optimization.service
        echo "✓ Old service disabled and masked"
        echo ""
        echo "✓ network-queue-optimization.service will now manage queues (8 queues)"
        ;;
    2)
        echo ""
        echo "📝 Updating old service to use 8 queues..."
        
        # Backup old script
        cp /home/jeb/programs/irq-stutter-diag-20251017_102431/persistent-network-optimization.sh \
           /home/jeb/programs/irq-stutter-diag-20251017_102431/persistent-network-optimization.sh.backup
        
        # Update the script to use 8 queues
        sed -i 's/combined 4/combined 8/g' \
            /home/jeb/programs/irq-stutter-diag-20251017_102431/persistent-network-optimization.sh
        sed -i 's/"4"/"8"/g' \
            /home/jeb/programs/irq-stutter-diag-20251017_102431/persistent-network-optimization.sh
        sed -i 's/4 queues/8 queues/g' \
            /home/jeb/programs/irq-stutter-diag-20251017_102431/persistent-network-optimization.sh
        
        echo "✓ Old script updated to use 8 queues"
        echo "✓ Backup saved to: persistent-network-optimization.sh.backup"
        
        # Disable the new service since old one is updated
        systemctl disable network-queue-optimization.service
        echo "✓ Disabled redundant network-queue-optimization.service"
        ;;
    3)
        echo ""
        echo "❌ Cancelled"
        exit 0
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl status network-optimization.service --no-pager | grep -E "Loaded:|Active:" || echo "Service disabled"
systemctl status network-queue-optimization.service --no-pager | grep -E "Loaded:|Active:" || echo "Service disabled"
echo ""
echo "Current queue configuration:"
ethtool -l enp3s0f0 | grep "Combined:"
echo ""
echo "✓ Conflict resolved!"
echo ""
echo "💡 Test after reboot with:"
echo "   sudo ethtool -l enp3s0f0"
echo ""
