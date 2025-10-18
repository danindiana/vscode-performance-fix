#!/bin/bash

echo "=== DIAGNOSING SYSTEM-WIDE FREEZE ON FILE SAVE ==="
echo ""

echo "1. CHECKING DISK I/O SCHEDULER"
echo "─────────────────────────────────────────────────────────────"
for disk in /sys/block/sd*/queue/scheduler; do
    if [ -f "$disk" ]; then
        echo "$disk: $(cat $disk)"
    fi
done
for disk in /sys/block/nvme*/queue/scheduler; do
    if [ -f "$disk" ]; then
        echo "$disk: $(cat $disk)"
    fi
done
echo ""

echo "2. CHECKING MOUNT OPTIONS (looking for 'sync')"
echo "─────────────────────────────────────────────────────────────"
mount | grep -E "^/dev" | grep -E "ext4|btrfs|xfs|ntfs"
echo ""

echo "3. CHECKING SYSTEM SWAPPINESS"
echo "─────────────────────────────────────────────────────────────"
echo "vm.swappiness = $(cat /proc/sys/vm/swappiness)"
echo "Current swap usage:"
free -h | grep Swap
echo ""

echo "4. CHECKING DIRTY PAGE WRITEBACK SETTINGS"
echo "─────────────────────────────────────────────────────────────"
echo "vm.dirty_ratio = $(cat /proc/sys/vm/dirty_ratio) (default: 20)"
echo "vm.dirty_background_ratio = $(cat /proc/sys/vm/dirty_background_ratio) (default: 10)"
echo "vm.dirty_writeback_centisecs = $(cat /proc/sys/vm/dirty_writeback_centisecs) (default: 500)"
echo "vm.dirty_expire_centisecs = $(cat /proc/sys/vm/dirty_expire_centisecs) (default: 3000)"
echo ""

echo "5. CHECKING VS CODE AUTO-SAVE SETTINGS"
echo "─────────────────────────────────────────────────────────────"
if [ -f ~/.config/Code/User/settings.json ]; then
    echo "Auto-save setting:"
    grep -i "files.autoSave" ~/.config/Code/User/settings.json || echo "  Not configured (default: off)"
    echo ""
    echo "Save participants (can cause sync delays):"
    grep -iE "formatOnSave|organizeImports|codeActions" ~/.config/Code/User/settings.json || echo "  None found"
fi
echo ""

echo "6. CHECKING FOR DISK ERRORS IN DMESG (last 20 lines)"
echo "─────────────────────────────────────────────────────────────"
dmesg 2>/dev/null | grep -iE "error|fail|ata|scsi|nvme|I/O" | tail -20 || echo "  (Need sudo for dmesg)"
echo ""

echo "7. CHECKING ACTIVE EXTENSIONS THAT MIGHT SYNC"
echo "─────────────────────────────────────────────────────────────"
ls ~/.vscode/extensions/ 2>/dev/null | grep -iE "sync|backup|git|save" | head -10 || echo "  No extensions directory found"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "MOST LIKELY CAUSES OF 2-3 SECOND FREEZE ON SAVE:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1. VS CODE EXTENSIONS doing heavy processing on save:"
echo "   - Formatters (Prettier, Black, etc.)"
echo "   - Linters (ESLint, Pylint, etc.)"
echo "   - Git auto-commit/sync extensions"
echo "   Fix: Disable 'formatOnSave' or problematic extensions"
echo ""
echo "2. FILESYSTEM MOUNTED WITH 'SYNC' FLAG:"
echo "   Check mount output above for 'sync' keyword"
echo "   Fix: Remount without sync (requires sudo)"
echo ""
echo "3. DIRTY PAGE RATIO TOO LOW (if < 5):"
echo "   Check vm.dirty_background_ratio above"
echo "   Fix: Increase to 10-15 (requires sudo)"
echo ""
echo "4. SLOW/FAILING DISK:"
echo "   Check dmesg for I/O errors"
echo "   Fix: Run SMART check, consider SSD upgrade"
echo ""
echo "5. ANTI-VIRUS OR FILE MONITORING SOFTWARE:"
echo "   Real-time scanning can block writes"
echo "   Fix: Exclude workspace from scanning"
echo "═══════════════════════════════════════════════════════════════"
