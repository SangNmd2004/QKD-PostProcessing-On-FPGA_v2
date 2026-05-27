`timescale 1ns/1ps

module axis_to_parallel #(
    parameter DATA_W = 64,       // AXI-Stream Data Width
    parameter BLOCK_BITS = 2304  // Kích thước của mảng song song đầu ra
) (
    input wire clk,
    input wire rst,
    
    // Giao tiếp AXI-Stream Input
    input wire [DATA_W-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Giao tiếp với mảng Parallel (Khối tính toán)
    output reg [BLOCK_BITS-1:0] p_data_out,
    output reg p_valid_out,      // Cờ báo mảng song song đã đầy
    input wire p_ready_in        // Khối tính toán đã nhận mảng (Pop)
);

    localparam NUM_CHUNKS = (BLOCK_BITS + DATA_W - 1) / DATA_W;
    
    reg [BLOCK_BITS-1:0] shift_reg;
    reg [$clog2(NUM_CHUNKS+1)-1:0] chunk_count;
    
    // Sẵn sàng nhận dữ liệu nếu chưa gom đủ, HOẶC đã gom đủ nhưng khối tính toán đã đọc xong
    assign s_axis_tready = (chunk_count < NUM_CHUNKS) || p_ready_in;

    always @(posedge clk) begin
        if (rst) begin
            shift_reg <= 0;
            chunk_count <= 0;
            p_data_out <= 0;
            p_valid_out <= 0;
        end else begin
            // Xử lý cờ valid out khi có ready
            if (p_valid_out && p_ready_in) begin
                p_valid_out <= 0;
                // Có thể reset chunk_count ở đây nếu không có data mới vào
                if (!s_axis_tvalid) chunk_count <= 0;
            end
            
            if (s_axis_tvalid && s_axis_tready) begin
                // Nếu đang đầy và bị đọc, ghi đè chunk đầu tiên luôn
                if (p_valid_out && p_ready_in) begin
                    shift_reg <= {{BLOCK_BITS-DATA_W{1'b0}}, s_axis_tdata};
                    chunk_count <= 1;
                end else begin
                    // Shift in data
                    shift_reg[chunk_count*DATA_W +: DATA_W] <= s_axis_tdata;
                    chunk_count <= chunk_count + 1;
                    
                    // Nếu đã đủ 1 khối
                    if (chunk_count == NUM_CHUNKS - 1) begin
                        p_data_out <= shift_reg;
                        p_data_out[(NUM_CHUNKS-1)*DATA_W +: DATA_W] <= s_axis_tdata;
                        p_valid_out <= 1;
                    end
                end
            end
        end
    end

endmodule
