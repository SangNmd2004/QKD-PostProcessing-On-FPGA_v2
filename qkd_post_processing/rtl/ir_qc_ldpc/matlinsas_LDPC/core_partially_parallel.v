`timescale 1ns / 1ps

module core_partially_parallel #(
    parameter Zc = 96,
    parameter data_w = 5,
    parameter D_vnu = 6, 
    parameter D_cnu = 8, 
    parameter ext_w = 1,
    parameter res_w = 8,
    parameter shift_w = 7
)(
    input  clk,
    input  rst,
    input  start,
    input  [Zc*data_w*24-1:0] llr_in_array,
    output reg done,
    output reg ir_success,
    output reg ir_fail_intr, 
    input  puncture_en,      
    input  resume_decoding,   
    output reg [Zc*24-1:0] ldpc_res_out 
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
    reg [5:0] iter_count;
    reg [4:0] block_count, col_count;
    reg [3:0] layer_count; 
    reg [1:0] current_code_rate; 
    reg [4:0] calc_delay;

    wire [4:0] rom_row = layer_count;
    wire [4:0] rom_col = col_count;
    
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
    reg valid_conn_d1, valid_conn_d2;
    reg [shift_w-1:0] shift_val_d1, shift_val_d2;
    
    wire [Zc*res_w*D_cnu-1:0] cnu_r_out;
    cnu_cluster #(.Zc(Zc), .D(D_cnu), .res_w(res_w), .ext_w(ext_w), .idx_w(3)) u_cnu_cluster (
        .clk(clk), .rst(rst), .en(1'b1), .active(1'b1),
        .syn_in({Zc{1'b0}}), 
        .q_in(q_in_buffer_flat), 
        .r_out(cnu_r_out)
    );

    wire [shift_w-1:0] shift_val;
    wire valid_conn;
    rom_h_matrix #(.ROW_BITS(5), .COL_BITS(5), .SHIFT_W(shift_w)) u_rom (
        .clk(clk), .row_idx(rom_row), .col_idx(rom_col), .shift_val(shift_val), .valid_conn(valid_conn)
    );

    wire [shift_w-1:0] inv_shift_amt = (shift_val == 0) ? 0 : (Zc - shift_val);
    wire [shift_w-1:0] current_shift_amt = (state == LAYER_WRITE) ? inv_shift_amt : shift_val;
    
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
        .data_in(c2v_new_shifted), .shift_amt(inv_shift_amt), .data_out(c2v_new_unshifted)
    );

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
        for(gi = 0; gi < Zc; gi = gi + 1) begin : gen_math
            wire signed [data_w-1:0] llr_val = llr_dout[gi*data_w +: data_w];
            wire signed [res_w+ext_w-1:0] llr_ext = {{ (res_w+ext_w-data_w){llr_val[data_w-1]} }, llr_val};
            wire signed [res_w-1:0] c2v_val = c2v_old[gi*res_w +: res_w];
            wire signed [res_w+ext_w-1:0] v2c_val = llr_ext - c2v_val;
            assign v2c_array[gi*(res_w+ext_w) +: (res_w+ext_w)] = v2c_val;
            
            wire signed [res_w+ext_w-1:0] v2c_old_shifted = v2c_old_shifted_block[gi*(res_w+ext_w) +: (res_w+ext_w)];
            wire signed [res_w-1:0] c2v_new_val = c2v_new_shifted[gi*res_w +: res_w];
            wire signed [res_w+ext_w-1:0] llr_new_shifted = v2c_old_shifted + c2v_new_val;
            assign llr_new_shifted_array[gi*(res_w+ext_w) +: (res_w+ext_w)] = llr_new_shifted;
            
            wire signed [res_w+ext_w-1:0] llr_new_unshifted = shift_out[gi*(res_w+ext_w) +: (res_w+ext_w)];
            wire [res_w-1:0] sat_max = (1 << (data_w-1)) - 1;
            wire [res_w-1:0] sat_min = ~(sat_max);
            wire signed [data_w-1:0] llr_new_sat = (llr_new_unshifted > $signed(sat_max)) ? sat_max[data_w-1:0] :
                                                   (llr_new_unshifted < $signed(sat_min)) ? sat_min[data_w-1:0] :
                                                   llr_new_unshifted[data_w-1:0];
            assign llr_din_math[gi*data_w +: data_w] = llr_new_sat;
        end
    endgenerate

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            ir_fail_intr <= 1'b0; ir_success <= 1'b0; done <= 1'b0;
            current_code_rate <= 2'b00; iter_count <= 0;
            block_count <= 0; layer_count <= 0; col_count <= 0;
            calc_delay <= 0; valid_degree_count <= 0; write_degree_count <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    block_count <= 0; layer_count <= 0; iter_count <= 0; col_count <= 0;
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
                    llr_we <= 1'b0; c2v_we <= 1'b0;
                    if (col_count == 0) begin
                        for(i=0; i<D_cnu; i=i+1) q_in_buffer[i] <= {Zc{9'h0FF}};
                        valid_degree_count <= 0;
                    end
                    if (col_count < 26) begin
                        if (col_count < 24) begin
                            llr_addr_r <= col_count; c2v_addr_r <= layer_count;
                        end
                        col_count <= col_count + 1;
                    end
                    if (valid_conn && col_count_d1 < 24) begin
                        q_in_buffer[valid_degree_count] <= shift_out;
                        valid_degree_count <= valid_degree_count + 1;
                    end
                    if (col_count == 26) col_count <= 0;
                end
                LAYER_CALC: begin
                    calc_delay <= calc_delay + 1;
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
                    if (valid_conn && col_count_d1 < 24) begin
                        llr_we <= 1'b1;
                        llr_addr_w <= col_count_d1;
                        llr_din <= llr_din_math;
                        
                        c2v_new_buffer[write_degree_count] <= c2v_new_unshifted;
                        write_degree_count <= write_degree_count + 1;
                    end
                    if (col_count == 26) begin
                        col_count <= 0;
                        c2v_we <= 1'b1;
                        c2v_addr_w <= layer_count;
                        c2v_din <= c2v_new_buffer_flat;
                        
                        layer_count <= layer_count + 1;
                        if (layer_count == 11) begin
                            layer_count <= 0;
                            iter_count <= iter_count + 1;
                        end
                    end
                end
                CHECK: begin
                    if (current_code_rate == 2'b00) ir_fail_intr <= 1'b1; else ir_success <= 1'b1;
                end 
                WAIT_FOR_EXTENSION: begin
                    if (resume_decoding) begin
                        ir_fail_intr <= 1'b0; current_code_rate <= current_code_rate + 1; iter_count <= 0; 
                    end
                end
                OUTPUT_RES: begin
                    llr_we <= 1'b0; llr_addr_r <= block_count;
                    if (block_count > 0) begin
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
                    if (layer_count == 11 && iter_count == 32) next_state = CHECK;
                    else next_state = LAYER_READ;
                end
            end
            CHECK: if (current_code_rate == 2'b00) next_state = WAIT_FOR_EXTENSION; else next_state = OUTPUT_RES; 
            WAIT_FOR_EXTENSION: if (resume_decoding) next_state = EXTENSION_LOAD;
            EXTENSION_LOAD: next_state = LAYER_READ;
            OUTPUT_RES: if (block_count == 25) next_state = IDLE;
        endcase
    end
endmodule
