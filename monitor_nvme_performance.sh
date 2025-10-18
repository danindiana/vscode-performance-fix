#!/bin/bash
# Monitor NVMe interrupt distribution and I/O performance

echo "=== NVMe Performance Monitor ==="
echo "Press Ctrl+C to exit"
echo ""

NVME_DEV="nvme1n1"

while true; do
    clear
    echo "=== NVMe1 (Intel 660P - Boot Drive) Monitoring ==="
    echo "Time: $(date '+%H:%M:%S')"
    echo ""
    
    # Interrupt distribution
    echo "Interrupt Distribution:"
    cat /proc/interrupts | grep "nvme1q" | head -8 | awk '{
        sum=0; 
        for(i=2;i<=NF-3;i++) sum+=$i; 
        gsub(":", "", $1);
        printf "  IRQ %3s (%s): %10d interrupts\n", $1, $NF, sum
    }'
    
    # Calculate percentage
    echo ""
    echo "Queue Load Distribution:"
    cat /proc/interrupts | grep "nvme1q[0-9]$" | awk '
    BEGIN {total=0}
    {
        sum=0;
        for(i=2;i<=NF-3;i++) sum+=$i;
        queue[NR]=sum;
        total+=sum;
    }
    END {
        for(i=1;i<=NR;i++) {
            pct = (total>0) ? (queue[i]/total)*100 : 0;
            printf "  Queue %d: %6.2f%% ", i-1, pct;
            # Visual bar
            bars = int(pct/2);
            for(j=0;j<bars;j++) printf "█";
            printf "\n";
        }
    }'
    
    echo ""
    echo "Current I/O Stats (1 sec sample):"
    iostat -x $NVME_DEV 1 2 | tail -2 | head -1 | awk '{
        printf "  r/s: %6.1f  w/s: %6.1f  rkB/s: %8.1f  wkB/s: %8.1f\n", $4, $5, $6, $7;
        printf "  await: %6.2f ms  %%util: %5.1f%%\n", $(NF-3), $NF;
    }'
    
    echo ""
    echo "Scheduler: $(cat /sys/block/$NVME_DEV/queue/scheduler | grep -o '\[.*\]' | tr -d '[]')"
    echo "Queue Depth: $(cat /sys/block/$NVME_DEV/queue/nr_requests)"
    echo "Read-ahead: $(cat /sys/block/$NVME_DEV/queue/read_ahead_kb) KB"
    
    echo ""
    echo "---"
    echo "Refreshing in 2 seconds..."
    sleep 2
done
