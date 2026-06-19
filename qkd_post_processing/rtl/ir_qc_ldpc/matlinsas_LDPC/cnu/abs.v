module abs(x, xmag, xsgn);
parameter data_w = 8;

input [data_w-1:0] x;
output [data_w-1:0] xmag;
output xsgn;

assign xsgn = x[data_w-1];
// Use strict Two's Complement to eliminate magnitude bias against negative LLRs
assign xmag = xsgn ? -$signed(x) : x;

endmodule
