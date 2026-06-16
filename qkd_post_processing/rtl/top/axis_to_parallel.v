`timescale 1ns/1ps

module axis_to_parallel #(
    parameter DATA_W = 64,       // AXI-Stream Data Width
    parameter BLOCK_BITS = 2304  // Kich thuoc mang song song dau ra
) (
    input wire clk,
    input wire rst,
    
    // Giao tiep AXI-Stream Input
    input wire [DATA_W-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    
    // Giao tiep voi mang Parallel
    output wire [BLOCK_BITS-1:0] p_data_out,
    output reg p_valid_out,      // Co bao mang song song da day
    input wire p_ready_in        // Khoi tinh toan da nhan mang
);

    localparam NUM_CHUNKS = (BLOCK_BITS + DATA_W - 1) / DATA_W;
    
    // Su dung mang 2D thay vi 1D de Vivado suy luan LUTRAM/BRAM
    // Giup tranh loi Synthesis Hang
    reg [DATA_W-1:0] shift_reg [0:NUM_CHUNKS-1];
    reg [DATA_W-1:0] out_reg   [0:NUM_CHUNKS-1];
    reg [$clog2(NUM_CHUNKS+1)-1:0] chunk_count;
    
    assign s_axis_tready = (chunk_count < NUM_CHUNKS) || p_ready_in;

    // Flatten mang 2D thanh mảng 1D cho p_data_out
    genvar gi;
    generate
        for(gi=0; gi<NUM_CHUNKS; gi=gi+1) begin : flatten_out
            if (gi == NUM_CHUNKS - 1) begin
                // Chunk cuoi cung co the khong rong bang DATA_W (padding)
                localparam REMAINING_BITS = BLOCK_BITS - (NUM_CHUNKS - 1) * DATA_W;
                assign p_data_out[gi*DATA_W +: REMAINING_BITS] = out_reg[gi][REMAINING_BITS-1:0];
            end else begin
                assign p_data_out[gi*DATA_W +: DATA_W] = out_reg[gi];
            end
        end
    endgenerate

    integer i;

    always @(posedge clk) begin
        if (rst) begin
            chunk_count <= 0;
            p_valid_out <= 0;
            for(i=0; i<NUM_CHUNKS; i=i+1) begin
                shift_reg[i] <= 0;
                out_reg[i] <= 0;
            end
        end else begin
            if (p_valid_out && p_ready_in) begin
                p_valid_out <= 0;
                if (!s_axis_tvalid) chunk_count <= 0;
            end
            
            if (s_axis_tvalid && s_axis_tready) begin
                if (p_valid_out && p_ready_in) begin
                    shift_reg[0] <= s_axis_tdata;
                    chunk_count <= 1;
                end else begin
                    shift_reg[chunk_count] <= s_axis_tdata;
                    chunk_count <= chunk_count + 1;
                    
                    if (chunk_count == NUM_CHUNKS - 1) begin
                        for(i=0; i<NUM_CHUNKS-1; i=i+1) out_reg[i] <= shift_reg[i];
                        out_reg[NUM_CHUNKS-1] <= s_axis_tdata;
                        p_valid_out <= 1;
                    end
                end
            end
        end
    end

endmodule
