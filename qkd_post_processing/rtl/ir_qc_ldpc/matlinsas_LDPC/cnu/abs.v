module abs(x, xmag, xsgn);
parameter data_w = 8;

input [data_w-1:0] x;
output [data_w-1:0] xmag;
output xsgn;

assign xsgn = x[data_w-1];
// Use One's Complement (~x) instead of Two's Complement (-x) to save an Adder (1 LUT per bit)
assign xmag = xsgn? (~x) : x;

endmodule
