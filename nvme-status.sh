#!/bin/bash
# Quick system status check command
# Usage: nvme-status

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}NVMe System Quick Status${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Current boot drive
CURRENT_ROOT=$(findmnt -n -o SOURCE /)
echo -e "${BOLD}Booted from:${NC} $CURRENT_ROOT"

# NVMe0 status
if [ -f /proc/interrupts ]; then
    NVME0_IRQ=$(cat /proc/interrupts | grep nvme0q | awk 'BEGIN{total=0; max=0; maxq=""} {sum=0; for(i=2;i<=NF-3;i++) sum+=$i; total+=sum; if(sum>max){max=sum; maxq=$NF}} END{printf "%s: %d/%d (%.1f%%)", maxq, max, total, (total>0 ? max/total*100 : 0)}')
    echo -e "${BOLD}nvme0:${NC} $NVME0_IRQ"
fi

# NVMe1 status
if [ -f /proc/interrupts ]; then
    NVME1_IRQ=$(cat /proc/interrupts | grep nvme1q | awk 'BEGIN{total=0; max=0; maxq=""} {sum=0; for(i=2;i<=NF-3;i++) sum+=$i; total+=sum; if(sum>max){max=sum; maxq=$NF}} END{printf "%s: %d/%d (%.1f%%)", maxq, max, total, (total>0 ? max/total*100 : 0)}')
    echo -e "${BOLD}nvme1:${NC} $NVME1_IRQ"
fi

# Queue counts
echo ""
echo -e "${BOLD}Queue Configuration:${NC}"
echo -e "  nvme0: $(cat /sys/class/nvme/nvme0/queue_count 2>/dev/null || echo 'N/A') queues"
echo -e "  nvme1: $(cat /sys/class/nvme/nvme1/queue_count 2>/dev/null || echo 'N/A') queues ($(cat /sys/module/nvme/parameters/write_queues 2>/dev/null || echo 'N/A') write)"

# Mount status
echo ""
echo -e "${BOLD}Mount Status:${NC}"
NVME1_MOUNT=$(findmnt -n -o TARGET -S /dev/nvme1n1p1 2>/dev/null)
if [ -n "$NVME1_MOUNT" ]; then
    echo -e "  ${GREEN}✓${NC} nvme1 mounted at: $NVME1_MOUNT"
else
    echo -e "  ${YELLOW}ℹ${NC} nvme1 not mounted (use: sudo mount /dev/nvme1n1p1 /mnt/fast)"
fi

echo ""
echo -e "For detailed analysis: ${BOLD}cat ~/programs/vscode_performance_fix_20251018_032616/FINAL_COMPLETE_SYSTEM_ANALYSIS.md${NC}"
echo ""
