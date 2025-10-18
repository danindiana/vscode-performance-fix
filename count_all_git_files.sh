#!/bin/bash

echo "=== COUNTING ALL GIT-TRACKED FILES ==="
echo ""

total=0
repos=()

# Find all .git directories
while IFS= read -r gitdir; do
    repo=$(dirname "$gitdir")
    count=$(cd "$repo" && git ls-files 2>/dev/null | wc -l)
    
    if [ "$count" -gt 0 ]; then
        repos+=("$count|$repo")
        total=$((total + count))
    fi
done < <(find /home/jeb -name .git -type d 2>/dev/null | grep -v "/\.cache/" | grep -v "/\.venv/" | head -150)

# Sort and display
printf "%s\n" "${repos[@]}" | sort -t'|' -k1 -rn | head -30 | while IFS='|' read count repo; do
    printf "%7d files: %s\n" "$count" "$repo"
done

echo ""
echo "======================================"
printf "TOTAL: %d files tracked in git\n" "$total"
echo "TARGET: 10,000 files"
printf "NEED TO REMOVE: %d files\n" $((total - 10000))
echo "======================================"
