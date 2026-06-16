`timescale 1ns / 1ps

// Bộ nhớ ROM lưu trữ ma trận H (H-Matrix) hỗ trợ tính năng Code Extension.
// Có khả năng mở rộng thêm các hàng (Rows) để hạ Code Rate khi QBER tăng cao.
module rom_h_matrix #(
    parameter ROW_BITS = 5,   // Hỗ trợ tối đa 32 hàng cơ sở (Base Rows)
    parameter COL_BITS = 5,   // Hỗ trợ tối đa 32 cột cơ sở (Base Columns)
    parameter SHIFT_W  = 7    // Độ rộng bit dịch vòng (log2(96) = 7)
)(
    input  clk,
    input  [ROW_BITS-1:0] row_idx,
    input  [COL_BITS-1:0] col_idx,
    output reg [SHIFT_W-1:0] shift_val,
    output reg valid_conn // 1 nếu có kết nối, 0 nếu là khoảng trống (-1)
);

    // ROM Implementation
    // File ROM thực tế sẽ được nạp bằng $readmemh sinh ra từ Python (Giai đoạn sau).
    // Ở đây, mạch được thiết kế hỗ trợ truy xuất không gian bộ nhớ lớn hơn bình thường:
    // - Địa chỉ Row 0-11: Chứa ma trận gốc WiMAX (Code Rate 1/2)
    // - Địa chỉ Row 12-23: Chứa ma trận phụ trợ mở rộng (Extended Protograph)
    // Khi mạch Blind Reconciliation yêu cầu thêm Syndrome, FSM sẽ đẩy row_idx vượt qua mốc 11.
    
    always @(posedge clk) begin
        // Placeholder cho việc đọc ROM
        // if (row_idx < 12) -> Đọc ma trận lõi
        // else if (row_idx < 24) -> Đọc ma trận mở rộng
        
        valid_conn <= 1'b1; 
        shift_val <= 7'd0;  
    end

endmodule
