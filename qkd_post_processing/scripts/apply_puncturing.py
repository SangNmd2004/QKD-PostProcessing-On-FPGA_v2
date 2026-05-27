import re

file_path = "rtl/ir_qc_ldpc/matlinsas_LDPC/core_static.v"
with open(file_path, "r") as f:
    content = f.read()

replacement = """assign cnu_active[95:0] = (code_rate == 2'b00) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[191:96] = {96{1'b1}};
assign cnu_active[287:192] = (code_rate == 2'b00) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[383:288] = (code_rate != 2'b11) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[479:384] = (code_rate == 2'b00) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[575:480] = (code_rate != 2'b11) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[671:576] = {96{1'b1}};
assign cnu_active[767:672] = (code_rate == 2'b00 || code_rate == 2'b01) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[863:768] = {96{1'b1}};
assign cnu_active[959:864] = (code_rate == 2'b00 || code_rate == 2'b01) ? {96{1'b1}} : {96{1'b0}};
assign cnu_active[1055:960] = {96{1'b1}};
assign cnu_active[1151:1056] = (code_rate == 2'b00) ? {96{1'b1}} : {96{1'b0}};"""

content = re.sub(
    r"assign cnu_active\[1151:768\][^\n]*\nassign cnu_active\[767:576\][^\n]*\nassign cnu_active\[575:384\][^\n]*\nassign cnu_active\[383:0\][^\n]*\n",
    replacement + "\n",
    content,
    flags=re.DOTALL
)

with open(file_path, "w") as f:
    f.write(content)

print("Applied Optimal Puncturing Vectors to core_static.v successfully")
