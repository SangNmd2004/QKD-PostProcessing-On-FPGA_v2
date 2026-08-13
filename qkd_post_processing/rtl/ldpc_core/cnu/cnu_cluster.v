`timescale 1ns / 1ps

module cnu_cluster #(
    parameter Zc = 96,
    parameter D = 8,
    parameter res_w = 8,
    parameter ext_w = 1,
    parameter idx_w = 3
)(
    input  clk,
    input  rst,
    input  en,
    input  active,
    input  [Zc-1:0] syn_in,
    input  [Zc*(res_w+ext_w)*D-1:0] q_in,    // VNU to CNU messages
    output [Zc*res_w*D-1:0] r_out,           // CNU to VNU messages
    output [Zc-1:0] parity_vector,
    input  [2:0] offset_val
);

    wire [Zc*D*(res_w+ext_w)-1:0] q_in_reordered;
    wire [Zc*D*res_w-1:0] r_out_reordered;
    
    genvar i, j;
    generate
        for(i = 0; i < Zc; i = i + 1) begin : reorder_Zc
            for(j = 0; j < D; j = j + 1) begin : reorder_D
                // Map [D][Zc] from core to [Zc][D] for CNU instances
                assign q_in_reordered[ (i*D + j)*(res_w+ext_w) +: (res_w+ext_w) ] = 
                       q_in[ (j*Zc + i)*(res_w+ext_w) +: (res_w+ext_w) ];
                       
                // Map [Zc][D] from CNU instances to [D][Zc] for core
                assign r_out[ (j*Zc + i)*res_w +: res_w ] = 
                       r_out_reordered[ (i*D + j)*res_w +: res_w ];
            end
        end
    endgenerate

    generate
        for(i = 0; i < Zc; i = i + 1) begin : cnu_inst
            cnu #(
                .D(D),
                .res_w(res_w),
                .ext_w(ext_w),
                .idx_w(idx_w)
            ) u_cnu (
                .en(en),
                .active(active),
                .clk(clk),
                .rst(rst),
                .q(q_in_reordered[i*D*(res_w+ext_w) +: (res_w+ext_w)*D]),
                .syn(syn_in[i]),
                .offset_val(offset_val),
                .r(r_out_reordered[i*res_w*D +: res_w*D]),
                .rsgn_out(parity_vector[i])
            );
        end
    endgenerate

endmodule
