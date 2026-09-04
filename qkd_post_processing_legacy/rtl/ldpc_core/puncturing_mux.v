`timescale 1ns / 1ps

// Khối Puncturing (Đục lỗ cứng trên RTL)
// Sử dụng để ép giá trị LLR về 0. Bằng cách này, ta có thể tăng Code Rate 
// (Ví dụ từ 1/2 lên 3/4) mà không cần thay đổi kích thước ma trận lõi.
module puncturing_mux #(
    parameter Zc = 96,
    parameter data_w = 8
)(
    input  [Zc*data_w-1:0] llr_in,
    input  puncture_en,             // Tín hiệu điều khiển: 1 = Xóa LLR về 0, 0 = Giữ nguyên
    output [Zc*data_w-1:0] llr_out
);

    // Mạch Multiplexer song song 96 kênh
    // Nếu puncture_en = 1, mạch sẽ xuất ra dãy số 0. Điều này làm thuật toán Min-Sum hiểu rằng
    // thông tin về các bit này hoàn toàn "mù" (Log-Likelihood Ratio = 0).
    assign llr_out = puncture_en ? {(Zc*data_w){1'b0}} : llr_in;

endmodule
