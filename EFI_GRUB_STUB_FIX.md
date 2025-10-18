# EFI GRUB Stub Configuration Fix

**Date:** October 18, 2025  
**Issue:** System booting from wrong GRUB configuration despite correct `/boot/grub/grub.cfg`  
**Severity:** Critical - Prevented kernel parameter changes from taking effect

---

## Problem Discovery

### Symptoms
- Updated `/boot/grub/grub.cfg` with `nvme.write_queues=16` 
- Ran `update-grub` successfully multiple times
- Rebooted system
- **Result:** System still booted with `nvme.write_queues=4` (old value)

### Investigation
```bash
# GRUB config showed correct parameter
$ sudo grep "linux.*vmlinuz-6.8.0-85" /boot/grub/grub.cfg | grep -o "nvme[._]*write_queues=[0-9]*"
nvme.write_queues=16  ✅ CORRECT

# But kernel cmdline showed wrong parameter
$ cat /proc/cmdline
nvme.write_queues=4 nvme.poll_queues=4  ❌ WRONG

# Current root filesystem
$ findmnt -n -o UUID /
2bd8e49f-7ea3-4755-8999-7b78f4223812
```

### Root Cause Identified

The EFI boot process uses a **stub configuration file** that determines which GRUB to load:

```bash
$ sudo cat /boot/efi/EFI/ubuntu/grub.cfg
search.fs_uuid ba4c008c-3079-47f1-8e31-cc3547f6307f root hd2,gpt2 
set prefix=($root)'/boot/grub'
configfile $prefix/grub.cfg
```

**Problem:** The stub was pointing to UUID `ba4c008c-3079-47f1-8e31-cc3547f6307f` which is:
- An **old Ubuntu installation on /dev/sdd2** (USB drive or secondary disk)
- NOT the current root filesystem (nvme1n1p1)

```bash
$ sudo blkid | grep ba4c008c-3079-47f1-8e31-cc3547f6307f
/dev/sdd2: UUID="ba4c008c-3079-47f1-8e31-cc3547f6307f" TYPE="ext4"
```

---

## The Boot Chain Problem

**What Was Happening:**

1. **EFI Firmware** → Loads `/boot/efi/EFI/ubuntu/grubx64.efi`
2. **GRUB EFI Stub** → Reads `/boot/efi/EFI/ubuntu/grub.cfg`
3. **Stub Config** → Points to UUID `ba4c008c...` (OLD system on /dev/sdd2)
4. **GRUB Loads** → From `/dev/sdd2/boot/grub/grub.cfg` (has old parameters)
5. **Kernel Boots** → With `nvme.write_queues=4` from the old GRUB config
6. **Root Switches** → To nvme1n1p1 (current system) but parameters already set

**Result:** System booted into the correct root filesystem but with wrong kernel parameters from the old GRUB configuration!

---

## The Fix

### Step 1: Backup Current EFI Stub
```bash
sudo cp /boot/efi/EFI/ubuntu/grub.cfg /boot/efi/EFI/ubuntu/grub.cfg.old
```

### Step 2: Update EFI Stub to Correct UUID
```bash
echo "search.fs_uuid 2bd8e49f-7ea3-4755-8999-7b78f4223812 root hd0,gpt1
set prefix=(\$root)'/boot/grub'
configfile \$prefix/grub.cfg" | sudo tee /boot/efi/EFI/ubuntu/grub.cfg
```

**Changed:**
- **Old UUID:** `ba4c008c-3079-47f1-8e31-cc3547f6307f` (/dev/sdd2 - old installation)
- **New UUID:** `2bd8e49f-7ea3-4755-8999-7b78f4223812` (/dev/nvme1n1p1 - current system)
- **Device:** Changed from `hd2,gpt2` to `hd0,gpt1` (nvme boot drive)

### Step 3: Verify the Change
```bash
$ sudo cat /boot/efi/EFI/ubuntu/grub.cfg
search.fs_uuid 2bd8e49f-7ea3-4755-8999-7b78f4223812 root hd0,gpt1
set prefix=($root)'/boot/grub'
configfile $prefix/grub.cfg
```

---

## Expected Outcome After Reboot

### Before Fix
```bash
$ cat /proc/cmdline
nvme.write_queues=4 nvme.poll_queues=4 ...  ❌

$ cat /sys/module/nvme/parameters/write_queues
4  ❌

$ sudo dmesg | grep "nvme nvme1:" | grep queues
nvme nvme1: 3/1/4 default/read/poll queues  ❌ (only 3 write queues)
```

### After Fix (Expected)
```bash
$ cat /proc/cmdline
nvme.write_queues=16 ...  ✅

$ cat /sys/module/nvme/parameters/write_queues
16  ✅

$ sudo dmesg | grep "nvme nvme1:" | grep queues
nvme nvme1: 16/X/4 default/read/poll queues  ✅ (16 write queues!)
```

---

## How This Happened

### Likely Scenario
1. System originally installed on /dev/sdd2 (USB drive or secondary disk)
2. Later migrated or reinstalled to nvme1n1p1 (NVMe boot drive)
3. EFI boot entry still pointed to old system's GRUB
4. Old system had custom nvme parameters (`nvme.write_queues=4 nvme.poll_queues=4`)
5. New system's GRUB updates never took effect

### Why It Was Hard to Diagnose
- Current root filesystem (nvme1n1p1) was correct ✓
- Kernel version was correct (6.8.0-85) ✓
- `/boot/grub/grub.cfg` was correct ✓
- But EFI stub loaded GRUB from a different disk's old installation ✗

---

## Verification Checklist (After Reboot)

Run these commands to verify the fix worked:

```bash
# 1. Check kernel cmdline has correct parameter
cat /proc/cmdline | grep "nvme.write_queues=16"

# 2. Check module parameter is 16
cat /sys/module/nvme/parameters/write_queues

# 3. Check driver initialized with more queues
sudo dmesg | grep "nvme nvme1:" | grep queues

# 4. Check queue count increased
cat /sys/class/nvme/nvme1/queue_count

# 5. Check interrupt distribution
cat /proc/interrupts | grep nvme1q | head -20

# 6. Verify no concentration on single queue
cat /proc/interrupts | grep nvme1q | awk '{sum=0; for(i=2;i<=NF-3;i++) sum+=$i; print sum, $NF}' | sort -rn | head -5
```

---

## Performance Impact

### Before Fix (nvme.write_queues=4)
- **Queue Count:** 9 total (5 active)
- **Write Queues:** 3-4
- **IRQ Distribution:** Severe concentration on nvme1q4 (>90% of interrupts)
- **Performance:** Bottlenecked by single queue saturation

### After Fix (nvme.write_queues=16) - Expected
- **Queue Count:** 40+ total
- **Write Queues:** 16
- **IRQ Distribution:** Balanced across multiple queues (<20% per queue)
- **Performance:** Full multi-core NVMe performance unlocked

---

## Related Files Modified

### Main GRUB Configuration
- **File:** `/etc/default/grub`
- **Change:** `GRUB_CMDLINE_LINUX="nvme.write_queues=16"`
- **Updated:** Via `update-grub` (multiple times, but wasn't being used!)

### Generated GRUB Config
- **File:** `/boot/grub/grub.cfg`
- **Status:** Correct, but not being loaded by EFI
- **Timestamp:** Oct 18 05:13 (latest update)

### EFI GRUB Stub (THE ACTUAL FIX)
- **File:** `/boot/efi/EFI/ubuntu/grub.cfg`
- **Change:** Updated UUID from old system to current system
- **Backup:** `/boot/efi/EFI/ubuntu/grub.cfg.old`
- **Critical:** This file determines which GRUB configuration is loaded!

---

## Lessons Learned

1. **EFI Boot Chain Complexity:** 
   - EFI → GRUB stub → GRUB config → Kernel
   - Each layer can override or redirect to different configurations

2. **UUID Mismatch Detection:**
   - Always verify EFI stub UUID matches current root filesystem
   - Check with: `diff <(findmnt -n -o UUID /) <(grep fs_uuid /boot/efi/EFI/ubuntu/grub.cfg | awk '{print $2}')`

3. **Multi-Installation Systems:**
   - Old installations can leave behind boot configurations
   - EFI boot entries may point to outdated systems
   - Always check `/boot/efi/EFI/ubuntu/grub.cfg` after system migration

4. **Verification Is Critical:**
   - Don't trust that `update-grub` worked until verifying `/proc/cmdline` after reboot
   - Compare expected vs actual kernel parameters

---

## Additional Monitoring

After reboot, use the monitoring script to verify performance:

```bash
cd /home/jeb/programs/vscode_performance_fix_20251018_032616
./monitor_nvme_performance.sh
```

Watch for:
- ✅ All queues showing activity (not just one concentrated queue)
- ✅ Total queue count 40+
- ✅ Even distribution of interrupts across queues
- ✅ No single queue exceeding 30-40% of total interrupts

---

## Emergency Rollback

If the system fails to boot or has issues:

1. **Boot into GRUB rescue mode**
2. **Restore old EFI stub:**
   ```bash
   sudo cp /boot/efi/EFI/ubuntu/grub.cfg.old /boot/efi/EFI/ubuntu/grub.cfg
   ```
3. **Reboot**

Or from another system/live USB:
```bash
# Mount the EFI partition
mount /dev/nvme1n1p2 /mnt  # or wherever EFI partition is
cp /mnt/EFI/ubuntu/grub.cfg.old /mnt/EFI/ubuntu/grub.cfg
umount /mnt
reboot
```

---

## Status

- [x] Problem identified
- [x] Root cause analyzed  
- [x] EFI stub updated
- [x] Backup created
- [ ] System rebooted (PENDING)
- [ ] Kernel parameters verified (PENDING)
- [ ] Performance improvement confirmed (PENDING)

**Next Action:** Reboot system and verify kernel parameters take effect.
