#!/bin/bash

echo "=== INVESTIGATING REMAINING STUTTERING ==="
echo ""
echo "Date: $(date)"
echo ""

echo "1. CHECKING IF FIXES ARE ACTIVE"
echo "─────────────────────────────────────────────────────────────"
echo "Dirty page settings:"
echo "  vm.dirty_ratio = $(cat /proc/sys/vm/dirty_ratio) (should be 20)"
echo "  vm.dirty_background_ratio = $(cat /proc/sys/vm/dirty_background_ratio) (should be 10)"
echo ""

echo "Global gitignore:"
git config --global core.excludesfile || echo "  ⚠️ NOT SET!"
echo ""

echo "Current git-tracked files:"
bash ~/programs/vscode_performance_fix_20251018_032616/count_all_git_files.sh 2>/dev/null | tail -5
echo ""

echo "2. CHECKING CPU/MEMORY LOAD"
echo "─────────────────────────────────────────────────────────────"
echo "System load:"
uptime
echo ""
echo "Memory usage:"
free -h
echo ""
echo "Top CPU processes:"
ps aux --sort=-%cpu | head -10
echo ""

echo "3. CHECKING INOTIFY WATCHES"
echo "─────────────────────────────────────────────────────────────"
echo "Max user watches: $(cat /proc/sys/fs/inotify/max_user_watches)"
echo "Current watches in use:"
find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null | cut -d/ -f3 | xargs -I '{}' cat /proc/{}/cmdline 2>/dev/null | tr '\0' ' ' | grep -oE '^[^ ]+' | sort | uniq -c | sort -rn | head -10
echo ""

echo "4. CHECKING FOR DISK I/O WAIT"
echo "─────────────────────────────────────────────────────────────"
iostat -x 1 2 | tail -20
echo ""

echo "5. CHECKING VS CODE EXTENSIONS"
echo "─────────────────────────────────────────────────────────────"
echo "VS Code extensions that might cause issues:"
code --list-extensions 2>/dev/null | grep -iE "format|lint|save|sync|git" | head -10 || echo "  (code command not available)"
echo ""

echo "6. CHECKING FOR BACKGROUND PROCESSES"
echo "─────────────────────────────────────────────────────────────"
echo "Background indexers/monitors:"
ps aux | grep -iE "baloo|tracker|zeitgeist|snapd|update|packagekit" | grep -v grep || echo "  None found"
echo ""

echo "7. CHECKING SWAP USAGE"
echo "─────────────────────────────────────────────────────────────"
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
swapon --show || echo "  No swap active"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "ADDITIONAL THINGS TO CHECK:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "A. VS CODE EXTENSIONS"
echo "   Disable extensions one by one to find the culprit"
echo "   Common offenders: Formatters, linters, git tools"
echo ""
echo "B. INOTIFY LIMIT (if > 500K watches in use)"
echo "   sudo sysctl fs.inotify.max_user_watches=1048576"
echo ""
echo "C. BALOO FILE INDEXER (KDE)"
echo "   balooctl disable"
echo ""
echo "D. CHROME/BROWSER with many tabs"
echo "   Close unused tabs, check memory usage"
echo ""
echo "E. NVIDIA DRIVERS (if applicable)"
echo "   Outdated drivers can cause stuttering"
echo ""
echo "F. CPU FREQUENCY SCALING"
echo "   Check if CPU is throttling due to power saving"
echo "   cat /proc/cpuinfo | grep MHz"
echo "═══════════════════════════════════════════════════════════════"
