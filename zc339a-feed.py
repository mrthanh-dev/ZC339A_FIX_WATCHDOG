#!/usr/bin/env python3
"""
ZC339A Hardware Watchdog Feeder & LED RUN Controller
Matches reverse-engineered driver 'rockchip,rk3288-dog-control' from stock Android 9 kernel.
"""

import time
import os
import sys

def export_gpio(pin):
    path = f"/sys/class/gpio/gpio{pin}"
    if not os.path.exists(path):
        try:
            with open("/sys/class/gpio/export", "w") as f:
                f.write(f"{pin}\n")
        except Exception:
            pass

def main():
    # 1. Export pins:
    # GPIO 35: dog_en  (GPIO1_A3) - External MCU Watchdog Enable
    # GPIO 36: dog_pwm (GPIO1_A4) - Watchdog Petting Pulse
    # GPIO 152: zc_led (GPIO4_D0) - System RUN Status LED
    export_gpio(35)
    export_gpio(36)
    export_gpio(152)
    time.sleep(0.1)

    # 2. Set direction to output
    for pin in [35, 36, 152]:
        try:
            with open(f"/sys/class/gpio/gpio{pin}/direction", "w") as f:
                f.write("out\n")
        except Exception as e:
            sys.stderr.write(f"Error setting direction for GPIO {pin}: {e}\n")

    # 3. Open value file handles
    f_en  = open("/sys/class/gpio/gpio35/value", "w")
    f_pwm = open("/sys/class/gpio/gpio36/value", "w")
    f_led = open("/sys/class/gpio/gpio152/value", "w")

    # dog_en is ALWAYS 1 (active HIGH) to keep watchdog armed
    f_en.write("1\n")
    f_en.flush()

    pwm = 0
    led = 0
    tick = 0

    # 4. Watchdog feeding loop
    while True:
        # Toggle dog_pwm every 250ms (matches stock Android driver)
        pwm = 1 - pwm
        f_pwm.seek(0)
        f_pwm.write(f"{pwm}\n")
        f_pwm.flush()

        # Toggle LED RUN every 1000ms (1 second per blink)
        tick += 1
        if tick >= 4:
            tick = 0
            led = 1 - led
            f_led.seek(0)
            f_led.write(f"{led}\n")
            f_led.flush()

        time.sleep(0.25)

if __name__ == "__main__":
    main()
