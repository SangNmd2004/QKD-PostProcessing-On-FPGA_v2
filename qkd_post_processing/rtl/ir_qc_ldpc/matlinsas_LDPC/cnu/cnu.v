`ifdef SIMULATION
    `include "abs.v"
    `include "sat.v"
    `include "cmp_tree.v"
	`include "sgn_ram.v"
`endif
module cnu(en, active, clk, rst, q, r, syn);
parameter D=8;
parameter res_w = 8;
parameter ext_w = 1;
parameter idx_w = 3;
localparam  data_w = res_w + ext_w;

input	clk, rst, en, active;
input [data_w*D-1:0] q;
input syn;
output [res_w*D-1:0] r;

wire	[data_w-1:0] min, min2;
wire signed [data_w+1:0] tmin, tmin2;

wire	[data_w*D-1:0] qmag;
wire	[idx_w-1:0] min_idx;
wire	[D-1:0] qsgn;
wire	[D-1:0] qsgn2;
wire	rsgn;

genvar i;

//-----------

generate
for(i=0; i<D; i=i+1) begin :get_abs
	abs #(.data_w(data_w)) AQ (.x(q[i*data_w +:data_w]), .xsgn(qsgn[i]), .xmag(qmag[i*data_w +:data_w]));
end
endgenerate

cmp_tree #(.D(D), .data_w(data_w), .idx_w(idx_w)) CPT (
    .en(en),
	.clk(clk),
	.rst(rst), 
	.in(qmag), 
	.min(min), 
	.min2(min2), 
	.min_idx(min_idx)
);

sgn_ram #(.D(D)) SRAM(
	.en(en), .clk(clk), .rst(rst), .qsgn(qsgn),
	.rsgn(rsgn), .qsgn2(qsgn2), .syn(syn)
);

assign tmin = active ? {2'b0, min} : 0;
// tmin2 and min2 are unused in Uniform Min-Sum, they will be optimized away by Vivado
assign tmin2 = active ? {2'b0, min2} : 0;

wire signed [data_w+1:0] tmin_scaled = ( $signed((tmin<<<1)+tmin)>>>2 );

generate
for(i=0; i<D; i=i+1) begin :calc_r
    // Uniform Min-Sum Approximation: Only use min1 (tmin_scaled) for all edges
    assign r[i*res_w +:res_w] = ( (rsgn^qsgn2[i])? -$signed(tmin_scaled) : tmin_scaled );
end
endgenerate

endmodule

