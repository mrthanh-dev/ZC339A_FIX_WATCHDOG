#!/bin/bash
# ==============================================================================
# Script to create a shrinked, universal bootable image of ZC-339A Ubuntu
# Output: /home/orangepi/ubuntu-zc339a.img (Size: ~6.5GB, fits on any >=8GB SD/eMMC)
# ==============================================================================
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root: sudo bash create_image.sh"
  exit 1
fi

IMG="/home/orangepi/ubuntu-zc339a.img"
SRC="/dev/mmcblk0"
IMG_SIZE_MB=6500  # 6.5 GB

echo "=== [1/6] Cleaning up old image if exists ==="
rm -f "$IMG"

echo "=== [2/6] Allocating image file ($IMG_SIZE_MB MB) ==="
# Ensure real file size so partition table tools can see the end of disk
dd if=/dev/zero of="$IMG" bs=1M count=1 seek=$((IMG_SIZE_MB - 1)) status=none

echo "=== [3/6] Copying bootloader, uboot, trust and patched boot partition (first 64MB) ==="
dd if="$SRC" of="$IMG" bs=1M count=64 conv=notrunc status=progress

echo "=== [4/6] Setting up loop device and creating GPT partition table ==="
# Attach loop device
LOOP_DEV=$(losetup -Pf --show "$IMG")
echo "      Loop device attached: $LOOP_DEV"

# Fix backup GPT at the end of the 6.5GB image
printf "x\ne\nw\ny\n" | gdisk "$LOOP_DEV" >/dev/null 2>&1 || true

# Recreate partition 4 to span from sector 376832 to the end of 6.5GB image
parted -s "$LOOP_DEV" rm 4 2>/dev/null || true
parted -s "$LOOP_DEV" unit s mkpart rootfs ext4 376832s 100%

partprobe "$LOOP_DEV"
sleep 2

echo "=== [5/6] Formatting Rootfs on image (${LOOP_DEV}p4) ==="
mkfs.ext4 -F -q -L "rootfs" "${LOOP_DEV}p4"

MOUNT_DIR="/mnt/zc_img_mount"
mkdir -p "$MOUNT_DIR"
mount "${LOOP_DEV}p4" "$MOUNT_DIR"

echo "=== [6/6] Syncing rootfs data to image (transferring ~2.8GB)... ==="
rsync -aHAXx \
  --exclude="/home/orangepi/ubuntu-zc339a.img" \
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
  / "$MOUNT_DIR/"

# Create excluded directories
mkdir -p "$MOUNT_DIR/proc" "$MOUNT_DIR/sys" "$MOUNT_DIR/dev" "$MOUNT_DIR/tmp" "$MOUNT_DIR/run" "$MOUNT_DIR/mnt" "$MOUNT_DIR/media"
chmod 1777 "$MOUNT_DIR/tmp"

# Cleanup
echo "      Unmounting and finalizing..."
sync
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
losetup -d "$LOOP_DEV"

chown orangepi:orangepi "$IMG"
chmod 644 "$IMG"

echo ""
echo "======================================================================"
echo "[SUCCESS] Image created successfully: $IMG"
ls -lh "$IMG"
echo "======================================================================"
echo "You can now insert a USB drive and copy this file out:"
echo "  sudo cp $IMG /media/your_usb/"
echo "======================================================================"
