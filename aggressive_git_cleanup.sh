#!/bin/bash

# AGGRESSIVE GIT CLEANUP - Get from 113K to 10K files
# Strategy: De-git clones, remove abandoned projects, keep only active development

set -e

MODE=${1:-analyze}

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║           AGGRESSIVE GIT CLEANUP - 113K → 10K FILES                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# CATEGORY 1: CLONE-ONLY REPOS (never commit to these)
CLONE_REPOS=(
    "/home/jeb/.local/share/tldr/tldr"           # 22,584 files - tldr database
    "/home/jeb/programs/bash_scripts/tqdm/dpdk"  # 6,323 files - networking lib
    "/home/jeb/programs/cupy"                    # 6,299 files - numpy alternative
    "/home/jeb/programs/scylladb"                # 5,117 files - database
    "/home/jeb/Downloads/nDPI"                   # 3,407 files - packet inspection
    "/home/jeb/programs/tika-trunk"              # 2,328 files - apache tika
    "/home/jeb/programs/ImageMagick"             # 2,097 files - image processing
    "/home/jeb/Downloads/vnote"                  # 1,652 files - note app
    "/home/jeb/Downloads/qBittorrent"            # 1,590 files - torrent client
    "/home/jeb/programs/alacritty"               # 1,298 files - terminal emulator
    "/home/jeb/programs/nDPI_packinspect/nDPI"   # 924 files - duplicate nDPI
    "/home/jeb/programs/tika_scripts/tesseract"  # 724 files - OCR engine
    "/home/jeb/common-lisp/lem"                  # 593 files - text editor
)

# CATEGORY 2: LARGE POTENTIALLY ABANDONED PROJECTS
REVIEW_REPOS=(
    "/home/jeb/programs/vector_rag"              # 14,508 files
    "/home/jeb/programs/pytorch"                 # 8,734 files
    "/home/jeb/programs/tfid_vectorizer"         # 3,825 files
    "/home/jeb/programs/tika_server"             # 2,926 files
    "/home/jeb/programs/OpenGPTp/gpt-pilot/workspace" # 2,801 files
    "/home/jeb/programs/pdf_downloader_rs"       # 2,672 files
    "/home/jeb/programs/rust_progs/hydra_3"      # 2,392 files
    "/home/jeb/programs/JN-nosim/JN-noiseim"     # 2,177 files
    "/home/jeb/programs/ghostty"                 # 1,877 files
    "/home/jeb/programs/pdf_validator"           # 1,725 files
)

total_clone=0
total_review=0

if [ "$MODE" = "analyze" ]; then
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "ANALYSIS MODE - No changes will be made"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    
    echo "CATEGORY 1: CLONE-ONLY REPOS (safe to de-git)"
    echo "Action: Remove .git folder, keep files"
    echo "───────────────────────────────────────────────────────────────────────"
    for repo in "${CLONE_REPOS[@]}"; do
        if [ -d "$repo/.git" ]; then
            count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
            total_clone=$((total_clone + count))
            printf "  %6d files: %s\n" "$count" "$repo"
        fi
    done
    echo "  ────────────────────────────────────────────────────────────────────"
    printf "  SUBTOTAL: %d files\n" "$total_clone"
    echo ""
    
    echo "CATEGORY 2: LARGE PROJECTS FOR REVIEW"
    echo "Action: Manually decide - keep, archive, or delete"
    echo "───────────────────────────────────────────────────────────────────────"
    for repo in "${REVIEW_REPOS[@]}"; do
        if [ -d "$repo/.git" ]; then
            count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
            total_review=$((total_review + count))
            
            # Check last commit date
            last_commit=$(cd "$repo" && git log -1 --format=%cd --date=short 2>/dev/null || echo "unknown")
            
            printf "  %6d files: %s (last: %s)\n" "$count" "$repo" "$last_commit"
        fi
    done
    echo "  ────────────────────────────────────────────────────────────────────"
    printf "  SUBTOTAL: %d files\n" "$total_review"
    echo ""
    
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "IMPACT SUMMARY:"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "Current:              113,020 files"
    printf "De-git clones:       -%6d files\n" "$total_clone"
    printf "After de-git:        ~%6d files\n" $((113020 - total_clone))
    echo ""
    printf "Review projects:     -%6d files (if deleted)\n" "$total_review"
    printf "If all deleted:      ~%6d files\n" $((113020 - total_clone - total_review))
    echo ""
    echo "TARGET:                 10,000 files"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "NEXT STEPS:"
    echo ""
    echo "  1. De-git clone-only repos (SAFE):"
    echo "     bash ~/aggressive_git_cleanup.sh degit"
    echo ""
    echo "  2. Review large projects and decide:"
    echo "     - Keep actively used"
    echo "     - Delete abandoned/unused"
    echo "     - Archive to external storage"
    echo ""

elif [ "$MODE" = "degit" ]; then
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "DE-GIT MODE - Removing .git from clone-only repos"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    
    for repo in "${CLONE_REPOS[@]}"; do
        if [ -d "$repo/.git" ]; then
            count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
            echo "De-gitting: $repo ($count files)"
            rm -rf "$repo/.git"
            total_clone=$((total_clone + count))
            echo "  ✓ Removed .git directory"
        fi
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════"
    printf "✓ De-gitted %d files from %d repos\n" "$total_clone" "${#CLONE_REPOS[@]}"
    printf "  New total: ~%d files\n" $((113020 - total_clone))
    echo "═══════════════════════════════════════════════════════════════════════"
    
elif [ "$MODE" = "delete-review" ]; then
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "DELETE REVIEW PROJECTS - This will DELETE entire directories!"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "This will delete the following repos:"
    for repo in "${REVIEW_REPOS[@]}"; do
        if [ -d "$repo" ]; then
            count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l 2>/dev/null || echo 0)
            printf "  %6d files: %s\n" "$count" "$repo"
        fi
    done
    echo ""
    read -p "Are you ABSOLUTELY SURE? Type 'DELETE PROJECTS' to confirm: " confirm
    
    if [ "$confirm" = "DELETE PROJECTS" ]; then
        for repo in "${REVIEW_REPOS[@]}"; do
            if [ -d "$repo" ]; then
                echo "Deleting: $repo"
                rm -rf "$repo"
            fi
        done
        echo "✓ Deleted all review projects"
    else
        echo "Aborted - no files deleted"
    fi
else
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [analyze|degit|delete-review]"
    exit 1
fi
