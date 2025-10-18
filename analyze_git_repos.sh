#!/bin/bash

echo "🔍 Analyzing Git Repositories"
echo "=============================="
echo ""

# Find all git repos
mapfile -t REPOS < <(find /home/jeb -name .git -type d 2>/dev/null | sed 's|/.git$||')

echo "Found ${#REPOS[@]} git repositories"
echo ""

# Analyze each repo
echo "📊 Repository Analysis:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-50s %10s %10s %10s %12s\n" "Repository" "Tracked" "Untracked" "Modified" "Repo Size"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_TRACKED=0
TOTAL_UNTRACKED=0
TOTAL_SIZE=0

for repo in "${REPOS[@]}"; do
    if [ ! -d "$repo" ]; then continue; fi
    
    cd "$repo" 2>/dev/null || continue
    
    # Get counts
    TRACKED=$(git ls-files 2>/dev/null | wc -l)
    UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    MODIFIED=$(git ls-files -m 2>/dev/null | wc -l)
    
    # Get .git size
    GIT_SIZE=$(du -sh .git 2>/dev/null | cut -f1)
    
    # Only show repos with significant files
    if [ "$TRACKED" -gt 100 ] || [ "$UNTRACKED" -gt 100 ]; then
        REPO_NAME=$(echo "$repo" | sed "s|/home/jeb/||")
        printf "%-50s %10s %10s %10s %12s\n" \
            "${REPO_NAME:0:49}" "$TRACKED" "$UNTRACKED" "$MODIFIED" "$GIT_SIZE"
        
        TOTAL_TRACKED=$((TOTAL_TRACKED + TRACKED))
        TOTAL_UNTRACKED=$((TOTAL_UNTRACKED + UNTRACKED))
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-50s %10s %10s\n" "TOTALS" "$TOTAL_TRACKED" "$TOTAL_UNTRACKED"
echo ""
echo "💡 Analysis complete! Output saved to: /tmp/git_analysis.txt"
