#!/bin/bash

# AGGRESSIVE PHASE 2: De-git large ML libraries and duplicate projects
# Target: Remove another ~48K files to reach 10K total

set -e

echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║         AGGRESSIVE PHASE 2 - DE-GIT LARGE PROJECTS                   ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo ""

# Large ML/library clones (likely never commit to these)
LARGE_LIBS=(
    "/home/jeb/programs/vector_rag"                    # 14,508 files
    "/home/jeb/programs/pytorch"                       # 8,734 files
    "/home/jeb/programs/tfid_vectorizer"               # 3,825 files
    "/home/jeb/programs/tika_server"                   # 2,926 files
    "/home/jeb/programs/ghostty"                       # 1,877 files
    "/home/jeb/programs/genichain/dna-storage-project" # 1,101 files
    "/home/jeb/programs/gemini-cli"                    # 1,071 files
    "/home/jeb/programs/ApeRAG"                        # 1,025 files
    "/home/jeb/programs/kftray"                        # 329 files
    "/home/jeb/programs/stable2/stable-diffusion-webui" # 321 files
    "/home/jeb/Downloads/rpi-imager"                   # 275 files
)

# Duplicate web crawler versions (keep one, de-git the rest)
DUPLICATE_CRAWLERS=(
    "/home/jeb/programs/rustp/webcraw_raybloom"        # 721 files
    "/home/jeb/programs/rustp/webcraw_rayonv2"         # 534 files
    "/home/jeb/programs/rustp/webcraw_rbv2"            # 431 files
    "/home/jeb/programs/rustp/webcraw_rayon"           # 376 files
    # Keeping: /home/jeb/programs/rustp/web_crawler (861 files - appears to be main)
)

# PDF tools (likely experiments)
PDF_TOOLS=(
    "/home/jeb/programs/pdf_downloader_rs"             # 2,672 files
    "/home/jeb/programs/pdf_validator"                 # 1,725 files
)

# Duplicate hydra versions
HYDRA_VERSIONS=(
    "/home/jeb/programs/rust_progs/hydra_3"            # 2,392 files
    "/home/jeb/programs/rust_progs/hydra_2"            # 483 files
)

# Other large projects
OTHER_LARGE=(
    "/home/jeb/programs/OpenGPTp/gpt-pilot/workspace"  # 2,801 files
    "/home/jeb/programs/JN-nosim/JN-noiseim"           # 2,177 files
    "/home/jeb/programs/qcrawl2/march04/quic-go"       # 486 files
    "/home/jeb/programs/mojo_install/hello-world/mojo" # 406 files
    "/home/jeb/.nvm"                                   # 339 files - node version manager
)

total_removed=0

echo "De-gitting large ML/library clones..."
echo "───────────────────────────────────────────────────────────────────────"
for repo in "${LARGE_LIBS[@]}"; do
    if [ -d "$repo/.git" ]; then
        count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
        echo "  De-gitting: $repo ($count files)"
        rm -rf "$repo/.git"
        total_removed=$((total_removed + count))
    fi
done

echo ""
echo "De-gitting duplicate web crawlers (keeping web_crawler)..."
echo "───────────────────────────────────────────────────────────────────────"
for repo in "${DUPLICATE_CRAWLERS[@]}"; do
    if [ -d "$repo/.git" ]; then
        count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
        echo "  De-gitting: $repo ($count files)"
        rm -rf "$repo/.git"
        total_removed=$((total_removed + count))
    fi
done

echo ""
echo "De-gitting PDF tools..."
echo "───────────────────────────────────────────────────────────────────────"
for repo in "${PDF_TOOLS[@]}"; do
    if [ -d "$repo/.git" ]; then
        count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
        echo "  De-gitting: $repo ($count files)"
        rm -rf "$repo/.git"
        total_removed=$((total_removed + count))
    fi
done

echo ""
echo "De-gitting duplicate hydra versions..."
echo "───────────────────────────────────────────────────────────────────────"
for repo in "${HYDRA_VERSIONS[@]}"; do
    if [ -d "$repo/.git" ]; then
        count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
        echo "  De-gitting: $repo ($count files)"
        rm -rf "$repo/.git"
        total_removed=$((total_removed + count))
    fi
done

echo ""
echo "De-gitting other large projects..."
echo "───────────────────────────────────────────────────────────────────────"
for repo in "${OTHER_LARGE[@]}"; do
    if [ -d "$repo/.git" ]; then
        count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
        echo "  De-gitting: $repo ($count files)"
        rm -rf "$repo/.git"
        total_removed=$((total_removed + count))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
printf "✓ Phase 2 complete: De-gitted %d files\n" "$total_removed"
printf "  Estimated new total: ~%d files\n" $((58084 - total_removed))
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "Run: bash ~/count_all_git_files.sh"
echo "To verify final count!"
