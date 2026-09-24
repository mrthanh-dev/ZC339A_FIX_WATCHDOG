#!/bin/bash
set -e

echo "[1/4] Configuring LightDM Auto-Login and No-DPMS..."
mkdir -p /etc/lightdm/lightdm.conf.d
cat << 'EOF' > /etc/lightdm/lightdm.conf.d/50-autologin.conf
[Seat:*]
autologin-user=orangepi
autologin-user-timeout=0
user-session=xfce
xserver-command=X -s 0 -dpms
EOF

echo "[2/4] Disabling DPMS and screen blanking in X11 Autostart..."
mkdir -p /etc/xdg/autostart
cat << 'EOF' > /etc/xdg/autostart/disable-dpms.desktop
[Desktop Entry]
Type=Application
Name=Disable Screen Blanking and DPMS
Exec=xset s off -dpms s noblank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo "[3/4] Configuring XFCE Power Manager settings for orangepi..."
USER_HOME="/home/orangepi"
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

cat << 'EOF' > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml"
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="power-button-action" type="uint" value="4"/>
    <property name="blank-on-ac" type="int" value="0"/>
    <property name="dpms-on-ac-sleep" type="uint" value="0"/>
    <property name="dpms-on-ac-off" type="uint" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="dpms-on-battery-sleep" type="uint" value="0"/>
    <property name="dpms-on-battery-off" type="uint" value="0"/>
  </property>
</channel>
EOF

cat << 'EOF' > "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml"
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
    <property name="mode" type="int" value="0"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
EOF

chown -R orangepi:orangepi "$USER_HOME/.config"

echo "[4/4] Waking up current active display and turning DPMS off..."
export DISPLAY=:0
export XAUTHORITY=$(ls -1 /var/run/lightdm/root/:0 /home/orangepi/.Xauthority 2>/dev/null | head -n 1 || true)
if [ -n "$XAUTHORITY" ]; then
    xset -display :0 dpms force on 2>/dev/null || true
    xset -display :0 s off -dpms s noblank 2>/dev/null || true
fi

echo "[OK] Auto-login enabled and DPMS permanently disabled!"
