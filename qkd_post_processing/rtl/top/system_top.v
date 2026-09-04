`timescale 1ns / 1ps

module system_top #(
    parameter Zc = 96,
    parameter data_w = 6, // Matching the core's default parameter (though it may be overridden in TB)
    parameter D_vnu = 6, 
    parameter D_cnu = 15, 
    parameter ext_w = 1,
    parameter res_w = 8,
    parameter shift_w = 7
)(
    input  wire clk,
    input  wire rst_n, // Active low reset for consistency with new modules
    input  wire start,
    
    // Data inputs
    input  wire [1535:0] syn_in,
    input  wire [1535:0] err_syn_in, // Thêm cổng nạp Error Syndrome từ Testbench
    input  wire [Zc*data_w*24-1:0] llr_in_array,
    input  wire puncture_en,
    input  wire resume_decoding,
    
    // Hash interface
    input  wire hash_ok,
    input  wire hash_fail,
    
    // Outputs
    output wire done,
    output wire ir_success,
    output wire ir_fail_intr, 
    output wire [5:0] iter_out, 
    output wire [7:0] iter_max_out, // Debug: xuất iter_max từ Controller ra ngoài
    output wire [Zc*24-1:0] ldpc_res_out,
    
    // Status flags
    output wire discard_flag
);

    wire rst_high = ~rst_n; // Convert to active high for the legacy core

    // 1. Syndrome Weight Counter (Adder Tree)
    wire [10:0] shw_val;
    syndrome_weight_counter u_adder_tree (
        .clk(clk),
        .rst_n(rst_n),
        .syn_in(err_syn_in[1151:0]), // Tính trọng số dựa trên Error Syndrome
        .shw_out(shw_val)
    );

    // 2. Statistical Controller
    wire [1:0] opt_rate;
    wire [7:0] iter_max;
    assign iter_max_out = iter_max;
    
    statistical_controller u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .shw_in(shw_val),
        .opt_rate(opt_rate),
        .iter_max(iter_max),
        .discard_flag(discard_flag)
    );
    wire real_start = start & ~discard_flag;
    wire ldpc_core_fail;
    assign ir_fail_intr = ldpc_core_fail | (start & discard_flag); // Tạo xung ngắt ảo để TB không bị treo khi vứt rác

    // 3. LDPC Core (Modified for dynamic iter_max_in)
    core_partially_parallel #(
        .Zc(Zc), .data_w(data_w), .D_vnu(D_vnu), .D_cnu(D_cnu), 
        .ext_w(ext_w), .res_w(res_w), .shift_w(shift_w)
    ) u_ldpc_core (
        .clk(clk),
        .rst(rst_high),
        .start(real_start), // Cắt nguồn ngắt start nếu discard_flag = 1
        .iter_max_in(iter_max),
        .code_rate(opt_rate),
        .syn_in(syn_in),
        .llr_in_array(llr_in_array),
        .done(done),
        .ir_success(ir_success),
        .ir_fail_intr(ldpc_core_fail), 
        .puncture_en(puncture_en),      
        .resume_decoding(resume_decoding),   
        .hash_ok(hash_ok),
        .hash_fail(hash_fail),
        .iter_out(iter_out), 
        .ldpc_res_out(ldpc_res_out)
    );

endmodule
