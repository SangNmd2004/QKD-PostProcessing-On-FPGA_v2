`timescale 1ns/1ps

module pa_toeplitz_hash #(
    parameter KEY_LEN = 4096,
    parameter HASH_LEN = 14,
    parameter NTT_N = 4096,
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

    // Pipeline shift registers for ModMult latency (8 cycles)
    reg [11:0] bit_rev_addr_delay [0:7];
    reg [7:0] mult_valid_delay;

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
    localparam ST_PRE_LOAD = 9;
    
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
    wire prng_en = (state == ST_MULT_DESCRAMBLE) || (state == ST_RUN_NTT && ntt_done);
    
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
    wire [11:0] bit_rev_addr;
    
    // Generate bit-reversed address for N=4096 (12 bits)
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : bit_rev
            assign bit_rev_addr[i] = cnt[11 - i];
        end
    endgenerate
    
    // Shift register for 64-bit word extraction
    reg [63:0] shift_reg;
    reg [5:0] bit_cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= ST_INIT_W;
            pa_hash_out <= 0;
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
            mult_valid_delay <= 0;
            ntt_din <= 0;
        end else begin
            ntt_load_w <= 0;
            ntt_load_data <= 0;
            ntt_start <= 0;
            ntt_start_intt <= 0;
            pa_hash_valid <= 0;
            
            case (state)
                ST_INIT_W: begin
                    // Dummy load for Twiddle factors, Q, and N_INV
                    // Pulse ntt_load_w for exactly 1 cycle to prevent re-triggering NTTN.v
                    if (cnt == 0) begin
                        ntt_load_w <= 1;
                    end else begin
                        ntt_load_w <= 0;
                    end
                    
                    // sys_cntr = cnt - 1. 
                    // sys_cntr == 8190 is q.
                    if (cnt == 8191) begin
                        ntt_din <= 17'd65537; // q
                    end else begin
                        ntt_din <= 17'd1;     // twiddles and n_inv
                    end
                    
                    // NTTN.v takes exactly 8192 cycles to finish loading Twiddle factors when RING_DEPTH=12
                    if (cnt == 8200) begin
                        state <= ST_IDLE;
                        cnt <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                
                ST_IDLE: begin
                    if (block_ready) begin
                        state <= ST_PRE_LOAD;
                        pa_active <= 1;
                        mem_addr <= 0;
                        mem_en <= 1;
                        pa_hash_out <= 0;
                    end
                end
                
                ST_PRE_LOAD: begin
                    state <= ST_LOAD_X;
                    cnt <= 0;
                    bit_cnt <= 0;
                end
                
                ST_LOAD_X: begin
                    if (cnt < NTT_N) begin
                        ntt_load_data <= 1;
                        if (bit_cnt == 0) begin
                            shift_reg <= mem_dout;
                            ntt_din <= {{(DATA_W-1){1'b0}}, mem_dout[0]};
                            mem_addr <= mem_addr + 1; // Fetch next word
                        end else begin
                            ntt_din <= {{(DATA_W-1){1'b0}}, shift_reg[bit_cnt]};
                        end
                        bit_cnt <= bit_cnt + 1; // Overflows at 63
                    end else begin
                        ntt_load_data <= 0;
                    end
                    
                    if (cnt == NTT_N + 1) begin
                        state <= ST_RUN_NTT;
                        mem_en <= 0;
                        ntt_start <= 1; // Trigger NTT
                    end
                    cnt <= cnt + 1;
                end
                
                ST_RUN_NTT: begin
                    if (ntt_done) begin
                        $display("[PA_DEBUG] NTT done! First ntt_dout = 0x%h", ntt_dout);
                        state <= ST_MULT_DESCRAMBLE;
                        cnt <= 1;
                        
                        // Capture cycle 0 immediately
                        mult_a <= ntt_dout;
                        mult_b <= prng_out;
                        mult_valid_delay <= {mult_valid_delay[6:0], 1'b1};
                        bit_rev_addr_delay[0] <= 12'd0;
                    end
                end
                
                ST_MULT_DESCRAMBLE: begin
                    // Read ntt_dout, multiply with PRNG Toeplitz ROM, write bit-reversed
                    if (cnt < NTT_N) begin
                        mult_a <= ntt_dout;
                        mult_b <= prng_out; // LFSR-generated seed
                        mult_valid_delay <= {mult_valid_delay[6:0], 1'b1};
                        bit_rev_addr_delay[0] <= bit_rev_addr;
                    end else begin
                        mult_valid_delay <= {mult_valid_delay[6:0], 1'b0};
                        bit_rev_addr_delay[0] <= 12'd0;
                    end
                    
                    // Shift pipeline for 8 cycles ModMult latency
                    bit_rev_addr_delay[1] <= bit_rev_addr_delay[0];
                    bit_rev_addr_delay[2] <= bit_rev_addr_delay[1];
                    bit_rev_addr_delay[3] <= bit_rev_addr_delay[2];
                    bit_rev_addr_delay[4] <= bit_rev_addr_delay[3];
                    bit_rev_addr_delay[5] <= bit_rev_addr_delay[4];
                    bit_rev_addr_delay[6] <= bit_rev_addr_delay[5];
                    bit_rev_addr_delay[7] <= bit_rev_addr_delay[6];
                    
                    if (mult_valid_delay[7]) begin
                        if (cnt == 8) $display("[PA_DEBUG] First mult_out = 0x%h", mult_out);
                        descramble_ram[bit_rev_addr_delay[7]] <= mult_out; 
                    end
                    
                    if (cnt == NTT_N + 8 - 1) begin
                        state <= ST_LOAD_Y;
                        cnt <= 0;
                        mult_valid_delay <= 0;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
                
                ST_LOAD_Y: begin
                    if (cnt < NTT_N) begin
                        ntt_load_data <= 1;
                        ntt_din <= descramble_ram[cnt];
                    end else begin
                        ntt_load_data <= 0;
                    end
                    
                    if (cnt == NTT_N + 1) begin
                        state <= ST_RUN_INTT;
                        ntt_start_intt <= 1;
                    end
                    cnt <= cnt + 1;
                end
                
                ST_RUN_INTT: begin
                    if (ntt_done) begin
                        $display("[PA_DEBUG] INTT done! First ntt_dout = 0x%h", ntt_dout);
                        state <= ST_ACCUMULATE;
                        cnt <= 1;
                        pa_hash_out <= {pa_hash_out[HASH_LEN-2:0], pa_hash_out[HASH_LEN-1]} ^ ntt_dout;
                    end
                end
                
                ST_ACCUMULATE: begin
                    if (cnt < NTT_N) begin
                        // Accumulate ntt_dout for final hash (Circular shift and XOR)
                        pa_hash_out <= {pa_hash_out[HASH_LEN-2:0], pa_hash_out[HASH_LEN-1]} ^ ntt_dout;
                    end
                    if (cnt == NTT_N - 1) begin
                        state <= ST_DONE;
                    end else begin
                        cnt <= cnt + 1;
                    end
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
