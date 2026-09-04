`timescale 1ns/1ps

module tb_ir_ldpc;

    parameter data_w = 5;
    parameter mtx_w = 8;
    parameter R = 24;
    parameter C = 12;
    parameter D = 96;

    reg clk;
    reg rst;
    reg en;
    
    // Mảng lưu dữ liệu LLR đầu vào
    reg [data_w-1:0] llr_mem [0:R*D-1];
    
    // Tín hiệu nối với LDPC Core
    reg [R*D*data_w-1:0] l;
    reg [C*R*mtx_w-1:0] mtx;
    wire [R*D-1:0] res;
    wire term;
    wire err;

    // Khởi tạo core tĩnh (Không dùng mtx)
    ldpc_core #(
        .data_w(data_w),
        .mtx_w(mtx_w),
        .R(R),
        .C(C),
        .D(D)
    ) dut (
        .en(en),
        .clk(clk),
        .rst(rst),
        .l(l),
        .mtx(mtx),  // core_static không cần mtx thực sự, truyền 0
        .res(res),
        .term(term),
        .err(err)
    );

    // Xung nhịp
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Quy trình test
    integer i, f;
    integer errors;
    initial begin
        rst = 1;
        en = 0;
        mtx = 0;
        l = 0;
        errors = 0;

        // Đọc dữ liệu LLR từ file sinh bởi Python (Sử dụng đường dẫn tuyệt đối cho Vivado)
        $readmemb("d:/DownloadD/03. Post-Processing-FPGA-QKD-20260508T062156Z-3-001/03. Post-Processing-FPGA-QKD/qkd_post_processing/data/llr_in.txt", llr_mem);
        
        // Đưa dữ liệu LLR vào thanh ghi l (Nối chuỗi)
        for (i = 0; i < R*D; i = i + 1) begin
            l[i*data_w +: data_w] = llr_mem[i];
        end

        #20 rst = 0;
        #10 en = 1;
        
        $display("========================================");
        $display("   Bắt đầu Giải mã QC-LDPC (QKD IR)   ");
        $display("========================================");

        // Chờ kết thúc (term = 1)
        wait(term == 1'b1);
        en = 0;
        
        #10;
        $display("Trạng thái: %s", (err == 1'b0) ? "Thành công (Syndrome = 0)" : "Thất bại (Err = 1)");
        
        // Đếm số bit lỗi (Vì codeword gốc là toàn 0, bất kỳ bit 1 nào cũng là lỗi còn lại)
        for(i = 0; i < R*D; i = i + 1) begin
            if (res[i] != 1'b0) errors = errors + 1;
        end
        
        $display("Số bit lỗi còn lại sau IR: %0d / %0d", errors, R*D);
        $display("========================================");
        $finish;
    end

endmodule
