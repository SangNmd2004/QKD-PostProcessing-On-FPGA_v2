`timescale 1ns / 1ps

// Bộ nhớ Block RAM đơn giản có thể Inferred (tự động tổng hợp thành BRAM36/BRAM18)
// Sử dụng để lưu trữ LLR, và các tin nhắn V2C, C2V cho thuật toán Partially Parallel
module ldpc_bram #(
    parameter DATA_WIDTH = 768, // Ví dụ: Zc(96) * 8 bits = 768 bits
    parameter DEPTH = 24,       // Số lượng Blocks (Ví dụ: 24 cho chuẩn WiMAX Rate 1/2)
    parameter ADDR_WIDTH = 5    // log2(24) = ~5 bits
)(
    input  clk,
    input  we,
    input  [ADDR_WIDTH-1:0] addr_r, // Địa chỉ đọc
    input  [ADDR_WIDTH-1:0] addr_w, // Địa chỉ ghi
    input  [DATA_WIDTH-1:0] din,    // Dữ liệu ghi
    output reg [DATA_WIDTH-1:0] dout // Dữ liệu đọc
);

    // Khởi tạo mảng nhớ
    // Vivado Synthesis tool sẽ tự động nhận diện mẫu code này và ánh xạ (map) nó vào Block RAM cứng.
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    always @(posedge clk) begin
        if (we) begin
            mem[addr_w] <= din;
        end
        // Quá trình đọc đồng bộ (Synchronous Read) phù hợp chuẩn BRAM
        dout <= mem[addr_r];
    end

endmodule
