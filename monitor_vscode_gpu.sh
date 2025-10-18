#!/bin/bash
# VS Code GPU Usage Monitor
# Monitors VS Code's GPU utilization in real-time

echo "=== VS Code GPU Monitoring ==="
echo "Press Ctrl+C to stop"
echo ""

# Find VS Code process
VSCODE_PID=$(pgrep -f "/usr/share/code/code" | head -1)

if [ -z "$VSCODE_PID" ]; then
    echo "❌ VS Code is not running"
    exit 1
fi

echo "✓ VS Code PID: $VSCODE_PID"
echo ""

# Monitor loop
while true; do
    clear
    echo "=== VS Code GPU Usage Monitor ==="
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # GPU Memory
    echo "=== GPU Memory Usage ==="
    nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader | grep code || echo "No compute usage"
    echo ""
    
    # GPU Utilization
    echo "=== GPU Utilization (last 5 seconds) ==="
    nvidia-smi pmon -c 5 -s um 2>/dev/null | grep code || echo "No GPU activity"
    echo ""
    
    # VS Code Process Stats
    echo "=== VS Code Process Stats ==="
    ps -p $VSCODE_PID -o pid,ppid,%cpu,%mem,vsz,rss,cmd --no-headers 2>/dev/null || echo "Process ended"
    echo ""
    
    # GPU Status Summary
    echo "=== GPU Status ==="
    nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader
    echo ""
    
    echo "Refreshing in 5 seconds... (Ctrl+C to stop)"
    sleep 5
done
