#!/bin/bash
# Fix NVMe IRQ Starvation - v2 with irqbalance handling
# Target: Intel 660P (nvme1) - boot drive with severe IRQ contention

echo "=== NVMe IRQ Starvation Fix v2 ==="
echo "Problem: nvme1q4 handling 400K+ interrupts across all 32 CPUs"
echo "Solution: Stop irqbalance interference and pin queues permanently"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Find nvme1 IRQ numbers
echo "Finding nvme1 IRQ numbers..."
IRQ_Q0=$(grep "nvme1q0" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q1=$(grep "nvme1q1" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q2=$(grep "nvme1q2" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q3=$(grep "nvme1q3" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q4=$(grep "nvme1q4" /proc/interrupts | awk '{print $1}' | tr -d ':')

if [ -z "$IRQ_Q4" ]; then
    echo "ERROR: Could not find nvme1q4 IRQ"
    exit 1
fi

echo "Found IRQs: Q0=$IRQ_Q0, Q1=$IRQ_Q1, Q2=$IRQ_Q2, Q3=$IRQ_Q3, Q4=$IRQ_Q4"
echo ""

# Current state
echo "Current nvme1 IRQ distribution:"
cat /proc/interrupts | grep "nvme1q" | awk '{sum=0; for(i=2;i<=NF-3;i++) sum+=$i; printf "%s: %'d interrupts on CPUs ", $NF, sum; system("cat /proc/irq/"substr($1,1,length($1)-1)"/smp_affinity_list")}'
echo ""

# Step 1: Configure irqbalance to ban these IRQs
echo "Step 1: Configuring irqbalance to exclude nvme1 IRQs..."

# Create irqbalance config
cat > /etc/default/irqbalance.d/nvme-fix.conf << EOF
# Exclude nvme1 IRQs from irqbalance management
# These are manually pinned for performance
IRQBALANCE_ARGS="--banirq=$IRQ_Q0 --banirq=$IRQ_Q1 --banirq=$IRQ_Q2 --banirq=$IRQ_Q3 --banirq=$IRQ_Q4"
EOF

# Also update main config
if [ -f /etc/default/irqbalance ]; then
    if ! grep -q "IRQBALANCE_ARGS.*banirq" /etc/default/irqbalance; then
        echo "" >> /etc/default/irqbalance
        echo "# NVMe IRQ fix - ban specific IRQs" >> /etc/default/irqbalance
        echo "IRQBALANCE_ARGS=\"\$IRQBALANCE_ARGS --banirq=$IRQ_Q0 --banirq=$IRQ_Q1 --banirq=$IRQ_Q2 --banirq=$IRQ_Q3 --banirq=$IRQ_Q4\"" >> /etc/default/irqbalance
    fi
fi

# Restart irqbalance to apply config
echo "Restarting irqbalance..."
systemctl restart irqbalance
sleep 2

# Step 2: Pin IRQs to specific CPUs
echo ""
echo "Step 2: Pinning nvme1 queues to specific CPUs..."

# Pin to specific CPUs
echo "  IRQ $IRQ_Q0 (nvme1q0 - admin) -> CPU 30"
echo 30 > /proc/irq/$IRQ_Q0/smp_affinity_list

echo "  IRQ $IRQ_Q1 (nvme1q1) -> CPUs 0-3"
echo "0-3" > /proc/irq/$IRQ_Q1/smp_affinity_list

echo "  IRQ $IRQ_Q2 (nvme1q2) -> CPUs 8-11"
echo "8-11" > /proc/irq/$IRQ_Q2/smp_affinity_list

echo "  IRQ $IRQ_Q3 (nvme1q3) -> CPUs 16-19"
echo "16-19" > /proc/irq/$IRQ_Q3/smp_affinity_list

echo "  IRQ $IRQ_Q4 (nvme1q4 - CRITICAL) -> CPUs 24-27"
echo "24-27" > /proc/irq/$IRQ_Q4/smp_affinity_list

# Wait a moment and verify irqbalance didn't override
sleep 1

echo ""
echo "Step 3: Verifying settings..."
SUCCESS=true
for irq in $IRQ_Q0 $IRQ_Q1 $IRQ_Q2 $IRQ_Q3 $IRQ_Q4; do
    queue=$(grep -w "^ *$irq:" /proc/interrupts | awk '{print $NF}')
    affinity=$(cat /proc/irq/$irq/smp_affinity_list)
    echo "  IRQ $irq ($queue): CPUs $affinity"
    
    # Check if Q4 is still on all CPUs (would indicate failure)
    if [ "$irq" = "$IRQ_Q4" ] && [ "$affinity" = "0-31" ]; then
        echo "    ⚠️  WARNING: Q4 still on all CPUs - irqbalance may be overriding!"
        SUCCESS=false
    fi
done

echo ""
if [ "$SUCCESS" = true ]; then
    echo "✓ NVMe IRQ pinning successful!"
    echo ""
    echo "Monitor with: watch -n 1 'cat /proc/interrupts | grep nvme1q'"
    echo ""
    echo "To make permanent across reboots, this script has updated:"
    echo "  - /etc/default/irqbalance"
    echo "  - /etc/default/irqbalance.d/nvme-fix.conf"
else
    echo "⚠️  IRQ pinning may have failed due to irqbalance interference"
    echo ""
    echo "Alternative: Temporarily disable irqbalance:"
    echo "  sudo systemctl stop irqbalance"
    echo "  Then re-run this script"
    echo ""
    echo "Or add to kernel command line: irqaffinity=0-31 (and manually pin IRQs)"
fi
