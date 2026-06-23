`timescale 1ns/1ps

module tb_system_top;

    parameter LLR_W = 6;
    parameter LDPC_BLOCK = 2304;
    parameter PA_DATA_W = 14;

    reg clk;
    reg rst;
    
    // AXI-Stream Input (LLR)
    reg [LLR_W-1:0] s_axis_llr_tdata;
    reg s_axis_llr_tvalid;
    wire s_axis_llr_tready;
    
    // AXI-Stream Input (Syndrome)
    reg [7:0] s_axis_syn_tdata;
    reg s_axis_syn_tvalid;
    wire s_axis_syn_tready;
    
    // AXI-Stream Output
    wire [63:0] m_axis_key_tdata;
    wire m_axis_key_tvalid;
    reg m_axis_key_tready;
    
    wire ir_success;
    wire pa_active;
    wire tx_err_feedback;
    wire ir_fail_intr;
    
    reg [1:0] code_rate = 2'b10; // Test Rate 3/4 ban đầu
    reg resume_decoding = 1'b0;
    
    qkd_post_processing_top #(
        .LLR_W(LLR_W),
        .LDPC_BLOCK(LDPC_BLOCK),
        .PA_DATA_W(64),
        .PA_RING_SIZE(512)
    ) dut (
        .clk(clk),
        .rst(rst),
        .code_rate(code_rate),
        .s_axis_llr_tdata(s_axis_llr_tdata),
        .s_axis_llr_tvalid(s_axis_llr_tvalid),
        .s_axis_llr_tready(s_axis_llr_tready),
        .s_axis_syn_tdata(s_axis_syn_tdata),
        .s_axis_syn_tvalid(s_axis_syn_tvalid),
        .s_axis_syn_tready(s_axis_syn_tready),
        .m_axis_key_tdata(m_axis_key_tdata),
        .m_axis_key_tvalid(m_axis_key_tvalid),
        .m_axis_key_tready(m_axis_key_tready),
        .m_axis_key_tlast(),
        .ir_success(ir_success),
        .pa_active(pa_active),
        .ir_fail_intr(ir_fail_intr),
        .resume_decoding(resume_decoding),
        .puncture_en(1'b0),
        .ldpc_iters_out()
    );

    // Xung nhịp
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Lưu dữ liệu mô phỏng
    reg [LLR_W-1:0] llr_mem [0:LDPC_BLOCK-1];
    reg [0:0] syn_mem [0:1151];
    reg [0:0] expected_mem [0:LDPC_BLOCK-1];

    integer i, j, k;
    integer err_count;
    initial begin
        rst = 1;
        s_axis_llr_tvalid = 0;
        s_axis_llr_tdata = 0;
        s_axis_syn_tvalid = 0;
        s_axis_syn_tdata = 0;
        m_axis_key_tready = 1;

        // Đọc dữ liệu mô phỏng từ file
        $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in.txt", llr_mem);
        $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in.txt", syn_mem);
        $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/expected_out.txt", expected_mem);
        
        #20 rst = 0;
        
        $display("Starting AXI-Stream Data Transfer...");
        
        fork
            // Thread 1: Load LLR
            begin
                for (i = 0; i < LDPC_BLOCK; i = i + 1) begin
                    wait(s_axis_llr_tready);
                    @(posedge clk);
                    #1;
                    s_axis_llr_tdata = llr_mem[i];
                    s_axis_llr_tvalid = 1;
                end
                @(posedge clk);
                #1;
                s_axis_llr_tvalid = 0;
                $display("Loaded %0d LLR elements.", LDPC_BLOCK);
            end
            
            // Thread 2: Load Syndrome
            begin
                for (k = 0; k < 1152; k = k + 8) begin
                    wait(s_axis_syn_tready);
                    @(posedge clk);
                    #1;
                    if (k < 576) begin
                        s_axis_syn_tdata = {syn_mem[k+7], syn_mem[k+6], syn_mem[k+5], syn_mem[k+4],
                                            syn_mem[k+3], syn_mem[k+2], syn_mem[k+1], syn_mem[k]};
                    end else begin
                        s_axis_syn_tdata = 8'd0; // Zero padding
                    end
                    s_axis_syn_tvalid = 1;
                end
                @(posedge clk);
                #1;
                s_axis_syn_tvalid = 0;
                $display("Loaded 72 bytes of Syndrome (Rate 3/4).");
            end
        join
        
        $display("Waiting for IR (LDPC) Module to complete Syndrome-based decoding (Rate 3/4)...");
        wait(ir_success || ir_fail_intr);
        
        if (ir_fail_intr) begin
            $display(">>> [FAILED] Rate 3/4 Failed! Tiến hành Blind Reconciliation (Hạ xuống Rate 2/3)...");
            @(posedge clk); #1;
            for (k = 0; k < 1152; k = k + 8) begin
                wait(s_axis_syn_tready);
                @(posedge clk); #1;
                if (k < 768) begin
                    s_axis_syn_tdata = {syn_mem[k+7], syn_mem[k+6], syn_mem[k+5], syn_mem[k+4],
                                        syn_mem[k+3], syn_mem[k+2], syn_mem[k+1], syn_mem[k]};
                end else begin
                    s_axis_syn_tdata = 8'd0;
                end
                s_axis_syn_tvalid = 1;
            end
            @(posedge clk); #1;
            s_axis_syn_tvalid = 0;
            $display("Loaded 96 bytes of Syndrome (Rate 2/3).");
            
            resume_decoding = 1;
            @(posedge clk); #1;
            resume_decoding = 0;
            
            wait(ir_success || ir_fail_intr);
            if (ir_fail_intr) begin
                $display(">>> [FAILED] Rate 2/3 Failed! Tiến hành Blind Reconciliation (Hạ xuống Rate 1/2)...");
                @(posedge clk); #1;
                for (k = 0; k < 1152; k = k + 8) begin
                    wait(s_axis_syn_tready);
                    @(posedge clk); #1;
                    s_axis_syn_tdata = {syn_mem[k+7], syn_mem[k+6], syn_mem[k+5], syn_mem[k+4],
                                        syn_mem[k+3], syn_mem[k+2], syn_mem[k+1], syn_mem[k]};
                    s_axis_syn_tvalid = 1;
                end
                @(posedge clk); #1;
                s_axis_syn_tvalid = 0;
                $display("Loaded 144 bytes of Syndrome (Rate 1/2).");
                
                resume_decoding = 1;
                @(posedge clk); #1;
                resume_decoding = 0;
                
                wait(ir_success || ir_fail_intr);
            end
        end
        
        if (ir_fail_intr) begin
            $display(">>> [FAILED] Error Reconciliation Phase Failed completely!");
        end else begin
            $display(">>> [SUCCESS] Error Reconciliation Phase Completed!");
        end
        
        // WAIT cho module LDPC xuất xong toàn bộ khóa ra thanh ghi (mất 25 xung nhịp sau khi check)
        wait(m_axis_key_tvalid);
        if (!ir_fail_intr) $display(">>> Key Extraction Complete! Transitioning to PA...");
        
        // Verify LDPC output data
        #10;
        begin : VERIFY_BLOCK
            integer f_out, f_exp;
            f_out = $fopen("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/hw_output.txt", "w");
            f_exp = $fopen("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/hw_expected.txt", "w");

            err_count = 0;
            for(j = 0; j < LDPC_BLOCK; j = j + 1) begin
                $fdisplay(f_out, "%b", dut.ldpc_res[j]);
                $fdisplay(f_exp, "%b", expected_mem[j]);
                if (dut.ldpc_res[j] !== expected_mem[j]) err_count = err_count + 1;
                if (j < 10) $display("ldpc_res[%0d]=%b, expected=%b", j, dut.ldpc_res[j], expected_mem[j]);
            end
            
            $fclose(f_out);
            $fclose(f_exp);
            $display(">>> Wrote hardware output and expected output to data/hw_output.txt and data/hw_expected.txt");
              $display("-------------------------------------------------");
            $display("DATA TEST RESULTS AFTER IR (LDPC) - SYNDROME DECODING:");
            $display("Total Key Bits (Reconciled Key): %0d bits", LDPC_BLOCK);
            $display("Remaining Error Bits: %0d bits", err_count);
            if (err_count == 0)
                $display("=> Excellent! The key is completely error-free (Matched Golden Model).");
            else
                $display("=> Errors still remain! LDPC algorithm requires review.");
            $display("-------------------------------------------------");
        end
        
        // Wait for PA activation
        wait(pa_active);
        $display(">>> Privacy Amplification (PA) is executing Toeplitz Hash...");
        
        // Stop simulation early since PA is bypassed for synthesis
        #2000;
        $display("System Top Simulation Complete!");
        $finish;
    end

    always @(posedge clk) begin
        // Monitor debug removed due to IP interface change
    end

endmodule
