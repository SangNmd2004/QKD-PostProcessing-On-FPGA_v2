import os

# IEEE 802.16e LDPC Base Matrices
# 00: Rate 1/2 (12x24)
rate_1_2 = [
    [-1, 94, 73, -1, -1, -1, -1, -1, 55, 83, -1, -1,  7,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [-1, 27, -1, -1, -1, 22, 79,  9, -1, -1, -1, 12, -1,  0,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1],
    [-1, -1, -1, 24, 22, 81, -1, 33, -1, -1, -1,  0, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1, -1, -1],
    [61, -1, 47, -1, -1, -1, -1, -1, 65, 25, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1, -1],
    [-1, -1, 39, -1, -1, -1, 84, -1, -1, 41, 72, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1],
    [-1, -1, -1, -1, 46, 40, -1, 82, -1, -1, -1, 79,  0, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1],
    [-1, -1, 95, 53, -1, -1, -1, -1, -1, 14, 18, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1],
    [-1,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1],
    [80, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1],
    [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1],
    [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0],
    [92, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0]
]

# 01: Rate 2/3 B (8x24)
rate_2_3 = [
    [ 2, -1, 19, -1, 47, -1, 48, -1, 36, -1, 82, -1, 47, -1, 15, -1, 95,  0, -1, -1, -1, -1, -1, -1],
    [-1, 69, -1, 88, -1, 33, -1,  3, -1, 16, -1, 37, -1, 40, -1, 48, -1,  0,  0, -1, -1, -1, -1, -1],
    [10, -1, 86, -1, 62, -1, 28, -1, 85, -1, 16, -1, 34, -1, 73, -1, -1, -1,  0,  0, -1, -1, -1, -1],
    [-1, 28, -1, 32, -1, 81, -1, 27, -1, 88, -1,  5, -1, 56, -1, 37, -1, -1, -1,  0,  0, -1, -1, -1],
    [23, -1, 29, -1, 15, -1, 30, -1, 66, -1, 24, -1, 50, -1, 62, -1, -1, -1, -1, -1,  0,  0, -1, -1],
    [-1, 30, -1, 65, -1, 54, -1, 14, -1,  0, -1, 30, -1, 74, -1,  0, -1, -1, -1, -1, -1,  0,  0, -1],
    [32, -1,  0, -1, 15, -1, 56, -1, 85, -1,  5, -1,  6, -1, 52, -1,  0, -1, -1, -1, -1, -1,  0,  0],
    [-1,  0, -1, 47, -1, 13, -1, 61, -1, 84, -1, 55, -1, 78, -1, 41, 95, -1, -1, -1, -1, -1, -1,  0]
]

# 10: Rate 3/4 B (6x24)
rate_3_4 = [
    [-1, 81, -1, 28, -1, -1, 14, 25, 17, -1, -1, 85, 29, 52, 78, 95, 22, 92,   0,   0,  -1,  -1,  -1,  -1],
    [42, -1, 14, -1, 25, 31, -1, -1, 85, 86, -1, -1, 40, 88, 54, 15, 54,  7,  -1,   0,   0,  -1,  -1,  -1],
    [-1, 53, 73, -1, -1, 64, -1, 39, -1, -1, 48, -1, 54, 74, 31, 83, 47, 41,  -1,  -1,   0,   0,  -1,  -1],
    [43, -1, -1, 86, 52, -1, 89, -1, -1, 71, -1, 39, 58, 44, 28, 53, -1, -1,  -1,  -1,  -1,   0,   0,  -1],
    [-1, 69, -1, -1, -1, 63, -1, 43, -1, 37, 40, -1, 48, -1, 33, 22, 89, 24,   0,  -1,  -1,  -1,   0,   0],
    [62, -1, 60, -1, 46, -1, 34, -1, 48, -1, 67, -1, 13, -1, 35, -1, 66, 11,   0,  -1,  -1,  -1,  -1,   0]
]

def generate_verilog_case(matrix, indent_level):
    indent = "    " * indent_level
    lines = []
    for r, row in enumerate(matrix):
        lines.append(f"{indent}5'd{r}: begin")
        lines.append(f"{indent}    case (col_idx)")
        for c, shift in enumerate(row):
            if shift != -1:
                lines.append(f"{indent}        5'd{c}: begin valid_conn <= 1'b1; shift_val <= 7'd{shift}; end")
        lines.append(f"{indent}        default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end")
        lines.append(f"{indent}    endcase")
        lines.append(f"{indent}end")
    return "\n".join(lines)

verilog_code = f"""`timescale 1ns / 1ps

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
{generate_verilog_case(rate_1_2, 5)}
                    default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                endcase
            end
            2'b01: begin // Rate 2/3 B
                case (row_idx)
{generate_verilog_case(rate_2_3, 5)}
                    default: begin valid_conn <= 1'b0; shift_val <= 7'd0; end
                endcase
            end
            2'b10: begin // Rate 3/4 B
                case (row_idx)
{generate_verilog_case(rate_3_4, 5)}
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
"""

with open("rtl/ir_qc_ldpc/matlinsas_LDPC/rom_h_matrix.v", "w") as f:
    f.write(verilog_code)

print("rom_h_matrix.v generated successfully!")
