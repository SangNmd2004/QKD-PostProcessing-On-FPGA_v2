`timescale 1ns / 1ps

module tb_core_partially_parallel();

    parameter Zc = 96;
    parameter data_w = 5;
    
    reg clk;
    reg rst;
    reg start;
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
    reg [Zc*data_w-1:0] mem_llr [0:23];
    integer i;

    initial begin
        // Initialize Inputs
        rst = 1;
        start = 0;
        puncture_en = 0;
        resume_decoding = 0;
        llr_in_array = 0;
        
        // Read input LLRs from Python script output
        $readmemh("D:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/input_llr.txt", mem_llr);
        
        // Pack into the 11520-bit array
        for(i = 0; i < 24; i = i + 1) begin
            llr_in_array[i*Zc*data_w +: Zc*data_w] = mem_llr[i];
        end

        // Reset
        #100;
        rst = 0;
        #20;
        
        // Start Decoding
        start = 1;
        #10;
        start = 0;
        
        // Wait for IR interrupt or done
        wait(ir_fail_intr == 1'b1 || ir_success == 1'b1 || done == 1'b1);
        
        #100;
        $display("Simulation Finished!");
        $finish;
    end


    // Monitor internal states for debugging
    integer f_debug;
    initial begin
        f_debug = $fopen("D:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/fpga_debug_row0.txt", "w");
    end
    
    always @(negedge clk) begin
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
