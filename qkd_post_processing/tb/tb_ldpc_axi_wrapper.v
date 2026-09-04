`timescale 1ns / 1ps

module tb_ldpc_axi_wrapper;

    // Clock and Reset
    reg clk;
    reg rst_n;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    initial begin
        rst_n = 0;
        #50;
        rst_n = 1;
    end
    
    // AXI4-Lite
    reg [31:0]  s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg [31:0]  s_axi_wdata;
    reg [3:0]   s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;
    
    reg [31:0]  s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;
    
    // AXI-Stream LLR
    reg [7:0]   s_axis_llr_tdata;
    reg         s_axis_llr_tvalid;
    wire        s_axis_llr_tready;
    
    // AXI-Stream SYN
    reg [7:0]   s_axis_syn_tdata;
    reg         s_axis_syn_tvalid;
    wire        s_axis_syn_tready;
    
    // AXI-Stream KEY (Output)
    wire [63:0] m_axis_key_tdata;
    wire        m_axis_key_tvalid;
    reg         m_axis_key_tready;
    wire        m_axis_key_tlast;
    
    wire ldpc_ir_success_intr;
    wire ldpc_ir_fail_intr;
    
    ldpc_axi_wrapper dut (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        
        .s_axis_llr_tdata(s_axis_llr_tdata),
        .s_axis_llr_tvalid(s_axis_llr_tvalid),
        .s_axis_llr_tready(s_axis_llr_tready),
        
        .s_axis_syn_tdata(s_axis_syn_tdata),
        .s_axis_syn_tvalid(s_axis_syn_tvalid),
        .s_axis_syn_tready(s_axis_syn_tready),
        
        .m_axis_key_tdata(m_axis_key_tdata),
        .m_axis_key_tvalid(m_axis_key_tvalid),
        .m_axis_key_tready(m_axis_key_tready),
        .m_axis_key_tlast(m_axis_key_tlast),
        
        .ldpc_ir_success_intr(ldpc_ir_success_intr),
        .ldpc_ir_fail_intr(ldpc_ir_fail_intr)
    );
    
    // AXI-Lite Write Task
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            s_axi_awaddr <= addr;
            s_axi_awvalid <= 1;
            s_axi_wdata <= data;
            s_axi_wvalid <= 1;
            s_axi_wstrb <= 4'hF;
            s_axi_bready <= 1;
            
            wait (s_axi_awready && s_axi_wready);
            @(posedge clk);
            s_axi_awvalid <= 0;
            s_axi_wvalid <= 0;
            
            wait (s_axi_bvalid);
            @(posedge clk);
            s_axi_bready <= 0;
        end
    endtask
    
    // AXI-Lite Read Task
    task axi_read;
        input [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            s_axi_araddr <= addr;
            s_axi_arvalid <= 1;
            s_axi_rready <= 1;
            
            wait (s_axi_arready);
            @(posedge clk);
            s_axi_arvalid <= 0;
            
            wait (s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge clk);
            s_axi_rready <= 0;
        end
    endtask
    
    integer i_llr;
    integer i_syn;
    integer blk;
    
    integer stats_discard [0:4];
    integer stats_iter [0:4];
    integer stats_ldpc_done [0:4];
    integer stats_shw [0:4];
    
    reg [5:0] llr_mem [0:2303];
    reg [0:0] syn_mem [0:1151];
    reg [0:0] err_syn_mem [0:1151]; // Thêm bộ nhớ cho Error Syndrome
    
    initial begin
        // Initialize AXI-Lite
        s_axi_awaddr = 0; s_axi_awvalid = 0;
        s_axi_wdata = 0; s_axi_wstrb = 0; s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_araddr = 0; s_axi_arvalid = 0; s_axi_rready = 0;
        
        // Initialize AXI-Stream
        s_axis_llr_tdata = 0; s_axis_llr_tvalid = 0;
        s_axis_syn_tdata = 0; s_axis_syn_tvalid = 0;
        m_axis_key_tready = 1; // Always ready to receive output
        
        wait (rst_n == 1);
        #100;
        
        $display("Configuring CTRL_REG via AXI-Lite...");
        axi_write(32'h00, 32'h00000000); // Write dummy config, rate will be predicted anyway
        
        for (blk = 0; blk < 5; blk = blk + 1) begin
            $display("=========================================================");
            $display(" RUNNING BLOCK %0d VIA AXI-STREAM", blk);
            $display("=========================================================");
            
            if (blk == 0) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_0.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_0.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_0.txt", err_syn_mem);
            end else if (blk == 1) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_1.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_1.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_1.txt", err_syn_mem);
            end else if (blk == 2) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_2.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_2.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_2.txt", err_syn_mem);
            end else if (blk == 3) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_3.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_3.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_3.txt", err_syn_mem);
            end else if (blk == 4) begin
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in_4.txt", llr_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in_4.txt", syn_mem);
                $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/err_syndrome_in_4.txt", err_syn_mem);
            end
            
            $display("Pushing LLR and Syndrome Data via AXI-Stream...");
            
            fork
                // LLR Stream: 2304 LLRs
                begin
                    for (i_llr = 0; i_llr < 2304; i_llr = i_llr + 1) begin
                        @(posedge clk);
                        s_axis_llr_tdata <= {2'b00, llr_mem[i_llr]}; 
                        s_axis_llr_tvalid <= 1;
                        wait(s_axis_llr_tready);
                    end
                    @(posedge clk);
                    s_axis_llr_tvalid <= 0;
                end
                
                // Syndrome Stream: 2304 bits packed into 288 bytes (144 Alice Syn + 144 Error Syn)
                begin
                    // Part 1: Gửi Alice Syndrome (144 bytes)
                    for (i_syn = 0; i_syn < 144; i_syn = i_syn + 1) begin
                        @(posedge clk);
                        s_axis_syn_tdata <= {syn_mem[i_syn*8+7], syn_mem[i_syn*8+6], syn_mem[i_syn*8+5], syn_mem[i_syn*8+4],
                                             syn_mem[i_syn*8+3], syn_mem[i_syn*8+2], syn_mem[i_syn*8+1], syn_mem[i_syn*8]};
                        s_axis_syn_tvalid <= 1;
                        wait(s_axis_syn_tready);
                    end
                    
                    // Part 2: Gửi Error Syndrome (144 bytes)
                    for (i_syn = 0; i_syn < 144; i_syn = i_syn + 1) begin
                        @(posedge clk);
                        s_axis_syn_tdata <= {err_syn_mem[i_syn*8+7], err_syn_mem[i_syn*8+6], err_syn_mem[i_syn*8+5], err_syn_mem[i_syn*8+4],
                                             err_syn_mem[i_syn*8+3], err_syn_mem[i_syn*8+2], err_syn_mem[i_syn*8+1], err_syn_mem[i_syn*8]};
                        s_axis_syn_tvalid <= 1;
                        wait(s_axis_syn_tready);
                    end
                    
                    @(posedge clk);
                    s_axis_syn_tvalid <= 0;
                end
            join
            
            $display("Data push complete. Waiting for Interrupts...");
            
            wait (ldpc_ir_success_intr || ldpc_ir_fail_intr);
            
            if (ldpc_ir_success_intr)
                $display("SUCCESS: Decoding successful for block %0d!", blk);
            else
                $display("FAIL: Decoding failed (Discarded by controller or hit iter_max) for block %0d!", blk);
                
            begin : read_stat_block
                reg [31:0] stat;
                axi_read(32'h04, stat);
                
                // Luu thong ke vao mang
                stats_ldpc_done[blk] = stat[0];
                stats_discard[blk] = stat[2];
                stats_iter[blk] = stat[15:8];
                stats_shw[blk] = dut.u_ldpc_top.shw_val;
                
                $display("---------------------------------");
                $display("STAT_REG Readback: 0x%08X", stat);
                $display("  -> IR Success   : %b", stat[0]);
                $display("  -> IR Fail      : %b", stat[1]);
                $display("  -> Discard Flag : %b", stat[2]);
                $display("  -> Iterations   : %d", stat[15:8]);
                $display("---------------------------------");
                
                // Clear flags for next block by writing 1 to bits 0 and 1
                axi_write(32'h04, 32'h00000003);
            end
            
            #1000;
        end
        
        $display("\n===============================================================================");
        $display("                 AXI-STREAM SIMULATION SUMMARY REPORT                          ");
        $display("===============================================================================");
        $display(" BLOCK | QBER TARGET |  SHW  | DISCARD | LDPC ITERS | LDPC STATUS ");
        $display("-------------------------------------------------------------------------------");
        for (blk = 0; blk < 5; blk = blk + 1) begin
            $display("   %0d   |      %0d%%    |  %3d  |    %0d    |     %2d     |   %s   ", 
                     blk, blk+2, stats_shw[blk], stats_discard[blk], stats_iter[blk], 
                     stats_ldpc_done[blk] ? "SUCCESS" : "FAIL   ");
        end
        $display("===============================================================================\n");
        $display("ALL 5 BLOCKS TESTED VIA AXI-STREAM SUCCESSFULLY!");
        
        #5000;
        $finish;
    end

endmodule
