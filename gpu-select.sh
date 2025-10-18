#!/bin/bash
# GPU Selection Helper Script
# Makes it easy to run commands on specific GPUs

show_usage() {
    cat << EOF
GPU Selection Helper

Current Configuration:
  GPU 0: RTX 3080 10GB - Display DISABLED (for ML/inference)
  GPU 1: RTX 3060 12GB - Display ENABLED (primary display)

Usage:
  $0 [gpu-number] [command]
  $0 status          # Show GPU status
  $0 3080 [command]  # Run on RTX 3080 (GPU 0)
  $0 3060 [command]  # Run on RTX 3060 (GPU 1)
  $0 0 [command]     # Run on GPU 0
  $0 1 [command]     # Run on GPU 1

Examples:
  $0 status
  $0 3080 python train.py
  $0 0 python inference.py
  $0 3060 python data_prep.py

EOF
}

if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

case "$1" in
    status)
        echo "=== GPU Status ==="
        nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,power.draw,display_active --format=csv
        echo ""
        echo "=== Process List ==="
        nvidia-smi pmon -c 1
        ;;
    3080|0)
        shift
        echo "Running on RTX 3080 (GPU 0): $@"
        CUDA_VISIBLE_DEVICES=0 "$@"
        ;;
    3060|1)
        shift
        echo "Running on RTX 3060 (GPU 1): $@"
        CUDA_VISIBLE_DEVICES=1 "$@"
        ;;
    -h|--help)
        show_usage
        ;;
    *)
        echo "Error: Invalid GPU selection '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac
