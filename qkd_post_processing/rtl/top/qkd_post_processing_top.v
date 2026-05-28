`timescale 1ns/1ps

module qkd_post_processing_top #(
    parameter LLR_W = 5,
    parameter LDPC_BLOCK = 2304,
    parameter PA_DATA_W = 64, // AXI-Stream TDATA must be multiple of 8 bits
    parameter PA_RING_SIZE = 512
) (
    input wire clk,
    input wire rst,
    input wire [1:0] code_rate, // 00: 1/2, 01: 2/3, 10: 3/4, 11: 5/6
    
    // Giao tiếp AXI-Stream Input (Nhận Sifted Key / LLRs)
    input wire [LLR_W-1:0] s_axis_llr_tdata,
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
    
    // Trạng thái hệ thống
    output wire ir_success,
    output wire pa_active,
    output wire tx_err_feedback
);

    // ==========================================
    // 1. MODULE: LLR Input FIFO (AXI-Stream)
    // ==========================================
    wire [7:0] axis_llr_fifo_tdata;
    wire axis_llr_fifo_tvalid;
    wire axis_llr_fifo_tready;

    // Xilinx IP: axis_data_fifo (8-bit width)
    fifo_llr_in u_fifo_llr_in (
        .s_axis_aresetn(~rst),
        .s_axis_aclk(clk),
        .s_axis_tvalid(s_axis_llr_tvalid),
        .s_axis_tready(s_axis_llr_tready),
        .s_axis_tdata({3'b000, s_axis_llr_tdata}), // Pad to 8-bit
        
        .m_axis_tvalid(axis_llr_fifo_tvalid),
        .m_axis_tready(axis_llr_fifo_tready),
        .m_axis_tdata(axis_llr_fifo_tdata)
    );

    // ==========================================
    // 2. LLR AXI-Stream to Parallel
    // ==========================================
    wire [LLR_W*LDPC_BLOCK-1:0] ldpc_l_buffer;
    wire ldpc_start;
    reg ldpc_en;
    
    // Tích hợp LLR tuần tự thành 1 khối
    axis_to_parallel #(
        .DATA_W(LLR_W),
        .BLOCK_BITS(LLR_W * LDPC_BLOCK)
    ) u_axis_to_parallel_llr (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(axis_llr_fifo_tdata),
        .s_axis_tvalid(axis_llr_fifo_tvalid),
        .s_axis_tready(axis_llr_fifo_tready),
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
            else if (ldpc_term) ldpc_en <= 0;
        end
    end

    // ==========================================
    // 3. MODULE: Information Reconciliation (QC-LDPC)
    // ==========================================
    wire [LDPC_BLOCK-1:0] ldpc_res;
    wire ldpc_term;
    wire ldpc_err;
    wire [12*24*8-1:0] zero_mtx = 0;

    ldpc_core #(
        .data_w(LLR_W),
        .mtx_w(8),
        .R(24),
        .C(12),
        .D(96)
    ) ir_qc_ldpc (
        .en(ldpc_en),
        .clk(clk),
        .rst(rst),
        .l(ldpc_l_buffer),
        .mtx(zero_mtx),
        .syndrome(syndrome_buffer),
        .code_rate(code_rate),
        .res(ldpc_res),
        .term(ldpc_term),
        .err(ldpc_err)
    );
    
    assign ir_success = ldpc_term && !ldpc_err;

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
    // 5. Inter-module FIFO (AXI-Stream)
    // ==========================================
    wire [63:0] axis_pa_fifo_tdata;
    wire axis_pa_fifo_tvalid;
    wire axis_pa_fifo_tready;

    // Xilinx IP: axis_data_fifo (64-bit width)
    fifo_ir_to_pa u_fifo_ir_to_pa (
        .s_axis_aresetn(~rst),
        .s_axis_aclk(clk),
        .s_axis_tvalid(axis_ir_to_pa_tvalid),
        .s_axis_tready(axis_ir_to_pa_tready),
        .s_axis_tdata(axis_ir_to_pa_tdata),
        
        .m_axis_tvalid(axis_pa_fifo_tvalid),
        .m_axis_tready(axis_pa_fifo_tready),
        .m_axis_tdata(axis_pa_fifo_tdata)
    );

    // ==========================================
    // 6. MODULE: PA Ping-Pong BRAM Controller
    // ==========================================
    wire [$clog2(32768/64)-1:0] pa_mem_addr;
    wire [63:0] pa_mem_dout;
    wire pa_mem_en;
    wire pa_block_ready;

    pa_bram_ctrl #(
        .DATA_W(64),
        .BLOCK_SIZE(32768)
    ) u_pa_bram_ctrl (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(axis_pa_fifo_tdata),
        .s_axis_tvalid(axis_pa_fifo_tvalid),
        .s_axis_tready(axis_pa_fifo_tready),
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
        .KEY_LEN(32768),
        .HASH_LEN(256), // Production-ready 256-bit hash
        .NTT_N(32768),
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
    // Pulse tx_err_feedback if LDPC fails, notifying Tx to request re-transmission
    assign tx_err_feedback = ldpc_term & ldpc_err;

endmodule
