#!/bin/bash
# ZC339A Complete Fix Installer
set -e

if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root: sudo bash install.sh"
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== [1/4] Patching Device Tree (PMU IO Domain) ==="
bash "$DIR/patch_dtb.sh"

echo "=== [2/4] Installing Watchdog Feeder Daemon ==="
cp "$DIR/zc339a-feed.py" /usr/local/sbin/zc339a-feed.py
chmod +x /usr/local/sbin/zc339a-feed.py

cp "$DIR/zc339a-watchdog.service" /etc/systemd/system/zc339a-watchdog.service
systemctl daemon-reload
systemctl enable --now zc339a-watchdog.service

echo "=== [3/5] Installing Uptime Logger Service ==="
cp "$DIR/zc339a-uptime-logger.sh" /usr/local/sbin/zc339a-uptime-logger.sh
chmod +x /usr/local/sbin/zc339a-uptime-logger.sh

cp "$DIR/zc339a-uptime.service" /etc/systemd/system/zc339a-uptime.service
systemctl daemon-reload
systemctl enable --now zc339a-uptime.service

echo "=== [4/5] Configuring Auto-Login and Disabling DPMS/Screen Blanking ==="
bash "$DIR/disable_dpms_autologin.sh"

echo "=== [5/5] Verifying Services ==="
echo "Watchdog service: $(systemctl is-active zc339a-watchdog.service)"
echo "Uptime service:   $(systemctl is-active zc339a-uptime.service)"

echo ""
echo "[SUCCESS] Installation complete! Please reboot the board once for DTB changes to take full effect:"
echo "          sudo reboot"
