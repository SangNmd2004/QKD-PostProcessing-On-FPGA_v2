`ifdef SIMULATION
    `include "abs.v"
    `include "sat.v"
    `include "cmp_tree.v"
	`include "sgn_ram.v"
`endif
module cnu(en, active, clk, rst, q, r, syn, offset_val, rsgn_out);
parameter D=8;
parameter res_w = 8;
parameter ext_w = 1;
parameter idx_w = 3;
localparam  data_w = res_w + ext_w;

input	clk, rst, en, active;
input [data_w*D-1:0] q;
input syn;
input [2:0] offset_val;
output [res_w*D-1:0] r;
output rsgn_out;



wire	[data_w-1:0] min, min2;
wire signed [data_w+1:0] tmin, tmin2;

wire	[data_w*D-1:0] qmag;
wire	[idx_w-1:0] min_idx;
wire	[D-1:0] qsgn;
wire	[D-1:0] qsgn2;
wire	rsgn;
assign rsgn_out = rsgn;

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
  assign tmin2 = active ? {2'b0, min2} : 0;
// Offset Min-Sum: subtract dynamic offset, clamp to 0
wire signed [data_w+1:0] tmin_scaled = ($signed(tmin) > offset_val) ? ($signed(tmin) - offset_val) : 0;
wire signed [data_w+1:0] tmin2_scaled = ($signed(tmin2) > offset_val) ? ($signed(tmin2) - offset_val) : 0;

generate
for(i=0; i<D; i=i+1) begin :calc_r
    wire signed [data_w+1:0] un_sat_r = (min_idx == i)?
            ( (rsgn^qsgn2[i])? -$signed(tmin2_scaled) : tmin2_scaled ):
            ( (rsgn^qsgn2[i])? -$signed(tmin_scaled) : tmin_scaled );
            
    wire signed [res_w-1:0] sat_max_r = (1 << (res_w-1)) - 1;
    wire signed [res_w-1:0] sat_min_r = ~(sat_max_r);
    
    assign r[i*res_w +: res_w] = (un_sat_r > sat_max_r) ? sat_max_r :
                                 (un_sat_r < sat_min_r) ? sat_min_r :
                                 un_sat_r[res_w-1:0];
end
endgenerate

endmodule

