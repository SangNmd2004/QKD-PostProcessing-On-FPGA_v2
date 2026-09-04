`timescale 1ns/1ps

module prng_lfsr #(
    parameter SEED = 64'hACE1_ACE1_ACE1_ACE1
)(
    input wire clk,
    input wire rst,
    input wire en,
    output wire [16:0] rand_out // Output 17-bits to match NTT data width
);

    reg [63:0] lfsr_reg;
    
    // Polynomial: x^64 + x^63 + x^61 + x^60 + 1
    wire feedback = lfsr_reg[63];
    
    always @(posedge clk) begin
        if (rst) begin
            lfsr_reg <= SEED;
        end else if (en) begin
            lfsr_reg[63:1] <= lfsr_reg[62:0];
            lfsr_reg[0] <= feedback;
            
            if (feedback) begin
                lfsr_reg[63] <= lfsr_reg[62] ^ 1'b1;
                lfsr_reg[61] <= lfsr_reg[60] ^ 1'b1;
                lfsr_reg[60] <= lfsr_reg[59] ^ 1'b1;
            end
        end
    end

    // Use lower 17 bits for Toeplitz seed. 
    // In practice, this would be accumulated or shifted, 
    // but for mock PRNG we just output the raw register bits.
    assign rand_out = lfsr_reg[16:0];

endmodule
