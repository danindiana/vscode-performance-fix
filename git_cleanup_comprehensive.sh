#!/bin/bash

# Comprehensive Git Cleanup with Multiple Strategies

MODE="${1:-analyze}"

echo "�� Git Repository Cleanup Tool"
echo "================================"
echo ""

case "$MODE" in
    analyze)
        echo "Mode: ANALYZE (no changes)"
        ;;
    clean-artifacts)
        echo "Mode: CLEAN BUILD ARTIFACTS"
        echo "⚠️  Will remove build artifacts from git tracking"
        ;;
    keep-42)
        echo "Mode: KEEP ONLY 42 ORIGINAL FILES"
        echo "⚠️  AGGRESSIVE - Only for abandoned projects!"
        ;;
    *)
        echo "Usage: $0 [analyze|clean-artifacts|keep-42]"
        echo ""
        echo "Modes:"
        echo "  analyze         - Scan and report (no changes)"
        echo "  clean-artifacts - Remove build artifacts (safe)"
        echo "  keep-42         - Keep only 42 oldest source files (DANGEROUS)"
        exit 1
        ;;
esac

echo ""

# Strategy 1: Clean Build Artifacts
clean_build_artifacts() {
    local repo=$1
    cd "$repo" || return
    
    local count=0
    
    # Remove common build artifacts
    for pattern in "target/" "build/" "dist/" "__pycache__/" "*.pyc" "node_modules/" ".pytest_cache/"; do
        while IFS= read -r file; do
            if [ "$MODE" = "clean-artifacts" ]; then
                git rm --cached "$file" 2>/dev/null && ((count++))
            else
                ((count++))
            fi
        done < <(git ls-files 2>/dev/null | grep "$pattern" || true)
    done
    
    echo "$count"
}

# Strategy 2: Keep Only 42 Original Files (based on first commit)
keep_only_original_42() {
    local repo=$1
    cd "$repo" || return
    
    # Get first commit
    local first_commit=$(git rev-list --max-parents=0 HEAD 2>/dev/null | head -1)
    if [ -z "$first_commit" ]; then
        echo "0"
        return
    fi
    
    # Get files from first commit
    mapfile -t original_files < <(git ls-tree -r --name-only "$first_commit" 2>/dev/null | head -42)
    
    if [ ${#original_files[@]} -eq 0 ]; then
        echo "0"
        return
    fi
    
    # Get all currently tracked files
    mapfile -t all_files < <(git ls-files 2>/dev/null)
    
    local removed=0
    for file in "${all_files[@]}"; do
        # Check if file is in original 42
        local keep=false
        for orig in "${original_files[@]}"; do
            if [ "$file" = "$orig" ]; then
                keep=true
                break
            fi
        done
        
        if [ "$keep" = false ]; then
            if [ "$MODE" = "keep-42" ]; then
                git rm --cached "$file" 2>/dev/null && ((removed++))
            else
                ((removed++))
            fi
        fi
    done
    
    echo "$removed"
}

# Main analysis
mapfile -t REPOS < <(find /home/jeb -name .git -type d 2>/dev/null | sed 's|/.git$||' | head -20)

echo "Analyzing first 20 repositories..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-45s %12s %12s %12s\n" "Repository" "Total Files" "Artifacts" "Beyond-42"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_ARTIFACTS=0
TOTAL_BEYOND_42=0

for repo in "${REPOS[@]}"; do
    if [ ! -d "$repo/.git" ]; then continue; fi
    
    cd "$repo" || continue
    REPO_NAME=$(basename "$repo")
    
    TOTAL_FILES=$(git ls-files 2>/dev/null | wc -l)
    
    # Count artifacts
    ARTIFACTS=$(clean_build_artifacts "$repo")
    
    # Count files beyond first 42
    FIRST_COMMIT=$(git rev-list --max-parents=0 HEAD 2>/dev/null | head -1)
    if [ -n "$FIRST_COMMIT" ]; then
        ORIGINAL_42=$(git ls-tree -r --name-only "$FIRST_COMMIT" 2>/dev/null | head -42 | wc -l)
        BEYOND_42=$((TOTAL_FILES - ORIGINAL_42))
        [ "$BEYOND_42" -lt 0 ] && BEYOND_42=0
    else
        BEYOND_42=0
    fi
    
    if [ "$TOTAL_FILES" -gt 100 ] || [ "$ARTIFACTS" -gt 0 ]; then
        printf "%-45s %12s %12s %12s\n" \
            "${REPO_NAME:0:44}" "$TOTAL_FILES" "$ARTIFACTS" "$BEYOND_42"
        
        TOTAL_ARTIFACTS=$((TOTAL_ARTIFACTS + ARTIFACTS))
        TOTAL_BEYOND_42=$((TOTAL_BEYOND_42 + BEYOND_42))
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-45s %12s %12s %12s\n" "TOTALS" "-" "$TOTAL_ARTIFACTS" "$TOTAL_BEYOND_42"
echo ""

if [ "$MODE" = "analyze" ]; then
    echo "💡 Recommendations:"
    echo ""
    echo "1. Clean build artifacts (SAFE):"
    echo "   bash $0 clean-artifacts"
    echo "   → Removes $TOTAL_ARTIFACTS build/cache files"
    echo ""
    echo "2. Keep only original files (AGGRESSIVE - for abandoned projects):"
    echo "   bash $0 keep-42"
    echo "   → Would remove $TOTAL_BEYOND_42 files added after initial commit"
    echo ""
    echo "⚠️  After running cleanup, commit changes in each affected repo"
fi
