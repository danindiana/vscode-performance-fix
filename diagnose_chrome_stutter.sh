#!/bin/bash

echo "═══════════════════════════════════════════════════════════════"
echo "        CHROME STUTTERING INVESTIGATION"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "1. TOP CPU-CONSUMING CHROME PROCESSES"
echo "───────────────────────────────────────────────────────────────"
ps aux --sort=-%cpu | grep -i chrome | grep -v grep | head -10 | while read line; do
    pid=$(echo $line | awk '{print $2}')
    cpu=$(echo $line | awk '{print $3}')
    cmd=$(echo $line | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}')
    
    # Try to get more info about the process
    if [[ $cmd == *"--type=renderer"* ]]; then
        type="RENDERER (Tab/Extension)"
    elif [[ $cmd == *"--type=gpu"* ]]; then
        type="GPU Process"
    elif [[ $cmd == *"--type=browser"* ]]; then
        type="Main Browser"
    elif [[ $cmd == *"--type=utility"* ]]; then
        type="Utility Process"
    else
        type="Other"
    fi
    
    printf "PID: %-7s CPU: %5s%%  Type: %s\n" "$pid" "$cpu" "$type"
done

echo ""
echo "2. DETAILED VIEW OF WORST OFFENDER"
echo "───────────────────────────────────────────────────────────────"
worst_pid=$(ps aux --sort=-%cpu | grep -i chrome | grep -v grep | head -1 | awk '{print $2}')
worst_cpu=$(ps aux --sort=-%cpu | grep -i chrome | grep -v grep | head -1 | awk '{print $3}')

echo "Worst process: PID $worst_pid consuming $worst_cpu% CPU"
echo ""
echo "Command line:"
cat /proc/$worst_pid/cmdline 2>/dev/null | tr '\0' '\n' | grep -E "type|extension|url" | head -5
echo ""

echo "3. CHROME EXTENSIONS INSTALLED"
echo "───────────────────────────────────────────────────────────────"
if [ -d ~/.config/google-chrome/Default/Extensions ]; then
    echo "Extensions count: $(ls ~/.config/google-chrome/Default/Extensions | wc -l)"
    echo ""
    echo "Top 10 by size:"
    du -sh ~/.config/google-chrome/Default/Extensions/* 2>/dev/null | sort -rh | head -10
fi

echo ""
echo "4. SYSTEM IMPACT"
echo "───────────────────────────────────────────────────────────────"
echo "Total Chrome CPU usage: $(ps aux | grep -i chrome | grep -v grep | awk '{sum+=$3} END {printf "%.1f%%\n", sum}')"
echo "Total Chrome memory: $(ps aux | grep -i chrome | grep -v grep | awk '{sum+=$6} END {printf "%.1f MB\n", sum/1024}')"
echo "Chrome process count: $(ps aux | grep -i chrome | grep -v grep | wc -l)"
echo ""
echo "System load: $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "        RECOMMENDATIONS"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "IMMEDIATE ACTION:"
echo "  1. Open Chrome"
echo "  2. Press Shift+Esc (Chrome Task Manager)"
echo "  3. Sort by CPU column"
echo "  4. Identify the tab/extension consuming most CPU"
echo "  5. Select it and click 'End process'"
echo ""
echo "COMMON CULPRITS:"
echo "  • YouTube or video streaming tabs"
echo "  • Google Docs/Sheets with auto-sync"
echo "  • Web-based development tools (CodePen, JSFiddle)"
echo "  • Cryptocurrency mining scripts"
echo "  • Auto-refreshing pages or extensions"
echo "  • Poorly optimized React/Angular apps"
echo "  • Chrome extensions: ad blockers, auto-refresh, feed readers"
echo ""
echo "LONG-TERM FIXES:"
echo "  • Disable unused extensions"
echo "  • Use 'The Great Suspender' extension to suspend inactive tabs"
echo "  • Enable hardware acceleration (if disabled)"
echo "  • Clear browsing data and cache"
echo "  • Update Chrome to latest version"
echo "═══════════════════════════════════════════════════════════════"
