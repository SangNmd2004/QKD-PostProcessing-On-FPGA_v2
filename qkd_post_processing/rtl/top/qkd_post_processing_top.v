`timescale 1ns/1ps

module qkd_post_processing_top #(
    parameter LLR_W = 5,
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
    output wire ir_success,
    output wire pa_active
);

    // ==========================================
    // 1. LLR AXI-Stream to Parallel (Direct)
    // ==========================================
    wire [LLR_W*LDPC_BLOCK-1:0] ldpc_l_buffer;
    wire ldpc_start;
    reg ldpc_en;
    
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
        .p_ready_in(ldpc_en) // Báo hiệu LDPC đã đọc xong block
    );

    // ==========================================
    // 2b. Syndrome AXI-Stream to Parallel
    // ==========================================
    wire [1151:0] syndrome_buffer;
    wire syn_start;
    
    axis_to_parallel #(
        .DATA_W(8),
        .BLOCK_BITS(1152)
    ) u_axis_to_parallel_syn (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_syn_tdata),
        .s_axis_tvalid(s_axis_syn_tvalid),
        .s_axis_tready(s_axis_syn_tready),
        .s_axis_tlast(1'b0),
        
        .p_data_out(syndrome_buffer),
        .p_valid_out(syn_start),
        .p_ready_in(ldpc_en)
    );

    always @(posedge clk) begin
        if (rst) ldpc_en <= 0;
        else begin
            // Chỉ bắt đầu giải mã khi CẢ LLR và Syndrome đều đã được nạp đủ
            if (ldpc_start && syn_start && !ldpc_en) ldpc_en <= 1;
            else if (ir_success || ir_fail_intr) ldpc_en <= 0;
        end
    end

    // ==========================================
    // 3. MODULE: Information Reconciliation (Partially Parallel QC-LDPC)
    // ==========================================
    wire [LDPC_BLOCK-1:0] ldpc_res;
    wire ldpc_done;

    // Sử dụng kiến trúc tiết kiệm tài nguyên mới nhất hỗ trợ Blind Reconciliation
    core_partially_parallel #(
        .Zc(96),
        .data_w(LLR_W),
        .D_vnu(12),
        .D_cnu(8),
        .ext_w(3),
        .res_w(8),
        .shift_w(7)
    ) u_ldpc_core (
        .clk(clk),
        .rst(rst),
        .start(ldpc_en),
        .done(ldpc_done),
        .ir_success(ir_success),
        .ir_fail_intr(ir_fail_intr),
        .puncture_en(puncture_en),
        .resume_decoding(resume_decoding),
        .ldpc_res_out(ldpc_res)
    );

    // ==========================================
    // 4. Parallel to AXI-Stream (IR to PA)
    // ==========================================
    wire [63:0] axis_ir_to_pa_tdata;
    wire axis_ir_to_pa_tvalid;
    wire axis_ir_to_pa_tready;
    wire axis_ir_to_pa_tlast;

    parallel_to_axis #(
        .DATA_W(64),
        .BLOCK_BITS(LDPC_BLOCK)
    ) u_parallel_to_axis_ir (
        .clk(clk),
        .rst(rst),
        .p_data_in(ldpc_res),
        .p_valid_in(ir_success), // Khi giải mã thành công thì đẩy xuống FIFO
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
    
    pa_toeplitz_hash #(
        .KEY_LEN(4096),
        .HASH_LEN(256), // Production-ready 256-bit hash
        .NTT_N(4096),
        .DATA_W(17)
    ) pa_hash_core (
        .clk(clk),
        .rst(rst),
        .mem_addr(pa_mem_addr),
        .mem_dout(pa_mem_dout),
        .mem_en(pa_mem_en),
        .block_ready(pa_block_ready),
        
        .pa_hash_out(hash_parallel_out),
        .pa_hash_valid(hash_parallel_valid),
        .pa_active(pa_active)
    );

    // ==========================================
    // 8. MODULE: Hash Output Serializer (AXI-Stream)
    // ==========================================
    parallel_to_axis #(
        .DATA_W(PA_DATA_W), // 64-bit output stream
        .BLOCK_BITS(256)
    ) u_parallel_to_axis_hash (
        .clk(clk),
        .rst(rst),
        .p_data_in(hash_parallel_out),
        .p_valid_in(hash_parallel_valid),
        .p_ready_out(),
        
        .m_axis_tdata(m_axis_key_tdata),
        .m_axis_tvalid(m_axis_key_tvalid),
        .m_axis_tready(m_axis_key_tready),
        .m_axis_tlast(m_axis_key_tlast)
    );

    // ==========================================
    // 9. ERROR FEEDBACK
    // ==========================================
    // Chân tx_err_feedback cũ đã được nâng cấp thành ir_fail_intr (Hardware Interrupt)
    // phục vụ cho cơ chế HW/SW Co-design ở Giai đoạn 5.

endmodule
