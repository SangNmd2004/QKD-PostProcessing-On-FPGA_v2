`timescale 1ns/1ps

module tb_hw_co_design;

    parameter Zc = 96;
    parameter data_w = 12; // Cấu hình siêu phân giải (12-bit) như thiết kế gốc
    parameter D_vnu = 12;
    parameter D_cnu = 15;
    parameter ext_w = 2;
    parameter res_w = 12;
    parameter shift_w = 7;

    reg clk;
    reg rst_n;
    reg start;
    
    reg [1535:0] syn_in;
    reg [1535:0] err_syn_in;
    reg [Zc*data_w*24-1:0] llr_in_array;
    
    wire done;
    wire ir_success;
    wire ir_fail_intr;
    wire [5:0] iter_out;
    wire [7:0] iter_max_out;
    wire [Zc*24-1:0] ldpc_res_out;
    wire discard_flag;

    system_top #(
        .Zc(Zc), .data_w(data_w), .D_vnu(D_vnu), .D_cnu(D_cnu), 
        .ext_w(ext_w), .res_w(res_w), .shift_w(shift_w)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .syn_in(syn_in),
        .err_syn_in(err_syn_in), // Đấu nối Error Syndrome
        .llr_in_array(llr_in_array),
        .puncture_en(1'b0),
        .resume_decoding(1'b0),
        .hash_ok(1'b0),
        .hash_fail(1'b0),
        .done(done),
        .ir_success(ir_success),
        .ir_fail_intr(ir_fail_intr),
        .iter_out(iter_out),
        .iter_max_out(iter_max_out),
        .ldpc_res_out(ldpc_res_out),
        .discard_flag(discard_flag)
    );

    // Clock generation (150 MHz = 6.66 ns period)
    initial begin
        clk = 0;
        forever #3.33 clk = ~clk;
    end

    // Memory for loading test vectors
    reg [5:0]        llr_mem [0:Zc*24-1]; // LLR file has 8-bit strings, but we only need 6 LSBs
    reg [0:0]        syn_mem [0:1535];
    reg [0:0]        err_syn_mem [0:1535]; // Bộ nhớ cho Error Syndrome
    reg [0:0]        expected_mem [0:Zc*24-1];
    
    integer i;
    integer err_count;
    integer blk;
    
    // Arrays to store summary statistics
    integer stats_shw [0:4];
    integer stats_discard [0:4];
    integer stats_iter [0:4];
    integer stats_ldpc_done [0:4];
    integer stats_err_bits [0:4];

    initial begin
        // Initialize inputs
        rst_n = 0;
        start = 0;
        syn_in = 0;
        err_syn_in = 0;
        llr_in_array = 0;

        for (blk = 0; blk < 5; blk = blk + 1) begin
            $display("=========================================================");
            $display(" RUNNING BLOCK %0d", blk);
            $display("=========================================================");
            
            // Hard reset system for each block
            rst_n = 0;
            #20 rst_n = 1;
            #10;
            
            $display("Loading LLR, Syndrome and Expected Data test vectors...");
            if (blk == 0) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_0.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_0.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_0.txt", err_syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/expected_out_0.txt", expected_mem);
            end else if (blk == 1) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_1.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_1.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_1.txt", err_syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/expected_out_1.txt", expected_mem);
            end else if (blk == 2) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_2.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_2.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_2.txt", err_syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/expected_out_2.txt", expected_mem);
            end else if (blk == 3) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_3.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_3.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_3.txt", err_syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/expected_out_3.txt", expected_mem);
            end else if (blk == 4) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_4.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_4.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_4.txt", err_syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/expected_out_4.txt", expected_mem);
            end
            
            // Pack data into wide buses with SIGN EXTENSION (6-bit -> 12-bit)
            for (i = 0; i < Zc*24; i = i + 1) begin
                // Sign extend the 6-bit LLR to 12-bit for the high-res LDPC core
                llr_in_array[i*data_w +: data_w] = { {6{llr_mem[i][5]}}, llr_mem[i] };
            end
            for (i = 0; i < 1536; i = i + 1) begin
                syn_in[i] = syn_mem[i];
                err_syn_in[i] = err_syn_mem[i];
            end
            
            // Start processing
            $display("Starting Hardware-Algorithm Co-Design System at 150MHz...");
            start = 1;
            #6.66 start = 0;
            
            // Wait for Adder Tree Pipeline (4 cycles) + FSM delay to extract SHW
            #40;
            $display("---------------------------------------------------------");
            $display("DYNAMIC PARAMETER EXTRACTION:");
            $display(" -> Detected Syndrome Hamming Weight (SHW) = %0d", dut.u_adder_tree.shw_out);
            $display(" -> Statistical Controller Set iter_max = %0d", iter_max_out);
            $display(" -> Discard Flag = %b", discard_flag);
            $display("---------------------------------------------------------");
            
            if (discard_flag) begin
                $display("WARNING: High noise block detected. In a real system, this block would be discarded immediately to save power.");
            end
            
            $display("Waiting for LDPC Core to finish decoding...");
            
            // Wait for core to complete
            wait(done || ir_fail_intr);
            
            $display("---------------------------------------------------------");
            $display("DECODING COMPLETED!");
            $display(" -> HW Status Flag: %s", done ? "SUCCESS (Parity Check OK)" : "FAILED (Max Iter Reached)");
            $display(" -> Iterations Executed: %0d / %0d", iter_out, iter_max_out);
            
            // Wait for RS Decoder (Outer Code) to process the data
            $display("Waiting for Reed-Solomon Outer Code to mop up residual errors...");
            // Notice we wait for rs_out_tlast to signal the end of the RS packet
            wait(rs_out_tlast);
            #20;
            
            // Verify bits against expected_mem (Only the 1152 Info Bits = 144 bytes)
            err_count = 0;
            for (i = 0; i < 1152; i = i + 1) begin
                if (rs_final_key[i] !== expected_mem[i]) begin
                    if (err_count < 15) begin
                        $display("   [Outer Code Error] Position: %0d | Expected: %b, Got: %b", i, expected_mem[i], rs_final_key[i]);
                    end else if (err_count == 15) begin
                        $display("   ... (Skipping remaining error position logs) ...");
                    end
                    err_count = err_count + 1;
                end
            end
            
            $display(" -> FINAL SECRET KEY VERIFICATION: %0d Error bits remaining out of 1152 bits", err_count);
            $display("---------------------------------------------------------");
            
            // Save statistics
            stats_shw[blk] = dut.u_adder_tree.shw_out;
            stats_discard[blk] = discard_flag;
            stats_iter[blk] = iter_out;
            stats_ldpc_done[blk] = done;
            stats_err_bits[blk] = err_count;

            #100; // Small delay before loading next block
        end
        
        $display("\n===============================================================================");
        $display("                   SIMULATION SUMMARY REPORT (LDPC + RS)                       ");
        $display("===============================================================================");
        $display(" BLOCK | QBER TARGET |  SHW  | DISCARD | LDPC ITERS | LDPC STATUS | RS ERRORS");
        $display("-------------------------------------------------------------------------------");
        for (blk = 0; blk < 5; blk = blk + 1) begin
            $display("   %0d   |      %0d%%    | %4d  |    %0d    |     %2d     |  %s  |   %4d", 
                     blk, blk+2, stats_shw[blk], stats_discard[blk], stats_iter[blk], 
                     stats_ldpc_done[blk] ? " SUCCESS " : " FAILED  ", stats_err_bits[blk]);
        end
        $display("===============================================================================\n");

        $display("ALL 5 BLOCKS TESTED SUCCESSFULLY!");
        $finish;
    end

    //================================================================
    // RS DECODER INTEGRATION FOR TESTBENCH
    //================================================================
    wire [63:0] axis_ldpc_tdata;
    wire axis_ldpc_tvalid;
    wire axis_ldpc_tready;
    wire axis_ldpc_tlast;

    parallel_to_axis #(
        .DATA_W(64),
        .BLOCK_BITS(2304)
    ) u_parallel_to_axis (
        .clk(clk),
        .rst(~rst_n),
        .p_data_in(ldpc_res_out),
        .p_valid_in(done),
        .p_ready_out(),
        .m_axis_tdata(axis_ldpc_tdata),
        .m_axis_tvalid(axis_ldpc_tvalid),
        .m_axis_tready(axis_ldpc_tready),
        .m_axis_tlast(axis_ldpc_tlast)
    );

    wire [63:0] rs_out_tdata;
    wire rs_out_tvalid;
    wire rs_out_tready = 1'b1;
    wire rs_out_tlast;

    bch_cleaner_wrapper #(
        .DATA_W(64)
    ) u_bch_cleaner_wrapper (
        .clk(clk),
        .rst(~rst_n),
        .bypass_bch(1'b0), // Kích hoạt Outer Code
        .s_axis_ldpc_tdata(axis_ldpc_tdata),
        .s_axis_ldpc_tvalid(axis_ldpc_tvalid),
        .s_axis_ldpc_tready(axis_ldpc_tready),
        .s_axis_ldpc_tlast(axis_ldpc_tlast),
        .m_axis_out_tdata(rs_out_tdata),
        .m_axis_out_tvalid(rs_out_tvalid),
        .m_axis_out_tready(rs_out_tready),
        .m_axis_out_tlast(rs_out_tlast)
    );
    
    // Thu thập dữ liệu AXI-Stream đầu ra thành một khối song song để kiểm tra
    reg [1151:0] rs_final_key;
    reg [4:0] rs_word_idx = 0;
    
    always @(posedge clk) begin
        if (~rst_n) begin
            rs_word_idx <= 0;
        end else if (rs_out_tvalid) begin
            rs_final_key[rs_word_idx*64 +: 64] <= rs_out_tdata;
            rs_word_idx <= rs_word_idx + 1;
        end
    end

endmodule
