#!/bin/bash
# ==============================================================================
# Universal Clean Image Creator for ZC-339A (Rockchip RK3399)
# Creates a valid GPT bootable image of ~6.5GB (fits any SD/eMMC >= 8GB)
# Output: /home/orangepi/ubuntu-zc339a.img
# ==============================================================================
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root: sudo bash build_image.sh"
  exit 1
fi

IMG="/home/orangepi/ubuntu-zc339a.img"
SRC_DISK="/dev/mmcblk0"
IMG_SIZE_MB=6500

echo "=== [1/6] Allocating image file ($IMG_SIZE_MB MB) ==="
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count=1 seek=$((IMG_SIZE_MB - 1)) status=none

echo "=== [2/6] Initializing fresh GPT Partition Table on Image ==="
parted -s "$IMG" mklabel gpt
parted -s "$IMG" unit s mkpart uboot 24576s 32767s
parted -s "$IMG" unit s mkpart trust 32768s 40959s
parted -s "$IMG" unit s mkpart boot 49152s 114687s
parted -s "$IMG" unit s mkpart rootfs ext4 376832s 100%

echo "=== [3/6] Copying Bootloaders, IDB, Uboot, Trust, and Patched Boot Partition ==="
# 1. IDB Loader (sector 64 to 24575)
dd if="$SRC_DISK" of="$IMG" bs=512 skip=64 seek=64 count=$((24576 - 64)) conv=notrunc status=none
# 2. UBoot (part 1)
dd if="${SRC_DISK}p1" of="$IMG" bs=512 seek=24576 count=8192 conv=notrunc status=none
# 3. Trust (part 2)
dd if="${SRC_DISK}p2" of="$IMG" bs=512 seek=32768 count=8192 conv=notrunc status=none
# 4. Boot (part 3 - Kernel + Patched DTB)
dd if="${SRC_DISK}p3" of="$IMG" bs=512 seek=49152 count=65536 conv=notrunc status=none

echo "=== [4/6] Attaching loop device for rootfs ==="
losetup -D 2>/dev/null || true
LOOP_DEV=$(losetup -Pf --show "$IMG")
echo "      Loop device attached: $LOOP_DEV"
partprobe "$LOOP_DEV"
sleep 2

echo "=== [5/6] Formatting Rootfs (${LOOP_DEV}p4) ==="
mkfs.ext4 -F -q -L "rootfs" "${LOOP_DEV}p4"

MOUNT_DIR="/mnt/zc_img_mount"
mkdir -p "$MOUNT_DIR"
mount "${LOOP_DEV}p4" "$MOUNT_DIR"

echo "=== [6/6] Copying OS files (~2.8GB, please wait 2-3 minutes)... ==="
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
  / "$MOUNT_DIR/"

# Create standard virtual mount points
mkdir -p "$MOUNT_DIR/proc" "$MOUNT_DIR/sys" "$MOUNT_DIR/dev" "$MOUNT_DIR/tmp" "$MOUNT_DIR/run" "$MOUNT_DIR/mnt" "$MOUNT_DIR/media"
chmod 1777 "$MOUNT_DIR/tmp"

echo "      Flushing disk cache and detaching loop device..."
sync
umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"
losetup -d "$LOOP_DEV"

chown orangepi:orangepi "$IMG"
chmod 644 "$IMG"

echo ""
echo "======================================================================"
echo "[SUCCESS] Bootable image created: $IMG"
ls -lh "$IMG"
echo "======================================================================"
echo "Ready to flash or copy to USB!"
echo "======================================================================"
