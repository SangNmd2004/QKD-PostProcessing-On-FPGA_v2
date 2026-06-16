`timescale 1ns / 1ps

module cnu_cluster #(
    parameter Zc = 96,
    parameter D = 8,
    parameter res_w = 8,
    parameter ext_w = 3,
    parameter idx_w = 3
)(
    input  clk,
    input  rst,
    input  en,
    input  active,
    input  [Zc-1:0] syn_in,
    input  [Zc*(res_w+ext_w)*D-1:0] q_in,    // VNU to CNU messages
    output [Zc*res_w*D-1:0] r_out            // CNU to VNU messages
);

    genvar i;
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
                .q(q_in[i*(res_w+ext_w)*D +: (res_w+ext_w)*D]),
                .syn(syn_in[i]),
                .r(r_out[i*res_w*D +: res_w*D])
            );
        end
    endgenerate

endmodule
