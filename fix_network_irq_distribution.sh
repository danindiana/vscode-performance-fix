#!/bin/bash
# Fix Network Adapter IRQ Distribution
# Increases RSS (Receive Side Scaling) queue count on 10G adapters

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Network Adapter IRQ Distribution Optimization             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo)"
    exit 1
fi

# Adapter to optimize
ADAPTER="enp3s0f0"

echo "🔍 Current Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ethtool -l $ADAPTER 2>/dev/null
echo ""

# Current IRQ distribution
echo "📊 Current IRQ Distribution:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep "$ADAPTER" /proc/interrupts | while read -r line; do
    queue=$(echo "$line" | awk '{print $NF}')
    total=$(echo "$line" | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}')
    printf "  %-20s %'10d interrupts\n" "$queue" "$total"
done
echo ""

# Calculate concentration
total_interrupts=$(grep "$ADAPTER" /proc/interrupts | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}' | awk '{sum+=$1} END {print sum}')
max_interrupts=$(grep "$ADAPTER" /proc/interrupts | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}' | sort -rn | head -1)
concentration=$((max_interrupts * 100 / total_interrupts))
echo "  Current Concentration: ${concentration}% on single queue"
echo ""

# Ask user for queue count
echo "💡 Recommendation: Use 8-16 queues for optimal distribution"
echo "   - More queues = better distribution, more CPU overhead"
echo "   - 8 queues: Good balance for most workloads"
echo "   - 16 queues: Maximum performance, higher CPU usage"
echo ""

read -p "Enter desired queue count (4-32) [default: 8]: " queue_count
queue_count=${queue_count:-8}

# Validate input
if ! [[ "$queue_count" =~ ^[0-9]+$ ]] || [ "$queue_count" -lt 4 ] || [ "$queue_count" -gt 32 ]; then
    echo "❌ Invalid queue count. Must be between 4 and 32."
    exit 1
fi

echo ""
echo "📝 Applying new configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Apply new queue count
ethtool -L $ADAPTER combined $queue_count

if [ $? -eq 0 ]; then
    echo "✓ Successfully set $ADAPTER to $queue_count queues"
else
    echo "❌ Failed to set queue count"
    exit 1
fi

echo ""
echo "🔄 New Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ethtool -l $ADAPTER
echo ""

echo "💾 Making change persistent across reboots..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create systemd service for persistence
cat > /etc/systemd/system/network-queue-optimization.service << EOF
[Unit]
Description=Network Queue Optimization
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -L $ADAPTER combined $queue_count
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl daemon-reload
systemctl enable network-queue-optimization.service
systemctl start network-queue-optimization.service

if [ $? -eq 0 ]; then
    echo "✓ Created systemd service: network-queue-optimization.service"
    echo "  Service will run on every boot"
else
    echo "❌ Failed to create systemd service"
fi

echo ""
echo "⏰ Wait 10 seconds for traffic to redistribute..."
sleep 10

echo ""
echo "📊 New IRQ Distribution (after 10s):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep "$ADAPTER" /proc/interrupts | while read -r line; do
    queue=$(echo "$line" | awk '{print $NF}')
    total=$(echo "$line" | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}')
    printf "  %-20s %'10d interrupts\n" "$queue" "$total"
done

# Calculate new concentration
total_interrupts=$(grep "$ADAPTER" /proc/interrupts | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}' | awk '{sum+=$1} END {print sum}')
max_interrupts=$(grep "$ADAPTER" /proc/interrupts | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}' | sort -rn | head -1)
new_concentration=$((max_interrupts * 100 / total_interrupts))

echo ""
echo "✓ Optimization Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Before: ${concentration}% concentration on 4 queues"
echo "  After:  ${new_concentration}% concentration on $queue_count queues"
echo ""
echo "📈 Expected improvement:"
echo "  - Better multi-core CPU utilization"
echo "  - Reduced single-queue bottleneck"
echo "  - Improved network throughput under load"
echo ""
echo "🔍 Monitor performance with:"
echo "  watch -n 1 'grep $ADAPTER /proc/interrupts'"
echo "  ethtool -S $ADAPTER | grep -E \"rx_queue|tx_queue\""
echo ""
echo "💡 To test different queue counts:"
echo "  sudo ethtool -L $ADAPTER combined <COUNT>"
echo ""

# Update our analysis script to show optimized status
echo ""
echo "📝 Updating system status..."
cat > /usr/local/bin/network-queue-status << 'EOFSTATUS'
#!/bin/bash
echo "Network Queue Status:"
for iface in enp3s0f0 enp3s0f1 enp9s0; do
    if [ -d /sys/class/net/$iface ]; then
        queues=$(ethtool -l $iface 2>/dev/null | grep "Combined:" | tail -1 | awk '{print $2}')
        echo "  $iface: $queues combined queues"
    fi
done
EOFSTATUS

chmod +x /usr/local/bin/network-queue-status

echo "✓ Created command: network-queue-status"
echo ""
