import re

file_path = "rtl/ir_qc_ldpc/matlinsas_LDPC/core_static.v"
with open(file_path, "r") as f:
    content = f.read()

# Add code_rate to module ports
content = re.sub(
    r"module ldpc_core\(en, clk, rst, l, mtx, res, term, err, syndrome\);",
    "module ldpc_core(en, clk, rst, l, mtx, res, term, err, syndrome, code_rate);",
    content
)

# Add code_rate input declaration and cnu_active logic
replacement = """input [C*D-1:0] syndrome;
input [1:0] code_rate;
output reg term;
output reg err;
output reg [R*D-1:0] res;

reg [count_w-1:0] count;

wire check;
wire [R*D-1:0] dec;
wire [C*D-1:0] cnu_active;

assign cnu_active[1151:768] = (code_rate == 2'b00) ? {384{1'b1}} : {384{1'b0}};
assign cnu_active[767:576]  = (code_rate == 2'b00 || code_rate == 2'b01) ? {192{1'b1}} : {192{1'b0}};
assign cnu_active[575:384]  = (code_rate == 2'b00 || code_rate == 2'b01 || code_rate == 2'b10) ? {192{1'b1}} : {192{1'b0}};
assign cnu_active[383:0]    = {384{1'b1}};

check #(.mtx_w(mtx_w), .C(C), .R(R), .D(D)) CH (.dec(dec), .mtx(mtx), .syndrome(syndrome), .active_bus(cnu_active), .res(check));"""

content = re.sub(
    r"input \[C\*D-1:0\] syndrome;\noutput reg term;\noutput reg err;\noutput reg \[R\*D-1:0\] res;\n\nreg \[count_w-1:0\] count;\n\nwire check;\nwire \[R\*D-1:0\] dec;\n\ncheck #\(\.mtx_w\(mtx_w\), \.C\(C\), \.R\(R\), \.D\(D\)\) CH \(\.dec\(dec\), \.mtx\(mtx\), \.syndrome\(syndrome\), \.res\(check\)\);",
    replacement,
    content
)

# Add .active(cnu_active[i]) to each CNU instantiation
def replace_cnu(match):
    idx = match.group(1)
    return match.group(0)[:-2] + f", .active(cnu_active[{idx}]));"

content = re.sub(
    r"CNU(\d+) \([^)]+\);",
    replace_cnu,
    content
)

with open(file_path, "w") as f:
    f.write(content)

print("Updated core_static.v successfully")
