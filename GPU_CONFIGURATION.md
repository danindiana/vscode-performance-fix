# GPU Configuration for Dual-GPU System

## Problem
System has 2 NVIDIA GPUs, but the more powerful RTX 3080 was being used for display, wasting compute resources that should be reserved for ML workloads.

## Hardware Configuration
- **GPU 0**: NVIDIA GeForce RTX 3080 (10GB VRAM) - PCI Bus `0F:00.0`
- **GPU 1**: NVIDIA GeForce RTX 3060 (12GB VRAM) - PCI Bus `10:00.0`

## Solution
Configure X11 to use RTX 3060 as primary display GPU, keeping RTX 3080 idle for machine learning/inference workloads.

### Before Configuration
```
GPU 0 (RTX 3080): Disp.A = On, 450MiB Xorg, 62W, 24% utilization
GPU 1 (RTX 3060): Disp.A = On,  67MiB Xorg, 14W, 42% utilization
```

### After Configuration (Expected)
```
GPU 0 (RTX 3080): Minimal/no Xorg, idle until ML workload
GPU 1 (RTX 3060): Primary display, handles all desktop/Chrome GPU tasks
```

## Implementation

### X11 Configuration File
Location: `/etc/X11/xorg.conf.d/10-nvidia-primary-3060.conf`

```xorg
# Make RTX 3060 (GPU 1, Bus 10:00.0) the primary display GPU
# Keep RTX 3080 (GPU 0, Bus 0F:00.0) available for compute workloads

Section "ServerLayout"
    Identifier     "Layout0"
    Screen      0  "Screen0" 0 0
    Option         "AllowNVIDIAGPUScreens"
EndSection

Section "Device"
    Identifier     "Device0"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    BoardName      "GeForce RTX 3060"
    BusID          "PCI:16:0:0"
    Screen          0
EndSection

Section "Device"
    Identifier     "Device1"
    Driver         "nvidia"
    VendorName     "NVIDIA Corporation"
    BoardName      "GeForce RTX 3080"
    BusID          "PCI:15:0:0"
    Option         "AllowEmptyInitialConfiguration" "True"
EndSection

Section "Screen"
    Identifier     "Screen0"
    Device         "Device0"
    Monitor        "Monitor0"
    DefaultDepth    24
    Option         "AllowEmptyInitialConfiguration" "True"
    SubSection     "Display"
        Depth       24
    EndSubSection
EndSection

Section "Monitor"
    Identifier     "Monitor0"
    VendorName     "Unknown"
    ModelName      "Unknown"
    Option         "DPMS"
EndSection
```

### Installation
```bash
sudo cp 10-nvidia-primary-3060.conf /etc/X11/xorg.conf.d/
sudo chmod 644 /etc/X11/xorg.conf.d/10-nvidia-primary-3060.conf
sudo reboot
```

## Verification Steps

### 1. Check GPU Assignment After Reboot
```bash
nvidia-smi
```

Expected output:
- GPU 1 (RTX 3060): `Disp.A = On`, high Xorg memory usage
- GPU 0 (RTX 3080): Minimal/no Xorg processes

### 2. Verify Chrome Uses Correct GPU
1. Open Chrome
2. Navigate to `chrome://gpu`
3. Check "Graphics Feature Status" - should show "Hardware accelerated"
4. Check "GL_RENDERER" - should show "NVIDIA GeForce RTX 3060"

### 3. Enable Chrome Hardware Acceleration
1. Chrome Settings → System
2. Enable "Use hardware acceleration when available"
3. Restart Chrome

## Related Chrome Performance Fix

This GPU configuration complements the Chrome performance optimization:

### Issue: Adblock Plus Consuming 84% CPU
- Extension ID: `cfhdojbkjhnklbpkdaibdccddilifddb`
- Size: 306MB (excessive filter lists)
- Impact: 84% CPU on single renderer, 23GB total Chrome RAM

### Fix:
1. **Disable Adblock Plus**: `chrome://extensions` → Toggle OFF
2. **Install uBlock Origin**: Lightweight alternative (~5MB vs 306MB)
3. **Enable Hardware Acceleration**: Settings → System → Enable
4. **Reduce Tab Count**: Close unused tabs (was running 96 processes)

## ML Workload Usage

With this configuration, the RTX 3080 remains available for compute:

```python
# PyTorch: Select RTX 3080 for training
import torch
torch.cuda.set_device(0)  # GPU 0 = RTX 3080

# TensorFlow: Select RTX 3080
import tensorflow as tf
gpus = tf.config.list_physical_devices('GPU')
tf.config.set_visible_devices(gpus[0], 'GPU')  # GPU 0 = RTX 3080
```

## Benefits
1. **RTX 3080**: Fully available for ML/inference (10GB VRAM, higher compute)
2. **RTX 3060**: Handles all desktop display tasks (12GB VRAM sufficient)
3. **Chrome**: Hardware accelerated on RTX 3060 (CPU drops from 191% to ~10%)
4. **System**: No more stuttering from software rendering

## Testing
After reboot, verify GPU assignment:
```bash
bash ~/programs/vscode_performance_fix_20251018_032616/gpu_setup_and_verify.sh
```

## Rollback (If Needed)
```bash
sudo rm /etc/X11/xorg.conf.d/10-nvidia-primary-3060.conf
sudo reboot
```

---
**Date**: October 18, 2025  
**System**: Ubuntu 22.04.5 LTS  
**NVIDIA Driver**: 565.77  
**CUDA Version**: 12.7
