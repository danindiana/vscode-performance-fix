#!/bin/bash
# Fix NVMe IRQ Starvation - Pin queues to specific CPUs
# Target: Intel 660P (nvme1) - boot drive with severe IRQ contention

echo "=== NVMe IRQ Starvation Fix ==="
echo "Problem: nvme1q4 handling 400K+ interrupts across all 32 CPUs"
echo "Solution: Pin each NVMe queue to specific CPU cores"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Find nvme1 IRQs
echo "Current nvme1 IRQ distribution:"
cat /proc/interrupts | grep "nvme1q" | awk '{sum=0; for(i=2;i<=NF-3;i++) sum+=$i; printf "%s: %d interrupts\n", $NF, sum}'
echo ""

# Pin nvme1 queues to specific CPUs for better distribution
# Queue 0 (admin): CPU 30
# Queue 1-4: CPUs 0,8,16,24 (spread across CCDs)
echo "Pinning nvme1 queues to specific CPUs..."

# Find IRQ numbers for nvme1
IRQ_Q0=$(grep "nvme1q0" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q1=$(grep "nvme1q1" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q2=$(grep "nvme1q2" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q3=$(grep "nvme1q3" /proc/interrupts | awk '{print $1}' | tr -d ':')
IRQ_Q4=$(grep "nvme1q4" /proc/interrupts | awk '{print $1}' | tr -d ':')

# Pin to specific CPUs
echo "$IRQ_Q0 (nvme1q0 - admin) -> CPU 30"
echo 30 > /proc/irq/$IRQ_Q0/smp_affinity_list

echo "$IRQ_Q1 (nvme1q1) -> CPU 0-3"
echo "0-3" > /proc/irq/$IRQ_Q1/smp_affinity_list

echo "$IRQ_Q2 (nvme1q2) -> CPU 8-11"
echo "8-11" > /proc/irq/$IRQ_Q2/smp_affinity_list

echo "$IRQ_Q3 (nvme1q3) -> CPU 16-19"
echo "16-19" > /proc/irq/$IRQ_Q3/smp_affinity_list

echo "$IRQ_Q4 (nvme1q4 - CRITICAL) -> CPU 24-27"
echo "24-27" > /proc/irq/$IRQ_Q4/smp_affinity_list

echo ""
echo "New affinity set. Verifying..."
for irq in $IRQ_Q0 $IRQ_Q1 $IRQ_Q2 $IRQ_Q3 $IRQ_Q4; do
    queue=$(grep -w "^ *$irq:" /proc/interrupts | awk '{print $NF}')
    affinity=$(cat /proc/irq/$irq/smp_affinity_list)
    echo "  IRQ $irq ($queue): CPUs $affinity"
done

echo ""
echo "=== Also checking nvme0 (WD Black SN750) ==="
cat /proc/interrupts | grep "nvme0q" | awk '{sum=0; for(i=2;i<=NF-3;i++) sum+=$i; printf "%s: %d interrupts\n", $NF, sum}' | head -10
echo ""

echo "✓ NVMe IRQ pinning complete!"
echo ""
echo "Monitor with: watch -n 1 'cat /proc/interrupts | grep nvme1q'"
echo "To make permanent, add to /etc/rc.local or create systemd service"
