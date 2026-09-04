`timescale 1ns / 1ps

module statistical_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [10:0] shw_in,     // 11-bit Syndrome Hamming Weight
    
    output reg  [1:0]  opt_rate,   // 00: Rate 1/2, 01: Rate 2/3, 10: Rate 3/4
    output reg  [7:0]  iter_max,
    output reg         discard_flag // Cờ hủy block nếu nhiễu quá cao
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opt_rate     <= 2'b00;
            iter_max     <= 8'd50;
            discard_flag <= 1'b0;
        end else begin
            // Default safe rate
            opt_rate <= 2'b00; 
            
            // LUT Mapping extracted from Python Phase 1
            if (shw_in <= 11'd100) begin
                iter_max     <= 8'd16;
                discard_flag <= 1'b0;
            end else if (shw_in <= 11'd150) begin
                iter_max     <= 8'd33;
                discard_flag <= 1'b0;
            end else if (shw_in <= 11'd200) begin
                iter_max     <= 8'd46;
                discard_flag <= 1'b0;
            end else begin
                // Nếu kênh siêu nhiễu (SHW > 200), chạy max hoặc báo hủy tùy thiết kế
                iter_max     <= 8'd50;
                discard_flag <= 1'b1; // Bật cờ discard_flag theo lý thuyết Q1
            end
        end
    end

endmodule
