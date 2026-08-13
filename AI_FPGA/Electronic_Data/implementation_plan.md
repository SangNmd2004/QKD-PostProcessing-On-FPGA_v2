# Hệ thống đếm linh kiện điện tử trên băng chuyền
## Tang Mega 138K Pro + BeagleBone Black (Kiến trúc lai)

### Bối cảnh
- **FPGA**: Sipeed Tang Mega 138K Pro (Gowin GW5AST-LV138PG484A)
- **MCU/SBC**: BeagleBone Black (AM3358 Cortex-A8, 512MB RAM, Linux)
- **Mục tiêu**: Đếm và phân loại 3 loại linh kiện (tụ, trở, IC) trên băng chuyền
- **Kinh nghiệm**: Cơ bản
- **Loại đồ án**: Tốt nghiệp

---

## User Review Required

> [!IMPORTANT]
> **BBB chạy Linux** → dùng **Python + TFLite** thay vì C bare-metal. Dễ code hơn nhiều so với ESP32-S3, rất phù hợp trình độ cơ bản.

> [!WARNING]
> **BBB KHÔNG đủ mạnh để chạy YOLO.** Thay vào đó, FPGA làm toàn bộ detection (blob detect), BBB chỉ **classify từng ROI nhỏ** bằng CNN tự thiết kế — đủ nhanh (~50-100ms/ROI).

> [!TIP]
> **Ưu điểm bất ngờ của BBB**: Có **HDMI** → hiển thị GUI trực tiếp lên màn hình, và **Ethernet** → web monitoring. Không cần mua thêm LCD riêng.

---

## 1. Tại sao BBB hoạt động được cho bài toán này

Mấu chốt: **FPGA đã làm phần nặng nhất** (detection). BBB chỉ cần classify ROI nhỏ.

```
Luồng truyền thống (1 board làm tất cả):
  Camera → [Detection + Classification] → Counting
                    ↑ CẦN YOLO, RẤT NẶNG

Luồng của chúng ta (2 board chia việc):
  Camera → [FPGA: Detection] → [BBB: Classification only] → Counting
              ↑ Hardware pipeline       ↑ CNN nhỏ, nhẹ
              Real-time, 30fps          ~10-20 ROI/s, ĐỦ
```

| Tác vụ | Ai làm | Tốc độ |
|---|---|---|
| Tìm vị trí linh kiện (detection) | FPGA (blob detect) | Real-time 30fps |
| Cắt ROI 64×64 | FPGA | Real-time |
| Phân loại tụ/trở/IC (classify) | BBB (TFLite CNN) | ~50-100ms/ROI |
| Tracking + Đếm | BBB (Python) | Rất nhanh |

→ Với băng chuyền chậm (~5-10 linh kiện/giây), BBB classify **đủ nhanh**.

---

## 2. Kiến trúc tổng thể

```
┌──────────────────────────────────────────────────────┐
│                FPGA (Tang Mega 138K Pro)              │
│                                                      │
│  ┌──────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │ OV5640   │──▶│ Preprocessing│──▶│ SPI Master   │─┼──▶ BBB
│  │ DVP      │   │ Pipeline     │   │ (10MHz)      │ │   (SPI1)
│  │ Capture  │   │              │   └──────────────┘ │
│  └──────────┘   │ • Grayscale  │   ┌──────────────┐ │
│                 │ • Gaussian   │──▶│ HDMI Output  │─┼──▶ Monitor
│                 │ • Threshold  │   │ (Debug)       │ │   (debug)
│                 │ • Morphology │   └──────────────┘ │
│                 │ • Blob Detect│                     │
│                 │ • ROI Extract│                     │
│                 └──────────────┘                     │
└──────────────────────────────────────────────────────┘
       │ SPI: bounding boxes + ROI pixels (grayscale 64×64)
       ▼
┌──────────────────────────────────────────────────────┐
│              BeagleBone Black (Linux)                 │
│                                                      │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────┐ │
│  │ SPI      │─▶│ TFLite     │─▶│ Tracker +        │ │
│  │ receive  │  │ CNN (INT8) │  │ Counter          │ │
│  │ (spidev) │  │ (Python)   │  └────────┬─────────┘ │
│  └──────────┘  └────────────┘           │           │
│                         ┌───────────────┘           │
│  ┌──────────┐  ┌────────┴───┐  ┌──────────────────┐ │
│  │ HDMI GUI │  │ Buzzer/LED │  │ Ethernet Web     │ │
│  │ (PyGame) │  │ (GPIO)     │  │ Server (Flask)   │ │
│  └──────────┘  └────────────┘  └──────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### Kết nối vật lý FPGA ↔ BBB

| Tín hiệu | FPGA Pin | BBB Pin (SPI1) | Ghi chú |
|---|---|---|---|
| SPI_CLK | GPIO header | P9_31 (SPI1_SCLK) | FPGA = Master |
| SPI_MOSI | GPIO header | P9_30 (SPI1_D1) | FPGA → BBB |
| SPI_MISO | GPIO header | P9_29 (SPI1_D0) | BBB → FPGA |
| SPI_CS | GPIO header | P9_28 (SPI1_CS0) | Chip select |
| IRQ | GPIO header | P9_12 (GPIO_60) | Data ready interrupt |
| GND | GND | P9_1 | Chung mass |

---

## 3. FPGA Side — Verilog Modules

### 3.1 Camera & Preprocessing (giữ nguyên plan trước)

| Module | File | Chức năng |
|---|---|---|
| DVP Capture | [cam_dvp_capture.v](file:///d:/Dem_linhkien/rtl/cam_dvp_capture.v) | Nhận pixel từ OV5640 |
| I2C Config | [cam_i2c_config.v](file:///d:/Dem_linhkien/rtl/cam_i2c_config.v) | Cấu hình camera registers |
| RGB→Gray | [rgb2gray.v](file:///d:/Dem_linhkien/rtl/rgb2gray.v) | `Gray = (R*77+G*150+B*29)>>8` |
| Gaussian 3×3 | [gaussian_3x3.v](file:///d:/Dem_linhkien/rtl/gaussian_3x3.v) | Khử nhiễu, line buffer |
| Threshold | [threshold.v](file:///d:/Dem_linhkien/rtl/threshold.v) | Binary segmentation |
| Morphology | [morphology.v](file:///d:/Dem_linhkien/rtl/morphology.v) | Erosion + Dilation |
| Blob Detect | [blob_detector.v](file:///d:/Dem_linhkien/rtl/blob_detector.v) | Connected component → BBox |

### 3.2 ROI + SPI (thay đổi so với plan trước)

#### [NEW] [roi_extractor.v](file:///d:/Dem_linhkien/rtl/roi_extractor.v)

Cắt ROI grayscale 64×64 từ mỗi bounding box:
- Đọc pixel từ grayscale frame buffer (BRAM/DDR3)
- Nearest-neighbor resize về 64×64
- Buffer sẵn sàng gửi SPI

#### [NEW] [spi_master.v](file:///d:/Dem_linhkien/rtl/spi_master.v)

SPI Master protocol:
```
Frame: [0xAA][FRAME_ID:2B][NUM_BLOBS:1B]
  Per blob: [x1:2B][y1:2B][x2:2B][y2:2B][ROI:4096B]
[CHECKSUM:1B]
```
- Clock 10MHz, IRQ pin báo data ready

#### [NEW] [hdmi_output.v](file:///d:/Dem_linhkien/rtl/hdmi_output.v)
#### [NEW] [top.v](file:///d:/Dem_linhkien/rtl/top.v)
#### [NEW] [top.cst](file:///d:/Dem_linhkien/constraints/top.cst)

---

## 4. BBB Side — Python (chạy trên Debian Linux)

> [!TIP]
> **Ưu điểm lớn nhất của BBB so với ESP32**: Viết code bằng **Python** trên Linux, dùng `pip install`, debug trực tiếp qua SSH. Rất phù hợp trình độ cơ bản.

### 4.1 SPI Receiver

#### [NEW] [spi_receiver.py](file:///d:/Dem_linhkien/software/spi_receiver.py)

```python
# Ví dụ đơn giản
import spidev
spi = spidev.SpiDev()
spi.open(1, 0)  # SPI1, CS0
spi.max_speed_hz = 10_000_000

# Đợi IRQ (GPIO interrupt) rồi đọc data
import Adafruit_BBIO.GPIO as GPIO
GPIO.setup("P9_12", GPIO.IN)
GPIO.wait_for_edge("P9_12", GPIO.RISING)
data = spi.readbytes(frame_size)
```

- Parse frame → extract bbox list + ROI numpy arrays
- Thread riêng cho SPI receive

### 4.2 CNN Classifier

#### [NEW] [classifier.py](file:///d:/Dem_linhkien/software/classifier.py)

```python
import tflite_runtime.interpreter as tflite
import numpy as np

interpreter = tflite.Interpreter(model_path="model.tflite")
interpreter.allocate_tensors()

def classify(roi_64x64):
    # roi shape: (64, 64) uint8 grayscale
    input_data = roi_64x64.reshape(1, 64, 64, 1).astype(np.int8)
    interpreter.set_tensor(input_index, input_data)
    interpreter.invoke()
    output = interpreter.get_tensor(output_index)
    classes = ["resistor", "capacitor", "IC"]
    return classes[np.argmax(output)]
```

- **TFLite Runtime** (không cần full TensorFlow, chỉ ~5MB)
- Model INT8 quantized, ~100-500KB
- Inference trên Cortex-A8: **~50-100ms per 64×64 ROI**

### 4.3 Model Training (chạy trên PC 1 lần)

#### [NEW] [train_and_convert.py](file:///d:/Dem_linhkien/training/train_and_convert.py)

CNN kiến trúc nhỏ cho MCU:
```
Input: 64×64×1 grayscale
Conv2D(16, 3×3) → ReLU → MaxPool(2×2)    → 32×32×16
Conv2D(32, 3×3) → ReLU → MaxPool(2×2)    → 16×16×32
Conv2D(64, 3×3) → ReLU → GlobalAvgPool   → 64
Dense(3, softmax)                          → 3 classes
```
- Train bằng TensorFlow/Keras trên PC
- Post-training quantization INT8
- Export `model.tflite` → copy lên BBB

#### [NEW] [dataset_capture.py](file:///d:/Dem_linhkien/training/dataset_capture.py)

Script chụp ảnh linh kiện tạo dataset (~200-500 ảnh/loại)

### 4.4 Tracking & Counting

#### [NEW] [tracker.py](file:///d:/Dem_linhkien/software/tracker.py)

- IoU matching giữa các frame
- Counting line (vạch ảo giữa frame)
- Mỗi object đếm 1 lần duy nhất
- Counter: `{"resistor": N, "capacitor": M, "IC": K}`

### 4.5 Hiển thị & Monitoring

#### [NEW] [gui_display.py](file:///d:/Dem_linhkien/software/gui_display.py)

BBB có **HDMI output** → chạy GUI trực tiếp:
- **PyGame** (nhẹ hơn tkinter cho embedded)
- Hiển thị:
  - Bộ đếm 3 loại (font lớn, dễ đọc)
  - ROI đang classify (debug)
  - Trạng thái: FPS, confidence
  - Nút Reset (touchscreen hoặc button vật lý)

#### [NEW] [web_server.py](file:///d:/Dem_linhkien/software/web_server.py)

BBB có **Ethernet** → web monitoring:
- Flask web server nhẹ
- Truy cập qua `http://<bbb_ip>:5000`
- Trang web hiển thị số đếm real-time (auto-refresh)
- Có thể truy cập từ điện thoại cùng mạng LAN

#### [NEW] [main.py](file:///d:/Dem_linhkien/software/main.py)

Entry point — 2 threads:
- **Thread 1**: SPI receive → CNN classify → Track → Count
- **Thread 2**: GUI display + Web server

---

## 5. Cấu trúc thư mục

```
d:\Dem_linhkien\
├── rtl\                        # FPGA Verilog
│   ├── top.v
│   ├── cam_dvp_capture.v
│   ├── cam_i2c_config.v
│   ├── rgb2gray.v
│   ├── gaussian_3x3.v
│   ├── threshold.v
│   ├── morphology.v
│   ├── blob_detector.v
│   ├── roi_extractor.v
│   ├── spi_master.v
│   └── hdmi_output.v
├── constraints\
│   └── top.cst
├── sim\
│   └── tb_*.v
├── software\                   # BBB Python app
│   ├── main.py
│   ├── spi_receiver.py
│   ├── classifier.py
│   ├── tracker.py
│   ├── gui_display.py
│   ├── web_server.py
│   ├── model.tflite
│   └── requirements.txt
├── training\                   # PC (chạy 1 lần)
│   ├── train_and_convert.py
│   └── dataset_capture.py
├── dataset\
│   ├── resistor\
│   ├── capacitor\
│   └── ic\
├── web\
│   └── index.html
└── gowin_project\
    └── Dem_linhkien.gprj
```

---

## 6. Lộ trình thực hiện

| Giai đoạn | Tuần | Nội dung |
|---|---|---|
| **1. Setup** | 1-2 | Gowin IDE + BBB Debian setup, test SPI loopback |
| **2. Camera** | 3-4 | OV5640 DVP → HDMI hiển thị |
| **3. Preprocessing** | 5-6 | Grayscale → Threshold → Morphology |
| **4. Blob + ROI** | 7-8 | Blob detector + ROI extractor + SPI |
| **5. SPI Link** | 9 | FPGA↔BBB SPI verify data |
| **6. CNN** | 9-10 | Chụp dataset, train trên PC, deploy TFLite lên BBB |
| **7. Integration** | 11-12 | Tracker + Counter + GUI + Web |
| **8. Fine-tune** | 13 | Test end-to-end trên băng chuyền |
| **9. Báo cáo** | 14 | Viết báo cáo, quay video demo |

---

## 7. Danh sách phần cứng

| STT | Linh kiện | Giá (VNĐ) | Ghi chú |
|---|---|---|---|
| 1 | Module OV5640 (DVP) | 100K – 200K | Camera |
| 2 | ~~ESP32-S3~~ **BBB đã có** | **0** | ✅ Tiết kiệm |
| 3 | ~~LCD SPI~~ | **0** | BBB dùng HDMI có sẵn |
| 4 | Băng chuyền mini | 200K – 500K | DIY motor + belt |
| 5 | Đèn LED bar | 50K – 150K | Chiếu sáng đều |
| 6 | Giá đỡ camera | 30K – 50K | |
| 7 | Dây nối jumper | 20K – 30K | SPI 5 dây |
| 8 | Buzzer + LED | 10K – 20K | Cảnh báo |

**Tổng**: ~410K – 950K VNĐ (rẻ hơn nhờ có sẵn BBB + dùng HDMI)

---

## 8. So sánh plan mới (BBB) vs plan cũ (ESP32-S3)

| Tiêu chí | ESP32-S3 | BBB |
|---|---|---|
| Ngôn ngữ phần mềm | C/C++ (ESP-IDF) | **Python** ✅ dễ hơn nhiều |
| AI framework | TFLite Micro (khó) | **TFLite Runtime** ✅ dễ hơn |
| Debug | Serial monitor | **SSH + terminal** ✅ |
| Hiển thị | Cần mua LCD | **HDMI có sẵn** ✅ |
| Mạng | WiFi (AP mode) | **Ethernet** ✅ ổn định hơn |
| Tốc độ AI | ~50-100ms | ~50-100ms (tương đương) |
| Chi phí thêm | +100-150K | **0** (có sẵn) ✅ |
| Kích thước | Rất nhỏ | Lớn hơn |

> **Kết luận**: BBB là lựa chọn **tốt hơn** cho trường hợp của bạn — code dễ hơn (Python), debug dễ hơn (SSH), tiết kiệm chi phí, và HDMI có sẵn.

---

## 9. Verification Plan

### Simulation (FPGA)
Testbench cho từng module, chạy Icarus Verilog / Gowin Sim

### Hardware Tests
1. Camera → HDMI: ảnh sống rõ nét
2. Binary image → HDMI: linh kiện tách nền tốt
3. SPI data → BBB `python3 -c "print(spi.readbytes(10))"`: verify raw data
4. CNN inference → `python3 classifier.py --test roi.png`: verify class label
5. End-to-end: linh kiện trên băng chuyền → HDMI GUI hiển thị đếm đúng

### CNN Model Test
```bash
# Train trên PC
python training/train_and_convert.py
# Kỳ vọng: accuracy > 95%, model < 500KB
# Copy lên BBB
scp model.tflite debian@beaglebone:~/Dem_linhkien/software/
```
