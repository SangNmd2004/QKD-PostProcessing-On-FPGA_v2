`timescale 1ns / 1ps

module ldpc_axi_wrapper (
    // Clock and Reset
    input wire s_axi_aclk,
    input wire s_axi_aresetn,

    // AXI4-Lite Slave Interface for Control/Status
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // AXI-Stream for Data Payload (Connected to Gowin DMA)
    input  wire [7:0]  s_axis_llr_tdata,
    input  wire        s_axis_llr_tvalid,
    output wire        s_axis_llr_tready,

    input  wire [7:0]  s_axis_syn_tdata,
    input  wire        s_axis_syn_tvalid,
    output wire        s_axis_syn_tready,

    output wire [63:0] m_axis_key_tdata,
    output wire        m_axis_key_tvalid,
    input  wire        m_axis_key_tready,
    output wire        m_axis_key_tlast,
    
    // Interrupts to AE350 PLIC
    output wire        ldpc_ir_success_intr,
    output wire        ldpc_ir_fail_intr
);

    // ==========================================
    // AXI4-Lite Slave Registers
    // ==========================================
    // Register Map:
    // 0x00: CTRL_REG  (W/R)
    //       [1:0] code_rate
    //       [2]   resume_decoding (Pulse)
    //       [3]   hash_ok (Pulse)
    //       [4]   hash_fail (Pulse)
    //       [5]   puncture_en
    // 0x04: STAT_REG  (R)
    //       [0]   ir_success
    //       [1]   ir_fail_intr
    //       [15:8] ldpc_iters_out
    
    reg [31:0] ctrl_reg;
    wire [31:0] stat_reg;

    // AXI4-Lite Write Logic
    assign s_axi_awready = s_axi_awvalid && s_axi_wvalid;
    assign s_axi_wready  = s_axi_awvalid && s_axi_wvalid;
    assign s_axi_bresp   = 2'b00; // OKAY
    assign s_axi_bvalid  = s_axi_awvalid && s_axi_wvalid;

    // Auto-clear pulse signals
    reg pulse_resume;
    reg pulse_hash_ok;
    reg pulse_hash_fail;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            ctrl_reg <= 32'h00000002; // Default to Rate 3/4
            pulse_resume <= 0;
            pulse_hash_ok <= 0;
            pulse_hash_fail <= 0;
        end else begin
            // Default pulse clear
            pulse_resume <= 0;
            pulse_hash_ok <= 0;
            pulse_hash_fail <= 0;
            
            if (s_axi_wready) begin
                case (s_axi_awaddr[7:0])
                    8'h00: begin
                        ctrl_reg[1:0] <= s_axi_wdata[1:0]; // code_rate
                        ctrl_reg[5]   <= s_axi_wdata[5];   // puncture_en
                        
                        // Extract Pulses
                        if (s_axi_wdata[2]) pulse_resume <= 1'b1;
                        if (s_axi_wdata[3]) pulse_hash_ok <= 1'b1;
                        if (s_axi_wdata[4]) pulse_hash_fail <= 1'b1;
                    end
                endcase
            end
        end
    end

    // AXI4-Lite Read Logic
    reg [31:0] rdata_reg;
    reg rvalid_reg;
    assign s_axi_arready = 1'b1;
    assign s_axi_rdata   = rdata_reg;
    assign s_axi_rresp   = 2'b00; // OKAY
    assign s_axi_rvalid  = rvalid_reg;

    wire ir_success;
    wire ir_fail_intr;
    wire [7:0] ldpc_iters_out;
    
    assign stat_reg = {16'b0, ldpc_iters_out, 6'b0, ir_fail_intr, ir_success};
    
    assign ldpc_ir_success_intr = ir_success;
    assign ldpc_ir_fail_intr    = ir_fail_intr;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            rvalid_reg <= 1'b0;
            rdata_reg <= 32'd0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                rvalid_reg <= 1'b1;
                case (s_axi_araddr[7:0])
                    8'h00: rdata_reg <= ctrl_reg;
                    8'h04: rdata_reg <= stat_reg;
                    default: rdata_reg <= 32'hDEADBEEF;
                endcase
            end else if (s_axi_rready) begin
                rvalid_reg <= 1'b0;
            end
        end
    end

    // ==========================================
    // LDPC Core Instantiation
    // ==========================================
    qkd_post_processing_top u_ldpc_top (
        .clk(s_axi_aclk),
        .rst(~s_axi_aresetn),
        
        .code_rate(ctrl_reg[1:0]),
        .resume_decoding(pulse_resume),
        .hash_ok(pulse_hash_ok),
        .hash_fail(pulse_hash_fail),
        .puncture_en(ctrl_reg[5]),
        
        .ir_success(ir_success),
        .ir_fail_intr(ir_fail_intr),
        .ldpc_iters_out(ldpc_iters_out),
        
        // DMA AXI-Stream Ports
        .s_axis_llr_tdata(s_axis_llr_tdata),
        .s_axis_llr_tvalid(s_axis_llr_tvalid),
        .s_axis_llr_tready(s_axis_llr_tready),
        
        .s_axis_syn_tdata(s_axis_syn_tdata),
        .s_axis_syn_tvalid(s_axis_syn_tvalid),
        .s_axis_syn_tready(s_axis_syn_tready),
        
        .m_axis_key_tdata(m_axis_key_tdata),
        .m_axis_key_tvalid(m_axis_key_tvalid),
        .m_axis_key_tready(m_axis_key_tready),
        .m_axis_key_tlast(m_axis_key_tlast)
    );

endmodule
