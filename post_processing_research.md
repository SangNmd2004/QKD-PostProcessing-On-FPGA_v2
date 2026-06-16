# Báo cáo Nghiên cứu Chuyên sâu: Hậu xử lý trong QKD và Kỹ thuật LDPC

Báo cáo này giải đáp chi tiết 6 vấn đề bạn yêu cầu, kết hợp với những tiến bộ từ 2 bài báo học thuật bạn đã cung cấp trong dự án.

---

## 1. Trình bày chi tiết cách thức và triển khai Post-Processing (Hậu xử lý)

Để hiểu rõ Hậu xử lý (Post-Processing) bắt đầu từ đâu, ta cần nhìn lại toàn cảnh quá trình giao tiếp giữa Alice (Người gửi) và Bob (Người nhận) từ lúc truyền photon vật lý cho đến khi ra được khóa số:

**Giai đoạn 1: Lớp Lượng tử (Quantum Layer) - Bắt nguồn của dữ liệu**
1.  **Chuẩn bị & Nhúng dữ liệu (Preparation):** Alice tạo ra các giá trị ngẫu nhiên liên tục theo phân phối chuẩn (Gaussian). Cô sử dụng thiết bị quang học để nhúng (Modulate) các giá trị này vào Biên độ ($X$) và Pha ($P$) của các xung Laser, sau đó truyền qua cáp quang.
2.  **Kênh lượng tử (Quantum Channel):** Xung Laser truyền đi bị suy hao (Loss) và dính nhiễu (Excess Noise) do môi trường hoặc do sự rình mò của kẻ thù (Eve).
3.  **Đo đạc & Lượng tử hóa (Measurement & ADC):** Bob dùng bộ thu kết hợp (Coherent Receiver) để đo đạc ánh sáng, thu được tín hiệu điện áp Analog. Tín hiệu này đi qua bộ chuyển đổi ADC và thuật toán Lượng tử hóa đa mức (Multi-bit Quantization) để biến thành dải bit nhị phân (gọi là LLR - Log-Likelihood Ratio). Đây chính là **Khóa thô (Raw Key)** chứa đầy lỗi của Bob.

**Giai đoạn 2: Lớp Hậu xử lý (Post-Processing) - Tinh chế Khóa**
Khi đã có Khóa thô, hệ thống số (CPU/FPGA) bắt đầu chuỗi 4 bước Hậu xử lý để biến nó thành Khóa bí mật tuyệt đối:

1.  **Lọc khóa (Sifting):** Alice và Bob liên lạc qua Internet công khai để đối chiếu "Hệ cơ sở" (Basis) đã dùng khi truyền/nhận. Các photon bị đo sai hệ cơ sở hoặc có mức điện áp quá nhiễu sẽ bị loại bỏ.
2.  **Ước lượng tham số (Parameter Estimation):** Trích ra một tập con ngẫu nhiên của khóa thô để công khai so sánh. Qua đó, tính toán tỷ lệ lỗi lượng tử (QBER), độ suy hao ($T$) và Nhiễu dư ($\xi$). Nếu nhiễu vượt quá ngưỡng bảo mật (chứng tỏ Eve đã can thiệp quá sâu), lập tức hủy bỏ toàn bộ quá trình.
3.  **Sửa lỗi & Hòa giải ngược (Information Reconciliation - IR):**
    *   Trong CV-QKD, Bob sẽ gửi một đoạn **Syndrome (Hội chứng)** của Khóa thô của mình cho Alice qua mạng Internet (gọi là Hòa giải ngược - Reverse Reconciliation).
    *   Alice nhận Syndrome và đưa vào bộ giải mã **QC-LDPC**. Lõi LDPC sẽ bẻ cong (sửa lỗi) các bit của Alice sao cho khớp 100% với dữ liệu của Bob.
4.  **Khuếch đại bảo mật (Privacy Amplification - PA):** Sau khi khớp nhau, cả hai bên ném khóa vào lõi băm mã **Toeplitz Hashing (dựa trên NTT)**. Phép băm này cắt ngắn khóa gốc, gột rửa hoàn toàn mọi mẩu thông tin vụn vặt mà Eve có thể đã thu thập được, cho ra Khóa bí mật (Secret Key) hoàn chỉnh.

**Triển khai trên cấu trúc ZYNQ FPGA:** 
Các bước Sifting và Parameter Estimation thường chạy trên lõi phần mềm CPU ARM (ZYNQ PS) vì tính toán nhẹ nhưng logic rẽ nhánh phức tạp. Ngược lại, bước 3 (QC-LDPC) và 4 (NTT Hash) là hai "Nút thắt cổ chai" đòi hỏi xử lý hàng tỷ phép tính ma trận mỗi giây, do đó bắt buộc phải được đúc cứng dưới dạng mạch logic (Programmable Logic - PL) thông qua giao thức AXI-Stream tốc độ cao.

---

## 2. Lý thuyết tổng quan về Syndrome và Mô hình QKD

**Lý thuyết Syndrome (Hội chứng):**
*   Trong lý thuyết mã hóa, Syndrome $S$ của một chuỗi dữ liệu $X$ được tính bằng cách nhân ma trận kiểm tra chẵn lẻ $H$: $S = H \times X$.
*   Syndrome thực chất là tập hợp các phương trình kiểm tra tính chẵn lẻ của các nhóm bit. Khi gửi Syndrome qua kênh công khai, ta gửi "manh mối" để sửa lỗi, chứ không gửi bản thân dữ liệu. Kẻ thù (Eve) bắt được Syndrome cũng không thể giải ngược ra khóa gốc vì số lượng phương trình ít hơn rất nhiều so với số lượng ẩn số.

**Mô hình Reverse Reconciliation (Hòa giải ngược - Đặc trưng của CV-QKD):**
*   Nếu Alice gửi Syndrome cho Bob (Hòa giải thuận - Forward), khoảng cách tối đa của QKD bị giới hạn vật lý ở mức suy hao 3dB (khoảng 15km).
*   Để truyền đi hàng trăm km, CV-QKD bắt buộc dùng **Hòa giải ngược**. Trong đó, **Bob mới là người lấy dữ liệu đo đạc của mình làm chuẩn**. Bob tính Syndrome từ khóa của mình và gửi công khai cho Alice. Alice sẽ dùng Syndrome đó + bộ giải mã LDPC để bẻ cong dữ liệu của Alice sao cho khớp 100% với Bob. Điều này khiến Eve (ở giữa kênh truyền) chịu thiệt thòi hơn Bob, đảm bảo tính bảo mật.

---

## 3. Phase Error Estimation, Puncture Code, và Code Extension

### A. Phase Error Estimation (Ước lượng lỗi pha)
*   Trong QKD rời rạc (DV-QKD - giao thức BB84), photon được mã hóa trên 2 hệ cơ sở (Z: Rectangular và X: Diagonal). Sự can thiệp của Eve trên cơ sở Z sẽ làm nhiễu cơ sở X. Do đó, Alice và Bob đo tỷ lệ lỗi bit (Bit Error Rate) trên cơ sở X để **ước lượng lỗi pha (Phase Error)** trên cơ sở Z. Lỗi pha không thể sửa được, nó đại diện cho lượng thông tin Eve đã trộm được, và sẽ bị cắt bỏ ở bước Privacy Amplification.
*   *Lưu ý:* Trong CV-QKD (hệ thống của bạn), ta không gọi là "Phase Error Estimation", mà gọi là ước lượng **Nhiễu dư (Excess Noise $\xi$)**.

### B. Puncture Code (Đục lỗ)
*   **Lý thuyết:** Khi kênh lượng tử tốt (QBER thấp), ta không cần hệ thống LDPC quá mạnh. Ta có thể chủ động **không truyền** một số bit chẵn lẻ (Parity bits). Tại phía nhận, các bit không được truyền này sẽ được gán giá trị LLR = 0 (hoàn toàn không chắc chắn). Thuật toán LDPC vẫn có thể tự khôi phục lại chúng. Kỹ thuật này giúp tăng **Code Rate** (Hiệu suất truyền).
*   **Triển khai FPGA:** Rất dễ. Chỉ cần cấu hình mạch Multiplexer (MUX) để ép các cổng đầu vào của một số Node (VNU) thành số $0$ cứng.

### C. Code Extension (Mở rộng mã)
*   **Lý thuyết:** Trái ngược với Puncture. Khi kênh xấu đi (QBER cao), mã hiện tại không đủ sức sửa. Ta ghép thêm (Extend) các ma trận con vào ma trận $H$ ban đầu, sinh ra thêm nhiều bit chẵn lẻ để gửi đi. Việc này làm giảm Code Rate nhưng tăng khả năng sửa lỗi (Robustness).
*   **Triển khai FPGA:** Khó hơn Puncture rất nhiều. Vì ma trận $H$ thay đổi kích thước, FPGA cần một kiến trúc linh hoạt (Dynamic/Adaptive Architecture). Giải pháp là đúc sẵn một siêu ma trận lớn trên phần cứng, và dùng tín hiệu điều khiển (Control signals) để "Kích hoạt" (Enable/Disable) các hàng/cột tương ứng với Code Rate mong muốn.

---

## 4. Giao thức gửi Syndrome & Xử lý khi Sửa lỗi không thành công

**Giao thức truyền Syndrome:**
Syndrome được truyền qua kênh liên lạc cổ điển (Classical Channel), ví dụ như mạng cáp đồng Ethernet, Internet TCP/IP thông thường. Giao thức này bắt buộc phải đi kèm chữ ký điện tử (Authentication) để đảm bảo Eve không thể thay đổi nội dung của Syndrome.

**Khi LDPC báo lỗi không hội tụ (Sửa lỗi thất bại):**
Trong các hệ thống QKD truyền thống: Nếu LDPC chạy hết số vòng lặp tối đa (VD: 32 iterations) mà phương trình kiểm tra vẫn sai, **Toàn bộ khối khóa đó sẽ bị vứt bỏ (Discarded)**. Việc này gây lãng phí rất lớn nguồn tài nguyên lượng tử quý giá.

**Giải pháp (Blind Reconciliation):**
Thay vì vứt bỏ, hệ thống có thể chuyển sang chế độ tương tác (Interactive):
1.  Bob thông báo cho Alice rằng sửa lỗi thất bại.
2.  Alice sẽ tạo thêm các bit kiểm tra phụ (dùng kỹ thuật Code Extension) và gửi thêm đoạn Syndrome phụ qua kênh công khai.
3.  Bob ghép đoạn Syndrome phụ này vào ma trận cũ, chạy giải mã LDPC lại từ đầu với sức mạnh sửa lỗi cao hơn.

---

## 5 & 6. Khảo sát Nghiên cứu Gần đây & Ứng dụng đột phá

Qua khảo sát 2 bài báo nghiên cứu chuyên sâu mà bạn đã bổ sung vào dự án, có thể thấy xu hướng phát triển của khâu Hậu xử lý QKD đang nhắm đến việc **giải quyết triệt để sự mất ổn định của kênh truyền (QBER fluctuation)**. Dưới đây là phân tích chi tiết và gợi ý để bạn đưa vào đồ án:

### Bài báo 1: "Blind Reconciliation with Protograph LDPC Code Extension for FSO-Based Satellite QKD Systems"
*(Tác giả: Cuong T. Nguyen, Hoang D. Le, et al.)*

*   **Vấn đề nan giải (Motivation):** Bài báo nhắm vào hệ thống QKD qua Vệ tinh quỹ đạo thấp (LEO) sử dụng sóng quang học không gian tự do (FSO). Nhiễu của khí quyển làm cho QBER trồi sụt cực kỳ hỗn loạn. Để dùng phương pháp *Adaptive-Rate (Chỉnh Rate thích nghi)* truyền thống, hệ thống bắt buộc phải tốn một lượng rất lớn bit của khóa thô chỉ để ước lượng QBER, gây lãng phí nghiêm trọng và làm rớt thê thảm tỷ lệ khóa cuối cùng (Final Key Rate).
*   **Tiến bộ đột phá (Proposed Scheme):** Các tác giả đề xuất giao thức **Blind Reconciliation (Hòa giải mù)** kết hợp với **Protograph LDPC Code Extension**.
    *   Hệ thống "nhắm mắt" bỏ qua luôn bước ước lượng QBER. Thay vào đó, nó cứ đoán bừa một Code Rate cao và chạy giải mã.
    *   Nếu giải mã xịt (thất bại), hệ thống dùng kỹ thuật **Extension (Mở rộng mã)**: tự động ghép thêm các hàng/cột phụ vào ma trận Protograph (Mã đồ thị gốc) và yêu cầu truyền thêm một phần Syndrome phụ. Việc này làm Code Rate hạ xuống dần dần cho đến khi giải mã thành công thì thôi.
*   **Gợi ý áp dụng cho bạn:** Đề tài của bạn hoàn toàn có thể đề xuất một cơ chế "Blind Reconciliation" cấp độ phần cứng. Khi chân `ir_fail` (sửa lỗi thất bại) của khối LDPC trên FPGA bật lên, thay vì vứt bỏ khối dữ liệu như thiết kế hiện hành, FPGA sẽ gửi ngắt (Interrupt) về ZYNQ PS để xin thêm dữ liệu Syndrome từ cổng AXI, tạo ra một hệ thống "sửa lỗi không bao giờ lãng phí khóa".

### Bài báo 2: "A Collaborative RC QC-LDPC Code Construction Scheme Using Both Extension and Splitting"
*(Tác giả: Huang-Chang Lee, Yeong-Luh Ueng, et al.)*

*   **Vấn đề nan giải (Motivation):** Để tạo ra hệ thống mã LDPC đa tốc độ (Rate-Compatible - RC) đáp ứng đường truyền biến động, các phương pháp đơn lẻ như Puncturing (Đục lỗ), Extension (Mở rộng) hay Splitting (Chia tách) bộc lộ nhược điểm làm suy yếu cấu trúc đồ thị Tanner (Tanner graph), đặc biệt ở các block dữ liệu ngắn hoặc trung bình. Điều này gây ra hiện tượng *Error Floor (Sàn lỗi)* khiến tỷ lệ lỗi bit không thể giảm xuống mức 0 tuyệt đối dù SNR có tốt đến đâu.
*   **Tiến bộ đột phá (Proposed Scheme):** Bài báo đề xuất sử dụng **Hỗn hợp (Collaborative)** cả hai kỹ thuật **Extension** và **Splitting**.
    *   **Splitting:** Lấy một phương trình kiểm tra (Check node) phức tạp chẻ làm đôi, nhét thêm một Variable Node trung gian vào giữa để giảm Rate.
    *   **Tiêu chí A2CE (Average ACE):** Tác giả đưa ra công thức đo lường mới gọi là *Độ lớn tin nhắn ngoại lai chu trình trung bình (Average Approximate Cycle Extrinsic)* để đánh giá độ "khỏe" của đồ thị kết nối Tanner sau khi biến đổi. Phương pháp lai này sinh ra các bộ ma trận có độ kết nối hoàn hảo, bao phủ mượt mà một dải Rate rất rộng mà sức mạnh sửa lỗi vẫn tương đương hoặc ăn đứt các chuẩn mã hóa hiện hành.
*   **Gợi ý áp dụng cho bạn:** Thiết kế FPGA "Fully-Parallel" của bạn hiện tại đã bị đóng đinh cứng (hard-coded) với 1 ma trận duy nhất nên không thể dùng Splitting được. Tuy nhiên, nếu bạn triển khai kiến trúc **Partially Parallel (Ghép kênh phân thời gian)** như kế hoạch trong Tương lai (Future Work), cấu trúc bộ nhớ ROM linh hoạt của nó hoàn toàn cho phép lưu trữ và chuyển đổi qua lại giữa các tập ma trận sinh ra từ kỹ thuật Collaborative (Extension + Splitting) này, biến FPGA của bạn thành một cỗ máy sửa lỗi QKD "Thích nghi vạn năng".
