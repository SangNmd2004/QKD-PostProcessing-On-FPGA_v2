#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xscugic.h"
#include "xil_cache.h"
#include "test_data.h" 

// =======================================================
// INSTANCE POINTERS
// =======================================================
XAxiDma dma_llr;
XAxiDma dma_syn_key;
XGpio gpio;
XScuGic intc;

// =======================================================
// MEMORY MAPPING (DDR)
// =======================================================
u8 *llr_buffer = (u8*) 0x10000000;
u8 *syn_buffer = (u8*) 0x10100000;
u8 *key_buffer = (u8*) 0x10200000;

// =======================================================
// GLOBAL STATE VARIABLES
// =======================================================
volatile int hw_reported_fail = 0;
volatile int current_sw_rate = 2; // 2: 3/4, 1: 2/3, 0: 1/2
volatile int isr_handling_in_progress = 0;

// =======================================================
// INTERRUPT SERVICE ROUTINE (ISR)
// Xử lý sự kiện Parity Check thất bại (ir_fail_intr)
// =======================================================
void ir_fail_isr(void *CallbackRef) {
    // Ngăn chặn ngắt gọi lồng nhau
    if (isr_handling_in_progress) return;
    isr_handling_in_progress = 1;
    hw_reported_fail = 1;

    xil_printf("\r\n>>> [INTERRUPT] HW reported FAILED parity check! (ir_fail_intr = 1)\r\n");

    if (current_sw_rate > 0) {
        current_sw_rate--;
        u32 logical_syn_bytes = (current_sw_rate == 1) ? 96 : 144;
        
        xil_printf(">>> [ZYNQ_PS] Initiating Blind Reconciliation. Lowering Code Rate. Injecting %lu bytes Syndrome...\r\n", logical_syn_bytes);
        
        // Bơm thêm Syndrome vào DMA (Hardware luôn nhận 144 bytes và tự cắt bớt)
        Xil_DCacheFlushRange((UINTPTR)syn_buffer, 144);
        XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)syn_buffer, 144, XAXIDMA_DMA_TO_DEVICE);
        while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DMA_TO_DEVICE)) {}
        
        // Kích xung resume_decoding (Chân GPIO2_Output, Bit 4)
        u32 gpio_val = XGpio_DiscreteRead(&gpio, 2);
        XGpio_DiscreteWrite(&gpio, 2, gpio_val | 0x10); 
        for(volatile int i=0; i<5000; i++); // Delay nhỏ để xung ổn định
        XGpio_DiscreteWrite(&gpio, 2, gpio_val & ~0x10); 
        
        xil_printf(">>> [ZYNQ_PS] Sent resume_decoding. Hardware is processing...\r\n");
    } else {
        xil_printf(">>> [ZYNQ_PS] WARNING: Rate is already at 1/2 limit! Cannot reconcile further.\r\n");
    }
    isr_handling_in_progress = 0;
}

// =======================================================
// MAIN ROUTINE
// =======================================================
int main() {
    init_platform();
    xil_printf("\r\n=================================================\r\n");
    xil_printf("     QKD POST-PROCESSING ACCELERATOR (VITIS)     \r\n");
    xil_printf("=================================================\r\n");

    int Status;

    // 1. KHỞI TẠO GPIO
    xil_printf("[-] Initializing GPIO...\r\n");
    Status = XGpio_Initialize(&gpio, XPAR_AXI_GPIO_0_DEVICE_ID);
    if (Status != XST_SUCCESS) { xil_printf("GPIO Init Failed\r\n"); return XST_FAILURE; }
    
    XGpio_SetDataDirection(&gpio, 1, 0xFF); // Channel 1: Input
    XGpio_SetDataDirection(&gpio, 2, 0x00); // Channel 2: Output
    
    // Reset Hardware LDPC
    XGpio_DiscreteWrite(&gpio, 2, 0x01);
    for(volatile int i=0; i<50000; i++);
    XGpio_DiscreteWrite(&gpio, 2, (2 << 1)); // Set Rate = 3/4 (Code 2) & Release Reset

    // 2. KHỞI TẠO AXI DMA
    xil_printf("[-] Initializing AXI DMAs...\r\n");
    XAxiDma_CfgInitialize(&dma_llr, XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID));
    XAxiDma_CfgInitialize(&dma_syn_key, XAxiDma_LookupConfig(XPAR_AXIDMA_1_DEVICE_ID));
    
    XAxiDma_IntrDisable(&dma_llr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&dma_llr, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_IntrDisable(&dma_syn_key, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    XAxiDma_IntrDisable(&dma_syn_key, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);

    // 3. KHỞI TẠO NGẮT CỨNG (GIC)
    xil_printf("[-] Configuring Hardware Interrupts...\r\n");
    XScuGic_Config *intc_cfg = XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
    XScuGic_CfgInitialize(&intc, intc_cfg, intc_cfg->CpuBaseAddress);
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, &intc);
    Xil_ExceptionEnable();
    
    // Đăng ký ngắt ir_fail_intr
    XScuGic_Connect(&intc, 61, (Xil_InterruptHandler)ir_fail_isr, NULL); // Thay 61 bằng ID ngắt tương ứng trong Block Design
    XScuGic_Enable(&intc, 61);

    // 4. LOAD DỮ LIỆU
    xil_printf("[-] Loading Test Vectors to RAM...\r\n");
    memcpy(llr_buffer, llr_data, LLR_ARRAY_SIZE);
    memcpy(syn_buffer, syn_data, SYN_ARRAY_SIZE);

    Xil_DCacheFlushRange((UINTPTR)llr_buffer, LLR_ARRAY_SIZE);
    Xil_DCacheFlushRange((UINTPTR)syn_buffer, SYN_ARRAY_SIZE);
    memset(key_buffer, 0, 288);
    Xil_DCacheFlushRange((UINTPTR)key_buffer, 288);
    
    // 5. CHẠY VÒNG LẶP CHO BLOCK 1
    // (Vì mảng dữ liệu sinh ra bởi Python hiện tại có 2 block, chúng ta sẽ test 1 block chuẩn)
    xil_printf("\r\n=================================================\r\n");
    xil_printf("             PROCESSING LDPC BLOCK                 \r\n");
    xil_printf("=================================================\r\n");
    
    hw_reported_fail = 0;
    current_sw_rate = 2; // Bắt đầu ở Rate 3/4
    
    // DMA chờ 288 bytes Key (Bypass Hash)
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)key_buffer, 288, XAXIDMA_DEVICE_TO_DMA);

    // Bơm 2304 bytes LLR và 144 bytes Syndrome (Initial Rate 3/4)
    XAxiDma_SimpleTransfer(&dma_llr, (UINTPTR)llr_buffer, 2304, XAXIDMA_DMA_TO_DEVICE);
    XAxiDma_SimpleTransfer(&dma_syn_key, (UINTPTR)syn_buffer, 144, XAXIDMA_DMA_TO_DEVICE);
    
    while (XAxiDma_Busy(&dma_llr, XAXIDMA_DMA_TO_DEVICE)) {}
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DMA_TO_DEVICE)) {}
    xil_printf("[-] Data injected! Waiting for LDPC convergence...\r\n");

    // Lắng nghe DMA Receive (S2MM) hoàn tất
    int timeout = 0;
    while (XAxiDma_Busy(&dma_syn_key, XAXIDMA_DEVICE_TO_DMA)) {
        timeout++;
        if (timeout > 50000000) {
            xil_printf(">>> [FATAL ERROR] DMA Timeout! Hardware stalled or Trapping Set limit reached.\r\n");
            break;
        }
    }
    
    Xil_DCacheInvalidateRange((UINTPTR)key_buffer, 288);
    
    xil_printf("\r\n=================================================\r\n");
    if (hw_reported_fail && current_sw_rate == 0) {
        xil_printf("[WARNING] Hardware Status: FAILED (Limit Reached or Parity Oscillation)\r\n");
        xil_printf("          Check Software Verification (Reed-Solomon) to confirm if Sifted Key is perfect.\r\n");
    } else {
        xil_printf("[SUCCESS] Hardware Status: PERFECT CONVERGENCE!\r\n");
    }

    xil_printf("Decoded Sifted Key (First 16 Bytes / 144 Bytes):\r\n");
    for (int i = 0; i < 16; i++) {
        xil_printf("%02X ", key_buffer[i]);
    }
    xil_printf("...\r\n");
    
    xil_printf("\r\n--- HALT ---\r\n");
    cleanup_platform();
    return 0;
}
