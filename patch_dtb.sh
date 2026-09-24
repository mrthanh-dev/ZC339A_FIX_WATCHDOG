#!/bin/bash
# Patch DTB on boot partition /dev/mmcblk0p3
# Changes pmu1830-supply from invalid vcc_3v0 to vcc1v8_pmu (phandle 256 / 0x100)
set -e

BOOT_PART="/dev/mmcblk0p3"
DTB_OFFSET=17770496
DTB_SIZE=120000
TMP_DTB="/tmp/zc_boot.dtb"

echo "[1/4] Extracting DTB from $BOOT_PART at offset $DTB_OFFSET..."
dd if="$BOOT_PART" of="$TMP_DTB" bs=1 count="$DTB_SIZE" skip="$DTB_OFFSET" 2>/dev/null

echo "[2/4] Checking current pmu1830-supply..."
cur_val=$(fdtget "$TMP_DTB" /syscon@ff320000/io-domains pmu1830-supply 2>/dev/null || echo "not_found")
echo "      Current pmu1830-supply: $cur_val"

echo "[3/4] Patching pmu1830-supply to 256 (0x100 = vcc1v8_pmu)..."
fdtput -t i "$TMP_DTB" /syscon@ff320000/io-domains pmu1830-supply 256

echo "[4/4] Writing patched DTB back to $BOOT_PART..."
dd if="$TMP_DTB" of="$BOOT_PART" bs=1 seek="$DTB_OFFSET" conv=notrunc 2>/dev/null
sync

echo "[OK] DTB successfully patched. Reboot required for changes to take effect."
