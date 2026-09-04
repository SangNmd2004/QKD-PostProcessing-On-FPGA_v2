`timescale 1ns/1ps

module parallel_to_axis #(
    parameter DATA_W = 64,       // AXI-Stream Data Width
    parameter BLOCK_BITS = 2304  // Kích thước của mảng song song
) (
    input wire clk,
    input wire rst,
    
    // Giao tiếp với mảng Parallel (Khối tính toán)
    input wire [BLOCK_BITS-1:0] p_data_in,
    input wire p_valid_in,       // Cờ báo mảng dữ liệu đã sẵn sàng
    output reg p_ready_out,      // Cờ báo converter đã rảnh để nhận mảng mới
    
    // Giao tiếp AXI-Stream Output
    output wire [DATA_W-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast
);

    localparam NUM_CHUNKS = (BLOCK_BITS + DATA_W - 1) / DATA_W;
    
    reg [BLOCK_BITS-1:0] shift_reg;
    reg [$clog2(NUM_CHUNKS+1)-1:0] chunk_count;
    reg is_transmitting;
    
    always @(posedge clk) begin
        if (rst) begin
            shift_reg <= 0;
            chunk_count <= 0;
            is_transmitting <= 0;
            p_ready_out <= 1;
        end else begin
            if (p_valid_in && p_ready_out) begin
                // Lấy toàn bộ mảng song song vào bộ đệm dịch
                shift_reg <= p_data_in;
                chunk_count <= NUM_CHUNKS;
                is_transmitting <= 1;
                p_ready_out <= 0;
            end else if (is_transmitting && m_axis_tready) begin
                // Dịch dữ liệu ra AXI-Stream
                shift_reg <= shift_reg >> DATA_W;
                chunk_count <= chunk_count - 1;
                
                if (chunk_count == 1) begin
                    is_transmitting <= 0;
                    p_ready_out <= 1; // Sẵn sàng nhận block mới
                end
            end
        end
    end
    
    assign m_axis_tdata = shift_reg[DATA_W-1:0];
    assign m_axis_tvalid = is_transmitting;
    assign m_axis_tlast = (chunk_count == 1) && is_transmitting;

endmodule
