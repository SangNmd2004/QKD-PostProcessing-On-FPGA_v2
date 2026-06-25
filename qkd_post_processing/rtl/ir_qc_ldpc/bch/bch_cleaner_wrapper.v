`timescale 1ns / 1ps

module bch_cleaner_wrapper #(
    parameter DATA_W = 64
) (
    input  wire clk,
    input  wire rst,
    input  wire bypass_bch,
    
    // Interface from LDPC Output (Parallel to AXI-Stream converter output)
    input  wire [DATA_W-1:0] s_axis_ldpc_tdata,
    input  wire              s_axis_ldpc_tvalid,
    output wire              s_axis_ldpc_tready,
    input  wire              s_axis_ldpc_tlast,
    
    // Interface to System Output
    output wire [DATA_W-1:0] m_axis_out_tdata,
    output wire              m_axis_out_tvalid,
    input  wire              m_axis_out_tready,
    output wire              m_axis_out_tlast
);

    //========================================================
    // REED-SOLOMON IP CORE SIGNALS (PLACEHOLDER FOR VIVADO IP)
    //========================================================
    // When you generate the RS Decoder IP in Vivado, you will connect it here.
    wire [DATA_W-1:0] rs_tdata = 0;
    wire              rs_tvalid = 0;
    wire              rs_tready;
    wire              rs_tlast = 0;
    
    // Dummy tie-off for IP input side
    assign rs_tready = 1'b1; // Replace with actual IP tready

    // INSTANTIATE XILINX REED-SOLOMON IP HERE IN THE FUTURE
    rs_decoder_0 u_rs_decoder (
      .aclk(clk),                                    
      
      // Control Stream (Must provide Block Length = 176 for Shortened Code)
      .s_axis_ctrl_tvalid(1'b1),
      .s_axis_ctrl_tdata(8'd176), // 176 = 144 message + 32 parity bytes
      .s_axis_ctrl_tready(),
      
      // Data Input Stream
      .s_axis_input_tvalid(s_axis_ldpc_tvalid & ~bypass_bch),  
      .s_axis_input_tdata(s_axis_ldpc_tdata),    
      .s_axis_input_tready(rs_tready),
      .s_axis_input_tlast(s_axis_ldpc_tlast),
      
      // Data Output Stream
      .m_axis_output_tvalid(rs_tvalid),  
      .m_axis_output_tdata(rs_tdata),    
      .m_axis_output_tready(m_axis_out_tready),
      .m_axis_output_tlast(rs_tlast),
      
      // Status Stream (Errors corrected, decode fail, etc.)
      .m_axis_stat_tvalid(),
      .m_axis_stat_tdata(),
      .m_axis_stat_tready(1'b1)
    );

    //========================================================
    // BYPASS MULTIPLEXER LOGIC
    //========================================================
    // If bypass_bch == 1, we route LDPC directly to OUT.
    // If bypass_bch == 0, we route RS IP to OUT.
    
    assign m_axis_out_tdata  = bypass_bch ? s_axis_ldpc_tdata  : rs_tdata;
    assign m_axis_out_tvalid = bypass_bch ? s_axis_ldpc_tvalid : rs_tvalid;
    assign m_axis_out_tlast  = bypass_bch ? s_axis_ldpc_tlast  : rs_tlast;
    
    assign s_axis_ldpc_tready = bypass_bch ? m_axis_out_tready : rs_tready;

endmodule
