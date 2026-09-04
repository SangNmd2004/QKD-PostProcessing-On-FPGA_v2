`timescale 1ns / 1ps

module bch_cleaner_wrapper #(
    parameter DATA_W = 64
) (
    input  wire clk,
    input  wire rst,
    input  wire bypass_bch,
    
    // Interface from LDPC Output
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
    // RS DECODER SIGNALS
    //========================================================
    wire       rs_in_ready;
    reg        rs_start_codeword;
    reg        rs_end_codeword;
    reg        rs_valid_in;
    reg  [7:0] rs_symbol_in;
    wire       rs_consume = 1'b1; // Always consume for now
    
    wire       rs_out_start;
    wire       rs_out_end;
    wire       rs_out_valid;
    wire       rs_out_error;
    wire [7:0] rs_out_symbol;
    
    // Instantiate Open-Source VHDL RS Decoder
    // Generics are hardcoded in VHDL to N=144, K=112
    rs_decoder u_rs_decoder (
        .clk(clk),
        .rst(rst),
        .i_end_codeword(rs_end_codeword),
        .i_start_codeword(rs_start_codeword),
        .i_valid(rs_valid_in),
        .i_consume(rs_consume),
        .i_symbol(rs_symbol_in),
        .o_in_ready(rs_in_ready),
        .o_end_codeword(rs_out_end),
        .o_start_codeword(rs_out_start),
        .o_valid(rs_out_valid),
        .o_error(rs_out_error),
        .o_symbol(rs_out_symbol)
    );

    //========================================================
    // DESERIALIZER (64-bit to 8-bit)
    //========================================================
    reg [2:0] byte_idx;
    reg [DATA_W-1:0] current_word;
    reg [8:0] symbol_count; // 0 to 287 (288 bytes total from LDPC)
    
    localparam STATE_IDLE = 0, STATE_PUSH = 1;
    reg state_in;
    
    assign s_axis_ldpc_tready = (state_in == STATE_IDLE) && !bypass_bch;
    
    always @(posedge clk) begin
        if (rst) begin
            state_in <= STATE_IDLE;
            byte_idx <= 0;
            symbol_count <= 0;
            rs_valid_in <= 0;
            rs_start_codeword <= 0;
            rs_end_codeword <= 0;
        end else begin
            rs_valid_in <= 0;
            rs_start_codeword <= 0;
            rs_end_codeword <= 0;
            
            if (state_in == STATE_IDLE) begin
                if (s_axis_ldpc_tvalid && s_axis_ldpc_tready) begin
                    current_word <= s_axis_ldpc_tdata;
                    byte_idx <= 0;
                    state_in <= STATE_PUSH;
                end
            end else if (state_in == STATE_PUSH) begin
                // Only push if rs_in_ready or if we are discarding
                if (rs_in_ready || (symbol_count >= 144)) begin
                    
                    if (symbol_count < 144) begin
                        rs_valid_in <= 1'b1;
                        rs_symbol_in <= current_word[byte_idx*8 +: 8];
                    end
                    
                    if (symbol_count == 0) rs_start_codeword <= 1'b1;
                    if (symbol_count == 143) rs_end_codeword <= 1'b1;
                    
                    if (symbol_count == 287) symbol_count <= 0;
                    else symbol_count <= symbol_count + 1;
                    
                    if (byte_idx == 7) begin
                        byte_idx <= 0;
                        state_in <= STATE_IDLE;
                    end else begin
                        byte_idx <= byte_idx + 1;
                    end
                end
            end
        end
    end

    //========================================================
    // SERIALIZER (8-bit to 64-bit)
    //========================================================
    reg [2:0] out_byte_idx;
    reg [DATA_W-1:0] out_word;
    reg out_valid_reg;
    reg out_last_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            out_byte_idx <= 0;
            out_valid_reg <= 0;
            out_last_reg <= 0;
        end else begin
            out_valid_reg <= 0;
            out_last_reg <= 0;
            if (rs_out_valid) begin
                out_word[out_byte_idx*8 +: 8] <= rs_out_symbol;
                
                if (rs_out_symbol != 0) begin
                    $display("[RS DECODER] o_valid: 1 | o_symbol: %h | o_error: %b", rs_out_symbol, rs_out_error);
                end
                
                if (out_byte_idx == 7) begin
                    out_byte_idx <= 0;
                    out_valid_reg <= 1'b1;
                    if (rs_out_end) out_last_reg <= 1'b1;
                end else begin
                    out_byte_idx <= out_byte_idx + 1;
                end
            end
        end
    end
    
    wire [DATA_W-1:0] rs_tdata = out_word;
    wire              rs_tvalid = out_valid_reg;
    wire              rs_tlast = out_last_reg;
    
    //========================================================
    // BYPASS MULTIPLEXER LOGIC
    //========================================================
    assign m_axis_out_tdata  = bypass_bch ? s_axis_ldpc_tdata  : rs_tdata;
    assign m_axis_out_tvalid = bypass_bch ? s_axis_ldpc_tvalid : rs_tvalid;
    assign m_axis_out_tlast  = bypass_bch ? s_axis_ldpc_tlast  : rs_tlast;
    
endmodule
