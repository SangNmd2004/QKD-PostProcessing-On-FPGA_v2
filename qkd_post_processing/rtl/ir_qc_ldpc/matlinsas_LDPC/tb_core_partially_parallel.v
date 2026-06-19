`timescale 1ns / 1ps

module tb_core_partially_parallel();

    parameter Zc = 96;
    parameter data_w = 5;
    
    reg clk;
    reg rst;
    reg start;
    reg [1151:0] syn_in;
    reg [Zc*data_w*24-1:0] llr_in_array;
    wire done;
    wire ir_success;
    wire ir_fail_intr;
    reg puncture_en;
    reg resume_decoding;
    wire [Zc*24-1:0] ldpc_res_out;

    // Instantiate the DUT
    core_partially_parallel #(
        .Zc(Zc), .data_w(data_w), .D_vnu(6), .D_cnu(8), 
        .ext_w(3), .res_w(8), .shift_w(7)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .syn_in(syn_in),
        .llr_in_array(llr_in_array),
        .done(done),
        .ir_success(ir_success),
        .ir_fail_intr(ir_fail_intr),
        .puncture_en(puncture_en),
        .resume_decoding(resume_decoding),
        .ldpc_res_out(ldpc_res_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // File I/O
    reg [data_w-1:0] mem_llr [0:2303];
    reg [0:0] mem_syn [0:1151];
    integer i, f_out;

    initial begin
        // Initialize Inputs
        rst = 1;
        start = 0;
        puncture_en = 0;
        resume_decoding = 0;
        llr_in_array = 0;
        
        // Read input LLRs from Python script output
        $readmemb("D:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in.txt", mem_llr, 0, 2303);
        
        // Pack into the 11520-bit array
        for(i = 0; i < 2304; i = i + 1) begin
            llr_in_array[i*data_w +: data_w] = mem_llr[i];
        end
        
        // Read Syndrome
        $readmemb("D:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/syndrome_in.txt", mem_syn, 0, 1151);
        for(i = 0; i < 1152; i = i + 1) begin
            syn_in[i] = mem_syn[i];
        end
        
        $display("\n--- DEBUG READMEMB ---");
        $display("mem_llr[0] = %b", mem_llr[0]);
        $display("mem_llr[2303] = %b", mem_llr[2303]);
        for(i=0; i<2304; i=i+1) if (mem_llr[i] === 5'bx) $display("mem_llr[%0d] IS X!", i);
        for(i=0; i<1152; i=i+1) if (mem_syn[i] === 1'bx) $display("mem_syn[%0d] IS X!", i);
        $display("mem_syn[0] = %b", mem_syn[0]);
        $display("mem_syn[1151] = %b", mem_syn[1151]);
        $display("----------------------\n");

        // Reset
        #100;
        rst = 0;
        #20;
        
        // Start Decoding
        $display("DEBUG_PRE_START: dut.u_llr_ram.mem[1][0:31] = %08X", dut.u_llr_ram.mem[1][31:0]);
        start = 1;
        #10;
        start = 0;
        
        // Wait for IR interrupt or done
        wait(ir_fail_intr == 1'b1 || ir_success == 1'b1 || done == 1'b1);
        wait(done == 1'b1);
        
        #100;
        $display("==================================================");
        $display("Simulation Finished! Decoding %s", ir_success ? "SUCCESS" : "FAILED");
        $display("First 16 Bytes of Codeword Output:");
        $write("HEX: ");
        for(i = 0; i < 16; i = i + 1) begin
            $write("%02X ", ldpc_res_out[i*8 +: 8]);
        end
        $display("");
        
        // Dump the full decoded information key (first 1152 bits / 144 bytes) to file
        begin
            f_out = $fopen("D:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/decoded_out.txt", "w");
            for(i = 0; i < 2304; i = i + 1) begin
                $fdisplay(f_out, "%b", ldpc_res_out[i]);
            end
            $fclose(f_out);
            $display("Full decoded codeword has been saved to: data/decoded_out.txt");
            
            $display("Full 144-Byte Information Key (Alice's Key):");
            $write("KEY: ");
            for(i = 0; i < 144; i = i + 1) begin
                $write("%02X ", ldpc_res_out[i*8 +: 8]);
                if ((i+1) % 32 == 0) $write("\n     ");
            end
            $display("");
        end
        $display("DEBUG: ldpc_res_out[0:31] (col0 start) = %08X", ldpc_res_out[31:0]);
        $display("DEBUG: ldpc_res_out[96:127] (col1 start) = %08X", ldpc_res_out[127:96]);
        $display("DEBUG: dut.u_llr_ram.mem[0][0:31] = %08X", dut.u_llr_ram.mem[0][31:0]);
        $display("DEBUG: dut.u_llr_ram.mem[1][0:31] = %08X", dut.u_llr_ram.mem[1][31:0]);
        $display("\n==================================================");
        $finish;
    end


    // Monitor internal states for debugging
    integer f_debug;
    initial begin
        f_debug = $fopen("D:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/fpga_debug_row0.txt", "w");
    end
    
    always @(negedge clk) begin
        if (dut.state == 1 && dut.next_state == 2) begin
            $display("DEBUG_POST_LOAD: dut.u_llr_ram.mem[1][0:31] = %08X", dut.u_llr_ram.mem[1][31:0]);
        end
        if (dut.state == 2 && dut.layer_count == 0 && dut.valid_conn && dut.col_count_d1 == 1) begin
            $fdisplay(f_debug, "FPGA LAYER_READ | col=%0d | LLR_in=%0d | C2V_old=%0d | V2C=%0d | V2C_shifted=%0d", 
                      dut.col_count_d1, 
                      $signed(dut.llr_dout[4:0]), 
                      $signed(dut.c2v_old[7:0]), 
                      $signed(dut.v2c_array[10:0]), 
                      $signed(dut.shift_out[10:0]));
        end
        if (dut.state == 4 && dut.layer_count == 0 && dut.valid_conn && dut.col_count_d1 == 1) begin
            $fdisplay(f_debug, "FPGA LAYER_WRITE | col=%0d | C2V_new_shifted=%0d | V2C_shifted_buf=%0d | LLR_new_shifted=%0d | LLR_new_sat=%0d", 
                      dut.col_count_d1,
                      $signed(dut.c2v_new_shifted[7:0]),
                      $signed(dut.v2c_old_shifted_block[10:0]),
                      $signed(dut.llr_new_shifted_array[10:0]),
                      $signed(dut.llr_din_math[4:0]));
        end
    end

    initial begin
        $monitor("Time=%0t | State=%0d | iter=%0d | row=%0d | col=%0d | valid=%b | calc_delay=%0d", 
                 $time, dut.state, dut.iter_count, dut.layer_count, dut.col_count, dut.valid_conn_d2, dut.calc_delay);
    end

endmodule
