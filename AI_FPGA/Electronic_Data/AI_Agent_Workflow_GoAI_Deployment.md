# End-to-End Workflow: YOLOv11s to Tang Mega 138K Pro (GoAI 3.0)

**Target Audience:** Autonomous AI Agent / Developer
**Prerequisites:** 
- `best.pt` (YOLOv11s trained PyTorch model).
- GoAI 3.0 SDK environment pre-configured.
- Gowin EDA and Gowin MCU Designer (GMD) installed.

This document outlines the precise, deterministic steps to convert a PyTorch YOLOv11s model into a hardware-compatible format and deploy it onto the Sipeed Tang Mega 138K Pro FPGA.

---

## Phase 1: Model Export & Full Integer Quantization (PTQ)

The GoAI 3.0 NPU exclusively supports INT8 operations. Therefore, the model MUST be exported with full integer quantization (activations and weights).

**Step 1.1: Prepare Calibration Data**
Create a numpy array of representative images from the training dataset. This is critical for calibrating activation bounds during Post-Training Quantization (PTQ).
*File:* `calibration_image_sample_data_20x128x128x3_float32.npy` (Shape: `[N, H, W, 3]`, normalized to `[0, 1]`).

**Step 1.2: Export to TFLite INT8**
Execute the Ultralytics export pipeline using `export_tflite_int8.py`.

```python
from ultralytics import YOLO

# Load the trained model
model = YOLO('best.pt')

# Export to TFLite with INT8 quantization
# Ensure imgsz matches the FPGA NPU input resolution (e.g., 416x416 or 128x128)
model.export(
    format='tflite', 
    int8=True, 
    data='calib_data.yaml', # Points to the representative dataset
    imgsz=128
)
```
*Output:* `best_full_integer_quant.tflite` (This specific file name indicates true full-integer quantization; ignore `best_saved_model` or `best_int8.tflite` if they contain Float32 I/O).

---

## Phase 2: GoAI 3.0 Model Parsing (TFLite -> C Header)

Convert the `.tflite` graph into the raw instruction sequence and weight payload understandable by the Gowin NPU.

**Step 2.1: Run the GoAI Parser**
Execute the `run_goai_parser.py` wrapper, which dynamically locates the GoAI compiler executable (`compiler.exe`) and parses the model.

```python
import subprocess
import os

# Locate GoAI 3.0 SDK model_parser.py
goai_parser_dir = r"C:\Users\Admin\Downloads\AI_FPGA\Go AI 3.0\GoAI3.0_SDK_V1.0\GoAI3.0_SDK_V1.0\tool\model_parser\bin"
tflite_model = r"C:\Path\To\best_full_integer_quant.tflite"

cmd = [
    "python", 
    "model_parser.py", 
    "--tflite_model_file", 
    tflite_model
]

# Run the parser inside its bin directory
subprocess.run(cmd, cwd=goai_parser_dir, check=True)
```
*Outputs Generated:*
1. `best_full_integer_quant.h` (C-header containing the network architecture and layer offsets).
2. `best_full_integer_quant.bin` (The physical NPU weight/bias/instruction payload).

---

## Phase 3: Firmware Integration (Gowin MCU Designer)

**Step 3.1: Update Firmware Headers**
1. Copy `best_full_integer_quant.h` into the firmware source directory: `MCU_YOLOv11_Electronic/src/demo/goai/`.
2. Modify `yolo_electronic.h` or `main.c` to `#include "best_full_integer_quant.h"`.
3. Update the network architecture constants in the firmware to match the generated header (e.g., Number of Layers, Output Tensor shapes).

**Step 3.2: Compile the RISC-V Firmware**
1. Open the project in **Gowin MCU Designer (GMD)**.
2. Select **Clean Project** followed by **Build Project**.
3. Verify that the build completes without `ilp32f` ABI mismatch errors (ensure the Toolchain Settings use the correct GCC 14.x architecture flags).
*Outputs Generated:* 
- `MCU_YOLOv11_Electronic.bin` (Application payload)
- `itcm0-3` (Instruction Tightly Coupled Memory initialization files for the bitstream).

---

## Phase 4: FPGA Bitstream Synthesis (Gowin EDA)

**Step 4.1: Update ITCM Files**
1. Copy the newly generated `itcm0`, `itcm1`, `itcm2`, `itcm3` files from the GMD output folder to the Gowin EDA project directory.
2. These files initialize the RISC-V CPU's RAM upon FPGA boot.

**Step 4.2: Synthesize and Place & Route**
1. Open the FPGA project `.gprj` in **Gowin EDA**.
2. Run **Synthesize (Synplify Pro)**.
3. Run **Place & Route**.
*Output Generated:* `project_name.fs` (The hardware bitstream).

---

## Phase 5: Hardware Flashing (Gowin Programmer)

Deploy the 3 distinct components to the Tang Mega 138K Pro board via JTAG/SPI.

1. **Open Gowin Programmer**.
2. **Flash 1 (Bitstream):** 
   - Operation: `SRAM Program` (or Flash for persistence).
   - File: `project_name.fs`
3. **Flash 2 (Firmware Application):**
   - Operation: `External Flash Program`.
   - Start Address: `0x400000` (Validate this address against the linker script).
   - File: `MCU_YOLOv11_Electronic.bin`
4. **Flash 3 (Model Weights):**
   - Operation: `External Flash Program`.
   - Start Address: `0x800000` (Validate this address against the C firmware macro).
   - File: `best_full_integer_quant.bin`
   - File: `best_full_integer_quant.bin`

---

## 🚨 Known Bugs & Workarounds (Critical for AI Agents)

During the implementation, several critical bugs were encountered with the standard tools. **You MUST apply these fixes if you are reproducing this pipeline:**

### Bug 1: Ultralytics TFLite Export (Float32 Leak)
- **Issue:** By default, the `model.export(format='tflite', int8=True)` command in Ultralytics often generates a `.tflite` model that still contains Float32 input/output layers (usually named `best_saved_model` or `best_int8.tflite`). The GoAI 3.0 NPU will **FAIL** to parse this, throwing a `KeyError` on unsupported Float32 operators.
- **Fix:** You must provide a valid `data='calib_data.yaml'` pointing to real images during export. The correct, fully quantized model will explicitly be named `best_full_integer_quant.tflite`. Ensure the parser wrapper script is hardcoded to select this specific file.

### Bug 2: GoAI Parser KeyError on C-Header Generation
- **Issue:** The original `run_goai_parser.py` blindly grabbed the first `.tflite` file it found in the directory. If it grabbed the standard `best_int8.tflite` (which has Float32 I/O), the parser would crash with `KeyError` when attempting to generate the C-array header.
- **Fix:** We modified `run_goai_parser.py` (lines 15-23) to explicitly filter for the string `integer_quant` in the filename: `if 'integer_quant' in file_name: return file`.

### Bug 3: Firmware Linking Failure (`ilp32f` ABI Mismatch)
- **Issue:** When compiling the RISC-V firmware in GMD, the linker threw `ABI mismatch` errors regarding `ilp32f` (Single-Precision Floating-Point). The Tang Mega 138K Pro AE350 CPU configuration did not match the default software flags.
- **Fix:** We upgraded the Toolchain in GMD to **GCC 14.2.0** and adjusted the Architecture flags to ensure strict software floating-point or matching hardware floating-point compilation. Additionally, the memory map in `ae350-xip.ld` was rewritten to support Execute-In-Place (XIP), fixing boot failures.

---

## Phase 6: Validation
- Connect the Tang Mega 138K Pro to a monitor via HDMI.
- Connect the MIPI OV5640 Camera.
- Reboot the board. The RISC-V MCU will fetch the model from Flash, stream camera data to the NPU, and output bounding boxes to the HDMI display.
