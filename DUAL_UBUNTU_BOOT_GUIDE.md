# Dual Ubuntu Boot Configuration

**Date:** October 18, 2025  
**System:** Dual Ubuntu installations on separate NVMe drives  
**Status:** ✅ Configured for proper dual-boot with correct parameters on each

---

## System Layout

### Primary Ubuntu (Current/Preferred)
- **Location:** `/dev/nvme1n1p1` (Intel SSD 660P, 953.9GB)
- **UUID:** `2bd8e49f-7ea3-4755-8999-7b78f4223812`
- **Mount:** `/` (root filesystem)
- **GRUB:** `/boot/grub/grub.cfg` (with optimized nvme.write_queues=16)
- **Purpose:** Main system with optimized NVMe performance

### Secondary Ubuntu
- **Location:** `/dev/sdd2` (931GB drive)
- **UUID:** `ba4c008c-3079-47f1-8e31-cc3547f6307f`
- **Mount:** Not currently mounted
- **GRUB:** Has its own `/boot/grub/grub.cfg` (with old nvme.write_queues=4)
- **Purpose:** Alternative/backup Ubuntu installation

---

## The Boot Configuration Issue (RESOLVED)

### What Was Happening (BEFORE FIX)

1. **EFI Firmware** → Loads `/boot/efi/EFI/ubuntu/grubx64.efi`
2. **EFI Stub** (`/boot/efi/EFI/ubuntu/grub.cfg`) → Pointed to secondary Ubuntu (sdd2) ❌
3. **GRUB Loaded** → From `/dev/sdd2/boot/grub/grub.cfg` (old config)
4. **Kernel Parameters** → Used `nvme.write_queues=4` from old system ❌
5. **Root Switch** → Booted into primary Ubuntu (nvme1n1p1) but with wrong parameters ❌

**Result:** Primary system ran with suboptimal NVMe configuration from secondary system's GRUB!

### Current Configuration (AFTER FIX)

1. **EFI Stub** → Now points to primary Ubuntu (nvme1n1p1) ✅
2. **GRUB** → Loads from primary system with correct parameters ✅
3. **os-prober** → Enabled to detect both Ubuntu installations ✅
4. **Boot Menu** → Shows both systems as separate entries ✅

---

## Dual-Boot Setup

### Configuration Files

**EFI Stub:** `/boot/efi/EFI/ubuntu/grub.cfg`
```bash
search.fs_uuid 2bd8e49f-7ea3-4755-8999-7b78f4223812 root hd0,gpt1
set prefix=($root)'/boot/grub'
configfile $prefix/grub.cfg
```
**Purpose:** Loads GRUB from PRIMARY Ubuntu (nvme1n1p1)

**GRUB Config:** `/etc/default/grub`
```bash
GRUB_DEFAULT=0
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX="nvme.write_queues=16"
```
**Purpose:** 
- Default to entry 0 (primary Ubuntu)
- Enable os-prober to detect secondary Ubuntu
- Apply optimized NVMe parameters

---

## How to Boot Each System

### Method 1: GRUB Menu (Recommended)

At boot time:
1. **Press and hold SHIFT** (or ESC on some systems) during boot
2. **GRUB menu appears** showing:
   - **Entry 0:** Ubuntu (primary - nvme1n1p1) ← Default
   - **Entry 1:** Advanced options for Ubuntu
   - **Entry 2:** Ubuntu 22.04.5 LTS (22.04) on /dev/sdd2 ← Secondary
   - **Entry 3:** UEFI Firmware Settings
3. **Use arrow keys** to select which Ubuntu to boot
4. **Press Enter**

**Default behavior:** If you don't press anything, boots Entry 0 (primary) after 10 seconds.

### Method 2: Change GRUB Default

To make secondary Ubuntu the default boot:
```bash
# Edit GRUB config on primary system
sudo nano /etc/default/grub

# Change to:
GRUB_DEFAULT=2  # or whatever entry number the secondary Ubuntu is

# Update GRUB
sudo update-grub
sudo reboot
```

### Method 3: EFI Stub (Not Recommended)

You could change the EFI stub to point to the secondary system, but this would:
- Load GRUB from secondary system (old nvme.write_queues=4)
- Lose optimized performance on primary system ❌
- Better to use the GRUB menu method ✅

---

## System-Specific Parameters

### Primary Ubuntu (nvme1n1p1)
**Kernel Parameters:**
```bash
nvme.write_queues=16
nvme_core.default_ps_max_latency_us=0
nvme.io_queue_depth=1023
```

**NVMe Performance:**
- 49 total queues (16 write / 32 read)
- Balanced interrupt distribution
- Optimized for Intel 660P boot drive

### Secondary Ubuntu (sdd2)
**Kernel Parameters:**
```bash
nvme.write_queues=4
nvme.poll_queues=4
```

**Status:** Old configuration, not optimized

**To optimize secondary system:**
1. Boot into secondary Ubuntu (via GRUB menu)
2. Edit `/etc/default/grub` on that system
3. Add `GRUB_CMDLINE_LINUX="nvme.write_queues=16"`
4. Run `sudo update-grub`
5. Reboot

---

## Verification Commands

### Check Which System You Booted Into
```bash
# Check root filesystem UUID
findmnt -n -o UUID /

# Expected outputs:
# Primary:   2bd8e49f-7ea3-4755-8999-7b78f4223812
# Secondary: ba4c008c-3079-47f1-8e31-cc3547f6307f
```

### Check Kernel Parameters
```bash
# Check nvme parameters
cat /proc/cmdline | grep nvme

# Primary should show:   nvme.write_queues=16
# Secondary will show:   nvme.write_queues=4 nvme.poll_queues=4
```

### Check NVMe Queue Configuration
```bash
# Check write queues
cat /sys/module/nvme/parameters/write_queues

# Primary should show:   16
# Secondary will show:   4
```

---

## Boot Selection Flowchart

```
┌─────────────────────────────┐
│   System Powers On          │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   EFI Firmware              │
│   Loads: grubx64.efi        │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   EFI Stub Config           │
│   Points to: nvme1n1p1      │◄── YOU FIXED THIS!
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│   GRUB (from Primary)       │
│   Shows menu if SHIFT held  │
└──────┬────────────┬─────────┘
       │            │
       │ No input   │ User selects
       │ (10 sec)   │
       ▼            ▼
   ┌───────┐   ┌────────────┐
   │Primary│   │Secondary or│
   │Ubuntu │   │Advanced    │
   │nvme1  │   │Ubuntu sdd  │
   └───┬───┘   └─────┬──────┘
       │             │
       ▼             ▼
   Optimized    Old config
   (16 queues)  (4 queues)
```

---

## Troubleshooting

### Problem: Can't see secondary Ubuntu in GRUB menu

**Solution:**
```bash
# Check if os-prober is enabled
grep GRUB_DISABLE_OS_PROBER /etc/default/grub
# Should show: GRUB_DISABLE_OS_PROBER=false

# If not, enable it:
sudo sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo update-grub
```

### Problem: Booted into wrong system

**Check which system you're in:**
```bash
findmnt -n -o UUID / && cat /proc/cmdline
```

**If you're in secondary but wanted primary:**
1. Reboot
2. Hold SHIFT at boot
3. Select first "Ubuntu" entry (not the one mentioning /dev/sdd2)

### Problem: Secondary Ubuntu also needs optimization

**Boot into secondary system, then:**
```bash
sudo nano /etc/default/grub
# Add: GRUB_CMDLINE_LINUX="nvme.write_queues=16"
sudo update-grub
# Note: This updates the GRUB on /dev/sdd2, not nvme1n1p1
```

---

## Backup Information

### EFI Stub Backups
- **Current (correct):** `/boot/efi/EFI/ubuntu/grub.cfg` → points to nvme1n1p1
- **Old (wrong):** `/boot/efi/EFI/ubuntu/grub.cfg.old` → pointed to sdd2
- **Original:** `/boot/efi/EFI/ubuntu/grub.cfg.bak` → original from install

### GRUB Config Backups
- `/etc/default/grub.backup.dual-boot` → Before enabling os-prober
- `/etc/default/grub.backup.20251018_050228` → Before kernel parameter changes

---

## Summary

✅ **Current State:**
- Primary Ubuntu (nvme1n1p1) boots by default with optimized parameters
- Secondary Ubuntu (sdd2) accessible via GRUB menu
- EFI stub correctly points to primary system
- Both systems can be booted independently

✅ **Performance:**
- Primary: 49 queues, 16 write queues, balanced distribution
- Secondary: 9 queues, 4 write queues (can be optimized if needed)

✅ **Usability:**
- Hold SHIFT at boot to select which Ubuntu to use
- Default: Primary Ubuntu (10 second timeout)
- No need to change any configs to switch systems

**Status:** Dual-boot properly configured! 🎉
