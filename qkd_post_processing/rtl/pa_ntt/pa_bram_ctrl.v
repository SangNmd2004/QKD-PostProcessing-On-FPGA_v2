`timescale 1ns/1ps

module pa_bram_ctrl #(
    parameter DATA_W = 64,
    parameter BLOCK_SIZE = 32768
) (
    input wire clk,
    input wire rst,
    
    // AXI-Stream Input (From IR)
    input wire [DATA_W-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    
    // PA Module Read Interface
    input wire [$clog2(BLOCK_SIZE/DATA_W)-1:0] mem_addr,
    output reg [DATA_W-1:0] mem_dout,
    input wire mem_en,
    
    // Status
    output reg block_ready
);
    localparam DEPTH = BLOCK_SIZE / DATA_W;
    localparam ADDR_W = $clog2(DEPTH);
    
    // Two BRAM blocks for Ping-Pong
    reg [DATA_W-1:0] bram_0 [0:DEPTH-1];
    reg [DATA_W-1:0] bram_1 [0:DEPTH-1];
    
    reg wr_bram_sel; // 0: writing to bram_0, 1: writing to bram_1
    reg rd_bram_sel; // 0: reading from bram_1, 1: reading from bram_0
    
    reg [ADDR_W-1:0] wr_addr;
    
    assign s_axis_tready = 1'b1; // Always ready to receive if we assume downstream processing is faster
    
    // Write Logic
    always @(posedge clk) begin
        if (rst) begin
            wr_addr <= 0;
            wr_bram_sel <= 0;
            block_ready <= 0;
            rd_bram_sel <= 1; // Opposite of wr_bram_sel
        end else begin
            block_ready <= 0; // Default pulse 0
            
            if (s_axis_tvalid && s_axis_tready) begin
                if (wr_bram_sel == 0) begin
                    bram_0[wr_addr] <= s_axis_tdata;
                end else begin
                    bram_1[wr_addr] <= s_axis_tdata;
                end
                
                if (wr_addr == DEPTH - 1) begin
                    wr_addr <= 0;
                    wr_bram_sel <= ~wr_bram_sel; // Swap
                    rd_bram_sel <= wr_bram_sel;  // Now PA reads the just-filled buffer
                    block_ready <= 1'b1;         // Signal PA that a block is ready
                end else begin
                    wr_addr <= wr_addr + 1'b1;
                end
            end
        end
    end
    
    // Read Logic (Synchronous Read)
    always @(posedge clk) begin
        if (mem_en) begin
            if (rd_bram_sel == 0) begin
                mem_dout <= bram_0[mem_addr];
            end else begin
                mem_dout <= bram_1[mem_addr];
            end
        end
    end

endmodule
