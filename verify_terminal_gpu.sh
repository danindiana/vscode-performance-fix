#!/bin/bash
# Verify Terminal GPU Acceleration is Enabled

echo "=== VS Code Terminal GPU Acceleration Verification ==="
echo ""

# Check settings.json
echo "1. Checking settings.json..."
SETTING=$(grep "terminal.integrated.gpuAcceleration" ~/.config/Code/User/settings.json)
echo "   $SETTING"

if echo "$SETTING" | grep -q '"auto"'; then
    echo "   ✅ Terminal GPU acceleration is set to 'auto'"
elif echo "$SETTING" | grep -q '"on"'; then
    echo "   ✅ Terminal GPU acceleration is set to 'on'"
elif echo "$SETTING" | grep -q '"off"'; then
    echo "   ❌ Terminal GPU acceleration is DISABLED"
else
    echo "   ⚠️  Setting not found"
fi
echo ""

# Check if VS Code is running
echo "2. Checking VS Code processes..."
VSCODE_PIDS=$(pgrep -f "/usr/share/code/code" | wc -l)
if [ "$VSCODE_PIDS" -gt 0 ]; then
    echo "   ✅ VS Code is running ($VSCODE_PIDS processes)"
    echo "   ⚠️  RESTART REQUIRED: You need to reload VS Code window for changes to take effect"
    echo ""
    echo "   How to reload:"
    echo "   - Press Ctrl+Shift+P"
    echo "   - Type: 'Developer: Reload Window'"
    echo "   - Press Enter"
else
    echo "   ℹ️  VS Code is not currently running"
fi
echo ""

# Monitor GPU usage
echo "3. Current GPU status..."
nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv
echo ""

echo "=== Next Steps ==="
echo "1. Reload VS Code window (Ctrl+Shift+P → 'Developer: Reload Window')"
echo "2. Open a new terminal in VS Code"
echo "3. Run: ./monitor_vscode_gpu.sh (to verify GPU usage)"
echo "4. Test with heavy terminal output: ls -lR / | head -1000"
echo ""
echo "Expected result: Terminal rendering should now use GPU instead of CPU"
