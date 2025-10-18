#!/bin/bash

echo "🧹 Python Cache Cleanup Script"
echo "=============================="
echo ""

# Count before
echo "📊 Counting before cleanup..."
TOTAL_PYCACHE=$(find /home/jeb/programs -type d -name __pycache__ 2>/dev/null | wc -l)
TOTAL_PYC=$(find /home/jeb/programs -type f -name "*.pyc" 2>/dev/null | wc -l)
echo "   __pycache__ directories: $TOTAL_PYCACHE"
echo "   .pyc files: $TOTAL_PYC"
echo ""

# Clean user-owned files
echo "🗑️  Removing user-owned .pyc files..."
USER_PYC=$(find /home/jeb/programs -type f -name "*.pyc" -user $USER 2>/dev/null | wc -l)
find /home/jeb/programs -type f -name "*.pyc" -user $USER -delete 2>/dev/null
echo "   ✓ Removed $USER_PYC files"

echo "🗑️  Removing user-owned __pycache__ directories..."
USER_DIRS=$(find /home/jeb/programs -type d -name __pycache__ -user $USER 2>/dev/null | wc -l)
find /home/jeb/programs -type d -name __pycache__ -user $USER -exec rm -rf {} + 2>/dev/null
echo "   ✓ Removed $USER_DIRS directories"
echo ""

# Count root-owned files (needs sudo)
ROOT_PYC=$(find /home/jeb/programs -type f -name "*.pyc" ! -user $USER 2>/dev/null | wc -l)
ROOT_DIRS=$(find /home/jeb/programs -type d -name __pycache__ ! -user $USER 2>/dev/null | wc -l)

if [ $ROOT_PYC -gt 0 ] || [ $ROOT_DIRS -gt 0 ]; then
    echo "⚠️  Found root-owned files:"
    echo "   .pyc files: $ROOT_PYC"
    echo "   __pycache__ dirs: $ROOT_DIRS"
    echo ""
    echo "💡 To clean these, run:"
    echo "   sudo find /home/jeb/programs -type f -name '*.pyc' ! -user $USER -delete"
    echo "   sudo find /home/jeb/programs -type d -name __pycache__ ! -user $USER -exec rm -rf {} +"
    echo ""
fi

# Count after
echo "📊 Counting after cleanup..."
AFTER_PYCACHE=$(find /home/jeb/programs -type d -name __pycache__ 2>/dev/null | wc -l)
AFTER_PYC=$(find /home/jeb/programs -type f -name "*.pyc" 2>/dev/null | wc -l)
echo "   __pycache__ directories: $AFTER_PYCACHE"
echo "   .pyc files: $AFTER_PYC"
echo ""

CLEANED_DIRS=$((TOTAL_PYCACHE - AFTER_PYCACHE))
CLEANED_PYC=$((TOTAL_PYC - AFTER_PYC))

echo "✅ Cleanup complete!"
echo "   Removed: $CLEANED_DIRS directories, $CLEANED_PYC files"
echo ""
