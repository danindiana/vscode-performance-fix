# VS Code Performance Fix - Eliminate Stuttering & System Freezes

> **Complete investigation and fixes for VS Code stuttering, backpressure, and system-wide freezes on Linux**

## 🎯 Problem

Experiencing severe performance issues with VS Code on Linux:
- System stuttering and backpressure
- 2-3 second **system-wide freeze** when saving files (Chrome freezes, videos stop, entire system locks)
- Slow git operations
- High CPU/memory usage from file watchers

## 🔍 Root Causes Identified

### 1. File System Overwhelm (94% of the problem)
- **113,020 files** tracked across 120+ git repositories
- **338,275 Python cache files** (`__pycache__/`, `.pyc`)
- **1.9+ million total files** in home directory
- Global `.gitignore` existed but was **NOT configured** in git
- Insufficient VS Code file watcher exclusions

### 2. Aggressive Dirty Page Writeback (System freezes)
- `vm.dirty_background_ratio = 1%` (default: 10%) - **WAY TOO LOW!**
- `vm.dirty_ratio = 3%` (default: 20%) - **TOO AGGRESSIVE!**
- System blocks ALL I/O when only 3% of RAM has dirty pages
- Every file save triggered immediate system-wide disk flush

**NOT an Electron bug** - purely configuration and file bloat issues!

---

## ✅ Solutions Applied

### Fix 1: Configure Global Git Ignore
```bash
# Activate existing global .gitignore
git config --global core.excludesfile ~/.gitignore
```

### Fix 2: Enhance VS Code File Watcher Exclusions
Add to `~/.config/Code/User/settings.json`:
```json
{
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/__pycache__/**": true,
    "**/target/**": true,
    "**/build/**": true,
    "**/dist/**": true,
    "**/.venv/**": true,
    "**/.cache/**": true,
    "**/Downloads/**": true,
    "**/Documents/**": true,
    "**/*.pyc": true,
    "**/.pytest_cache/**": true,
    "**/venv/**": true,
    "**/.eggs/**": true,
    "**/*.egg-info/**": true,
    "**/.tox/**": true,
    "**/.mypy_cache/**": true,
    "**/.ruff_cache/**": true,
    "**/*.zip": true,
    "**/*.tar.gz": true,
    "**/*.tar.bz2": true,
    "**/*.7z": true,
    "**/*.rar": true,
    "**/*.iso": true,
    "**/*.deb": true,
    "**/*.rpm": true,
    "**/*.AppImage": true
  },
  "git.autofetch": false,
  "git.autorefresh": false,
  "git.scanRepositories": []
}
```

### Fix 3: Clean Python Cache
```bash
# Run the provided script
bash cleanup_python_cache.sh
```
**Result:** Removed 338,275 files!

### Fix 4: De-Git Clone-Only Repositories
```bash
# Remove .git from libraries you never commit to
bash aggressive_git_cleanup.sh degit
```
**Result:** Removed 54,936 tracked files from 13 repos

### Fix 5: Aggressive Git Cleanup
```bash
# De-git large ML libraries, duplicates, abandoned projects
bash aggressive_degit_phase2.sh
```
**Result:** Removed 51,535 additional tracked files

### Fix 6: Fix Dirty Page Writeback Settings
```bash
# Restore sane kernel defaults
sudo bash fix_dirty_page_freeze.sh
```

Sets:
```bash
vm.dirty_ratio = 20              (was: 3)
vm.dirty_background_ratio = 10   (was: 1)
vm.dirty_writeback_centisecs = 500
vm.dirty_expire_centisecs = 3000
```

---

## 📊 Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Git-tracked files** | 113,020 | 6,549 | **-94%** |
| **Python cache files** | 338,275 | 0 | **-100%** |
| **Total files** | 1,938,412 | ~1,600,000 | -17% |
| **Git repositories** | 120 | 83 | -37 de-gitted |
| **System freezes on save** | 2-3 seconds | 0 | **ELIMINATED** |
| **VS Code responsiveness** | Stuttering | Smooth | **FIXED** |

---

## 🛠️ Tools Included

### Diagnostic Scripts
- `diagnose_io_freeze_nosudo.sh` - Diagnose system freeze issues
- `count_all_git_files.sh` - Monitor git-tracked file count
- `analyze_git_repos.sh` - Analyze repository file counts

### Cleanup Scripts
- `cleanup_python_cache.sh` - Remove Python cache files
- `git_smart_cleanup.sh` - Safe build artifact cleanup
- `git_cleanup_comprehensive.sh` - Advanced git cleanup options
- `aggressive_git_cleanup.sh` - De-git clone-only repositories
- `aggressive_degit_phase2.sh` - Aggressive large project cleanup

### Fix Scripts
- `fix_dirty_page_freeze.sh` - Fix kernel dirty page settings

### Documentation
- `backpressure_analysis_report.md` - Initial investigation
- `COMPLETE_SOLUTION_SUMMARY.md` - Phase 1 summary
- `PERFORMANCE_FIX_SUCCESS.md` - Complete success report

---

## 🚀 Quick Start

1. **Check your current git-tracked files:**
   ```bash
   bash count_all_git_files.sh
   ```
   If over 10,000, you'll benefit from cleanup!

2. **Run Python cache cleanup:**
   ```bash
   bash cleanup_python_cache.sh
   ```

3. **Check for system freeze on save:**
   ```bash
   bash diagnose_io_freeze_nosudo.sh
   ```
   Look for `vm.dirty_ratio` and `vm.dirty_background_ratio` under 5

4. **Fix dirty page settings if needed:**
   ```bash
   sudo bash fix_dirty_page_freeze.sh
   ```

5. **Configure git and VS Code:**
   - Set `git config --global core.excludesfile ~/.gitignore`
   - Add file watcher exclusions to VS Code settings

6. **De-git clone-only repos (optional):**
   ```bash
   bash aggressive_git_cleanup.sh analyze  # Review first
   bash aggressive_git_cleanup.sh degit    # Execute
   ```

---

## 💡 Prevention Tips

1. **Use shallow clones:** `git clone --depth 1 <repo>`
2. **Monitor git tracking:** Keep under 10,000 files
3. **Clean Python cache periodically**
4. **Don't open VS Code from ~/** - Open specific project folders
5. **Review dirty page settings** if system freezes on save

---

## 📋 System Info

- **OS:** Ubuntu 22.04.5 LTS (applies to most Linux distributions)
- **Kernel:** 6.8.0-85-generic
- **VS Code:** 1.105.1 (Electron 37.6.0)
- **Hardware:** AMD Ryzen Threadripper, Dual Intel X540-T2 10G, Dual NVMe SSDs
- **Investigation Date:** October 18, 2025

---

## 🔄 Post-Reboot Verification

All optimizations have been **verified to survive system reboot** (tested October 18, 2025):

### ✅ Network Configuration Persistent
- Both 10G ports maintain 8 combined queues
- Service conflict resolved (old 4-queue service disabled)
- New 8-queue optimization service active and enabled

### ✅ NVMe Optimizations Persistent
- Kernel parameters applied: `nvme.write_queues=16`
- Queue counts maintained across reboot
- Optimal interrupt distribution preserved

### ✅ IRQ Balancing Configured Optimally
- **Discovery:** System already configured for oneshot mode (`IRQBALANCE_ONESHOT=1`)
- **Behavior:** IRQs balanced **once at boot**, then remain static
- **Misconception Clarified:** No periodic rebalancing occurring (service correctly shows "inactive")

See [IRQ_BALANCING_ONESHOT_DISCOVERY.md](IRQ_BALANCING_ONESHOT_DISCOVERY.md) for details.

---

## 🤝 Contributing

Found other causes of VS Code stuttering? Have additional fixes? PRs welcome!

---

## 📄 License

MIT License - Feel free to use, modify, and share!

---

## 🙏 Acknowledgments

Created during a comprehensive investigation into VS Code performance issues. The problem was NOT an Electron bug, but rather a combination of:
- Misconfiguration (global gitignore not activated)
- File system bloat (338K Python cache + 113K git-tracked files)
- Aggressive kernel settings (dirty page writeback)

All easily fixable with the right diagnosis and tools!

---

**⭐ If this helped you, please star the repo and share with others experiencing VS Code performance issues!**

Brought to you by https://calisota.ai/
