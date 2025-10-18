#!/bin/bash
# Complete Status Check - VS Code GPU Acceleration

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║         VS Code GPU Acceleration Status Report                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Generated: $(date)"
echo ""

# 1. Settings Check
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. SETTINGS CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SETTING=$(grep "terminal.integrated.gpuAcceleration" ~/.config/Code/User/settings.json)
echo "   $SETTING"
if echo "$SETTING" | grep -q '"auto"\|"on"'; then
    echo "   Status: ✅ ENABLED"
else
    echo "   Status: ❌ DISABLED"
fi
echo ""

# 2. GPU Assignment
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. GPU ASSIGNMENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,display_active --format=csv,noheader | \
while IFS=, read -r idx name mem_used mem_total util display; do
    echo "   GPU $idx: $name"
    echo "      Memory: $mem_used /$mem_total"
    echo "      Utilization: $util"
    echo "      Display: $display"
    
    if [ "$idx" = "0" ]; then
        if echo "$display" | grep -q "Disabled"; then
            echo "      Role: ✅ Reserved for ML/Inference"
        else
            echo "      Role: ⚠️  Display active (should be disabled)"
        fi
    else
        if echo "$display" | grep -q "Enabled"; then
            echo "      Role: ✅ Primary Display + Terminal Rendering"
        else
            echo "      Role: ⚠️  Display inactive"
        fi
    fi
    echo ""
done

# 3. VS Code GPU Usage
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. VS CODE GPU USAGE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CODE_GPU=$(nvidia-smi | grep code | tail -1)
if [ -n "$CODE_GPU" ]; then
    echo "   $CODE_GPU"
    VRAM=$(echo "$CODE_GPU" | awk '{print $(NF-1)}')
    echo ""
    echo "   VS Code VRAM Usage: $VRAM"
    echo "   Status: ✅ Using GPU for rendering"
else
    echo "   ⚠️  VS Code not detected in GPU process list"
fi
echo ""

# 4. Hardware Acceleration Features
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. HARDWARE ACCELERATION FEATURES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
code --status 2>/dev/null | grep -A 20 "GPU Status:" | grep -E "enabled|disabled" | \
while IFS=: read -r feature status; do
    feature_clean=$(echo "$feature" | xargs)
    status_clean=$(echo "$status" | xargs)
    
    if echo "$status_clean" | grep -q "enabled"; then
        echo "   ✅ $feature_clean"
    else
        echo "   ❌ $feature_clean: $status_clean"
    fi
done
echo ""

# 5. Performance Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. PERFORMANCE SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
VSCODE_PID=$(pgrep -f "/usr/share/code/code" | head -1)
if [ -n "$VSCODE_PID" ]; then
    ps -p $VSCODE_PID -o %cpu,%mem,rss --no-headers | \
    while read cpu mem rss; do
        echo "   CPU Usage: $cpu%"
        echo "   RAM Usage: $mem% ($(echo "scale=0; $rss/1024" | bc) MB)"
    done
fi
echo ""

# 6. Recommendations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. NEXT STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   [ ] Enable Chrome hardware acceleration"
echo "   [ ] Disable/replace Adblock Plus (306MB, 84% CPU)"
echo "   [ ] Monitor terminal performance improvements"
echo "   [ ] Push documentation to GitHub"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
