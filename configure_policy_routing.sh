#!/bin/bash
#
# Policy-Based Routing Configuration
# Prevents asymmetric routing by ensuring each NIC handles its own traffic
#
# Date: 2025-10-18
# Purpose: Enable all 3 NICs without multipath routing issues
#
# NIC Priority:
#   1. enp3s0f0 (10G port 0) - 192.168.1.64  - PRIMARY (default traffic)
#   2. enp3s0f1 (10G port 1) - 192.168.1.113 - SECONDARY (specific apps)
#   3. enp9s0 (onboard)      - 192.168.1.85  - TERTIARY (fallback/background)

# Note: NOT using 'set -e' to allow idempotent operation

echo "=========================================="
echo "Policy-Based Routing Configuration"
echo "Prevents asymmetric routing issues"
echo "=========================================="
echo ""

# Interface configuration
PRIMARY_IF="enp3s0f0"
PRIMARY_IP="192.168.1.64"
PRIMARY_TABLE="100"

SECONDARY_IF="enp3s0f1"
SECONDARY_IP="192.168.1.113"
SECONDARY_TABLE="101"

TERTIARY_IF="enp9s0"
TERTIARY_IP="192.168.1.85"
TERTIARY_TABLE="102"

GATEWAY="192.168.1.254"

echo "Step 1: Clean up existing policy routing rules"
echo "----------------------------------------------"

# Remove old policy routing rules (ignore errors if they don't exist)
ip rule del from $PRIMARY_IP table $PRIMARY_TABLE 2>/dev/null || true
ip rule del from $SECONDARY_IP table $SECONDARY_TABLE 2>/dev/null || true
ip rule del from $TERTIARY_IP table $TERTIARY_TABLE 2>/dev/null || true

# Remove old routing tables
ip route flush table $PRIMARY_TABLE 2>/dev/null || true
ip route flush table $SECONDARY_TABLE 2>/dev/null || true
ip route flush table $TERTIARY_TABLE 2>/dev/null || true

echo "✓ Cleaned old rules"
echo ""

echo "Step 2: Remove multipath default route"
echo "---------------------------------------"

# Remove the problematic multipath route
ip route del default 2>/dev/null || true

echo "✓ Removed multipath routing"
echo ""

echo "Step 3: Create dedicated routing tables for each NIC"
echo "-----------------------------------------------------"

# PRIMARY (enp3s0f0) - Main routing table
ip route add default via $GATEWAY dev $PRIMARY_IF metric 100 2>/dev/null || true
ip route add $PRIMARY_IP dev $PRIMARY_IF src $PRIMARY_IP table $PRIMARY_TABLE 2>/dev/null || true
ip route add default via $GATEWAY dev $PRIMARY_IF table $PRIMARY_TABLE 2>/dev/null || true

echo "✓ PRIMARY table $PRIMARY_TABLE: $PRIMARY_IF ($PRIMARY_IP)"

# SECONDARY (enp3s0f1) - Separate routing table
ip route add $SECONDARY_IP dev $SECONDARY_IF src $SECONDARY_IP table $SECONDARY_TABLE 2>/dev/null || true
ip route add default via $GATEWAY dev $SECONDARY_IF table $SECONDARY_TABLE 2>/dev/null || true

echo "✓ SECONDARY table $SECONDARY_TABLE: $SECONDARY_IF ($SECONDARY_IP)"

# TERTIARY (enp9s0) - Separate routing table
ip route add $TERTIARY_IP dev $TERTIARY_IF src $TERTIARY_IP table $TERTIARY_TABLE 2>/dev/null || true
ip route add default via $GATEWAY dev $TERTIARY_IF table $TERTIARY_TABLE 2>/dev/null || true

echo "✓ TERTIARY table $TERTIARY_TABLE: $TERTIARY_IF ($TERTIARY_IP)"
echo ""

echo "Step 4: Add policy routing rules (source-based)"
echo "------------------------------------------------"

# Traffic FROM each IP uses its own routing table
# This ensures symmetric routing (TX and RX on same NIC)
ip rule add from $PRIMARY_IP table $PRIMARY_TABLE priority 100 2>/dev/null || true
ip rule add from $SECONDARY_IP table $SECONDARY_TABLE priority 101 2>/dev/null || true
ip rule add from $TERTIARY_IP table $TERTIARY_TABLE priority 102 2>/dev/null || true

echo "✓ Policy rules created:"
echo "  - Traffic FROM $PRIMARY_IP   → table $PRIMARY_TABLE (via $PRIMARY_IF)"
echo "  - Traffic FROM $SECONDARY_IP → table $SECONDARY_TABLE (via $SECONDARY_IF)"
echo "  - Traffic FROM $TERTIARY_IP  → table $TERTIARY_TABLE (via $TERTIARY_IF)"
echo ""

echo "Step 5: Set route metrics (priority order)"
echo "-------------------------------------------"

# Adjust metrics so system prefers PRIMARY for new connections
# Lower metric = higher priority
ip route add default via $GATEWAY dev $PRIMARY_IF metric 100 2>/dev/null || true
ip route add default via $GATEWAY dev $SECONDARY_IF metric 200 2>/dev/null || true
ip route add default via $GATEWAY dev $TERTIARY_IF metric 300 2>/dev/null || true

echo "✓ Route priorities set:"
echo "  1. $PRIMARY_IF (metric 100) - HIGHEST priority for new connections"
echo "  2. $SECONDARY_IF (metric 200)"
echo "  3. $TERTIARY_IF (metric 300) - LOWEST priority (background/fallback)"
echo ""

echo "Step 6: Enable reverse path filtering (loose mode)"
echo "---------------------------------------------------"

# Loose mode allows packets to arrive on different interfaces
# but still validates they came from a valid route
for iface in $PRIMARY_IF $SECONDARY_IF $TERTIARY_IF; do
    sysctl -w net.ipv4.conf.$iface.rp_filter=2 >/dev/null
done

echo "✓ Reverse path filtering set to loose mode (allows multi-NIC)"
echo ""

echo "Step 7: Flush routing cache"
echo "----------------------------"

ip route flush cache 2>/dev/null || true
echo "✓ Routing cache flushed"
echo ""

echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Current routing table:"
ip route show
echo ""
echo "Policy routing rules:"
ip rule show
echo ""
echo "=========================================="
echo "How This Works:"
echo "=========================================="
echo ""
echo "1. NEW connections use PRIMARY ($PRIMARY_IF) by default"
echo "   - Lowest metric = highest priority"
echo "   - Most traffic uses this NIC"
echo ""
echo "2. Each NIC's traffic stays on that NIC"
echo "   - Packets sent FROM $PRIMARY_IP use $PRIMARY_IF"
echo "   - Packets sent FROM $SECONDARY_IP use $SECONDARY_IF"
echo "   - Packets sent FROM $TERTIARY_IP use $TERTIARY_IF"
echo "   - NO ASYMMETRIC ROUTING!"
echo ""
echo "3. To use a specific NIC for an application:"
echo "   - Bind to that NIC's IP address"
echo "   - Example: wget --bind-address=$SECONDARY_IP http://example.com"
echo ""
echo "4. Fallback behavior:"
echo "   - If PRIMARY fails, system tries SECONDARY"
echo "   - If SECONDARY fails, system tries TERTIARY"
echo ""
echo "=========================================="
echo "Testing Commands:"
echo "=========================================="
echo ""
echo "# Test PRIMARY route:"
echo "ip route get 8.8.8.8 from $PRIMARY_IP"
echo ""
echo "# Test SECONDARY route:"
echo "ip route get 8.8.8.8 from $SECONDARY_IP"
echo ""
echo "# Test TERTIARY route:"
echo "ip route get 8.8.8.8 from $TERTIARY_IP"
echo ""
echo "# Monitor traffic per NIC:"
echo "watch -n 1 'iftop -t -s 1 -i $PRIMARY_IF 2>&1 | head -10'"
echo ""
echo "=========================================="
