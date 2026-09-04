# KIẾN TRÚC TỔNG THỂ VÀ BẢN ĐỒ THỰC THI (Master Execution Plan)

> [!IMPORTANT]
> Bản kế hoạch này đóng vai trò là "La bàn" (Master Blueprint) cho toàn bộ quá trình lập trình ở đoạn chat mới. Nó đã tiếp thu định hướng: **Thực hiện từng bước một để tránh vỡ luồng dữ liệu** và **Nhắm tới xung nhịp 150MHz** trên chip Gowin 138K Pro.

---

## 1. Phân tích Hệ thống Hiện tại (System Analysis)
Trước khi đập đi xây lại, đây là hiện trạng của lõi `qkd_post_processing` nguyên bản (hiện đã được backup sang `qkd_post_processing_legacy`):
*   **Điểm mạnh:** Lõi LDPC hiện tại (`core_partially_parallel.v`) có kiến trúc Partially Parallel cực kỳ mạnh mẽ, khả năng giải mã nhanh, phù hợp cho QKD.
*   **Điểm nghẽn (Bottlenecks):** Nó bị mù. Nó hoạt động như một cỗ máy thụ động, các tham số như `ITER_MAX`, `SAT_MAX`, `OFFSET_VAL` đều bị "đóng cứng" bằng `localparam`. Nếu FSO kênh quang học bất ngờ bị nhiễu nặng, lõi LDPC này sẽ thất bại hoàn toàn. Ngược lại, nếu kênh sạch, nó vẫn chạy đủ 50 vòng lặp gây lãng phí ít nhất 50-70% năng lượng tĩnh và động.
*   **Sự giải quyết:** Chúng ta sẽ không đập bỏ lõi LDPC. Thay vào đó, chúng ta sẽ "phẫu thuật" mở các `localparam` thành các `input ports`, và tiêm vào đó một "Bộ Não" (Statistical Controller) chạy ở tốc độ phần cứng.

---

## 2. Lộ trình Triển khai Chi tiết (Granular Roadmap)

Vì chúng ta ưu tiên sự an toàn và chất lượng, lộ trình sẽ được chia cực kỳ nhỏ. Ở Giai đoạn 2 này, **ta CHỈ mở khóa 2 tham số là `opt_rate` và `iter_max`** để cấu hình động. Các tham số ảnh hưởng sâu đến giá trị LLR (`sat_max`, `offset_val`) sẽ được giữ cố định tạm thời để đảm bảo Datapath không bị tràn bit (Overflow).

### Phase 1: Statistical Modeling (Mô phỏng Thống kê trên Python)
*   **Task 1.1 - Data Generation:** Viết script Python sinh ra 10,000 blocks dữ liệu bị nhiễu theo mô hình kênh quang học FSO (Quét QBER từ 1% đến 8%).
*   **Task 1.2 - Offline Brute-force:** Cho chạy thuật toán giải mã trên Python với các Code Rate khác nhau để tìm ra: Với mỗi giá trị Syndrome Hamming Weight (SHW), đâu là Code Rate tối ưu (`opt_rate`) và số vòng lặp tối thiểu cần thiết (`iter_max`) để giải mã thành công?
*   **Task 1.3 - LUT Extraction:** Đóng gói kết quả của Task 1.2 thành một bảng tra cứu (Statistical LUT) với các khoảng ngưỡng (Thresholds). *Ví dụ: Nếu SHW nằm trong khoảng [100, 150] $\rightarrow$ Rate 2/3, Iter = 15.*

### Phase 2: Hardware Architecture Design (Viết code RTL)
> **Mục tiêu Xung nhịp:** 150 MHz

*   **Task 2.1 - Code mạch `syndrome_weight_counter.v` (Mạch đếm SHW):**
    *   Tạo cây cộng (Adder Tree) khổng lồ cho 1152 bit đầu vào.
    *   *Tính toán Pipeline:* Để cộng 1152 bit cần khoảng 11 bậc (stages). Ở 150MHz trên FPGA Gowin, ta không cần chèn Register ở mọi bậc. Sẽ tối ưu bằng cách gộp 3-4 bậc Logic vào 1 Pipeline Register. Tổng độ trễ dự kiến: 3-4 Clock cycles (Vẫn là zero-latency so với hàng ngàn clock của LDPC).
*   **Task 2.2 - Code mạch `statistical_controller.v`:**
    *   Nhận 11-bit SHW từ Adder Tree.
    *   Sử dụng lệnh `case` hoặc `if-else` trong `always @(*)` để ánh xạ bảng LUT (thu được từ Phase 1) thành các tín hiệu điều khiển `opt_rate` và `iter_max`.
*   **Task 2.3 - Mở khóa lõi LDPC `core_partially_parallel.v`:**
    *   Xóa `localparam ITER_MAX`, thay bằng cổng `input [7:0] iter_max_in`.
    *   Bổ sung logic **Early Termination** vào máy trạng thái (FSM) để Lõi tự động ngắt khi phương trình chẵn lẻ báo 0 (All Check Nodes Satisfied), hoặc ngắt khi chạm ngưỡng `iter_max_in` được cấp bởi Controller.

### Phase 3: System Integration & Benchmarking
*   **Task 3.1 - Tích hợp Hệ thống:** Viết file `tb_system_top.v`, gắn 3 khối (Adder Tree, Controller, LDPC Core) lại với nhau. Bắn 10,000 test vectors thay đổi QBER liên tục để xem Controller có tự động nhảy Rate không.
*   **Task 3.2 - Timing Closure:** Đẩy hệ thống qua quá trình Synthesis & Place/Route của Gowin. Kiểm tra file báo cáo Timing (Setup/Hold) để chứng minh mạch Adder Tree đạt chuẩn 150 MHz.
*   **Task 3.3 - Energy Benchmarking:** Trích xuất báo cáo Dynamic Power của phiên bản mới. Chạy lại cấu hình tương tự trên bản `qkd_post_processing_legacy`. Thu thập số liệu đối chiếu để viết bản thảo luận văn/bài báo Q1 (Mục tiêu chứng minh tiết kiệm $>3\times$ năng lượng).

---

> [!TIP]
> **Hướng dẫn cho phiên Chat Mới:**
> Khi mở cửa sổ chat mới, bạn hãy yêu cầu hệ thống đọc file `implementation_plan.md` này đầu tiên (hoặc copy toàn bộ nội dung này dán vào). Chatbot ở phiên mới sẽ lập tức nắm bắt được bối cảnh học thuật, trạng thái code hiện tại và tuần tự thực hiện từng Task một mà không đi chệch hướng!
