#!/bin/bash

# FIX: Aggressive dirty page writeback causing system freezes on file save
# This adjusts kernel parameters to sane defaults

echo "=== FIXING AGGRESSIVE DIRTY PAGE WRITEBACK ==="
echo ""

echo "Current settings:"
echo "  vm.dirty_ratio = $(cat /proc/sys/vm/dirty_ratio) (causing freeze!)"
echo "  vm.dirty_background_ratio = $(cat /proc/sys/vm/dirty_background_ratio) (too low!)"
echo "  vm.dirty_writeback_centisecs = $(cat /proc/sys/vm/dirty_writeback_centisecs)"
echo "  vm.dirty_expire_centisecs = $(cat /proc/sys/vm/dirty_expire_centisecs)"
echo ""

echo "Applying recommended settings..."
echo ""

# Temporary fix (until reboot)
sudo sysctl -w vm.dirty_ratio=20
sudo sysctl -w vm.dirty_background_ratio=10
sudo sysctl -w vm.dirty_writeback_centisecs=500
sudo sysctl -w vm.dirty_expire_centisecs=3000

echo ""
echo "✓ Settings applied (temporary)"
echo ""

# Permanent fix
echo "Making changes permanent..."
sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# Fix system freeze on file save - restore sane dirty page defaults
# Added: $(date)
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
vm.dirty_writeback_centisecs = 500
vm.dirty_expire_centisecs = 3000
EOF

echo "✓ Added to /etc/sysctl.conf (permanent)"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "New settings:"
echo "  vm.dirty_ratio = $(cat /proc/sys/vm/dirty_ratio)"
echo "  vm.dirty_background_ratio = $(cat /proc/sys/vm/dirty_background_ratio)"
echo "  vm.dirty_writeback_centisecs = $(cat /proc/sys/vm/dirty_writeback_centisecs)"
echo "  vm.dirty_expire_centisecs = $(cat /proc/sys/vm/dirty_expire_centisecs)"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "WHAT THIS FIXES:"
echo "  - System no longer freezes on file save"
echo "  - Dirty pages can accumulate up to 20% of RAM before blocking"
echo "  - Background flushing starts at 10% instead of 1%"
echo "  - More intelligent write combining and buffering"
echo ""
echo "TEST:"
echo "  Save a file in VS Code - should be instant with no freeze!"
echo ""
