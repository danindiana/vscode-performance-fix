#!/bin/bash
# NVMe System Configuration - Message of the Day
# Shows important system information about drive configuration and optimizations

# Color codes for better visibility
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         NVMe System Configuration & Status Report              ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check which system we're currently booted from
CURRENT_ROOT=$(findmnt -n -o UUID /)

if [ "$CURRENT_ROOT" == "2bd8e49f-7ea3-4755-8999-7b78f4223812" ]; then
    echo -e "${GREEN}✓ Booted from:${NC} ${BOLD}Primary System${NC} (nvme0 - Intel 660P)"
    BOOT_SYSTEM="primary"
elif [ "$CURRENT_ROOT" == "ba4c008c-3079-47f1-8e31-cc3547f6307f" ]; then
    echo -e "${YELLOW}⚠ Booted from:${NC} ${BOLD}Backup System${NC} (sdd - WD Blue SATA)"
    BOOT_SYSTEM="backup"
else
    echo -e "${RED}? Booted from:${NC} Unknown system (UUID: $CURRENT_ROOT)"
    BOOT_SYSTEM="unknown"
fi

echo ""
echo -e "${BOLD}Storage Configuration:${NC}"
echo -e "  ${BLUE}nvme0${NC} (Intel 660P 1TB)   → Primary OS (daily driver)"
echo -e "  ${BLUE}sdd${NC}   (WD Blue 1TB SATA) → Backup/Fallback OS"
echo -e "  ${BLUE}nvme1${NC} (WD Black 500GB)   → Fast data storage"

echo ""
echo -e "${BOLD}NVMe Performance Status:${NC}"

# Check nvme0 configuration
if [ -f /sys/block/nvme0n1/queue/read_ahead_kb ]; then
    NVME0_RA=$(cat /sys/block/nvme0n1/queue/read_ahead_kb)
    NVME0_QD=$(cat /sys/block/nvme0n1/queue/nr_requests)
    NVME0_QUEUES=$(cat /sys/class/nvme/nvme0/queue_count 2>/dev/null || echo "N/A")
    
    echo -e "  ${BLUE}nvme0:${NC} $NVME0_QUEUES queues, QD=$NVME0_QD, RA=${NVME0_RA}KB"
    
    if [ "$NVME0_RA" -eq 128 ]; then
        echo -e "         ${GREEN}✓${NC} Optimized (read-ahead reduced for random I/O)"
    else
        echo -e "         ${YELLOW}⚠${NC} Not optimized (read-ahead: ${NVME0_RA}KB)"
    fi
    
    # Check for IRQ concentration
    if [ -f /proc/interrupts ]; then
        IRQ_CHECK=$(cat /proc/interrupts | grep nvme0q | awk 'BEGIN{total=0; max=0} {sum=0; for(i=2;i<=NF-3;i++) sum+=$i; total+=sum; if(sum>max) max=sum} END{if(total>0) print int(max/total*100); else print 0}')
        if [ "$IRQ_CHECK" -gt 60 ]; then
            echo -e "         ${YELLOW}⚠${NC} IRQ concentration: ${IRQ_CHECK}% (hardware limited to 16 MSI-X vectors)"
        fi
    fi
fi

# Check nvme1 configuration
if [ -f /sys/block/nvme1n1/queue/read_ahead_kb ]; then
    NVME1_RA=$(cat /sys/block/nvme1n1/queue/read_ahead_kb)
    NVME1_QD=$(cat /sys/block/nvme1n1/queue/nr_requests)
    NVME1_QUEUES=$(cat /sys/class/nvme/nvme1/queue_count 2>/dev/null || echo "N/A")
    NVME1_WRITE_QUEUES=$(cat /sys/module/nvme/parameters/write_queues 2>/dev/null || echo "N/A")
    
    echo -e "  ${BLUE}nvme1:${NC} $NVME1_QUEUES queues (${NVME1_WRITE_QUEUES} write), QD=$NVME1_QD, RA=${NVME1_RA}KB"
    
    if [ "$NVME1_WRITE_QUEUES" -eq 16 ] && [ "$NVME1_QUEUES" -gt 40 ]; then
        echo -e "         ${GREEN}✓${NC} Fully optimized (excellent hardware: 65 MSI-X vectors)"
    fi
fi

# Check if nvme1 is mounted
NVME1_MOUNT=$(findmnt -n -o TARGET -S /dev/nvme1n1p1 2>/dev/null)
if [ -n "$NVME1_MOUNT" ]; then
    echo -e "         ${GREEN}✓${NC} Mounted at: $NVME1_MOUNT (ready for high-performance I/O)"
else
    echo -e "         ${YELLOW}ℹ${NC} Not mounted (mount at /mnt/fast for performance workloads)"
fi

echo ""
echo -e "${BOLD}Boot Options:${NC}"
echo -e "  • Hold ${BOLD}SHIFT${NC} at boot to access GRUB menu"
echo -e "  • Primary system: ${GREEN}Ubuntu${NC} (nvme0 - default)"
echo -e "  • Backup system:  ${YELLOW}Ubuntu 22.04.5 LTS (on /dev/sdd2)${NC}"

if [ "$BOOT_SYSTEM" == "primary" ]; then
    echo ""
    echo -e "${BOLD}Optimization Notes:${NC}"
    echo -e "  ${YELLOW}⚠${NC} Primary drive (nvme0) has hardware limitations:"
    echo -e "    • Intel 660P supports only 16 MSI-X vectors (max 9 queues)"
    echo -e "    • Kernel parameter nvme.write_queues=16 cannot increase this"
    echo -e "    • IRQ concentration on nvme0q8 (~73%) is unavoidable"
    echo ""
    echo -e "  ${GREEN}✓${NC} Recommended usage:"
    echo -e "    • Use nvme0 for: OS, applications, general daily work"
    echo -e "    • Use nvme1 for: Heavy I/O (dev, video, VMs, databases)"
    echo -e "    • nvme1 has superior hardware (65 MSI-X, 49 queues, TLC NAND)"
fi

echo ""
echo -e "${BOLD}Documentation:${NC}"
echo -e "  → Full analysis: ~/programs/vscode_performance_fix_20251018_032616/"
echo -e "    • FINAL_COMPLETE_SYSTEM_ANALYSIS.md (complete overview)"
echo -e "    • EFI_GRUB_STUB_FIX.md (boot configuration fix)"
echo -e "    • DUAL_NVME_IRQ_ANALYSIS.md (performance analysis)"

echo ""
echo -e "${GREEN}System optimized on October 18, 2025${NC}"
echo ""
