# Hệ thống phát hiện mạch PCB lỗi — GoAI 3.0 + Tang Mega 138K Pro

## Bối cảnh

- **FPGA**: Sipeed Tang Mega 138K Pro (Gowin GW5AST-LV138FPG676A)
- **AI Framework**: **Gowin GoAI 3.0 SDK V1.0** (chính thức hỗ trợ GW5AST)
- **Mục tiêu**: Phát hiện **thiếu linh kiện** và **linh kiện hàn ngược** trên PCB
- **Standalone**: Toàn bộ xử lý trên 1 board FPGA, không cần PC

---

## User Review Required

> [!IMPORTANT]
> **GoAI 3.0 chính thức hỗ trợ GW5AST-LV138PG676A** — đây là chip trên Tang Mega 138K Pro. Không còn rủi ro tương thích như GoAI 2.0. Reference design (`EVAL_GOAI3_GW5ASTLV138PG676A_V1.0`) là nền tảng chính.

> [!WARNING]
> **Board GoAI 3.0 EVK ≠ Tang Mega 138K Pro Dock**: Pin mapping (MIPI CSI connector, DDR3, HDMI) có thể **khác nhau** giữa 2 board. Cần so sánh schematic và chỉnh lại file `.cst` constraint cho phù hợp Tang Mega 138K Pro.

> [!TIP]
> **Scaler IP** resize 1920×1080 → 224×224 sẵn → CNN input size nên thiết kế 224×224 (hoặc nhỏ hơn). Không cần tự viết resize module.

---

## Kiến trúc tổng thể (dựa trên GoAI 3.0 SDK)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                       FPGA Tang Mega 138K Pro                                │
│                                                                              │
│  ┌────────────┐    ┌──────────────┐    ┌────────────┐    ┌───────────────┐  │
│  │ Camera     │───▶│ Gowin MIPI   │───▶│ DDR3 1GB   │───▶│ Gowin Scaler  │  │
│  │ CSI        │    │ RX Advance   │    │ Frame      │    │ IP            │  │
│  │ (OV5647/   │    │ IP (2-lane)  │    │ Buffer     │    │ 1920×1080     │  │
│  │  OV5640)   │    └──────────────┘    └────────────┘    │ → 224×224     │  │
│  └────────────┘                              │           └───────┬───────┘  │
│                                              │                   │          │
│                                              │           ┌───────▼───────┐  │
│                                              │           │ GoAI 3.0      │  │
│                                              │           │ Accelerator   │  │
│                                              │           │ ┌───────────┐ │  │
│  ┌────────────┐    ┌──────────────┐          │           │ │ Conv2D    │ │  │
│  │ Gowin DVI  │◀───│ OSD Overlay  │◀─────────┤           │ │ DWConv2D  │ │  │
│  │ TX IP      │    │ + Result     │          │           │ │ MaxPool   │ │  │
│  │ (HDMI out) │    │ Display      │          │           │ │ AvgPool   │ │  │
│  └────────────┘    └──────────────┘          │           │ │ FC        │ │  │
│                                              │           │ │ Add, Mean │ │  │
│       ┌──────────────────────────────────────┤           │ └───────────┘ │  │
│       │                                      │           └───────┬───────┘  │
│       │   ┌──────────────────────────────────▼───────────────────▼──────┐   │
│       │   │              RISC-V AE350 SoC (Hardened)                    │   │
│       │   │  • Inference orchestration (GoAI 3.0 firmware)              │   │
│       │   │  • CNN layer sequencing (Conv → Pool → FC → result)         │   │
│       │   │  • ROI management: danh sách vị trí linh kiện cần check     │   │
│       │   │  • UART output: log kết quả + defect report                 │   │
│       │   │  • GPIO: buzzer/LED alarm khi phát hiện lỗi                 │   │
│       │   └─────────────────────────────────────────────────────────────┘   │
│       │                                                                      │
│       ▼                                                                      │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐                                    │
│  │ HDMI    │  │ Buzzer  │  │ UART     │                                    │
│  │ Monitor │  │ + LED   │  │ Terminal │                                    │
│  └─────────┘  └─────────┘  └──────────┘                                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## GoAI 3.0 Build Workflow

Đây là luồng build **chính thức** từ Gowin documentation:

```
                    ┌──────────────────────┐
                    │  1. Train CNN (PC)   │
                    │  TensorFlow/Keras    │
                    │  → quantize INT8     │
                    │  → export .tflite    │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  2. Model Parser     │
                    │  goai3.0_run.bat     │
                    │  Input:  .tflite     │
                    │  Output: .bin (wts)  │
                    │          .h (params) │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────┐
              │                                 │
   ┌──────────▼───────────┐         ┌───────────▼──────────┐
   │  3a. MCU Firmware    │         │  3b. FPGA Design     │
   │  (RDS V1.3)          │         │  (Gowin V1.9.12.01)  │
   │  • Copy .h → src/    │         │  • Copy ITCM hex     │
   │  • Compile → .bin    │         │    → init/ITCM/       │
   │  • make_hex → itcm*  │         │  • Synthesis + PnR   │
   └──────────┬───────────┘         │  • → bitstream .fs   │
              │                     └───────────┬──────────┘
              └────────────────┬────────────────┘
                               │
                    ┌──────────▼───────────┐
                    │  4. Download         │
                    │  • Weights .bin      │
                    │    → Flash 0x0700000 │
                    │  • Bitstream .fs     │
                    │    → Flash 0x0000000 │
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │  5. Run!             │
                    │  Camera → Inference  │
                    │  → HDMI + UART       │
                    └──────────────────────┘
```

---

## Proposed Changes

### Component 1: Dựa trên GoAI 3.0 Reference Design

> Xuất phát từ `GoAI3.0_SDK/ref_design/FPGA_RefDesign/EVAL_GOAI3_GW5ASTLV138PG676A_V1.0/ai_tflite_goai_3_0`, chỉnh sửa cho bài toán PCB defect.

#### [MODIFY] FPGA Reference Design
- Clone reference design → project mới `pcb_defect_goai3`
- **Giữ nguyên**: MIPI RX, DDR3, GoAI 3.0 Accelerator, DVI TX, PLL, RISC-V AE350 SoC
- **Chỉnh sửa**: Constraint file `.cst` → mapping lại pin cho Tang Mega 138K Pro Dock
- **Thêm mới**: OSD overlay module (vẽ bounding box + text kết quả lên HDMI)

#### Gowin IP Cores (giữ cấu hình GoAI 3.0 reference)

| IP Core | Cấu hình | Ghi chú |
|---|---|---|
| MIPI RX Advance | 2-lane, 1:8 mode, MIPI IO | Kết nối camera CSI |
| DDR3 Memory Interface | 400MHz, CLK 1:4, DQ 8-bit | Frame buffer 1GB |
| Scaler | 1920×1080 → 224×224, Bilinear | CNN input resize |
| RiscV AE350 SoC | ITCM 32KB, DTCM 32KB, UART1 | Inference control |
| DVI TX | TLVDS | HDMI output |
| GoAI 3.0 Accelerator | Conv2D, DWConv, Pool, FC, Add, Mean | CNN hardware |

---

### Component 2: Preprocessing & ROI (thêm mới)

> GoAI 3.0 reference design xử lý **toàn bộ frame** (hand landmark). Cho bài toán PCB, ta cần **kiểm tra từng vùng linh kiện** (ROI).

#### [NEW] [roi_manager.v](file:///d:/Nhan_dien_mach_loi/rtl/roi_manager.v)
- Quản lý danh sách ROI (vị trí linh kiện trên PCB)
- Lần lượt crop từng ROI → feed vào Scaler → GoAI accelerator
- FSM: SELECT_ROI → CROP → SCALE → INFERENCE → NEXT_ROI → DONE

#### [NEW] [osd_overlay.v](file:///d:/Nhan_dien_mach_loi/rtl/osd_overlay.v)
- Vẽ bounding box lên HDMI output:
  - 🟢 Xanh = OK | 🔴 Đỏ = Missing | 🟡 Vàng = Reversed
- Text overlay: "PASS" / "FAIL" + thống kê
- Đọc kết quả classify từ RISC-V register

#### [NEW] [alarm_ctrl.v](file:///d:/Nhan_dien_mach_loi/rtl/alarm_ctrl.v)
- GPIO output → buzzer + LED
- Kêu khi phát hiện lỗi (FAIL)

---

### Component 3: CNN Model Training (trên PC)

> Thay đổi model từ hand_landmark → PCB defect classification. Giữ nguyên GoAI 3.0 workflow.

> [!NOTE]
> **Scope: 3 lớp thay vì 4.** Lớp "wrong" (sai trị số linh kiện) đã được **loại khỏi scope đồ án**. Với linh kiện SMD nhỏ (0402/0603), thông tin trị số hoặc không tồn tại trên thân linh kiện (tụ gốm không in trị số) hoặc quá nhỏ để CNN đọc được sau khi resize 224×224 (ký tự in trên điện trở chỉ ~4-15px ở ảnh gốc). Phát hiện sai trị số cần một pipeline OCR độ phân giải cao riêng biệt — nằm ngoài phạm vi 13 tuần. Hướng phát triển này được ghi nhận là **future work** trong báo cáo.

#### [NEW] [train_pcb_model.py](file:///d:/Nhan_dien_mach_loi/training/train_pcb_model.py)

**CNN Architecture** (tương thích GoAI 3.0 accelerator operators):
```
Input: 224×224×3 (RGB) — khớp Scaler IP output

Block 1: Conv2D(16, 3×3) → ReLU → MaxPool2D(2×2)     → 112×112×16
Block 2: Conv2D(32, 3×3) → ReLU → MaxPool2D(2×2)     → 56×56×32
Block 3: Conv2D(64, 3×3) → ReLU → MaxPool2D(2×2)     → 28×28×64
Block 4: Conv2D(128, 3×3) → ReLU → AvgPool2D(global)  → 128
FC:      Dense(3, softmax)  → ["ok", "missing", "reversed"]
```

> [!IMPORTANT]
> **Chỉ sử dụng operators mà GoAI 3.0 hỗ trợ**: Conv2D, DepthwiseConv2D, MaxPool2D, AvgPool2D, Add, FullyConnected, Mean. **KHÔNG** dùng BatchNorm, Dropout, hoặc operators khác trong model export — phải fuse/remove trước khi convert.

#### [NEW] [quantize_export.py](file:///d:/Nhan_dien_mach_loi/training/quantize_export.py)
- Post-training INT8 quantization (representative dataset required)
- Export `.tflite` với INT8 input/output (`io8`)
- Validate: accuracy drop < 2% so với FP32

#### [NEW] [capture_dataset.py](file:///d:/Nhan_dien_mach_loi/training/capture_dataset.py)
- Chụp ảnh thu thập dataset qua UART/camera trực tiếp
- Cấu trúc: `dataset/{ok, missing, reversed}/`
- Mục tiêu: 300-500 ảnh/class, augmentation → 1500-2500/class

---

### Component 4: GoAI 3.0 Model Deployment

> Dùng chính xác GoAI 3.0 SDK tools.

#### Bước 1: Model Parser
```bash
# Chỉnh path trong goai3.0_run.bat
set tflite_model_file=D:\Nhan_dien_mach_loi\training\pcb_defect_quant_io8.tflite

# Chạy
cd GoAI3.0_SDK\tool\model_parser\bin
goai3.0_run.bat

# Output:
#   output/pcb_defect_quant_io8.bin    ← weights & biases
#   output/pcb_defect_quant_io8.h      ← model parameters
```

#### Bước 2: MCU Firmware (RISC-V AE350)
```
1. Copy pcb_defect_quant_io8.h → goai_3_0_pcb_defect/src/demo/goai/
2. Sửa firmware: thay hand_landmark logic → PCB defect classification
3. Compile bằng AE350_RDS V1.3 → goai_3_0_pcb_defect.bin
4. make_hex.exe goai_3_0_pcb_defect.bin → itcm0, itcm1, itcm2, itcm3
```

#### Bước 3: FPGA Bitstream
```
1. Copy itcm0~3 → ai_tflite_goai_3_0/init/ITCM/
2. Synthesis + Place & Route (Gowin V1.9.12.01)
3. → bitstream .fs
```

#### Bước 4: Download
```
1. Weights:    pcb_defect_quant_io8.bin → Flash 0x0700000
2. Bitstream:  pcb_defect.fs           → Flash 0x0000000
```

---

### Component 5: RISC-V AE350 Firmware (chỉnh sửa từ reference)

#### [MODIFY] [main.c](file:///d:/Nhan_dien_mach_loi/software/riscv/main.c)

Chỉnh sửa từ `goai_3_0_hand_landmark` reference:

```c
// Thay đổi chính so với hand_landmark demo:

// 1. Output interpretation: 3 classes thay vì 63 keypoints
const char* class_names[] = {"OK", "MISSING", "REVERSED"};
int predicted_class = argmax(output_tensor, 3);

// 2. ROI iteration: lặp qua N vị trí linh kiện
for (int roi = 0; roi < num_rois; roi++) {
    configure_scaler_crop(roi_list[roi]);  // Crop ROI → 224×224
    trigger_inference();                    // GoAI 3.0 accelerator
    wait_inference_done();
    int result = get_result();
    
    if (result != CLASS_OK) {
        defect_count++;
        uart_printf("DEFECT at ROI[%d]: %s\n", roi, class_names[result]);
        set_alarm(1);  // Buzzer ON
    }
}

// 3. Board-level judgment
if (defect_count == 0) {
    uart_printf(">>> BOARD PASS <<<\n");
    set_led_green();
} else {
    uart_printf(">>> BOARD FAIL: %d defects <<<\n", defect_count);
    set_led_red();
}
```

#### [NEW] [roi_config.h](file:///d:/Nhan_dien_mach_loi/software/riscv/roi_config.h)
```c
// Danh sách vị trí linh kiện trên PCB (pixel coordinates in 1920×1080)
typedef struct {
    uint16_t x, y, w, h;    // Bounding box
    uint8_t  expected_class; // 0=OK expected
    char     name[16];       // "R1", "C3", "U1"...
} roi_entry_t;

const roi_entry_t roi_list[] = {
    {100, 200, 80, 60, 0, "R1"},
    {300, 400, 90, 70, 0, "C1"},
    {500, 150, 120, 100, 0, "U1"},
    // ... thêm theo layout PCB cụ thể
};
```

---

## Cấu trúc thư mục

```
d:\Nhan_dien_mach_loi\
├── Go AI 3.0\                         # GoAI 3.0 SDK (đã có)
│   ├── GoAI3.0_SDK_V1.0.zip
│   ├── MUG1526-1.0E_Gowin GoAI 3.0 User Guide.pdf
│   └── MRN1526-1.0E_Gowin GoAI 3.0 SDK Release Note.pdf
│
├── gowin_project\                      # FPGA project (clone từ ref design)
│   ├── pcb_defect_goai3.gprj
│   ├── src\                            # RTL sources
│   │   ├── (GoAI 3.0 ref design modules — giữ nguyên)
│   │   ├── roi_manager.v              # [MỚI] ROI crop manager
│   │   ├── osd_overlay.v             # [MỚI] HDMI overlay
│   │   └── alarm_ctrl.v              # [MỚI] Buzzer/LED
│   ├── ip\                            # Gowin IP cores
│   ├── init\ITCM\                     # RISC-V firmware hex
│   └── impl\                          # Constraints (.cst, .sdc)
│
├── training\                           # CNN training (chạy trên PC)
│   ├── train_pcb_model.py
│   ├── quantize_export.py
│   └── capture_dataset.py
│
├── dataset\                            # Training images
│   ├── ok\          (~300-500 ảnh)
│   ├── missing\     (~300-500 ảnh)
│   └── reversed\    (~300-500 ảnh)
│
├── software\                           # RISC-V firmware source
│   └── riscv\
│       ├── main.c                      # Chỉnh từ hand_landmark demo
│       └── roi_config.h                # Vị trí linh kiện
│
└── docs\                               # Tài liệu đồ án
    └── ...
```

---

## Lộ trình thực hiện (13 tuần)

| Giai đoạn | Tuần | Nội dung | Output cần đạt |
|---|---|---|---|
| **1. Setup GoAI 3.0** | 1–2 | • Giải nén SDK, cài Gowin V1.9.12.01 + RDS V1.3<br>• Nạp prebuilt demo (`ai_tflite_goai_3_0.fs` + weights)<br>• Verify: hand landmark chạy OK trên board | Hand landmark demo hiển thị trên HDMI |
| **2. Port sang Tang Mega 138K Pro** | 3 | • So sánh schematic EVK vs Tang Mega 138K Pro<br>• Chỉnh `.cst` constraint file<br>• Build + nạp → verify camera + HDMI | Camera live feed trên HDMI qua Tang Mega 138K Pro |
| **3. Thu thập dataset** | 4–5 | • Setup đèn + giá đỡ + camera<br>• Chụp ảnh PCB: OK, thiếu LK, LK ngược<br>• Augmentation → ≥1500 ảnh/class | Dataset sẵn sàng train |
| **4. Train CNN** | 5–6 | • Thiết kế model (chỉ dùng operators GoAI hỗ trợ)<br>• Train trên PC (TensorFlow/Keras)<br>• INT8 quantize → export `.tflite` | accuracy > 90%, model `.tflite` |
| **5. Deploy model** | 7–8 | • `model_parser` → `.bin` + `.h`<br>• Sửa firmware RISC-V cho PCB defect<br>• `make_hex` → ITCM<br>• Build FPGA bitstream + download | CNN inference chạy trên FPGA, UART output class |
| **6. ROI + Multi-inspect** | 9–10 | • Thêm `roi_manager.v` — crop từng vùng LK<br>• Firmware lặp qua ROI list<br>• Board pass/fail judgment | Kiểm tra N linh kiện tuần tự, kết quả đúng |
| **7. OSD + Alarm** | 11 | • `osd_overlay.v` — bounding box + text<br>• `alarm_ctrl.v` — buzzer/LED<br>• HDMI hiển thị đầy đủ | HDMI: ảnh PCB + bbox màu + PASS/FAIL |
| **8. Test & Báo cáo** | 12–13 | • Test end-to-end trên nhiều PCB<br>• Đo accuracy, throughput<br>• Viết báo cáo, quay video demo | Demo hoàn chỉnh |

---

## Verification Plan

### Giai đoạn 1-2: Hardware Setup
```
✓ Nạp prebuilt demo → hand landmark hiển thị trên HDMI
✓ Camera live feed hiển thị trên HDMI (qua Tang Mega 138K Pro)
✓ UART terminal hiển thị inference output
```

### Giai đoạn 4: CNN Model
```bash
# Train
python training/train_pcb_model.py
# Kỳ vọng: val_accuracy > 90%

# Quantize
python training/quantize_export.py
# Kỳ vọng: accuracy drop < 2%, output: pcb_defect_quant_io8.tflite

# Verify operators — chỉ dùng GoAI supported ops
python -c "
import tensorflow as tf
interp = tf.lite.Interpreter('pcb_defect_quant_io8.tflite')
for op in interp._get_ops_details():
    print(op['op_name'])
# Phải chỉ có: CONV_2D, MAX_POOL_2D, AVERAGE_POOL_2D, FULLY_CONNECTED
"
```

### Giai đoạn 5: Deploy
```
✓ model_parser output: .bin + .h files generated
✓ Firmware compile: no errors
✓ FPGA synthesis: no timing violations
✓ UART output: inference result cho 1 frame
```

### Giai đoạn 6-8: End-to-End
| Test case | Input | Expected output |
|---|---|---|
| PCB hoàn chỉnh | Board tốt | UART: "BOARD PASS", HDMI: tất cả box xanh |
| Thiếu 1 resistor | Tháo R1 | UART: "DEFECT at R1: MISSING", HDMI: box đỏ tại R1 |
| IC hàn ngược | IC U1 lật | UART: "DEFECT at U1: REVERSED", HDMI: box vàng tại U1 |
| Nhiều lỗi | Thiếu R1 + C3 ngược | UART: 2 defects, HDMI: R1 đỏ + C3 vàng |
