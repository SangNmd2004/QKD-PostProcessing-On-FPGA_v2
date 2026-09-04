`timescale 1ns/1ps

module qkd_post_processing_top #(
    parameter LLR_W = 6,
    parameter LDPC_BLOCK = 2304,
    parameter PA_DATA_W = 64, // AXI-Stream TDATA must be multiple of 8 bits
    parameter PA_RING_SIZE = 64
) (
    input wire clk,
    input wire rst,
    input wire [1:0] code_rate, // 00: 1/2, 01: 2/3, 10: 3/4, 11: 5/6
    
    // Giao tiếp AXI-Stream Input (Nhận Sifted Key / LLRs)
    input wire [7:0] s_axis_llr_tdata, // AXI-Stream TDATA must be multiple of 8 bits
    input wire s_axis_llr_tvalid,
    output wire s_axis_llr_tready,
    
    // Giao tiếp AXI-Stream Input (Nhận Syndrome từ Alice)
    input wire [7:0] s_axis_syn_tdata,
    input wire s_axis_syn_tvalid,
    output wire s_axis_syn_tready,
    
    // Giao tiếp AXI-Stream Output (Xuất Secret Key cuối cùng)
    output wire [PA_DATA_W-1:0] m_axis_key_tdata,
    output wire m_axis_key_tvalid,
    input wire m_axis_key_tready,
    output wire m_axis_key_tlast,
    
    // Giao tiếp Điều khiển Hardware/Software Co-design (PS-PL)
    output wire ir_fail_intr,    // Ngắt (Interrupt) báo hiệu giải mã thất bại (Blind Reconciliation)
    input  wire resume_decoding, // PS gửi lệnh yêu cầu tiếp tục giải mã sau khi nạp thêm Syndrome
    input  wire puncture_en,     // PS cấu hình mạch đục lỗ (Puncturing)
    
    // Trạng thái hệ thống
    input  wire hash_ok,
    input  wire hash_fail,
    output wire ir_success,
    output wire [5:0] ldpc_iters_out,
    output wire pa_active,
    output wire discard_flag
);

    // ==========================================
    // 1. LLR AXI-Stream to Parallel (Direct)
    // ==========================================
    wire [LLR_W*LDPC_BLOCK-1:0] ldpc_l_buffer;
    wire ldpc_start;
    reg ldpc_en;
    wire p_ready_sig;
    wire ldpc_core_fail;
    
    // Tích hợp LLR tuần tự thành 1 khối
    axis_to_parallel #(
        .DATA_W(LLR_W), // Trích xuất 5-bit LLR từ gói 8-bit
        .BLOCK_BITS(LLR_W * LDPC_BLOCK)
    ) u_axis_to_parallel_llr (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_llr_tdata[LLR_W-1:0]),
        .s_axis_tvalid(s_axis_llr_tvalid),
        .s_axis_tready(s_axis_llr_tready),
        .s_axis_tlast(1'b0),
        
        .p_data_out(ldpc_l_buffer),
        .p_valid_out(ldpc_start),
        .p_ready_in(p_ready_sig) // Báo hiệu LDPC đã đọc xong block (hoặc bị discard)
    );

    // ==========================================
    // 2b. Syndrome AXI-Stream to Parallel
    // ==========================================
    wire [2303:0] syndrome_buffer_full;
    wire [1151:0] syndrome_buffer = syndrome_buffer_full[1151:0];      // 144 byte đầu tiên: Alice Syndrome
    wire [1151:0] err_syndrome_buffer = syndrome_buffer_full[2303:1152]; // 144 byte tiếp theo: Error Syndrome
    wire syn_start_raw;
    
    axis_to_parallel #(
        .DATA_W(8),
        .BLOCK_BITS(2304) // Nhận 144 byte Alice Syndrome + 144 byte Error Syndrome
    ) u_axis_to_parallel_syn (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_syn_tdata),
        .s_axis_tvalid(s_axis_syn_tvalid),
        .s_axis_tready(s_axis_syn_tready),
        .s_axis_tlast(1'b0),
        
        .p_data_out(syndrome_buffer_full),
        .p_valid_out(syn_start_raw),
        .p_ready_in(p_ready_sig)
    );

    // Pipeline delay to wait for SHW calculation (takes ~4 cycles)
    reg [4:0] syn_start_delay_reg;
    always @(posedge clk) begin
        if (rst) syn_start_delay_reg <= 0;
        else syn_start_delay_reg <= {syn_start_delay_reg[3:0], syn_start_raw};
    end
    wire syn_start = syn_start_delay_reg[4];

    reg buffer_release_pulse;
    always @(posedge clk) begin
        if (rst) begin
            ldpc_en <= 0;
            buffer_release_pulse <= 0;
        end else begin
            buffer_release_pulse <= 0; // Mặc định xóa pulse
            
            // Chỉ bắt đầu giải mã khi CẢ LLR và Syndrome đều đã được nạp đủ (đã chờ SHW ổn định)
            if (ldpc_start && syn_start && !ldpc_en && !buffer_release_pulse) begin
                if (discard_flag)
                    buffer_release_pulse <= 1; // Kích hoạt pulse vứt bỏ rác, giải phóng buffer, cắt điện LDPC
                else
                    ldpc_en <= 1; // Bật nguồn khối LDPC
            end
            else if (resume_decoding) ldpc_en <= 1; // Kích hoạt p_ready_in để giải phóng buffer Syndrome cũ
            else if (ir_success || ldpc_core_fail) ldpc_en <= 0;
        end
    end

    assign p_ready_sig = ldpc_en | buffer_release_pulse;

    // ==========================================
    // 3. MODULE: Information Reconciliation (Partially Parallel QC-LDPC)
    // ==========================================
    wire [LDPC_BLOCK-1:0] ldpc_res;
    wire ldpc_done;
    wire [5:0] ldpc_iters_core;
    
    // Latch iter_count to preserve it when core goes to IDLE
    reg [5:0] final_iter_count;
    always @(posedge clk) begin
        if (rst) final_iter_count <= 0;
        else if (ldpc_done || ldpc_core_fail) final_iter_count <= ldpc_iters_core;
        else if (buffer_release_pulse) final_iter_count <= 0; // Discard = 0 iters
    end
    assign ldpc_iters_out = final_iter_count;

    wire [12*LDPC_BLOCK-1:0] ldpc_l_buffer_ext;
    genvar gi_llr;
    generate
        // Split the generate loop into two to bypass Gowin EDA's 2000 loop iteration limit
        for(gi_llr=0; gi_llr<1200; gi_llr=gi_llr+1) begin : gen_llr_ext_0
            wire [LLR_W-1:0] val = ldpc_l_buffer[gi_llr*LLR_W +: LLR_W];
            assign ldpc_l_buffer_ext[gi_llr*12 +: 12] = {{ (12-LLR_W){val[LLR_W-1]} }, val};
        end
        for(gi_llr=1200; gi_llr<LDPC_BLOCK; gi_llr=gi_llr+1) begin : gen_llr_ext_1
            wire [LLR_W-1:0] val = ldpc_l_buffer[gi_llr*LLR_W +: LLR_W];
            assign ldpc_l_buffer_ext[gi_llr*12 +: 12] = {{ (12-LLR_W){val[LLR_W-1]} }, val};
        end
    endgenerate
    // ==========================================
    // Predictive Controller (Hardware Algorithm Co-Design)
    // ==========================================
    wire [10:0] shw_val;
    wire [1:0] opt_rate;
    wire [7:0] iter_max;

    syndrome_weight_counter u_adder_tree (
        .clk(clk),
        .rst_n(~rst),
        .syn_in(err_syndrome_buffer), // Tính trọng số dựa trên Error Syndrome thay vì Alice Syndrome
        .shw_out(shw_val)
    );

    statistical_controller u_controller (
        .clk(clk),
        .rst_n(~rst),
        .shw_in(shw_val),
        .opt_rate(opt_rate),
        .iter_max(iter_max),
        .discard_flag(discard_flag)
    );

    assign ir_fail_intr = ldpc_core_fail | buffer_release_pulse;

    // Sử dụng kiến trúc tối ưu cho Gowin 138K Pro (Siêu phân giải)
    core_partially_parallel #(
        .Zc(96),
        .data_w(12), // LLR 12-bit
        .D_vnu(12),
        .D_cnu(15), 
        .ext_w(2),   // V2C width = res_w (12) + ext_w (2) = 14 bits
        .res_w(12),  // C2V 12-bit
        .shift_w(7)
    ) u_ldpc_core (
        .clk(clk),
        .rst(rst),
        .start(ldpc_en), // Nếu discard_flag = 1, ldpc_en = 0 -> LDPC hoàn toàn ngủ yên
        .iter_max_in(iter_max), // Sử dụng Predictive Controller
        .code_rate(opt_rate),   // Dùng hoàn toàn thuật toán dự đoán thay vì AXI
        .llr_in_array(ldpc_l_buffer_ext),
        .syn_in(syndrome_buffer),
        .done(ldpc_done),
        .ir_success(ir_success),
        .ir_fail_intr(ldpc_core_fail),
        .iter_out(ldpc_iters_core),
        .puncture_en(puncture_en),
        .resume_decoding(resume_decoding),
        .hash_ok(1'b1), // Bỏ qua pha Hash vì khối PA đang tạm tắt
        .hash_fail(1'b0),
        .ldpc_res_out(ldpc_res)
    );

    // ==========================================
    // 4. Parallel to AXI-Stream (IR to PA)
    // ==========================================
    wire [63:0] axis_ir_to_pa_tdata;
    wire axis_ir_to_pa_tvalid;
    wire axis_ir_to_pa_tready;
    wire axis_ir_to_pa_tlast;

    /* --- DISABLED PA MODULES TO SAVE RESOURCES ---
    parallel_to_axis #(
        .DATA_W(64),
        .BLOCK_BITS(4096) // Zero-pad from 2304 to 4096 to satisfy NTT Core's power-of-2 requirement
    ) u_parallel_to_axis_ir (
        .clk(clk),
        .rst(rst),
        .p_data_in(ldpc_res),
        .p_valid_in(ldpc_done), // Bắt buộc phải dùng ldpc_done vì lúc này ldpc_res mới chứa codeword hợp lệ
        .p_ready_out(),
        
        .m_axis_tdata(axis_ir_to_pa_tdata),
        .m_axis_tvalid(axis_ir_to_pa_tvalid),
        .m_axis_tready(axis_ir_to_pa_tready),
        .m_axis_tlast(axis_ir_to_pa_tlast)
    );

    // ==========================================
    // 5. MODULE: PA Ping-Pong BRAM Controller (Direct)
    // ==========================================
    wire [$clog2(32768/64)-1:0] pa_mem_addr;
    wire [63:0] pa_mem_dout;
    wire pa_mem_en;
    wire pa_block_ready;

    pa_bram_ctrl #(
        .DATA_W(64),
        .BLOCK_SIZE(4096)
    ) u_pa_bram_ctrl (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(axis_ir_to_pa_tdata),
        .s_axis_tvalid(axis_ir_to_pa_tvalid),
        .s_axis_tready(axis_ir_to_pa_tready),
        .mem_addr(pa_mem_addr),
        .mem_dout(pa_mem_dout),
        .mem_en(pa_mem_en),
        .block_ready(pa_block_ready)
    );

    // ==========================================
    // 7. MODULE: Privacy Amplification (NTT-Toeplitz)
    // ==========================================
    wire [255:0] hash_parallel_out;
    wire hash_parallel_valid;
    
    // pa_toeplitz_hash #(
    //     .KEY_LEN(4096),
    //     .HASH_LEN(256), // Production-ready 256-bit hash
    //     .NTT_N(4096),
    //     .DATA_W(17)
    // ) pa_hash_core (
    //     .clk(clk),
    //     .rst(rst),
    //     .mem_addr(pa_mem_addr),
    //     .mem_dout(pa_mem_dout),
    //     .mem_en(pa_mem_en),
    //     .block_ready(pa_block_ready),
    //     
    //     .pa_hash_out(hash_parallel_out),
    //     .pa_hash_valid(hash_parallel_valid),
    //     .pa_active(pa_active)
    // );
    
    assign pa_active = 1'b0; // Driven to 0 since PA is disabled
    --- END DISABLED PA MODULES --- */


    // ==========================================
    // 8. MODULE: LDPC Output Serializer (AXI-Stream) - NO PA
    // ==========================================
    wire [PA_DATA_W-1:0] axis_ldpc_to_bch_tdata;
    wire                 axis_ldpc_to_bch_tvalid;
    wire                 axis_ldpc_to_bch_tready;
    wire                 axis_ldpc_to_bch_tlast;

    parallel_to_axis #(
        .DATA_W(PA_DATA_W), // 64-bit output stream
        .BLOCK_BITS(2304)   // Xuất trọn vẹn Codeword 2304 bits (288 Bytes)
    ) u_parallel_to_axis_ldpc (
        .clk(clk),
        .rst(rst),
        .p_data_in(ldpc_res),   // Bypass PA: Trỏ thẳng vào kết quả của LDPC
        .p_valid_in(ldpc_done), // Bypass PA: Kích hoạt ngay khi LDPC xong
        .p_ready_out(),
        
        .m_axis_tdata(axis_ldpc_to_bch_tdata),
        .m_axis_tvalid(axis_ldpc_to_bch_tvalid),
        .m_axis_tready(axis_ldpc_to_bch_tready),
        .m_axis_tlast(axis_ldpc_to_bch_tlast)
    );

    // ==========================================
    // 9. MODULE: BCH Cleaner Wrapper (Bypassable)
    // ==========================================
    // BYPASS = 0: Active Mode. Data flows through the RS Decoder.
    // If you need to disable RS later, change to 1'b1.
    wire bypass_bch = 1'b1;

    bch_cleaner_wrapper #(
        .DATA_W(PA_DATA_W)
    ) u_bch_cleaner_wrapper (
        .clk(clk),
        .rst(rst),
        .bypass_bch(bypass_bch),
        
        .s_axis_ldpc_tdata(axis_ldpc_to_bch_tdata),
        .s_axis_ldpc_tvalid(axis_ldpc_to_bch_tvalid),
        .s_axis_ldpc_tready(axis_ldpc_to_bch_tready),
        .s_axis_ldpc_tlast(axis_ldpc_to_bch_tlast),
        
        .m_axis_out_tdata(m_axis_key_tdata),
        .m_axis_out_tvalid(m_axis_key_tvalid),
        .m_axis_out_tready(m_axis_key_tready),
        .m_axis_out_tlast(m_axis_key_tlast)
    );

    // ==========================================
    // 9. ERROR FEEDBACK
    // ==========================================
    // Chân tx_err_feedback cũ đã được nâng cấp thành ir_fail_intr (Hardware Interrupt)
    // phục vụ cho cơ chế HW/SW Co-design ở Giai đoạn 5.

endmodule
