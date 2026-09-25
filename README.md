# ZC-339A (Rockchip RK3399) Linux Hardware Fix

Hướng dẫn kỹ thuật và bộ công cụ khắc phục triệt để các lỗi phần cứng trên bo mạch **ZC-339A** (SoC Rockchip RK3399, 4GB LPDDR4, PMIC RK808, tích hợp MCU quản lý nguồn) khi chạy các bản phân phối Linux (như Ubuntu 18.04/20.04/22.04, Debian từ OrangePi, Armbian...):

1. **Khắc phục lỗi tự động sập nguồn / Reset đúng 10:00 phút (600 giây)**.
2. **Khắc phục lỗi Kernel Panic (`rockchip_dfi_init`) khi sửa Device Tree**.
3. **Bảo toàn tín hiệu xuất hình HDMI (`/dev/fb0`, `/dev/dri/card0`)**.

---

## 1. Bản Chất Phần Cứng & Nguyên Nhân Gốc Rễ

### A. Cơ chế Watchdog 10 Phút của MCU Ngoại Vi
- Theo tài liệu đặc tả phần cứng bo mạch (*ZC-339主板规格书*), bo mạch trang bị một **vi điều khiển (MCU ngoại vi)** độc lập phối hợp cùng IC nguồn **RK808** để phụ trách tính năng hồng ngoại (IR), hẹn giờ bật/tắt (定时开关机) và **Watchdog phần cứng**.
- Nếu hệ điều hành không gửi tín hiệu kích hoạt và xung nuôi định kỳ đến MCU, sau đúng **600 giây (10 phút)** MCU sẽ ra lệnh cho RK808 ngắt nguồn hoặc kéo chân reset toàn bộ hệ thống.

### B. Logic Trong Driver Gốc Android (`rockchip,rk3288-dog-control`)
Dịch ngược mã máy ARM64 từ Android Kernel gốc (`real-android-kernel.img`) xác định chính xác hoạt động của driver watchdog:
- **`dog_en` (GPIO 35 - `GPIO1_A3`):** Bắt buộc duy trì mức **HIGH (`1`)** để bật mạch watchdog.
- **`dog_pwm` (GPIO 36 - `GPIO1_A4`):** Nhận chuỗi xung đảo trạng thái (`0 <-> 1`) chu kỳ **250ms**.
- **`zc_led` (GPIO 152 - `GPIO4_D0`):** Đảo mức sau mỗi 4 chu kỳ timer (chu kỳ đúng **1000ms / 1 giây**) để nháy đèn LED `RUN` báo trạng thái bình thường.

### C. Tại Sao Trên Linux Trước Đây Không Thể Xuất Mức HIGH Ra GPIO 35 & 36?
- Trong Device Tree của OrangePi/Linux thông thường, node cấp nguồn cho GPIO Bank 1 (`/syscon@ff320000/io-domains/pmu1830-supply`) bị gán nhầm vào `vcc_3v0` (3.0V từ `LDO_REG8`).
- Trên thực tế mạch phần cứng ZC-339A, domain `pmu1830` được cấp bởi **`vcc1v8_pmu` (1.8V từ `LDO_REG3`)**.
- Cấu hình sai nguồn khiến silicon output buffer của GPIO Bank 1 không được cấp điện đúng chuẩn, khiến chân vật lý bị kẹt ở mức 0V (`val=0`), không thể kích hoạt MCU!

---

## 2. Cài Đặt Nhanh (1 Lệnh Duy Nhất)

Clone hoặc copy thư mục `ZC339A_FIX` vào bo mạch, sau đó chạy:

```bash
cd ZC339A_FIX
sudo bash install.sh
sudo reboot
```

Sau khi khởi động lại, bo mạch sẽ chạy liên tục ổn định, đèn LED `RUN` nháy đều 1 giây / lần và không còn bị reset sau 10 phút.

---

## 3. Cài Đặt Thủ Công Từng Bước

### Bước 1: Patch Device Tree Sửa Lỗi Nguồn I/O Domain `pmu1830`
Sửa trực tiếp nhị phân DTB trong phân vùng boot của thẻ nhớ (`/dev/mmcblk0p3` tại offset `17770496` bytes) bằng công cụ `fdtput`:

```bash
# 1. Trích xuất DTB ra file tạm
sudo dd if=/dev/mmcblk0p3 of=/tmp/zc_dtb.dtb bs=1 count=120000 skip=17770496

# 2. Phân quyền cho user
sudo chown $USER:$USER /tmp/zc_dtb.dtb

# 3. Patch pmu1830-supply trỏ về phandle 256 (0x100 = LDO_REG3 vcc1v8_pmu)
fdtput -t i /tmp/zc_dtb.dtb /syscon@ff320000/io-domains pmu1830-supply 256

# 4. Ghi đè lại vào phân vùng boot
sudo dd if=/tmp/zc_dtb.dtb of=/dev/mmcblk0p3 bs=1 seek=17770496 conv=notrunc
sync
```

*(Sau bước này cần reboot bo mạch 1 lần để DTB mới có hiệu lực)*.

---

### Bước 2: Cài Đặt Daemon Nuôi Watchdog & Nháy LED RUN
Copy file `zc339a-feed.py` vào `/usr/local/sbin/`:

```bash
sudo cp zc339a-feed.py /usr/local/sbin/zc339a-feed.py
sudo chmod +x /usr/local/sbin/zc339a-feed.py
```

Cài đặt service tự khởi động:

```bash
sudo cp zc339a-watchdog.service /etc/systemd/system/zc339a-watchdog.service
sudo systemctl daemon-reload
sudo systemctl enable --now zc339a-watchdog.service
```

---

### Bước 3: Cài Đặt Dịch Vụ Ghi Log Uptime (Tùy Chọn)
Dịch vụ này tự động ghi timestamp và uptime vào `/home/orangepi/uptime.txt` mỗi 60 giây (kèm `sync` đĩa):

```bash
sudo cp zc339a-uptime-logger.sh /usr/local/sbin/zc339a-uptime-logger.sh
sudo chmod +x /usr/local/sbin/zc339a-uptime-logger.sh

sudo cp zc339a-uptime.service /etc/systemd/system/zc339a-uptime.service
sudo systemctl daemon-reload
sudo systemctl enable --now zc339a-uptime.service
```

---

## 4. Cài Đặt Linux Lên Bộ Nhớ Trong eMMC (Tùy Chọn)

Nếu bạn muốn chạy trực tiếp Ubuntu trên bộ nhớ trong eMMC thay vì chạy từ thẻ nhớ SD:

> [!CAUTION]
> Quá trình này sẽ ghi đè toàn bộ hệ điều hành Android gốc trên eMMC (`/dev/mmcblk1`). Hãy chắc chắn bạn đã sao lưu dữ liệu quan trọng trước khi chạy!

Chạy script cài đặt vào eMMC:
```bash
cd ZC339A_FIX
sudo bash install_to_emmc.sh
```
Nhập `YES` để xác nhận. Sau khi script hoàn tất:
1. Tắt máy: `sudo poweroff`
2. Rút thẻ nhớ MicroSD ra khỏi khe cắm.
3. Cấp lại nguồn, bo mạch sẽ khởi động trực tiếp Ubuntu Linux từ eMMC với đầy đủ các bản vá phần cứng, xuất hình HDMI và chống sập nguồn.

---

## 5. Kiểm Tra & Xác Minh Kết Quả

1. **Kiểm tra trạng thái dịch vụ:**
   ```bash
   systemctl is-active zc339a-watchdog.service
   # Kết quả: active
   ```

2. **Kiểm tra trạng thái các chân GPIO:**
   ```bash
   cat /sys/class/gpio/gpio35/value   # Luôn là 1 (dog_en)
   cat /sys/class/gpio/gpio36/value   # Đảo xung 0 <-> 1 mỗi 250ms (dog_pwm)
   cat /sys/class/gpio/gpio152/value  # Đảo 0 <-> 1 mỗi 1 giây (zc_led)
   ```

3. **Quan sát trực quan phần cứng:**
   - Đèn LED `RUN` trên bo mạch nháy đều đặn **1 giây / lần** (khớp hoàn toàn với Android gốc).
   - Màn hình HDMI hiển thị sắc nét 1080p@60Hz.
   - Bo mạch hoạt động liên tục 24/7, vượt xa mốc 10 phút.

---

## 6. Cấu Trúc Thư Mục Repo

```text
ZC339A_FIX/
??? README.md                  # Tài liệu hướng dẫn kỹ thuật chi tiết
??? install.sh                 # Script cài đặt tự động toàn bộ bản fix
??? install_to_emmc.sh         # Script cài đặt / clone Ubuntu sang eMMC
??? build_image.sh             # Script tạo file ảnh đĩa ubuntu-zc339a.img bootable
??? patch_dtb.sh               # Script tự động patch Device Tree PMU
??? zc339a-feed.py             # Daemon nuôi Watchdog và điều khiển LED RUN
??? zc339a-watchdog.service    # Systemd service cho Watchdog Daemon
??? zc339a-uptime-logger.sh    # Script ghi log uptime định kỳ
??? zc339a-uptime.service      # Systemd service ghi log uptime
```

## Bản Quyền & Giấy Phép
Dự án được cung cấp theo giấy phép MIT. Mã nguồn mở phục vụ cộng đồng phát triển nhúng Rockchip RK3399.
