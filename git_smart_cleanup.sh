#!/bin/bash

# Git Smart Cleanup - Remove build artifacts from git tracking

DRYRUN=true
if [ "$1" == "--execute" ]; then
    DRYRUN=false
    echo "⚠️  EXECUTE MODE - Changes will be made!"
else
    echo "🔍 DRY RUN MODE (use --execute to apply changes)"
fi

echo "Git Smart Cleanup"
echo "================="
echo ""

# Find problematic repos quickly
echo "Scanning repositories..."

CLEANED=0
TOTAL_FILES=0

# Check a few key repos that likely have issues
TEST_REPOS=(
    "/home/jeb/programs/pytorch"
    "/home/jeb/programs/scylladb"
    "/home/jeb/programs/tfid_vectorizer"
    "/home/jeb/programs/stable2/stable-diffusion-webui"
    "/home/jeb/programs/rust_progs/hydra_3"
    "/home/jeb/Documents/Vibemon"
    "/home/jeb/.local/share/tldr/tldr"
)

for repo in "${TEST_REPOS[@]}"; do
    if [ ! -d "$repo/.git" ]; then continue; fi
    cd "$repo" 2>/dev/null || continue
    
    # Quick check for common issues
    BUILD_COUNT=$(git ls-files 2>/dev/null | grep -cE 'target/|build/|dist/|__pycache__|\.pyc$|node_modules/' 2>/dev/null || echo 0)
    
    if [ "$BUILD_COUNT" -gt 0 ]; then
        echo "📁 $(basename $repo)"
        echo "   Build artifacts tracked: $BUILD_COUNT files"
        
        if [ "$DRYRUN" = false ]; then
            git ls-files | grep -E 'target/|build/|dist/|__pycache__|\.pyc$|node_modules/' | xargs -r git rm --cached 2>/dev/null || true
            echo "   ✓ Removed from tracking"
        else
            echo "   → Would remove"
        fi
        
        CLEANED=$((CLEANED + 1))
        TOTAL_FILES=$((TOTAL_FILES + BUILD_COUNT))
    fi
done

echo ""
echo "Summary: $CLEANED repos, $TOTAL_FILES files"
