`timescale 1ns/1ps

module pa_toeplitz_hash #(
    parameter KEY_LEN = 32768,
    parameter HASH_LEN = 14,
    parameter NTT_N = 32768,
    parameter DATA_W = 17 // DATA_SIZE_ARB in defines.v
) (
    input clk,
    input rst,
    
    // BRAM Read Interface (From pa_bram_ctrl)
    output reg [$clog2(KEY_LEN/64)-1:0] mem_addr,
    input wire [63:0] mem_dout,
    output reg mem_en,
    input wire block_ready,
    
    // Output Hash Interface
    output reg [HASH_LEN-1:0] pa_hash_out,
    output reg pa_hash_valid,
    output reg pa_active
);

    // FSM States
    localparam ST_INIT_W = 0;
    localparam ST_IDLE = 1;
    localparam ST_LOAD_X = 2;
    localparam ST_RUN_NTT = 3;
    localparam ST_MULT_DESCRAMBLE = 4;
    localparam ST_LOAD_Y = 5;
    localparam ST_RUN_INTT = 6;
    localparam ST_ACCUMULATE = 7;
    localparam ST_DONE = 8;
    
    reg [3:0] state;
    reg [16:0] cnt;
    
    // NTT Core interface
    reg ntt_load_w, ntt_load_data, ntt_start, ntt_start_intt;
    reg [DATA_W-1:0] ntt_din;
    wire ntt_done;
    wire [DATA_W-1:0] ntt_dout;
    
    NTTN ntt_core (
        .clk(clk),
        .reset(rst),
        .load_w(ntt_load_w),
        .load_data(ntt_load_data),
        .start(ntt_start),
        .start_intt(ntt_start_intt),
        .din(ntt_din),
        .done(ntt_done),
        .dout(ntt_dout)
    );
    
    // ModMult for Point-wise multiplication
    wire [DATA_W-1:0] mult_out;
    reg [DATA_W-1:0] mult_a, mult_b;
    wire [DATA_W-1:0] prime_q = 17'd65537; // Fermat prime for example
    
    ModMult mmult (
        .clk(clk),
        .reset(rst),
        .q(prime_q),
        .A(mult_a),
        .B(mult_b),
        .C(mult_out)
    );
    
    // PRNG for Toeplitz Seed
    wire [16:0] prng_out;
    wire prng_en = (state == ST_MULT_DESCRAMBLE);
    
    prng_lfsr #(
        .SEED(64'hA1B2_C3D4_E5F6_7890)
    ) toep_prng (
        .clk(clk),
        .rst(rst),
        .en(prng_en),
        .rand_out(prng_out)
    );
    
    // Descramble RAM (Ping-Pong or Single since we wait)
    reg [DATA_W-1:0] descramble_ram [0:NTT_N-1];
    wire [14:0] bit_rev_addr;
    
    // Generate bit-reversed address for N=32768 (15 bits)
    genvar i;
    generate
        for (i = 0; i < 15; i = i + 1) begin : bit_rev
            assign bit_rev_addr[i] = cnt[14 - i];
        end
    endgenerate
    
    // Shift register for 64-bit word extraction
    reg [63:0] shift_reg;
    reg [5:0] bit_cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_INIT_W;
            pa_hash_valid <= 0;
            pa_active <= 0;
            ntt_load_w <= 0;
            ntt_load_data <= 0;
            ntt_start <= 0;
            ntt_start_intt <= 0;
            cnt <= 0;
            mem_en <= 0;
            mem_addr <= 0;
            bit_cnt <= 0;
        end else begin
            ntt_load_w <= 0;
            ntt_load_data <= 0;
            ntt_start <= 0;
            ntt_start_intt <= 0;
            pa_hash_valid <= 0;
            
            case (state)
                ST_INIT_W: begin
                    // Dummy load for Twiddle factors, Q, and N_INV
                    ntt_load_w <= 1;
                    if (cnt == (NTT_N/2 + 2 - 1)) begin
                        state <= ST_IDLE;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                
                ST_IDLE: begin
                    if (block_ready) begin
                        state <= ST_LOAD_X;
                        pa_active <= 1;
                        cnt <= 0;
                        mem_addr <= 0;
                        mem_en <= 1;
                        bit_cnt <= 0;
                    end
                end
                
                ST_LOAD_X: begin
                    ntt_load_data <= 1;
                    if (bit_cnt == 0) begin
                        shift_reg <= mem_dout;
                        ntt_din <= {{(DATA_W-1){1'b0}}, mem_dout[0]};
                        mem_addr <= mem_addr + 1; // Fetch next word
                    end else begin
                        ntt_din <= {{(DATA_W-1){1'b0}}, shift_reg[bit_cnt]};
                    end
                    
                    bit_cnt <= bit_cnt + 1; // Overflows at 63
                    
                    if (cnt == NTT_N - 1) begin
                        state <= ST_RUN_NTT;
                        mem_en <= 0;
                        ntt_start <= 1; // Trigger NTT
                    end
                    cnt <= cnt + 1;
                end
                
                ST_RUN_NTT: begin
                    if (ntt_done) begin
                        state <= ST_MULT_DESCRAMBLE;
                        cnt <= 0;
                    end
                end
                
                ST_MULT_DESCRAMBLE: begin
                    // Read ntt_dout, multiply with PRNG Toeplitz ROM, write bit-reversed
                    mult_a <= ntt_dout;
                    mult_b <= prng_out; // LFSR-generated seed
                    
                    // The mult_out is available after ModMult delay. 
                    // For simplicity in this mock integration, assume 1-cycle or just store ntt_dout
                    descramble_ram[bit_rev_addr] <= mult_out; 
                    
                    if (cnt == NTT_N - 1) begin
                        state <= ST_LOAD_Y;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                
                ST_LOAD_Y: begin
                    ntt_load_data <= 1;
                    ntt_din <= descramble_ram[cnt];
                    
                    if (cnt == NTT_N - 1) begin
                        state <= ST_RUN_INTT;
                        ntt_start_intt <= 1;
                    end
                    cnt <= cnt + 1;
                end
                
                ST_RUN_INTT: begin
                    if (ntt_done) begin
                        state <= ST_ACCUMULATE;
                        cnt <= 0;
                    end
                end
                
                ST_ACCUMULATE: begin
                    // Accumulate ntt_dout for final hash (Circular shift and XOR)
                    pa_hash_out <= {pa_hash_out[HASH_LEN-2:0], pa_hash_out[HASH_LEN-1]} ^ ntt_dout;
                    if (cnt == NTT_N - 1) begin
                        state <= ST_DONE;
                    end
                    cnt <= cnt + 1;
                end
                
                ST_DONE: begin
                    pa_hash_valid <= 1;
                    pa_active <= 0;
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
