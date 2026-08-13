`timescale 1ns / 1ps

module ldpc_bram_bank #(
    parameter P = 24,       // Parallelism factor
    parameter F = 4,        // Folding factor (Zc / P = 96 / 24 = 4)
    parameter DATA_W = 6,   // Data width per element
    parameter DEPTH = 24    // Number of blocks (e.g., 24 for WiMAX Rate 1/2)
)(
    input clk,
    input we,
    input [$clog2(DEPTH)-1:0] base_addr_r,
    input [$clog2(DEPTH)-1:0] base_addr_w,
    input [$clog2(F)-1:0] batch_r,
    input [$clog2(F)-1:0] batch_w,
    input [6:0] shift_amt_r,
    input [6:0] shift_amt_w,
    input [P*DATA_W-1:0] din,
    output [P*DATA_W-1:0] dout
);

    // BRAM storage arrays
    // 24 independent BRAMs, each with depth DEPTH * F
    localparam ACTUAL_DEPTH = DEPTH * F;
    localparam ADDR_W = $clog2(ACTUAL_DEPTH);

    wire [DATA_W-1:0] din_array [0:P-1];
    wire [DATA_W-1:0] dout_array [0:P-1];
    
    genvar i;
    generate
        for(i = 0; i < P; i = i + 1) begin : gen_banks
            assign din_array[i] = din[i*DATA_W +: DATA_W];
            assign dout[i*DATA_W +: DATA_W] = dout_array[i];
            
            // Calculate read address offset for this bank
            wire [4:0] s_div_r = shift_amt_r / P;
            wire [4:0] s_mod_r = shift_amt_r % P;
            wire is_wrap_r = (i + s_mod_r >= P) ? 1'b1 : 1'b0;
            wire [1:0] offset_r = (batch_r + F - s_div_r - is_wrap_r) % F;
            wire [ADDR_W-1:0] addr_r = base_addr_r * F + offset_r;
            
            // Calculate write address offset for this bank
            wire [4:0] s_div_w = shift_amt_w / P;
            wire [4:0] s_mod_w = shift_amt_w % P;
            wire is_wrap_w = (i + s_mod_w >= P) ? 1'b1 : 1'b0;
            wire [1:0] offset_w = (batch_w + F - s_div_w - is_wrap_w) % F;
            wire [ADDR_W-1:0] addr_w = base_addr_w * F + offset_w;
            
            // Instantiate BRAM primitive
            (* ram_style = "block" *)
            reg [DATA_W-1:0] mem [0:ACTUAL_DEPTH-1];
            
            reg [DATA_W-1:0] mem_out;
            always @(posedge clk) begin
                if (we) begin
                    mem[addr_w] <= din_array[i];
                end
                mem_out <= mem[addr_r];
            end
            assign dout_array[i] = mem_out;
        end
    endgenerate

endmodule
