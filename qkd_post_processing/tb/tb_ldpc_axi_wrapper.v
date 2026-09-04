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
    
    integer i;
    
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
        
        $display("Pushing LLR and Syndrome Data via AXI-Stream...");
        
        // Fork streams to push LLR and Syndrome in parallel (just like real DMA)
        fork
            // LLR Stream: 2304 LLRs, padded to 8-bits
            begin
                for (i = 0; i < 2304; i = i + 1) begin
                    @(posedge clk);
                    s_axis_llr_tdata <= (i % 31) + 1; // Send dummy pseudo-random positive LLRs
                    s_axis_llr_tvalid <= 1;
                    wait(s_axis_llr_tready);
                end
                @(posedge clk);
                s_axis_llr_tvalid <= 0;
            end
            
            // Syndrome Stream: 1152 bits = 144 bytes
            begin
                for (i = 0; i < 144; i = i + 1) begin
                    @(posedge clk);
                    s_axis_syn_tdata <= 8'h00; // Zero syndrome (simulating perfectly matching strings)
                    s_axis_syn_tvalid <= 1;
                    wait(s_axis_syn_tready);
                end
                @(posedge clk);
                s_axis_syn_tvalid <= 0;
            end
        join
        
        $display("Data push complete. Waiting for Interrupts...");
        
        // Wait for processing to finish
        wait (ldpc_ir_success_intr || ldpc_ir_fail_intr);
        
        if (ldpc_ir_success_intr)
            $display("SUCCESS: Decoding successful!");
        else
            $display("FAIL: Decoding failed (Discarded by controller or hit iter_max)!");
            
        // Read STAT_REG to get status details
        begin : read_stat_block
            reg [31:0] stat;
            axi_read(32'h04, stat);
            $display("---------------------------------");
            $display("STAT_REG Readback: 0x%08X", stat);
            $display("  -> IR Success   : %b", stat[0]);
            $display("  -> IR Fail      : %b", stat[1]);
            $display("  -> Discard Flag : %b", stat[2]);
            $display("  -> Iterations   : %d", stat[15:8]);
            $display("---------------------------------");
        end
        
        #5000;
        $finish;
    end

endmodule
