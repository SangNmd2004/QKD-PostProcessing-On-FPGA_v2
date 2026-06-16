`timescale 1ns / 1ps

// Mạng dịch vòng (Barrel Shifter) chuyên dụng cho LDPC Partially Parallel
// Thực hiện dịch vòng Zc phần tử (Cyclic Shift) trong 1 nhịp clock.
module barrel_shifter #(
    parameter Zc = 96,          // Hệ số mở rộng
    parameter word_w = 8,       // Độ rộng mỗi phần tử (V2C hoặc C2V message)
    parameter shift_w = 7       // Độ rộng bit điều khiển dịch (log2(96) = 7)
)(
    input  [Zc*word_w-1:0] data_in,   // Đầu vào 96 phần tử
    input  [shift_w-1:0] shift_amt,   // Số lượng phần tử cần dịch vòng
    output [Zc*word_w-1:0] data_out   // Kết quả sau khi dịch
);

    wire [word_w-1:0] in_array [0:Zc-1];
    reg  [Zc*word_w-1:0] out_reg;
    
    genvar i;
    generate
        // Tách chuỗi bit dài thành mảng các phần tử để dễ tính toán
        for(i = 0; i < Zc; i = i + 1) begin : split_in
            assign in_array[i] = data_in[i*word_w +: word_w];
        end
    endgenerate

    integer j;
    always @(*) begin
        // Thuật toán dịch vòng: out[j] = in[(j + shift_amt) % Zc]
        // Vì Zc = 96 không phải là lũy thừa của 2, ta dùng lệnh If để tránh hàm modulo % gây tốn tài nguyên phần cứng.
        for(j = 0; j < Zc; j = j + 1) begin
            if ((j + shift_amt) >= Zc) begin
                out_reg[j*word_w +: word_w] = in_array[j + shift_amt - Zc];
            end else begin
                out_reg[j*word_w +: word_w] = in_array[j + shift_amt];
            end
        end
    end

    assign data_out = out_reg;

endmodule
