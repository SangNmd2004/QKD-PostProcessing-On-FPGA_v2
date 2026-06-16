`timescale 1ns / 1ps

module vnu_cluster #(
    parameter Zc = 96,
    parameter data_w = 8,
    parameter D = 12,
    parameter ext_w = 3
)(
    input  [Zc*data_w-1:0] l_in,             // LLR inputs for Zc VNUs
    input  [Zc*data_w*D-1:0] r_in,           // CNU to VNU messages
    output [Zc*(data_w+ext_w)*D-1:0] q_out,  // VNU to CNU messages
    output [Zc-1:0] dec_out                  // Decoded bits
);

    genvar i;
    generate
        for(i = 0; i < Zc; i = i + 1) begin : vnu_inst
            vnu #(
                .data_w(data_w),
                .D(D),
                .ext_w(ext_w)
            ) u_vnu (
                .l(l_in[i*data_w +: data_w]),
                .r(r_in[i*data_w*D +: data_w*D]),
                .q(q_out[i*(data_w+ext_w)*D +: (data_w+ext_w)*D]),
                .dec(dec_out[i])
            );
        end
    endgenerate

endmodule
