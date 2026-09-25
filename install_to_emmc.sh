#!/bin/bash
# ==============================================================================
# ZC-339A (RK3399): Clean & Robust Installer from SD to eMMC (32GB)
# ==============================================================================
set -e

SRC_DISK="/dev/mmcblk0"
DST_DISK="/dev/mmcblk1"
EMMC_ROOTFS_PARTUUID="615E0000-0000-4B53-8000-1D28000054A9"

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root: sudo bash install_to_emmc.sh"
  exit 1
fi

echo "=== [1/7] Unmounting any active partitions on $DST_DISK ==="
for p in $(ls -1 ${DST_DISK}p* 2>/dev/null || true); do
  umount -f "$p" 2>/dev/null || true
done

echo "=== [2/7] Initializing clean GPT partition table on $DST_DISK ==="
parted -s "$DST_DISK" mklabel gpt
parted -s "$DST_DISK" unit s mkpart uboot 24576s 32767s
parted -s "$DST_DISK" unit s mkpart trust 32768s 40959s
parted -s "$DST_DISK" unit s mkpart boot 49152s 114687s
parted -s "$DST_DISK" unit s mkpart rootfs ext4 376832s 100%

# Critical: Set PARTUUID required by Rockchip U-Boot when booting from eMMC
sfdisk --part-uuid "$DST_DISK" 4 "$EMMC_ROOTFS_PARTUUID"

partprobe "$DST_DISK" 2>/dev/null || true
sleep 2

echo "=== [3/7] Copying Rockchip IDB Loader & Bootloader Partitions ==="
# 1. IDB Loader (sector 64 to 24575)
dd if="$SRC_DISK" of="$DST_DISK" bs=512 skip=64 seek=64 count=$((24576 - 64)) conv=notrunc status=none
# 2. UBoot (part 1)
dd if="${SRC_DISK}p1" of="${DST_DISK}p1" bs=1M status=none conv=fsync
# 3. Trust (part 2)
dd if="${SRC_DISK}p2" of="${DST_DISK}p2" bs=1M status=none conv=fsync
# 4. Boot (part 3 - Kernel + Patched DTB)
dd if="${SRC_DISK}p3" of="${DST_DISK}p3" bs=1M status=none conv=fsync

echo "=== [4/7] Formatting Rootfs on eMMC (${DST_DISK}p4) ==="
mkfs.ext4 -F -q -L "rootfs" "${DST_DISK}p4"

MOUNT_DIR="/mnt/emmc_root"
mkdir -p "$MOUNT_DIR"
mount "${DST_DISK}p4" "$MOUNT_DIR"

echo "=== [5/7] Copying Ubuntu OS (~2.8GB to eMMC, please wait ~2 minutes)... ==="
rsync -aHAXx \
  --exclude="/home/orangepi/ubuntu-zc339a.img*" \
  --exclude="/home/orangepi/real-android-kernel.img" \
  --exclude="/home/orangepi/test-*" \
  --exclude="/proc/*" \
  --exclude="/sys/*" \
  --exclude="/dev/*" \
  --exclude="/tmp/*" \
  --exclude="/run/*" \
  --exclude="/mnt/*" \
  --exclude="/media/*" \
  --exclude="/lost+found" \
  / "$MOUNT_DIR/" || true

# Recreate standard mount directories
mkdir -p "$MOUNT_DIR/proc" "$MOUNT_DIR/sys" "$MOUNT_DIR/dev" "$MOUNT_DIR/tmp" "$MOUNT_DIR/run" "$MOUNT_DIR/mnt" "$MOUNT_DIR/media"
chmod 1777 "$MOUNT_DIR/tmp"

echo "=== [6/7] Updating /etc/fstab for eMMC Rootfs ==="
cat << 'EOF' > "$MOUNT_DIR/etc/fstab"
PARTUUID=615E0000-0000-4B53-8000-1D28000054A9 / ext4 defaults,noatime 0 1
EOF

echo "=== [7/7] Flushing data to eMMC and unmounting ==="
sync
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo ""
echo "======================================================================"
echo "[SUCCESS] Ubuntu has been cleanly installed to internal eMMC!"
echo "======================================================================"
echo "You can now safely shut down, remove the SD card, and boot from eMMC:"
echo "  poweroff"
echo "======================================================================"
