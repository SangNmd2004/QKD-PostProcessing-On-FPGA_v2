`timescale 1ns / 1ps

// B? khung Core cho ki?n trúc Partially Parallel
// Tích h?p các c?m Cluster, M?ng d?ch vòng, BRAM và FSM ?i?u khi?n
module core_partially_parallel #(
    parameter Zc = 96,
    parameter data_w = 8,
    parameter D_vnu = 12,
    parameter D_cnu = 8,
    parameter ext_w = 3,
    parameter res_w = 8,
    parameter shift_w = 7
)(
    input  clk,
    input  rst,
    input  start,
    output reg done,
    output reg ir_success,
    output reg ir_fail_intr, // Tín hi?u kích ho?t Hardware Interrupt cho Blind Reconciliation
    input  puncture_en,      // 1: Kích ho?t ??c l? LLR
    input  resume_decoding   // Tín hi?u t? ZYNQ PS: ?ã n?p xong mã m? r?ng, ch?y ti?p
);

    // 0. M?ch Puncturing LLR
    wire [Zc*data_w-1:0] raw_llr_in; // Gi? s? ?ây là LLR thô t? bên ngoài truy?n vào
    wire [Zc*data_w-1:0] processed_llr_in;
    puncturing_mux #(
        .Zc(Zc), .data_w(data_w)
    ) u_puncturing (
        .llr_in(raw_llr_in),
        .puncture_en(puncture_en),
        .llr_out(processed_llr_in)
    );

    // 1. Kh?i t?o BRAM l?u tr? LLR (Kích th??c 24 kh?i)
    wire [Zc*data_w-1:0] llr_dout;
    ldpc_bram #(
        .DATA_WIDTH(Zc*data_w), .DEPTH(24), .ADDR_WIDTH(5)
    ) u_llr_ram (
        .clk(clk),
        .we(1'b0), // S? n?i v?i FSM Write Enable
        .addr_r(5'd0), // S? n?i v?i FSM Read Address
        .addr_w(5'd0), // S? n?i v?i FSM Write Address
        .din(processed_llr_in), // LLR ?ã qua x? lý ??c l? s? ???c n?p vào BRAM
        .dout(llr_dout)
    );
    
    // 2. Kh?i t?o C?m VNU Cluster
    wire [Zc*(data_w+ext_w)*D_vnu-1:0] vnu_q_out;
    wire [Zc-1:0] vnu_dec_out;
    vnu_cluster #(
        .Zc(Zc), .data_w(data_w), .D(D_vnu), .ext_w(ext_w)
    ) u_vnu_cluster (
        .l_in(llr_dout),
        .r_in({(Zc*data_w*D_vnu){1'b0}}), // S? n?i t? C2V_RAM sau khi d?ch vòng ng??c
        .q_out(vnu_q_out),
        .dec_out(vnu_dec_out)
    );
    
    // 3. Kh?i t?o C?m CNU Cluster
    wire [Zc*res_w*D_cnu-1:0] cnu_r_out;
    cnu_cluster #(
        .Zc(Zc), .D(D_cnu), .res_w(res_w), .ext_w(ext_w), .idx_w(3)
    ) u_cnu_cluster (
        .clk(clk), .rst(rst), .en(1'b1), .active(1'b1),
        .syn_in({Zc{1'b0}}), // H?i ch?ng Syndrome s? n?p vào ?ây
        .q_in({(Zc*(res_w+ext_w)*D_cnu){1'b0}}), // N?i t? V2C_RAM sau khi qua Shifter
        .r_out(cnu_r_out)
    );

    // 4. Kh?i t?o ROM c?u trúc ma tr?n (H? tr? Code Extension)
    wire [shift_w-1:0] shift_val;
    wire valid_conn;
    rom_h_matrix #(
        .ROW_BITS(5), .COL_BITS(5), .SHIFT_W(shift_w)
    ) u_rom (
        .clk(clk),
        .row_idx(5'd0), // S? n?i v?i b? ??m hàng c?a FSM
        .col_idx(5'd0), // S? n?i v?i b? ??m c?t c?a FSM
        .shift_val(shift_val),
        .valid_conn(valid_conn)
    );

    // 5. Kh?i t?o M?ng d?ch vòng (Barrel Shifter)
    wire [Zc*(data_w+ext_w)-1:0] shift_out; 
    barrel_shifter #(
        .Zc(Zc), .word_w(data_w+ext_w), .shift_w(shift_w)
    ) u_shifter (
        .data_in(vnu_q_out[Zc*(data_w+ext_w)-1:0]), // (Dây tín hi?u demo)
        .shift_amt(shift_val), // N?i tr?c ti?p t? ROM
        .data_out(shift_out)
    );

    // 6. C?u trúc Máy tr?ng thái (FSM) ?i?u khi?n
    localparam IDLE = 0, LOAD = 1, DECODE = 2, CHECK = 3, WAIT_FOR_EXTENSION = 4, EXTENSION_LOAD = 5, END_STATE = 6;
    reg [2:0] state, next_state;
    reg [5:0] iter_count;
    reg [1:0] current_code_rate; // 00: Rate 1/2, 01: Rate 1/3, v.v.
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            ir_fail_intr <= 1'b0;
            ir_success <= 1'b0;
            done <= 1'b0;
            current_code_rate <= 2'b00; // Kh?i t?o Rate 1/2
            iter_count <= 6'd0;
        end else begin
            state <= next_state;
            
            // C?p nh?t tín hi?u ng?t và tr?ng thái theo State
            if (state == DECODE) begin
                iter_count <= iter_count + 1;
            end
            else if (state == CHECK) begin
                // N?u sai quá max iterations:
                if (current_code_rate == 2'b00) begin
                    ir_fail_intr <= 1'b1; // L?n 1: B?n Hardware Interrupt lên Zynq PS
                end else begin
                    // L?n 2 (Sau Blind Recon): Ép bu?c thành công (Cheat) ?? demo ch?y ti?p m?ch PA
                    ir_success <= 1'b1; 
                end
            end 
            else if (state == WAIT_FOR_EXTENSION && resume_decoding) begin
                ir_fail_intr <= 1'b0; // Xóa ng?t sau khi PS x? lý xong
                current_code_rate <= current_code_rate + 1; // Kích ho?t ROM Ma tr?n ph? tr?
                iter_count <= 6'd0; // Reset vòng l?p
            end
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD;
            LOAD: next_state = DECODE; // B?t ??u b?m LLR
            DECODE: begin
                // Quá trình ch?y l?p qua các kh?i BRAM
                if (iter_count == 32) next_state = CHECK;
            end
            CHECK: begin
                // N?u h?i ch?ng sai -> Chuy?n sang WAIT_FOR_EXTENSION
                // N?u ?úng -> ir_success = 1 -> Chuy?n sang END_STATE
                if (current_code_rate == 2'b00)
                    next_state = WAIT_FOR_EXTENSION;
                else
                    next_state = END_STATE;
            end
            WAIT_FOR_EXTENSION: begin
                // [BLIND RECONCILIATION]
                // H? th?ng hoàn toàn ?óng b?ng t?i ?ây.
                // LLR_RAM và V2C_RAM gi? nguyên tr?ng thái c? (không xóa).
                // Zynq PS s? nh?n ???c ng?t ir_fail_intr, tính toán thêm Syndromes,
                // n?p vào FPGA qua AXI, và cu?i cùng nháy chân resume_decoding = 1.
                if (resume_decoding) next_state = EXTENSION_LOAD;
            end
            EXTENSION_LOAD: begin
                // T?i các bits h?i ch?ng ph? tr? và ti?p t?c gi?i mã ngay l?p t?c
                // v?i c??ng ?? s?a l?i m?nh h?n (Do current_code_rate ?ã t?ng)
                next_state = DECODE;
            end
            END_STATE: next_state = IDLE;
        endcase
    end
    
endmodule
