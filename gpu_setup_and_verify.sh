#!/bin/bash
# GPU Configuration Verification and Chrome Hardware Acceleration Setup
# Makes RTX 3060 primary display, RTX 3080 for compute workloads

echo "=== GPU CONFIGURATION VERIFICATION ==="
echo ""

echo "1. Current GPU Status:"
nvidia-smi --query-gpu=index,name,pci.bus_id,memory.total,power.draw --format=csv,noheader

echo ""
echo "2. Display GPU Assignment:"
nvidia-smi --query-gpu=index,name,display_active --format=csv,noheader

echo ""
echo "3. GPU Memory Usage:"
nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader

echo ""
echo "4. Xorg Processes:"
nvidia-smi | grep Xorg

echo ""
echo "=== EXPECTED RESULTS AFTER REBOOT ==="
echo "✓ RTX 3060 (GPU 1): Should show 'Disp.A = On' with high Xorg memory"
echo "✓ RTX 3080 (GPU 0): Should show minimal/no Xorg usage (idle for ML)"
echo ""

echo "=== X11 CONFIGURATION ==="
echo "Current config file:"
cat /etc/X11/xorg.conf.d/10-nvidia-primary-3060.conf

echo ""
echo "=== CHROME HARDWARE ACCELERATION CHECK ==="
echo ""
echo "After reboot and verifying GPU assignment:"
echo "1. Open Chrome"
echo "2. Go to: chrome://gpu"
echo "3. Verify 'Graphics Feature Status' shows 'Hardware accelerated'"
echo "4. Check 'GL_RENDERER' shows RTX 3060"
echo ""
echo "Then enable in Chrome settings:"
echo "  Settings → System → Enable 'Use hardware acceleration when available'"
echo "  Restart Chrome"
echo ""

echo "=== NEXT STEPS ==="
echo ""
echo "1. REBOOT SYSTEM: sudo reboot"
echo "2. After reboot, run: nvidia-smi"
echo "3. Verify RTX 3060 is primary (high Xorg memory usage on GPU 1)"
echo "4. Enable Chrome hardware acceleration"
echo "5. Disable Adblock Plus (306MB) → Install uBlock Origin instead"
echo ""
