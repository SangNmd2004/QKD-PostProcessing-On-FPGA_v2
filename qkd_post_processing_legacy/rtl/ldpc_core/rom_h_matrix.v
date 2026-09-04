`timescale 1ns / 1ps

// ROM Ma tran WiMAX IEEE 802.16e (Rate 1/2, 2/3B, 3/4B)
// Tu dong sinh bang Python
module rom_h_matrix #(
    parameter ROW_BITS = 5,
    parameter COL_BITS = 5,
    parameter SHIFT_W  = 7
)(
    input  clk,
    input  [1:0] code_rate, // 00: 1/2, 01: 2/3, 10: 3/4
    input  [ROW_BITS-1:0] row_idx,
    input  [COL_BITS-1:0] col_idx,
    output reg [SHIFT_W-1:0] shift_val,
    output reg valid_conn
);

    always @(posedge clk) begin
        valid_conn <= 1'b0;
        shift_val <= 7'd0;
        // Unconditionally use Rate 1/2 Matrix for Rate-Compatible Blind Reconciliation
        // Rate 3/4 uses top 6 rows. Rate 2/3 uses top 8 rows. Rate 1/2 uses 12 rows.
        case (row_idx)
                5'd0: begin
                    case (col_idx)
                        5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd94; end
                        5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd73; end
                        5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd55; end
                        5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd83; end
                        5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd7; end
                        5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd1: begin
                    case (col_idx)
                        5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd27; end
                        5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd22; end
                        5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd79; end
                        5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd9; end
                        5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd12; end
                        5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd2: begin
                    case (col_idx)
                        5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd24; end
                        5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd22; end
                        5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd81; end
                        5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd33; end
                        5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd3: begin
                    case (col_idx)
                        5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd61; end
                        5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd47; end
                        5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd65; end
                        5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd25; end
                        5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd4: begin
                    case (col_idx)
                        5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd39; end
                        5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd84; end
                        5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd41; end
                        5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd72; end
                        5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd5: begin
                    case (col_idx)
                        5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd46; end
                        5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd40; end
                        5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd82; end
                        5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd79; end
                        5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd6: begin
                    case (col_idx)
                        5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd95; end
                        5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd53; end
                        5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd14; end
                        5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd18; end
                        5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd19: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd7: begin
                    case (col_idx)
                        5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd1; end
                        5'd19: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd20: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd8: begin
                    case (col_idx)
                        5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd80; end
                        5'd20: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd21: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd9: begin
                    case (col_idx)
                        5'd21: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd22: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd10: begin
                    case (col_idx)
                        5'd22: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        5'd23: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                5'd11: begin
                    case (col_idx)
                        5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd92; end
                        5'd23: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                    endcase
                end
                default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
            endcase
    end
endmodule
