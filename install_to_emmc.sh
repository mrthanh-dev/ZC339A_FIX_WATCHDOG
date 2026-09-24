#!/bin/bash
# ==============================================================================
# ZC-339A (RK3399): Clone & Install Linux from SD Card to eMMC
# ==============================================================================
# CAUTION: This script will OVERWRITE all data on eMMC (/dev/mmcblk1)!
# Make sure you have backed up any needed data or stock Android firmware.
# ==============================================================================

set -e

SRC_DEV="/dev/mmcblk0"
DST_DEV="/dev/mmcblk1"

if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: Please run this script as root: sudo bash install_to_emmc.sh"
  exit 1
fi

if [ ! -b "$SRC_DEV" ]; then
  echo "[-] Error: Source SD card $SRC_DEV not found!"
  exit 1
fi

if [ ! -b "$DST_DEV" ]; then
  echo "[-] Error: Destination eMMC $DST_DEV not found!"
  exit 1
fi

echo "======================================================================"
echo "          ZC-339A LINUX eMMC INSTALLATION WIZARD                      "
echo "======================================================================"
echo " Source (SD Card): $SRC_DEV ($(lsblk -dn -o SIZE $SRC_DEV | tr -d ' '))"
echo " Target (eMMC):    $DST_DEV ($(lsblk -dn -o SIZE $DST_DEV | tr -d ' '))"
echo "======================================================================"
echo "WARNING: ALL DATA ON eMMC ($DST_DEV) WILL BE PERMANENTLY ERASED!"
echo "This will replace stock Android with the current patched Ubuntu Linux."
echo "======================================================================"
read -p "Are you sure you want to proceed? (type 'YES' to confirm): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
  echo "[-] Aborted by user."
  exit 0
fi

echo ""
echo "[1/5] Unmounting any active partitions on eMMC..."
for part in $(ls -1 ${DST_DEV}p* 2>/dev/null || true); do
  umount -f "$part" 2>/dev/null || true
done

echo "[2/5] Copying Bootloader & Partition Table (First 16MB)..."
dd if="$SRC_DEV" of="$DST_DEV" bs=1M count=16 status=progress conv=fsync
partprobe "$DST_DEV" 2>/dev/null || true
sleep 2

echo "[3/5] Copying Kernel Boot Partition (${SRC_DEV}p3 -> ${DST_DEV}p3)..."
if [ -b "${SRC_DEV}p3" ] && [ -b "${DST_DEV}p3" ]; then
  dd if="${SRC_DEV}p3" of="${DST_DEV}p3" bs=4M status=progress conv=fsync
else
  echo "[!] Warning: Boot partition p3 not found, cloning raw first 64MB..."
  dd if="$SRC_DEV" of="$DST_DEV" bs=1M count=64 seek=0 conv=notrunc status=progress
fi

echo "[4/5] Copying Root Filesystem (${SRC_DEV}p4 -> ${DST_DEV}p4)..."
if [ -b "${SRC_DEV}p4" ] && [ -b "${DST_DEV}p4" ]; then
  dd if="${SRC_DEV}p4" of="${DST_DEV}p4" bs=4M status=progress conv=fsync
  e2fsck -fy "${DST_DEV}p4" || true
  resize2fs "${DST_DEV}p4" || true
else
  echo "[-] Error: Root partition p4 not found on destination."
  exit 1
fi

echo "[5/5] Syncing buffers to disk..."
sync

echo ""
echo "======================================================================"
echo "[SUCCESS] Ubuntu Linux has been successfully installed to eMMC!"
echo "======================================================================"
echo "Next steps:"
echo "1. Power off the board: sudo poweroff"
echo "2. Remove the SD card."
echo "3. Power on the board to boot directly from internal eMMC."
echo "======================================================================"
