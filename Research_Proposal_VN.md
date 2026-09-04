# ĐỀ CƯƠNG NGHIÊN CỨU: KIẾN TRÚC TÁI CẤU TRÚC TỰ ĐỘNG ZERO-LATENCY CHO HỆ THỐNG QKD
**Định hướng xuất bản: Tạp chí Quốc tế (IEEE TCAS-I, IEEE TVLSI, IEEE Systems Journal)**

---

## 1. BÀI TOÁN ĐẶT RA (THE PROBLEM)

### Bối cảnh Mạng QKD Vệ tinh (FSO)
Trong các hệ thống Phân phối Khóa Lượng tử (QKD) qua kênh vệ tinh / không gian tự do (FSO - Free-Space Optical), nhiễu loạn khí quyển khiến tỷ lệ lỗi bit lượng tử (QBER) biến động liên tục và dữ dội trong tính toán bằng mili-giây. 

### Nút thắt cổ chai (The Bottleneck)
*   **Vấn đề Ước lượng thông số (Parameter Estimation):** Cách truyền thống là hy sinh 10-20% lượng khóa thô để tính toán QBER. Tuy nhiên trong kênh FSO, con số QBER này lỗi thời ngay lập tức do kênh biến đổi quá nhanh.
*   **Hạn chế của Giao thức Dò mù (Blind Reconciliation):** Để không lãng phí khóa thô, các giao thức "Blind" ra đời (Giải mã thử bằng Rate 3/4, nếu thất bại thì báo qua mạng xin thêm Parity để hạ xuống Rate 2/3, 1/2). Việc "thử nghiệm - sai - giao tiếp mạng - thử lại" (Ping-Pong Protocol) này tạo ra **độ trễ mạng khổng lồ** và tiêu tốn **gấp 3 lần điện năng động (Dynamic Power)** trên chip FPGA vì phải chạy vòng lặp giải mã LDPC vô ích quá nhiều lần.

---

## 2. LỖ HỔNG HỌC THUẬT VÀ TÍNH MỚI (LITERATURE GAP & NOVELTY)

Khi khảo sát các công trình State-of-the-Art từ 2020 - 2024, nhóm nghiên cứu phát hiện một "điểm mù" lớn do sự đứt gãy giữa các chuyên ngành (Academic Silo):
1.  **Thiên vị Toán học:** Các nhà lý thuyết mã (Coding theory) tạo ra các ma trận Rate-Compatible xuất sắc nhưng lại thờ ơ với độ trễ giao tiếp phần cứng, họ mặc định sử dụng giao thức Ping-Pong chậm chạp.
2.  **Thiên vị Phần cứng:** Các kỹ sư Vi mạch (VLSI) tạo ra các lõi LDPC FPGA chạy tốc độ Tbps nhưng lại thiết kế chúng như những cỗ máy thụ động, tĩnh lặng, phụ thuộc hoàn toàn vào CPU bên ngoài để ra lệnh đổi cấu hình.
3.  **Ảo tưởng AI (Deep Learning Hype):** Một số bài báo gần đây cố gắng giải quyết sự thích ứng bằng Mạng Nơ-ron (CNN, RL). Nhưng chúng quá cồng kềnh, ngốn sạch tài nguyên DSP/BRAM của FPGA, vi phạm quy tắc Low-SWaP (Kích thước nhỏ, Khối lượng nhẹ, Tiết kiệm pin) của vệ tinh.

**👉 Tính mới của chúng ta (Cross-Layer Novelty):**
Đề xuất một Kiến trúc **Đồng thiết kế Phần cứng - Thuật toán (Hardware-Algorithm Co-Design)**. Chúng ta lấp đầy lỗ hổng trên bằng một **"Khối điều khiển Thống kê Phần cứng" (Autonomous Hardware Controller)**. Nó mang tư duy Toán học vào thẳng tầng vật lý Vi mạch để hệ thống tự suy luận và cấu hình lại (Self-Reconfigure) với **độ trễ bằng Không (Zero-Latency)**.

---

## 3. CƠ SỞ TOÁN HỌC VÀ KIẾN TRÚC HỆ THỐNG

### 3.1. Phân tích Trọng số Syndrome (Syndrome Hamming Weight - SHW)
Thay vì đếm QBER thực tế (không thể biết) hoặc dùng AI dự đoán, hệ thống khai thác thuộc tính Toán học tự nhiên của mã LDPC:
*   Syndrome $S = H \times E \pmod 2$. 
*   Vì ma trận $H$ thưa, nên số lượng bit '1' trong $S$ (gọi là Trọng số Hamming) có **mối tương quan tuyến tính** cực kỳ chặt chẽ với số lượng bit lỗi (QBER) trong $E$.
*   Chỉ cần đếm số lượng bit '1' của $S$, hệ thống có thể phán đoán chính xác chất lượng kênh truyền mà không cần hy sinh bất kỳ bit khóa thô nào.

### 3.2. Mạch Đếm song định (Hardware Adder Tree)
Hệ thống nhúng một mạch cộng cây nhị phân đa tầng (Pipelined Binary Adder Tree) trên FPGA. Mạch này có khả năng hút 1152 bit Syndrome và cộng dồn song song để cho ra kết quả Hamming Weight chỉ trong $O(\log_2 N) \approx 11$ chu kỳ xung nhịp (chớp nhoáng).

### 3.3. Tái cấu trúc Liên tầng (Cross-Layer Reconfiguration)
Trái tim của hệ thống là một Bảng tra thống kê (Statistical LUT). Dựa vào con số Hamming Weight vừa đếm được, LUT lập tức phóng các tín hiệu điều khiển chọc thẳng vào cấu trúc nội tại của khối giải mã LDPC:
*   **`opt_rate`:** Sang số ngay lập tức (Rate 1/2, 2/3, 3/4) bỏ qua bước dò mù.
*   **`iter_max`:** Nếu kênh sạch, chặn đứng vòng lặp sớm (ví dụ ép dừng ở iter = 20 thay vì 50) để tiết kiệm điện.
*   **`sat_max` & `offset_val`:** Nếu kênh siêu nhiễu, tự động can thiệp vào phép toán Offset Min-Sum của các node để bẻ khóa các Trapping Set (Lỗi cục bộ).
*   **`discard_flag`:** Báo hiệu hủy block tức thì nếu nhiễu > 6.5%, cứu hệ thống khỏi việc đốt năng lượng vô ích.

---

## 4. KẾT QUẢ ĐÓNG GÓP (EXPECTED IMPACTS)

So với phương pháp Dò mù (Blind Reconciliation) truyền thống hiện có trên các chip QKD FPGA, giải pháp của chúng ta dự kiến mang lại:
1.  **Tiết kiệm năng lượng (Energy-per-bit):** Giảm thiểu tối đa điện năng động (Dynamic Power) do triệt tiêu hoàn toàn các vòng lặp giải mã sai ở Code Rate không phù hợp.
2.  **Thông lượng mạng (Throughput):** Tăng vọt thông lượng hữu ích do xóa bỏ hoàn toàn thời gian chết (Latency) mạng để giao tiếp qua lại xin thêm Parity.
3.  **Chi phí Tài nguyên siêu thấp:** Toàn bộ khối "Bộ não" bằng Toán học Thống kê này (LUT + Adder Tree) dự kiến tiêu tốn chưa tới $1\%$ tài nguyên LUTs của FPGA.

---

## 5. LỘ TRÌNH THỰC HIỆN BÀI BÁO 

*   **Giai đoạn 1 (Toán học Thống kê - Python):** Xây dựng bộ mô phỏng 10,000 Block khóa lượng tử với các cấu hình nhiễu FSO khác nhau. Dùng Python mô phỏng chính xác thuật toán phần cứng để rà quét và trích xuất các ranh giới ngưỡng (Thresholds) cho Bảng tra tĩnh (LUT).
*   **Giai đoạn 2 (Thiết kế Vi mạch - Verilog):** Lập trình mạch Adder Tree tốc độ cao và nhúng Khối LUT Controller vào FPGA (Mục tiêu phần cứng: Tần số > 250 MHz trên Gowin/Xilinx). Chỉnh sửa lõi LDPC để mở cổng cho phép can thiệp thông số động.
*   **Giai đoạn 3 (Đo lường & Benchmarking):** Chạy thực nghiệm, thu thập số liệu Tài nguyên (Resource), Độ trễ (Timing), và đặc biệt là Năng lượng tiêu thụ (Power Report) để lập bảng đối chiếu trực diện, làm bằng chứng khoa học cốt lõi cho bài báo .
