#!/usr/bin/env python3
"""Test GPU selection and availability"""
import torch

print("=== GPU Configuration ===")
print(f"CUDA Available: {torch.cuda.is_available()}")
print(f"GPU Count: {torch.cuda.device_count()}")
print()

for i in range(torch.cuda.device_count()):
    print(f"GPU {i}: {torch.cuda.get_device_name(i)}")
    print(f"  Memory: {torch.cuda.get_device_properties(i).total_memory / 1024**3:.1f} GB")
    print()

# Test allocation on each GPU
print("=== Testing GPU 0 (RTX 3080 - ML/Inference) ===")
with torch.device("cuda:0"):
    x = torch.randn(1000, 1000, device="cuda:0")
    print(f"✓ Tensor allocated on GPU 0: {x.device}")
    del x

print()
print("=== Testing GPU 1 (RTX 3060 - Display) ===")
with torch.device("cuda:1"):
    x = torch.randn(1000, 1000, device="cuda:1")
    print(f"✓ Tensor allocated on GPU 1: {x.device}")
    del x

print()
print("=== Recommendation ===")
print("GPU 0 (RTX 3080 10GB): Use for ML training/inference")
print("GPU 1 (RTX 3060 12GB): Currently handling display, use for lighter tasks")
