#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xscugic.h"
#include "xil_cache.h"
#include "test_data.h" // Sinh ra từ Python script

// Instance Pointers cho các ngoại vi
XAxiDma dma_llr;
XAxiDma dma_syn_key;
XGpio gpio;
XScuGic intc;

// Buffers trong DDR RAM (Phải chia vạch rõ ràng để không dẫm đạp lên nhau)
u8 *llr_buffer = (u8*) 0x10000000;
u8 *syn_buffer = (u8*) 0x10100000;
u8 *key_buffer = (u8*) 0x10200000;

// =======================================================
// INTERRUPT SERVICE ROUTINE (ISR)
// Bắt cờ ir_fail_intr từ phần cứng
// =======================================================
void ir_fail_isr(void *CallbackRef) {
    xil_printf("\r\n[INTERRUPT] HW Interrupt Asserted! ir_fail_intr = 1\r\n");
    xil_printf("[ZYNQ_PS] Lỗi giải mã! Đóng băng Hệ thống Lượng Tử. Tiến hành Blind Reconciliation...\r\n");
    
    // Ở hệ thống thực tế, PS sẽ tính toán hội chứng mở rộng ở đây. 
    // Trong file mô phỏng này, ta gởi lại chính Syndrome cũ (Fake Data)
    Xil_DCacheFlushRange((UINTPTR)syn_buffer, SYN_ARRAY_SIZE);
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)syn_buffer, SYN_ARRAY_SIZE, XAXIDMA_DMA_TO_DEVICE);
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DMA_TO_DEVICE)) {}
    xil_printf("[ZYNQ_PS] Nạp xong ma trận mở rộng. Đang gọi mạch PL chạy tiếp...\r\n");

    // Đá tín hiệu resume_decoding (Chân GPIO2_Output, Bit 4)
    // Cấu trúc bit: [0]: rst, [2:1]: code_rate, [3]: puncture_en, [4]: resume_decoding
    u32 gpio_val = XGpio_DiscreteRead(&gpio, 2);
    XGpio_DiscreteWrite(&gpio, 2, gpio_val | 0x10); // Bật bit 4 lên 1
    
    // Đợi 1 chút (Khoảng vài chục chu kỳ máy)
    for(volatile int i=0; i<1000; i++);
    
    XGpio_DiscreteWrite(&gpio, 2, gpio_val & ~0x10); // Hạ bit 4 xuống 0
    xil_printf("[ZYNQ_PS] Phục hồi giải mã thành công!\r\n");
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
    // Giải phóng Reset, Bật Bit[3] = 1 (Puncture_en = 1) -> 0x08
    XGpio_DiscreteWrite(&gpio, 2, 0x08); 

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
    Xil_DCacheFlushRange((UINTPTR)key_buffer, 32); // Key Output = 256 bits = 32 bytes
    
    // =======================================================
    // KỊCH BẢN 1: GỬI LLR VÀ SYNDROME & CHỜ SECRET KEY
    // =======================================================
    xil_printf("\r\n[1] Starting Privacy Amplification Listen Channel...\r\n");
    // Ép kênh S2MM (Receive) của DMA 1 há mồm chờ Secret Key 32 bytes đổ về.
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)key_buffer, 32, XAXIDMA_DEVICE_TO_DMA);

    xil_printf("[2] Streaming %d bytes of LLR & %d bytes of Syndrome...\r\n", LLR_ARRAY_SIZE, SYN_ARRAY_SIZE);
    XAxiDma_SimpleTransfer(&dma_llr, (UINTPTR)llr_buffer, LLR_ARRAY_SIZE, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)syn_buffer, SYN_ARRAY_SIZE, XAXIDMA_DMA_TO_DEVICE);
    
    while (XAxiDma_Busy(&dma_llr, XAXIDMA_DMA_TO_DEVICE)) {}
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DMA_TO_DEVICE)) {}
    xil_printf("[2] Data injected into FPGA Pipeline successfully.\r\n");

    // =======================================================
    // KỊCH BẢN 2: LẮNG NGHE NGẮT (INTERRUPT SẼ TỰ KÍCH HOẠT) VÀ ĐỢI KEY
    // =======================================================
    xil_printf("\r\n[3] Waiting for Toeplitz Hashing Algorithm (NTT Core) to finish...\r\n");
    
    // Vòng lặp kẹt ở đây để đợi mảng S2MM nhận đủ 32 bytes Key
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DEVICE_TO_DMA)) {
        // Có thể đọc GPIO Channel 1 ở đây để in trạng thái pa_active ra màn hình nếu muốn
    }
    
    // Vô hiệu hóa cache chỗ này để bắt CPU ARM đọc dữ liệu MỚI TỪ RAM, thay vì L1 Cache cũ.
    Xil_DCacheInvalidateRange((UINTPTR)key_buffer, 32);
    
    xil_printf("\r\n=================================================\r\n");
    xil_printf("[SUCCESS] 256-BIT SECRET KEY EXTRACTION COMPLETE! \r\n");
    xil_printf("=================================================\r\n");
    
    xil_printf("HEX DUMP: 0x");
    for(int i=0; i<32; i++) {
        xil_printf("%02X", key_buffer[i]);
    }
    xil_printf("\r\n");
    
    xil_printf("\r\n--- HALT ---\r\n");
    cleanup_platform();
    return 0;
}
