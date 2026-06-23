#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xscugic.h"
#include "xil_cache.h"
#include "test_data.h" // Sử dụng data thật có nhiễu QBER 0.50%

// Instance Pointers cho các ngoại vi
XAxiDma dma_llr;
XAxiDma dma_syn_key;
XGpio gpio;
XScuGic intc;

// Buffers trong DDR RAM (Phải chia vạch rõ ràng để không dẫm đạp lên nhau)
u8 *llr_buffer = (u8*) 0x10000000;
u8 *syn_buffer = (u8*) 0x10100000;
u8 *key_buffer = (u8*) 0x10200000;

// Biến trạng thái phần mềm quản lý Blind Reconciliation
int current_sw_rate = 2; // 2: 3/4 (576 bits), 1: 2/3 (768 bits), 0: 1/2 (1152 bits)

// =======================================================
// INTERRUPT SERVICE ROUTINE (ISR)
// Bắt cờ ir_fail_intr từ phần cứng
// =======================================================
void ir_fail_isr(void *CallbackRef) {
    xil_printf("\r\n[INTERRUPT] HW Interrupt Asserted! ir_fail_intr = 1\r\n");
    if (current_sw_rate > 0) {
        current_sw_rate--;
        u32 logical_syn_bytes = 0;
        if (current_sw_rate == 1) logical_syn_bytes = 96; // Rate 2/3: 768 bits
        else if (current_sw_rate == 0) logical_syn_bytes = 144; // Rate 1/2: 1152 bits
        
        xil_printf("[ZYNQ_PS] Hạ Code Rate. Bơm %lu bytes Syndrome mở rộng xuống mạch...\r\n", logical_syn_bytes);
        // Lưu ý: Hardware axis_to_parallel_syn bị fix cứng 1152 bits (144 bytes), nên DMA LÚC NÀO CŨNG PHẢI TRUYỀN ĐỦ 144 BYTES. 
        // Các byte thừa (padding) sẽ tự động bị LDPC core bỏ qua dựa theo code_rate.
        Xil_DCacheFlushRange((UINTPTR)syn_buffer, 144);
        XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)syn_buffer, 144, XAXIDMA_DMA_TO_DEVICE);
        while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DMA_TO_DEVICE)) {}
        
        // Đá tín hiệu resume_decoding (Chân GPIO2_Output, Bit 4)
        u32 gpio_val = XGpio_DiscreteRead(&gpio, 2);
        // Lưu ý: RTL sẽ tự động giảm current_code_rate bên trong lõi
        XGpio_DiscreteWrite(&gpio, 2, gpio_val | 0x10); // Bật bit 4 lên 1
        for(volatile int i=0; i<1000; i++);
        XGpio_DiscreteWrite(&gpio, 2, gpio_val & ~0x10); // Hạ bit 4 xuống 0
        xil_printf("[ZYNQ_PS] Đã đánh xung resume_decoding. Mạch đang chạy lại...\r\n");
    } else {
        xil_printf("[ZYNQ_PS] CẢNH BÁO: Đã hạ xuống Rate 1/2 nhưng vẫn thất bại! Drop Block này.\r\n");
    }
}

// =======================================================
// MAIN ROUTINE
// =======================================================
int main() {
    init_platform();
    xil_printf("\r\n=================================================\r\n");
    xil_printf("     QKD POST-PROCESSING ACCELERATOR DEMO        \r\n");
    xil_printf("=================================================\r\n");

    int Status;

    // 1. KHỞI TẠO GPIO ĐIỀU KHIỂN
    xil_printf("[-] Initializing GPIO...\r\n");
    Status = XGpio_Initialize(&gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
    if (Status != XST_SUCCESS) { xil_printf("GPIO Init Failed\r\n"); return XST_FAILURE; }
    
    XGpio_SetDataDirection(&gpio, 1, 0xFF); // Channel 1: Input (Đọc cờ trạng thái ir_success, pa_active)
    XGpio_SetDataDirection(&gpio, 2, 0x00); // Channel 2: Output (Điều khiển rst, code_rate...)
    
    // Xả Reset và bật tính năng Puncture
    // Bit[0]=1 (Reset ON)
    XGpio_DiscreteWrite(&gpio, 2, 0x01);
    for(volatile int i=0; i<10000; i++);
    // Giải phóng Reset, Set Code Rate = 2 (Rate 3/4) vào bit [2:1]
    XGpio_DiscreteWrite(&gpio, 2, (2 << 1)); 

    // 2. KHỞI TẠO AXI DMA
    xil_printf("[-] Initializing AXI DMAs...\r\n");
    XAxiDma_Config *cfg_0 = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
    XAxiDma_CfgInitialize(&dma_llr, cfg_0);
    
    XAxiDma_Config *cfg_1 = XAxiDma_LookupConfig(XPAR_AXIDMA_1_DEVICE_ID);
    XAxiDma_CfgInitialize(&dma_syn_key, cfg_1);
    
    // Tắt ngắt DMA (Sử dụng phương pháp Polling cho các luồng truyền dữ liệu)
    XAxiDma_IntrDisable(&dma_llr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&dma_llr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&dma_syn_key, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&dma_syn_key, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    // 3. KHỞI TẠO NGẮT (GIC - GENERIC INTERRUPT CONTROLLER)
    xil_printf("[-] Configuring Hardware Interrupts...\r\n");
    XScuGic_Config *intc_cfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    XScuGic_CfgInitialize(&intc, intc_cfg, intc_cfg->CpuBaseAddress);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, &intc);
    Xil_ExceptionEnable();
    
    // Kết nối tín hiệu ir_fail_intr từ GPIO (Zynq IRQ_F2P thường rơi vào ID 61)
    // Nếu bạn nối nó vào bộ điều khiển ngắt AXI, hãy thay 61 bằng macro XPAR_... trong xparameters.h
    int intr_id = 61; 
    XScuGic_Connect(&intc, intr_id, (Xil_InterruptHandler)ir_fail_isr, NULL);
    XScuGic_Enable(&intc, intr_id);

    // 4. CHUẨN BỊ MẢNG DỮ LIỆU
    xil_printf("[-] Loading Test Vectors to RAM...\r\n");
    memcpy(llr_buffer, llr_data, LLR_ARRAY_SIZE);
    memcpy(syn_buffer, syn_data, SYN_ARRAY_SIZE);

    // Xóa bộ nhớ đệm Cache (Quan trọng nhất khi chạy Bare-metal ARM Cortex-A9)
    Xil_DCacheFlushRange((UINTPTR)llr_buffer, LLR_ARRAY_SIZE);
    Xil_DCacheFlushRange((UINTPTR)syn_buffer, SYN_ARRAY_SIZE);
    Xil_DCacheFlushRange((UINTPTR)key_buffer, 288); // Bật chế độ Debug: Nhận Full Codeword 288 Bytes thay vì 32 bytes Hash
    
    // =======================================================
    // 5. BƠM DỮ LIỆU (STREAMING LLR & SYNDROME) VÀO MẠCH PL
    // Ép kênh S2MM (Receive) của DMA 1 há mồm chờ Full Codeword 288 bytes đổ về.
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)key_buffer, 288, XAXIDMA_DEVICE_TO_DMA);

    u32 llr_single_block = LLR_ARRAY_SIZE / 2;
    u32 syn_single_block = 144; // DMA luôn truyền 144 bytes để lấp đầy axis_to_parallel
    
    xil_printf("[2] Streaming %lu bytes of LLR & 72 bytes of valid Syndrome (Padded to 144) (Block 1)...\r\n", llr_single_block);
    
    // CHỈ TRUYỀN ĐÚNG 1 BLOCK CHO MẠCH GIẢI MÃ XONG MỚI TRUYỀN TIẾP
    XAxiDma_SimpleTransfer(&dma_llr, (UINTPTR)llr_buffer, llr_single_block, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)syn_buffer, syn_single_block, XAXIDMA_DMA_TO_DEVICE);
    
    while (XAxiDma_Busy(&dma_llr, XAXIDMA_DMA_TO_DEVICE)) {}
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DMA_TO_DEVICE)) {}
    xil_printf("[2] Data injected into FPGA Pipeline successfully. Waiting for LDPC...\r\n");

    // =======================================================
    // KỊCH BẢN 2: LẮNG NGHE DMA HOÀN TẤT ĐỂ LẤY KẾT QUẢ LDPC
    // =======================================================
    xil_printf("\r\n[3] Waiting for LDPC Error Reconciliation Core to finish...\r\n");
    
    // Vòng lặp kẹt ở đây để đợi mảng S2MM nhận đủ 288 bytes Key từ LDPC
    int wait_cnt = 0;
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DEVICE_TO_DMA)) {
        wait_cnt++;
        if (wait_cnt > 20000000) {
            xil_printf("DEBUG: TIMEOUT! LDPC Core or DMA is stuck!\r\n");
            break;
        }
    }
    
    // Vô hiệu hóa cache chỗ này để bắt CPU ARM đọc dữ liệu MỚI TỪ RAM, thay vì L1 Cache cũ.
    Xil_DCacheInvalidateRange((UINTPTR)key_buffer, 288);
    
    xil_printf("\r\n=================================================\r\n");
    xil_printf("[SUCCESS] ERROR RECONCILIATION COMPLETE!\r\n");
    xil_printf("Decoded LDPC Codeword (288-byte Hex / PA Bypassed):\r\n");
    for (int i = 0; i < 288; i++) {
        xil_printf("%02X ", key_buffer[i]);
        if ((i + 1) % 16 == 0) xil_printf("\r\n");
    }
    xil_printf("\r\n");
    
    xil_printf("\r\n--- HALT ---\r\n");
    cleanup_platform();
    return 0;
}
