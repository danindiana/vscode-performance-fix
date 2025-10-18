#!/bin/bash
# Comprehensive IRQ Starvation Analysis
# Analyzes all devices for potential IRQ concentration issues

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       System-Wide IRQ Starvation Analysis                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Function to analyze IRQ distribution for a device
analyze_device_irqs() {
    local device_pattern="$1"
    local device_name="$2"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔍 $device_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get all IRQs for this device
    local irqs=$(grep -i "$device_pattern" /proc/interrupts)
    
    if [ -z "$irqs" ]; then
        echo "  ℹ No IRQs found"
        return
    fi
    
    # Count total queues/IRQs
    local queue_count=$(echo "$irqs" | wc -l)
    echo "  Queues/IRQs: $queue_count"
    
    # Calculate total interrupts and distribution
    local total_interrupts=0
    local max_interrupts=0
    local max_queue=""
    
    while IFS= read -r line; do
        local queue_name=$(echo "$line" | awk '{print $NF}')
        local queue_interrupts=$(echo "$line" | awk '{for(i=2;i<=NF-3;i++) sum+=$i} END {print sum}')
        
        total_interrupts=$((total_interrupts + queue_interrupts))
        
        if [ "$queue_interrupts" -gt "$max_interrupts" ]; then
            max_interrupts=$queue_interrupts
            max_queue=$queue_name
        fi
    done <<< "$irqs"
    
    if [ "$total_interrupts" -gt 0 ]; then
        local concentration=$((max_interrupts * 100 / total_interrupts))
        echo "  Total Interrupts: $(printf "%'d" $total_interrupts)"
        echo "  Max on Single Queue: $(printf "%'d" $max_interrupts) ($max_queue)"
        echo "  Concentration: ${concentration}%"
        
        # Assess severity
        if [ "$concentration" -ge 75 ]; then
            echo "  ⚠️  SEVERE: High IRQ concentration (≥75%)"
        elif [ "$concentration" -ge 50 ]; then
            echo "  ⚠️  WARNING: Moderate IRQ concentration (≥50%)"
        elif [ "$concentration" -ge 40 ]; then
            echo "  ℹ️  NOTICE: Some IRQ concentration (≥40%)"
        else
            echo "  ✓ Good: Well-distributed IRQs"
        fi
        
        # Show top 3 busiest queues
        echo ""
        echo "  Top 3 Busiest:"
        echo "$irqs" | awk '{
            queue=$NF; 
            sum=0; 
            for(i=2;i<=NF-3;i++) sum+=$i; 
            print sum, queue
        }' | sort -rn | head -3 | awk '{printf "    %s: %'"'"'d interrupts\n", $2, $1}'
    else
        echo "  ℹ No activity recorded"
    fi
    
    echo ""
}

echo ""

# Analyze NVMe drives
analyze_device_irqs "nvme0q" "NVMe0 (Intel 660P - Boot Drive)"
analyze_device_irqs "nvme1q" "NVMe1 (WD Black - Data Drive)"

# Analyze Network interfaces
analyze_device_irqs "enp3s0f0" "Network: enp3s0f0 (10G Port 0)"
analyze_device_irqs "enp3s0f1" "Network: enp3s0f1 (10G Port 1)"
analyze_device_irqs "enp9s0" "Network: enp9s0 (1G Ethernet)"

# Analyze NVIDIA GPUs
analyze_device_irqs "nvidia" "NVIDIA GPUs"

# Analyze SATA/AHCI controllers
analyze_device_irqs "ahci" "SATA/AHCI Controllers"

# Analyze USB controllers
analyze_device_irqs "xhci_hcd" "USB Controllers (xHCI)"

# Analyze audio
analyze_device_irqs "snd_hda_intel" "Audio (HDA Intel)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary & Recommendations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Legend:"
echo "  ≥75% = SEVERE (single queue handling 3/4+ of all I/O)"
echo "  ≥50% = WARNING (single queue handling half of all I/O)"
echo "  ≥40% = NOTICE (some concentration, monitor)"
echo "  <40% = Good (well distributed)"
echo ""
echo "Check CPU affinity with:"
echo "  cat /proc/irq/<IRQ_NUMBER>/smp_affinity_list"
echo ""
echo "Check if IRQs are managed (cannot be changed manually):"
echo "  cat /proc/irq/<IRQ_NUMBER>/effective_affinity_list"
echo ""
