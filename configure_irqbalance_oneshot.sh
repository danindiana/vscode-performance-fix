#!/bin/bash
# Configure IRQBalance: Oneshot Mode (Balance at Boot Only)
# Prevents continuous IRQ rebalancing every 10 minutes

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║       IRQBalance Configuration: Static vs Dynamic               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo)"
    exit 1
fi

echo "📊 Current IRQBalance Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl status irqbalance.service --no-pager | grep -E "Active:|interval"
echo ""

echo "Current configuration:"
grep -E "^IRQBALANCE" /etc/default/irqbalance | grep -v "^#"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Configuration Options:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  ONESHOT Mode (RECOMMENDED for your setup)"
echo "    Balance IRQs once at boot, then exit"
echo "    ✓ Static IRQ assignments after boot"
echo "    ✓ No continuous rebalancing"
echo "    ✓ Manual optimizations stay in place"
echo "    ✓ Predictable IRQ distribution"
echo ""
echo "2️⃣  Disable IRQBalance Completely"
echo "    Stop and disable the service"
echo "    ✓ Complete control over IRQ assignments"
echo "    ⚠️  No automatic balancing at all"
echo "    ⚠️  Must manually distribute IRQs"
echo ""
echo "3️⃣  Increase Interval (Current: 600 seconds)"
echo "    Keep dynamic but rebalance less frequently"
echo "    Options: 1800s (30min), 3600s (1hr), 7200s (2hr)"
echo "    ⚠️  Still rebalances periodically"
echo ""
echo "4️⃣  Keep Current (600 second interval)"
echo "    No changes"
echo ""

read -p "Choose option [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "🔧 Configuring ONESHOT mode..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Backup current config
        cp /etc/default/irqbalance /etc/default/irqbalance.backup-oneshot
        echo "✓ Backed up config to: /etc/default/irqbalance.backup-oneshot"
        
        # Enable ONESHOT mode
        sed -i 's/^#IRQBALANCE_ONESHOT=.*/IRQBALANCE_ONESHOT=1/' /etc/default/irqbalance
        
        # If IRQBALANCE_ONESHOT doesn't exist, add it
        if ! grep -q "^IRQBALANCE_ONESHOT=" /etc/default/irqbalance; then
            echo "" >> /etc/default/irqbalance
            echo "# Balance once at boot, then exit (static assignments)" >> /etc/default/irqbalance
            echo "IRQBALANCE_ONESHOT=1" >> /etc/default/irqbalance
        fi
        
        # Remove interval argument (not needed in oneshot mode)
        sed -i 's/^IRQBALANCE_ARGS=.*/IRQBALANCE_ARGS=""/' /etc/default/irqbalance
        
        echo "✓ Enabled ONESHOT mode"
        echo ""
        echo "Restarting irqbalance service..."
        systemctl restart irqbalance.service
        
        echo ""
        echo "✅ ONESHOT mode configured!"
        echo ""
        echo "Behavior:"
        echo "  - At boot: IRQBalance runs, balances IRQs optimally"
        echo "  - After ~1 minute: IRQBalance exits"
        echo "  - Runtime: IRQ assignments remain static"
        echo "  - Your manual optimizations: PRESERVED"
        echo ""
        ;;
        
    2)
        echo ""
        echo "🛑 Disabling IRQBalance completely..."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        systemctl stop irqbalance.service
        systemctl disable irqbalance.service
        
        echo "✓ IRQBalance stopped and disabled"
        echo ""
        echo "⚠️  WARNING: No automatic IRQ balancing at all!"
        echo "You'll need to manually manage IRQ distribution."
        echo ""
        echo "To re-enable later:"
        echo "  sudo systemctl enable --now irqbalance.service"
        echo ""
        ;;
        
    3)
        echo ""
        echo "⏱️  Set custom interval..."
        read -p "Enter interval in seconds [1800=30min, 3600=1hr, 7200=2hr]: " interval
        
        if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
            echo "❌ Invalid number"
            exit 1
        fi
        
        # Backup
        cp /etc/default/irqbalance /etc/default/irqbalance.backup-interval
        
        # Update interval
        sed -i "s/^IRQBALANCE_ARGS=.*/IRQBALANCE_ARGS=\"--interval=$interval\"/" /etc/default/irqbalance
        
        echo "✓ Set interval to $interval seconds"
        
        systemctl restart irqbalance.service
        
        echo "✓ IRQBalance restarted with new interval"
        echo ""
        ;;
        
    4)
        echo ""
        echo "ℹ️  No changes made"
        echo "Current interval: 600 seconds (10 minutes)"
        exit 0
        ;;
        
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 New Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -E "^IRQBALANCE" /etc/default/irqbalance | grep -v "^#"
echo ""

echo "Service Status:"
systemctl status irqbalance.service --no-pager | head -5
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Testing:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Watch IRQ distribution (should stay static in ONESHOT mode):"
echo "  watch -n 5 'cat /proc/interrupts | grep -E \"nvme0q8|nvme1q0|enp3s0f0\"'"
echo ""
echo "Monitor irqbalance process:"
echo "  ps aux | grep irqbalance"
echo "  (In ONESHOT mode, process exits after ~60 seconds)"
echo ""
echo "Check service logs:"
echo "  journalctl -u irqbalance.service -f"
echo ""

if [ "$choice" == "1" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⏳ Waiting 60 seconds to verify ONESHOT behavior..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    sleep 60
    echo ""
    echo "Process check:"
    if ps aux | grep -q "[i]rqbalance"; then
        echo "  ⚠️  irqbalance still running (may take up to 2 minutes to exit)"
        ps aux | grep "[i]rqbalance"
    else
        echo "  ✓ irqbalance has exited (ONESHOT mode working!)"
    fi
    echo ""
    echo "Service status:"
    systemctl status irqbalance.service --no-pager | grep -E "Active:|Main PID"
fi

echo ""
echo "✓ Configuration complete!"
echo ""
