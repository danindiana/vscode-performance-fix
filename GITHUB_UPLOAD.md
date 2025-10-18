# GitHub Upload Instructions

## Option 1: Use GitHub Web Interface (Easiest)

1. **Go to GitHub and create the repo:**
   - Navigate to: https://github.com/new
   - Repository name: `vscode-performance-fix`
   - Description: `Complete investigation and fixes for VS Code stuttering and system freezes on Linux`
   - Public repository (so others can benefit)
   - **Don't** initialize with README (we already have one)
   - Click "Create repository"

2. **Push from command line:**
   ```bash
   cd ~/programs/vscode_performance_fix_20251018_032616
   
   # If you don't have SSH key set up, use HTTPS:
   git remote remove origin
   git remote add origin https://github.com/danindiana/vscode-performance-fix.git
   git branch -M main
   git push -u origin main
   ```

## Option 2: Set Up SSH Key (For Future Ease)

1. **Generate SSH key (if you don't have one):**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # Press Enter to accept default location
   # Optionally add a passphrase
   ```

2. **Copy public key:**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Add to GitHub:**
   - Go to: https://github.com/settings/keys
   - Click "New SSH key"
   - Paste your public key
   - Click "Add SSH key"

4. **Then push:**
   ```bash
   cd ~/programs/vscode_performance_fix_20251018_032616
   git push -u origin main
   ```

## Quick HTTPS Push (Recommended Now)

```bash
cd ~/programs/vscode_performance_fix_20251018_032616
git remote remove origin
git remote add origin https://github.com/danindiana/vscode-performance-fix.git
git branch -M main
git push -u origin main
```

**You'll need to enter your GitHub username and Personal Access Token (not password).**

## After Pushing

The repo will be available at:
**https://github.com/danindiana/vscode-performance-fix**

Add topics on GitHub:
- `vscode`
- `performance`
- `linux`
- `ubuntu`
- `troubleshooting`
- `file-watcher`
- `git`
- `optimization`

---

## About the Chrome Stuttering

The remaining stuttering is from **Chrome, not VS Code!**

Chrome process PID 44063 is consuming **110% CPU** constantly.

**Fix:**
1. Open Chrome
2. Press **Shift+Esc** (Chrome Task Manager)
3. Find the tab or extension consuming the most CPU
4. Close that tab or disable the extension

Common culprits:
- YouTube/video tabs
- Poorly optimized web apps
- Chrome extensions (ad blockers, auto-refresh, etc.)
- Web-based IDEs or development tools
