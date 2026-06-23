`timescale 1ns / 1ps

module core_partially_parallel #(
    parameter Zc = 96,
    parameter data_w = 6,
    parameter D_vnu = 6, 
    parameter D_cnu = 15, 
    parameter ext_w = 1,
    parameter res_w = 8,
    parameter shift_w = 7
)(
    input  clk,
    input  rst,
    input  start,
    input  [1:0] code_rate, // 00: 1/2, 01: 2/3B, 10: 3/4B
    input  [1535:0] syn_in,
    input  [Zc*data_w*24-1:0] llr_in_array,
    output reg done,
    output reg ir_success,
    output reg ir_fail_intr, 
    input  puncture_en,      
    input  resume_decoding,   
    output [5:0] iter_out, output reg [Zc*24-1:0] ldpc_res_out 
);

    wire [Zc*data_w-1:0] raw_llr_in; 
    wire [Zc*data_w-1:0] processed_llr_in;
    puncturing_mux #(.Zc(Zc), .data_w(data_w)) u_puncturing (
        .llr_in(raw_llr_in), .puncture_en(puncture_en), .llr_out(processed_llr_in)
    );

    wire [Zc*data_w-1:0] llr_dout;
    reg llr_we;
    reg [4:0] llr_addr_r, llr_addr_w;
    reg [Zc*data_w-1:0] llr_din;
    
    ldpc_bram #(.DATA_WIDTH(Zc*data_w), .DEPTH(24), .ADDR_WIDTH(5)) u_llr_ram (
        .clk(clk), .we(llr_we), .addr_r(llr_addr_r), .addr_w(llr_addr_w), .din(llr_din), .dout(llr_dout)
    );

    reg c2v_we;
    reg [4:0] c2v_addr_w, c2v_addr_r;
    reg [Zc*res_w*D_cnu-1:0] c2v_din;
    wire [Zc*res_w*D_cnu-1:0] c2v_dout;
    
    ldpc_bram #(.DATA_WIDTH(Zc*res_w*D_cnu), .DEPTH(12), .ADDR_WIDTH(5)) u_c2v_ram (
        .clk(clk), .we(c2v_we), .addr_r(c2v_addr_r), .addr_w(c2v_addr_w), .din(c2v_din), .dout(c2v_dout)
    );

    localparam IDLE = 0, LOAD_LLR = 1, LAYER_READ = 2, LAYER_CALC = 3, LAYER_WRITE = 4, CHECK = 5, WAIT_FOR_EXTENSION = 6, EXTENSION_LOAD = 7, OUTPUT_RES = 8;
    reg [3:0] state, next_state;
    reg [6:0] iter_count;
    assign iter_out = iter_count;
    reg [4:0] block_count, col_count;
    reg [3:0] layer_count; 
    reg [1:0] current_code_rate; 
    wire [3:0] max_layer = (current_code_rate == 2'b00) ? 11 :
                           (current_code_rate == 2'b01) ? 7 :
                           (current_code_rate == 2'b10) ? 5 : 11;
    reg [4:0] calc_delay;

    wire [4:0] rom_row = layer_count;
    // Delay rom_col by 1 cycle to match the 1-cycle read latency of ldpc_bram
    
    
    reg valid_read_0, valid_read_1, valid_read_2;
    always @(posedge clk) begin
        if (state == LAYER_READ || state == LAYER_WRITE) begin
            valid_read_0 <= (col_count < 24);
        end else begin
            valid_read_0 <= 1'b0;
        end
        valid_read_1 <= valid_read_0;
        valid_read_2 <= valid_read_1;
    end
    
    reg [Zc*(res_w+ext_w)-1:0] q_in_buffer [0:D_cnu-1];
    wire [Zc*(res_w+ext_w)*D_cnu-1:0] q_in_buffer_flat;
    reg [Zc*res_w-1:0] c2v_new_buffer [0:D_cnu-1];
    wire [Zc*res_w*D_cnu-1:0] c2v_new_buffer_flat;
    genvar gf;
    generate
        for(gf=0; gf<D_cnu; gf=gf+1) begin : flatten_buffers
            assign q_in_buffer_flat[gf*Zc*(res_w+ext_w) +: Zc*(res_w+ext_w)] = q_in_buffer[gf];
            assign c2v_new_buffer_flat[gf*Zc*res_w +: Zc*res_w] = c2v_new_buffer[gf];
        end
    endgenerate
    reg [3:0] valid_degree_count, write_degree_count;

    reg [4:0] col_count_d1, col_count_d2;
    wire [4:0] rom_col = col_count;
    reg valid_conn_d1, valid_conn_d2;
    reg [shift_w-1:0] shift_val_d1, shift_val_d2;
    
    localparam [res_w+ext_w-1:0] MAX_POS_VAL = (1 << (res_w+ext_w-1)) - 1;
    wire [Zc*(res_w+ext_w)-1:0] DUMMY_Q_IN;
    genvar dq;
    generate
        for(dq=0; dq<Zc; dq=dq+1) begin : gen_dummy
            assign DUMMY_Q_IN[dq*(res_w+ext_w) +: (res_w+ext_w)] = MAX_POS_VAL;
        end
    endgenerate
    
    wire [Zc-1:0] current_layer_syn;
    
    // Sử dụng mảng 2D cho Syndrome để tránh lỗi Synthesis Hang do MUX 1D quá lớn
    wire [Zc-1:0] syn_2d [0:11];
    genvar sy;
    generate
        for(sy=0; sy<12; sy=sy+1) begin : gen_syn_2d
            assign syn_2d[sy] = syn_in[sy*Zc +: Zc];
        end
    endgenerate
    assign current_layer_syn = syn_2d[layer_count < 12 ? layer_count : 0];
    
    wire [Zc-1:0] parity_vector;
    
    wire [Zc*res_w*D_cnu-1:0] cnu_r_out;
    cnu_cluster #(.Zc(Zc), .D(D_cnu), .res_w(res_w), .ext_w(ext_w), .idx_w(4)) u_cnu_cluster (
        .clk(clk), .rst(rst), .en(1'b1), .active(1'b1),
        .syn_in(current_layer_syn), 
        .q_in(q_in_buffer_flat), 
        .r_out(cnu_r_out),
        .parity_vector(parity_vector)
    );

    wire [shift_w-1:0] shift_val;
    wire valid_conn;
    rom_h_matrix #(.ROW_BITS(5), .COL_BITS(5), .SHIFT_W(shift_w)) u_rom (
        .clk(clk), .code_rate(current_code_rate), .row_idx(rom_row), .col_idx(rom_col), .shift_val(shift_val), .valid_conn(valid_conn)
    );

    wire [shift_w-1:0] inv_shift_amt_d2 = (shift_val_d2 == 0) ? 0 : (Zc - shift_val_d2);
    wire [shift_w-1:0] current_shift_amt = (state == LAYER_WRITE) ? inv_shift_amt_d2 : shift_val_d2;
    
    wire [Zc*(res_w+ext_w)-1:0] v2c_array;
    wire [Zc*(res_w+ext_w)-1:0] llr_new_shifted_array;
    wire [Zc*data_w-1:0] llr_din_math;
    wire [Zc*res_w-1:0] c2v_old = c2v_dout[valid_degree_count * Zc*res_w +: Zc*res_w];
    wire [Zc*res_w-1:0] c2v_new_shifted = cnu_r_out[write_degree_count * Zc*res_w +: Zc*res_w];
    wire [Zc*(res_w+ext_w)-1:0] v2c_old_shifted_block = q_in_buffer[write_degree_count];
    
    wire [Zc*(res_w+ext_w)-1:0] shifter_in = (state == LAYER_WRITE) ? llr_new_shifted_array : v2c_array;

    wire [Zc*(res_w+ext_w)-1:0] shift_out; 
    barrel_shifter #(.Zc(Zc), .word_w(res_w+ext_w), .shift_w(shift_w)) u_shifter (
        .data_in(shifter_in), .shift_amt(current_shift_amt), .data_out(shift_out)
    );
    
    wire [Zc*res_w-1:0] c2v_new_unshifted;
    barrel_shifter #(.Zc(Zc), .word_w(res_w), .shift_w(shift_w)) u_inv_shifter (
        .data_in(c2v_new_shifted), .shift_amt(inv_shift_amt_d2), .data_out(c2v_new_unshifted)
    );
    wire [Zc*res_w-1:0] c2v_new_unshifted_sat;

    always @(posedge clk) begin
        col_count_d1 <= col_count;
        col_count_d2 <= col_count_d1;
        valid_conn_d1 <= valid_conn;
        valid_conn_d2 <= valid_conn_d1;
        shift_val_d1 <= shift_val;
        shift_val_d2 <= shift_val_d1;
    end

    genvar gi;
    generate
        for(gi=0; gi<Zc; gi=gi+1) begin : gen_v2c
            wire signed [data_w-1:0] llr_val = llr_dout[gi*data_w +: data_w];
            wire signed [res_w+ext_w-1:0] llr_ext = {{ (res_w+ext_w-data_w){llr_val[data_w-1]} }, llr_val};
            wire signed [res_w-1:0] c2v_val = c2v_dout[ (valid_degree_count*Zc + gi)*res_w +: res_w ];
            wire signed [res_w+ext_w-1:0] v2c_val = llr_ext - c2v_val;
            assign v2c_array[gi*(res_w+ext_w) +: (res_w+ext_w)] = v2c_val;
        end
        for(gi=0; gi<Zc; gi=gi+1) begin : gen_math
            wire signed [res_w+ext_w-1:0] v2c_old_shifted = q_in_buffer_flat[ (write_degree_count*Zc + gi)*(res_w+ext_w) +: (res_w+ext_w) ];
            wire signed [res_w-1:0] c2v_new_val = cnu_r_out[ (write_degree_count*Zc + gi)*res_w +: res_w ];
            wire signed [res_w+ext_w-1:0] llr_new_shifted = v2c_old_shifted + c2v_new_val;
            assign llr_new_shifted_array[gi*(res_w+ext_w) +: (res_w+ext_w)] = llr_new_shifted;
            
            wire signed [res_w+ext_w-1:0] llr_new_unshifted = shift_out[gi*(res_w+ext_w) +: (res_w+ext_w)];
            wire [data_w-1:0] sat_max = (1 << (data_w-1)) - 1;
            wire [data_w-1:0] sat_min = ~(sat_max);
            wire signed [data_w-1:0] llr_new_sat = (llr_new_unshifted > $signed(sat_max)) ? sat_max[data_w-1:0] :
                                                   (llr_new_unshifted < $signed(sat_min)) ? sat_min[data_w-1:0] : 
                                                   llr_new_unshifted[data_w-1:0];
            assign llr_din_math[gi*data_w +: data_w] = llr_new_sat;
            
            // Extract c2v_new_unshifted to write to RAM
            wire signed [data_w-1:0] llr_old_val = llr_dout[gi*data_w +: data_w];
            wire signed [res_w+ext_w-1:0] llr_old_ext = {{ (res_w+ext_w-data_w){llr_old_val[data_w-1]} }, llr_old_val};
            wire signed [res_w-1:0] c2v_old_val = c2v_dout[ (write_degree_count*Zc + gi)*res_w +: res_w ];
            wire signed [res_w+ext_w-1:0] diff_c2v = llr_new_unshifted - llr_old_ext + c2v_old_val;
            
            wire [res_w-1:0] c2v_sat_max = (1 << (res_w-1)) - 1;
            wire [res_w-1:0] c2v_sat_min = ~(c2v_sat_max);
            wire signed [res_w-1:0] diff_c2v_sat = (diff_c2v > $signed(c2v_sat_max)) ? c2v_sat_max :
                                                   (diff_c2v < $signed(c2v_sat_min)) ? c2v_sat_min :
                                                   diff_c2v[res_w-1:0];
                        wire signed [res_w-1:0] c2v_unshifted_val = c2v_new_unshifted[gi*res_w +: res_w];
              wire [res_w-1:0] c2v_sat_max_val = (1 << (res_w-1)) - 1;
              wire [res_w-1:0] c2v_sat_min_val = ~(c2v_sat_max_val);
            wire signed [res_w-1:0] c2v_new_sat = (c2v_unshifted_val > $signed(c2v_sat_max_val)) ? c2v_sat_max_val :
                                                  (c2v_unshifted_val < $signed(c2v_sat_min_val)) ? c2v_sat_min_val :
                                                  c2v_unshifted_val;
            assign c2v_new_unshifted_sat[gi*res_w +: res_w] = c2v_new_sat;
        end
    endgenerate

    integer i;
    reg all_layers_parity_ok;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            ir_fail_intr <= 1'b0; ir_success <= 1'b0; done <= 1'b0;
            current_code_rate <= 2'b00; iter_count <= 0;
            block_count <= 0; layer_count <= 0; col_count <= 0;
            calc_delay <= 0; valid_degree_count <= 0; write_degree_count <= 0;
            all_layers_parity_ok <= 1'b1;
            ldpc_res_out <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    block_count <= 0; layer_count <= 0; iter_count <= 0; col_count <= 0;
                    done <= 1'b0;
                    if (start) begin
                        ir_success <= 1'b0; ir_fail_intr <= 1'b0;
                        current_code_rate <= code_rate;
                    end
                end
                LOAD_LLR: begin
                    llr_we <= 1'b1; llr_addr_w <= block_count;
                    llr_din <= llr_in_array[block_count * Zc*data_w +: Zc*data_w];
                    block_count <= block_count + 1;
                    
                    if (block_count < 12) begin
                        c2v_we <= 1'b1; c2v_addr_w <= block_count; c2v_din <= 0;
                    end else begin
                        c2v_we <= 1'b0;
                    end
                end
                LAYER_READ: begin
                    if (layer_count == 0 && col_count == 0) all_layers_parity_ok <= 1'b1;
                    
                    llr_we <= 1'b0; c2v_we <= 1'b0;
                    if (col_count == 0) begin
                        for(i=0; i<D_cnu; i=i+1) q_in_buffer[i] <= {Zc{DUMMY_Q_IN}};
                        valid_degree_count <= 0;
                    end
                    if (col_count < 26) begin
                        if (col_count < 24) begin
                            llr_addr_r <= col_count; c2v_addr_r <= layer_count;
                        end
                        col_count <= col_count + 1;
                    end
                    if (valid_read_2 && valid_conn_d2) begin
                        q_in_buffer[valid_degree_count] <= shift_out;
                        valid_degree_count <= valid_degree_count + 1;
                    end
                    if (col_count == 26) col_count <= 0;
                end
                LAYER_CALC: begin
                    calc_delay <= calc_delay + 1;
                    if (calc_delay == 1) begin
                        if (|parity_vector) all_layers_parity_ok <= 1'b0;
                    end
                    if (calc_delay == 5) calc_delay <= 0;
                end
                LAYER_WRITE: begin
                    if (col_count == 0) begin
                        write_degree_count <= 0;
                        for(i=0; i<D_cnu; i=i+1) c2v_new_buffer[i] <= 0;
                    end
                    
                    llr_we <= 1'b0; c2v_we <= 1'b0;
                    if (col_count < 26) begin
                        if (col_count < 24) begin
                            llr_addr_r <= col_count;
                        end
                        col_count <= col_count + 1;
                    end
                    if (valid_read_2 && valid_conn_d2) begin
                        llr_we <= 1'b1;
                        llr_addr_w <= col_count_d2;
                        llr_din <= llr_din_math;
                        
                        c2v_new_buffer[write_degree_count] <= c2v_new_unshifted_sat;
                        write_degree_count <= write_degree_count + 1;
                    end
                    if (col_count == 26) begin
                        col_count <= 0;
                        c2v_we <= 1'b1;
                        c2v_addr_w <= layer_count;
                        c2v_din <= c2v_new_buffer_flat;
                        
                        layer_count <= layer_count + 1;
                        if (layer_count == max_layer) begin
                            layer_count <= 0;
                            iter_count <= iter_count + 1;
                        end
                    end
                end
                CHECK: begin
                    if (all_layers_parity_ok) ir_success <= 1'b1; else ir_fail_intr <= 1'b1;
                    block_count <= 0;
                    col_count <= 0;
                    llr_addr_r <= 0; // Pre-load RAM[0] so OUTPUT_RES has it ready
                end 
                WAIT_FOR_EXTENSION: begin
                    if (resume_decoding) begin
                        ir_fail_intr <= 1'b0; current_code_rate <= current_code_rate + 1; iter_count <= 0; 
                    end
                end
                OUTPUT_RES: begin
                    llr_we <= 1'b0;
                    // BRAM 1-cycle latency: CHECK pre-loaded addr_r=0
                    // block=0: BRAM outputs RAM[0], set addr_r=1 for next
                    // block=1: BRAM outputs RAM[1] (from addr=1), write res[0] from current dout=RAM[0]
                    // block=N: write res[(N-1)*Zc] from dout=RAM[N-1], set addr_r=N+1
                    if (block_count + 1 < 24) llr_addr_r <= block_count + 1;
                    
                    if (block_count > 0 && block_count <= 24) begin
                        for (i = 0; i < Zc; i = i + 1) ldpc_res_out[(block_count-1)*Zc + i] <= llr_dout[i*data_w + data_w - 1];
                    end
                    block_count <= block_count + 1;
                    if (block_count == 25) done <= 1'b1;
                end
            endcase
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD_LLR;
            LOAD_LLR: if (block_count == 23) next_state = LAYER_READ;
            LAYER_READ: if (col_count == 26) next_state = LAYER_CALC;
            LAYER_CALC: if (calc_delay == 5) next_state = LAYER_WRITE;
            LAYER_WRITE: begin
                if (col_count == 26) begin
                    if (layer_count == max_layer && (iter_count >= 100 || all_layers_parity_ok)) next_state = CHECK;
                    else next_state = LAYER_READ;
                end
            end
            CHECK: next_state = OUTPUT_RES; // ALWAYS force output for diagnostics!
            WAIT_FOR_EXTENSION: if (resume_decoding) next_state = EXTENSION_LOAD;
            EXTENSION_LOAD: next_state = LAYER_READ;
            OUTPUT_RES: if (block_count == 25) next_state = IDLE;
        endcase
    end
endmodule
