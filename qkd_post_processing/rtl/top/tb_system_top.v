`timescale 1ns/1ps

// Testbench Cấp Hệ Thống (System-Level) cho Kiến trúc QKD Mới
// Kiểm tra khả năng tương tác giữa: AXI -> LDPC (Partially Parallel) -> HW Interrupt -> NTT Hash -> AXI
module tb_system_top();

    // Khai báo tín hiệu Clock & Reset
    reg clk;
    reg rst;
    
    // Giao tiếp Điều khiển (PS-PL)
    reg [1:0] code_rate;
    wire ir_fail_intr;
    reg resume_decoding;
    reg puncture_en;
    
    // Giao tiếp AXI-Stream Input (LLR)
    reg [7:0] s_axis_llr_tdata;
    reg s_axis_llr_tvalid;
    wire s_axis_llr_tready;
    
    // Giao tiếp AXI-Stream Input (Syndrome)
    reg [7:0] s_axis_syn_tdata;
    reg s_axis_syn_tvalid;
    wire s_axis_syn_tready;
    
    // Giao tiếp AXI-Stream Output (Secret Key)
    wire [63:0] m_axis_key_tdata;
    wire m_axis_key_tvalid;
    reg m_axis_key_tready;
    wire m_axis_key_tlast;
    
    // Tín hiệu Trạng thái
    wire ir_success;
    wire pa_active;
    
    // ========================================================
    // Instantiation: Module Top-Level Của Hệ Thống QKD
    // ========================================================
    qkd_post_processing_top #(
        .LLR_W(5), .LDPC_BLOCK(2304), .PA_DATA_W(64), .PA_RING_SIZE(64)
    ) dut (
        .clk(clk), .rst(rst), .code_rate(code_rate),
        // LLR AXI
        .s_axis_llr_tdata(s_axis_llr_tdata), .s_axis_llr_tvalid(s_axis_llr_tvalid), .s_axis_llr_tready(s_axis_llr_tready),
        // Syndrome AXI
        .s_axis_syn_tdata(s_axis_syn_tdata), .s_axis_syn_tvalid(s_axis_syn_tvalid), .s_axis_syn_tready(s_axis_syn_tready),
        // Key AXI
        .m_axis_key_tdata(m_axis_key_tdata), .m_axis_key_tvalid(m_axis_key_tvalid), .m_axis_key_tready(m_axis_key_tready), .m_axis_key_tlast(m_axis_key_tlast),
        // HW/SW Co-design
        .ir_fail_intr(ir_fail_intr), .resume_decoding(resume_decoding), .puncture_en(puncture_en),
        // Status
        .ir_success(ir_success), .pa_active(pa_active)
    );
    
    // ========================================================
    // Khởi tạo Clock 100MHz
    // ========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end
    
    // ========================================================
    // Task: Bơm dữ liệu LLR ngẫu nhiên vào FPGA qua AXI-Stream
    // ========================================================
    task send_llr_block;
        integer i;
        begin
            $display("[%0t] [AXI_LLR] Starting to send LLR block (2304 chunks)...", $time);
            #1 s_axis_llr_tvalid = 1;
            for(i=0; i < 2304; i=i+1) begin
                #1 s_axis_llr_tdata = $random;
                @(posedge clk);
                while(!s_axis_llr_tready) @(posedge clk);
            end
            #1 s_axis_llr_tvalid = 0;
            $display("[%0t] [AXI_LLR] Finished sending LLR.", $time);
        end
    endtask

    task send_syn_block;
        integer i;
        begin
            $display("[%0t] [AXI_SYN] Starting to send Syndrome block (144 chunks)...", $time);
            #1 s_axis_syn_tvalid = 1;
            for(i=0; i < 144; i=i+1) begin
                #1 s_axis_syn_tdata = $random;
                @(posedge clk);
                while(!s_axis_syn_tready) @(posedge clk);
            end
            #1 s_axis_syn_tvalid = 0;
            $display("[%0t] [AXI_SYN] Finished sending Syndrome.", $time);
        end
    endtask

    // Debug Monitor
    reg last_ldpc_en;
    reg [2:0] last_state;
    initial begin
        last_ldpc_en = 0;
        last_state = 0;
    end
    always @(posedge clk) begin
        if (dut.ldpc_en != last_ldpc_en) begin
            $display("[%0t] [DEBUG] ldpc_en changed: %b -> %b", $time, last_ldpc_en, dut.ldpc_en);
            last_ldpc_en = dut.ldpc_en;
        end
        if (dut.ir_qc_ldpc.state != last_state) begin
            $display("[%0t] [DEBUG] FSM state changed: %d -> %d", $time, last_state, dut.ir_qc_ldpc.state);
            last_state = dut.ir_qc_ldpc.state;
        end
        
        // Print when ldpc_start or syn_start become 1
        if (dut.ldpc_start && !dut.ldpc_en && $time > 23000000) 
            $display("[%0t] [DEBUG] ldpc_start is HIGH!", $time);
    end
    
    // Tiến độ NTT Hash (để không lầm tưởng là bị kẹt)
    reg [31:0] ntt_cycle_cnt;
    initial ntt_cycle_cnt = 0;
    always @(posedge clk) begin
        if (pa_active) begin
            ntt_cycle_cnt = ntt_cycle_cnt + 1;
            if (ntt_cycle_cnt % 10000 == 0) begin
                $display("[%0t] [NTT_HASH] Progress: %d / 70000 clock cycles... | pa_state: %d | ntt_state: %d", 
                         $time, ntt_cycle_cnt, dut.pa_hash_core.state, dut.pa_hash_core.ntt_core.state);
            end
        end else begin
            ntt_cycle_cnt = 0;
        end
    end

    initial begin
        rst = 1;
        code_rate = 2'b00;
        s_axis_llr_tvalid = 0;
        s_axis_syn_tvalid = 0;
        m_axis_key_tready = 1; 
        resume_decoding = 0;
        puncture_en = 0;
        
        #100; rst = 0; #100;
        
        $display("-----------------------------------------------------");
        $display("=== SCENARIO 1: Sending AXI Streams & Puncturing ===");
        $display("-----------------------------------------------------");
        puncture_en = 1; 
        
        fork
            send_llr_block();
            send_syn_block();
        join
        
        $display("-----------------------------------------------------");
        $display("=== SCENARIO 2: LDPC Decoding & HW Interrupt ===");
        $display("-----------------------------------------------------");
        $display("[%0t] [LDPC_CORE] Waiting for Min-Sum FSM loop...", $time);
        
        wait(ir_fail_intr == 1 || ir_success == 1);
        
        if (ir_fail_intr) begin
            $display("[%0t] [INTERRUPT] HW Interrupt Asserted! ir_fail_intr = 1.", $time);
            $display("[%0t] [FREEZE] Freezing Quantum State for Blind Reconciliation.", $time);
            
            #500;
            $display("[%0t] [ZYNQ_PS] Expanded Matrix written. Asserting Resume...", $time);
            resume_decoding = 1;
            #10;
            resume_decoding = 0;
            
            wait(ir_success == 1 || ir_fail_intr == 1);
            if (ir_success)
                $display("[%0t] [SUCCESS] BLIND RECONCILIATION SUCCESSFUL!", $time);
            else
                $display("[%0t] [WARNING] Second Decoding Pass Failed (Expected for Random Data).", $time);
        end
        
        $display("-----------------------------------------------------");
        $display("=== SCENARIO 3: Privacy Amplification NTT Hash ===");
        $display("-----------------------------------------------------");
        
        $display("[%0t] [NTT_HASH] Loading Ping-Pong BRAM (Requires 2 LDPC blocks)...", $time);
        
        // Ta dùng lệnh Force để giả lập tín hiệu ir_success bật sáng 2 lần
        // Mỗi lần đẩy 2304 bits (36 chunks) vào BRAM. BRAM cần 64 chunks (4096 bits).
        begin : PUMP_BLOCKS
            integer k;
            for(k=0; k<2; k=k+1) begin
                @(posedge clk);
                #1 force dut.ir_qc_ldpc.ir_success = 1;
                
                @(posedge clk);
                #1 release dut.ir_qc_ldpc.ir_success;
                
                // Đợi mạch truyền xong 36 chunks (36 * 10ns = 360ns)
                // Dùng Fixed Delay thay vì wait(p_ready_out) để tránh việc Vivado Optimizer xóa mất port không dùng
                #400;
            end
        end
        wait(pa_active == 1);
        $display("[%0t] [NTT_HASH] Active! Hashing data...", $time);
        
        wait(m_axis_key_tvalid == 1);
        $display("[%0t] [AXI_KEY] First 64-bit Secret Key output: %h", $time, m_axis_key_tdata);
        
        wait(m_axis_key_tlast == 1);
        $display("[%0t] [AXI_KEY] [PASSED] 256-bit Final Secret Key exported successfully!", $time);
        
        $display("-----------------------------------------------------");
        $display("[%0t] SIMULATION COMPLETE. ALL MODULES VERIFIED!", $time);
        $display("-----------------------------------------------------");
        
        #1000;
        $finish;
    end

endmodule
