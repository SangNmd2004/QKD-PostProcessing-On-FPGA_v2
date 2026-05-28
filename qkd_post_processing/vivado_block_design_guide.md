# Hướng Dẫn Chi Tiết: Tạo Vivado Block Design cho QKD Post-Processing IP

Quá trình này sẽ giúp bạn đóng gói mã nguồn RTL (Verilog) của dự án thành một khối sở hữu trí tuệ (IP Core) và kết nối nó với bộ vi xử lý ARM Cortex-A9 trên chip Zynq-7000 (Board ZC702) thông qua chuẩn giao tiếp AXI.

---

## Bước 1: Đóng gói RTL thành IP Core (Package IP)

Trang bị các cổng AXI-Stream cho file `qkd_post_processing_top.v` là chưa đủ, Vivado cần bạn "đóng gói" nó lại.

1. Trên menu chính của Vivado, chọn **Tools > Create and Package New IP**.
2. Chọn **Package your current project** và bấm Next.
3. Chọn thư mục lưu trữ (ví dụ: `D:/XilinxProjects/QKD/ip_repo`) và bấm **Next > Finish**.
4. Cửa sổ **Package IP - qkd_post_processing_top** sẽ hiện ra. Bạn hãy đi qua các tab:
   - **Identification**: Đổi tên cho ngầu, ví dụ: *QKD_Post_Processor*.
   - **Ports and Interfaces**: Kiểm tra xem Vivado có tự nhận diện đúng các bus `s_axis_llr`, `s_axis_syn`, và `m_axis_key` là chuẩn **AXI4-Stream** hay chưa. (Nếu chưa, chuột phải > *Auto Infer Interface*).
   - **Review and Package**: Bấm nút **Package IP** ở góc dưới cùng. Vivado sẽ tạo ra một khối block vuông vức hoàn chỉnh.

---

## Bước 2: Tạo Block Design (BD)

1. Tắt project Package IP (nếu nó mở ra ở cửa sổ mới) và quay lại Project QKD chính.
2. Bên khung *Flow Navigator* (bên trái), chọn **Create Block Design** dưới mục *IP INTEGRATOR*. Đặt tên là `design_1`.
3. Một khung vẽ (Canvas) trắng sẽ hiện ra. Đây là nơi bạn lắp ráp hệ thống.

---

## Bước 3: Thêm Vi xử lý Zynq (Processing System)

1. Bấm nút dấu cộng **+ (Add IP)** ở giữa màn hình canvas.
2. Gõ chữ `Zynq` và double-click vào **ZYNQ7 Processing System**. Khối vi xử lý ARM sẽ xuất hiện.
3. Phía trên màn hình sẽ hiện dải màu xanh lá cây: *Run Block Automation*. Bấm vào đó, để nguyên cấu hình mặc định (có kết nối DDR và FIXED_IO) rồi bấm **OK**. Vivado sẽ tự động nối các chân nguồn và bộ nhớ cơ bản cho chip.

---

## Bước 4: Thêm QKD IP và AXI DMA (Người Vận Chuyển)

1. Bấm **+ (Add IP)**, tìm tên IP của bạn: *QKD_Post_Processor* và thả vào canvas.
2. Bấm **+ (Add IP)** lần nữa, tìm `AXI Direct Memory Access` (AXI DMA) và thêm nó vào. Khối này rất quan trọng, nó có nhiệm vụ lấy dữ liệu từ RAM của Zynq và "bắn" vào QKD IP của chúng ta mà không làm CPU bị nghẽn.
3. Double-click vào khối **AXI DMA** để cấu hình:
   - Bỏ tick mục `Enable Scatter Gather`.
   - **Width of Buffer Length Register**: Đặt lên 26 (để truyền được file lớn).
   - Bấm **OK**.

> [!NOTE]
> Bạn có thể cần add thêm 1 khối AXI DMA nữa, vì IP của chúng ta có 2 đường vào (LLR và Syndrome) nhưng DMA mặc định chỉ có 1 đường Read Channel (MM2S). Do đó, DMA_0 sẽ truyền LLR, DMA_1 sẽ truyền Syndrome, và DMA_0 sẽ kiêm luôn việc nhận Key (S2MM).

---

## Bước 5: Nối dây (Wiring)

Bạn có thể tự nối bằng tay, hoặc dùng tính năng tự động cực kỳ thông minh của Vivado:
1. Bấm **Run Connection Automation** trên dải màu xanh lá.
2. Vivado sẽ tự động chèn các khối **AXI Interconnect** và **Processor System Reset** để nối AXI-Lite (cấu hình DMA) với chip Zynq. Bấm **OK**.
3. Bây giờ bạn cần nối tay các đường AXI-Stream:
   - Nối cổng `M_AXIS_MM2S` của **AXI DMA 0** vào cổng `s_axis_llr` của **QKD IP**.
   - Nối cổng `M_AXIS_MM2S` của **AXI DMA 1** vào cổng `s_axis_syn` của **QKD IP**.
   - Nối cổng `m_axis_key` của **QKD IP** vào cổng `S_AXIS_S2MM` của **AXI DMA 0**.
4. Đối với các chân tín hiệu rời của QKD IP:
   - Nối chân `clk` và `rst` của QKD IP vào hệ thống clock chung (ví dụ: `FCLK_CLK0` của Zynq). Chú ý chân `rst` của chúng ta là Active-High, hãy nối đúng ngõ ra reset.
   - Các chân `tx_err_feedback` hoặc `ir_success` có thể được nối vào một khối **AXI GPIO** để ARM Cortex-A9 có thể đọc trạng thái lỗi.

---

## Bước 6: Kiểm tra và Xuất XSA

1. Nhấn nút **Validate Design** (biểu tượng dấu Check màu xanh trên thanh công cụ hoặc F6). Nếu không có báo lỗi (Error), bạn đã thiết kế chuẩn!
2. Ở cửa sổ *Sources* (bên trái), chuột phải vào file `design_1.bd` và chọn **Create HDL Wrapper** > *Let Vivado manage wrapper and auto-update*. Việc này sẽ dịch bản vẽ đồ họa thành code Verilog.
3. Chạy quá trình **Generate Bitstream** (Góc dưới bên trái). Tùy vào máy tính, quá trình này mất khoảng 15-30 phút.
4. Khi chạy xong, trên thanh Menu chọn **File > Export > Export Hardware...**
5. Tích chọn **Include bitstream** và lưu file `.xsa` lại.

---

## Bước tiếp theo là gì?

File `.xsa` vừa xuất ra chứa toàn bộ "Thể xác" của hệ thống. Bạn sẽ mở phần mềm **Xilinx Vitis** (hoặc Petalinux), nạp file `.xsa` này vào và bắt đầu viết code ngôn ngữ C ("Linh hồn") để điều khiển khối DMA nhồi dữ liệu lượng tử vào màng băm NTT của chúng ta!
