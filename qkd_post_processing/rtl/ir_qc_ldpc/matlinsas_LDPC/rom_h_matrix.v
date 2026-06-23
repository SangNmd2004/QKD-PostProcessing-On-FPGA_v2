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
        case (code_rate)
            2'b00: begin // Rate 1/2
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
            2'b01: begin // Rate 2/3 B
                case (row_idx)
                    5'd0: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd2; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd19; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd47; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd48; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd36; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd82; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd47; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd15; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd95; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd1: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd69; end
                            5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd88; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd33; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd3; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd16; end
                            5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd37; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd40; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd48; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd2: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd10; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd86; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd62; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd28; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd85; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd16; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd34; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd73; end
                            5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd19: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd3: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd28; end
                            5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd32; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd81; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd27; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd88; end
                            5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd5; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd56; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd37; end
                            5'd19: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd20: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd4: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd23; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd29; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd15; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd30; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd66; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd24; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd50; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd62; end
                            5'd20: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd21: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd5: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd30; end
                            5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd65; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd54; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd14; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd30; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd74; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd21: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd22: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd6: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd32; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd15; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd56; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd85; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd5; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd6; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd52; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd22: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd23: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd7: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd47; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd13; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd61; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd84; end
                            5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd55; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd78; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd41; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd95; end
                            5'd23: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                endcase
            end
            2'b10: begin // Rate 3/4 B
                case (row_idx)
                    5'd0: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd81; end
                            5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd28; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd14; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd25; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd17; end
                            5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd85; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd29; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd52; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd78; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd95; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd22; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd92; end
                            5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd19: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd1: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd42; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd14; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd25; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd31; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd85; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd86; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd40; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd88; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd54; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd15; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd54; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd7; end
                            5'd19: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd20: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd2: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd53; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd73; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd64; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd39; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd48; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd54; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd74; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd31; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd83; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd47; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd41; end
                            5'd20: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd21: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd3: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd43; end
                            5'd3: begin valid_conn <= 1'b1; shift_val <= 7'd86; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd52; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd89; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd71; end
                            5'd11: begin valid_conn <= 1'b1; shift_val <= 7'd39; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd58; end
                            5'd13: begin valid_conn <= 1'b1; shift_val <= 7'd44; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd28; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd53; end
                            5'd21: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd22: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd4: begin
                        case (col_idx)
                            5'd1: begin valid_conn <= 1'b1; shift_val <= 7'd69; end
                            5'd5: begin valid_conn <= 1'b1; shift_val <= 7'd63; end
                            5'd7: begin valid_conn <= 1'b1; shift_val <= 7'd43; end
                            5'd9: begin valid_conn <= 1'b1; shift_val <= 7'd37; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd40; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd48; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd33; end
                            5'd15: begin valid_conn <= 1'b1; shift_val <= 7'd22; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd89; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd24; end
                            5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd22: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd23: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    5'd5: begin
                        case (col_idx)
                            5'd0: begin valid_conn <= 1'b1; shift_val <= 7'd62; end
                            5'd2: begin valid_conn <= 1'b1; shift_val <= 7'd60; end
                            5'd4: begin valid_conn <= 1'b1; shift_val <= 7'd46; end
                            5'd6: begin valid_conn <= 1'b1; shift_val <= 7'd34; end
                            5'd8: begin valid_conn <= 1'b1; shift_val <= 7'd48; end
                            5'd10: begin valid_conn <= 1'b1; shift_val <= 7'd67; end
                            5'd12: begin valid_conn <= 1'b1; shift_val <= 7'd13; end
                            5'd14: begin valid_conn <= 1'b1; shift_val <= 7'd35; end
                            5'd16: begin valid_conn <= 1'b1; shift_val <= 7'd66; end
                            5'd17: begin valid_conn <= 1'b1; shift_val <= 7'd11; end
                            5'd18: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            5'd23: begin valid_conn <= 1'b1; shift_val <= 7'd0; end
                            default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                        endcase
                    end
                    default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                endcase
            end
            default: begin
                valid_conn <= 1'b0;
                shift_val <= 7'd0;
            end
        endcase
    end
endmodule
