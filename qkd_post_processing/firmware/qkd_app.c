#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include "ldpc_regs.h"

// Note: These DMA functions are placeholders. You will implement them using 
// the specific Gowin/Andes DMA driver API provided in AndeSight IDE.
extern void dma_start_transfer(uint32_t src_addr, uint32_t dst_addr, uint32_t len_bytes);
extern void dma_wait_complete(void);
extern bool hash_check_2304(uint8_t* key_data);

// Memory buffers (would normally be aligned DDR or SRAM addresses)
#define LLR_BUFFER_ADDR  0x20000000
#define SYN_BUFFER_ADDR  0x20100000
#define KEY_OUTPUT_ADDR  0x20200000

#define LLR_BLOCK_SIZE   2304 // 2304 bytes (if each LLR is packed in 8-bit AXI stream)
#define SYN_RATE34_SIZE  72   // 72 bytes
#define SYN_RATE23_SIZE  24   // Additional 24 bytes (total 96)
#define SYN_RATE12_SIZE  48   // Additional 48 bytes (total 144)

volatile bool ir_interrupt_flag = false;

// Interrupt Service Routine (Mapped via PLIC)
void ldpc_isr_handler(void) {
    if (LDPC_IS_SUCCESS() || LDPC_IS_FAIL()) {
        ir_interrupt_flag = true;
    }
}

/**
 * Perform Blind Reconciliation for a single Block
 */
bool process_qkd_block(uint32_t block_idx) {
    printf("--- Processing Block %d ---\n", block_idx);
    
    // 1. Initial State: Rate 3/4
    LDPC_SET_RATE(RATE_3_4);
    ir_interrupt_flag = false;
    
    // Calculate offsets based on block index
    uint32_t llr_src = LLR_BUFFER_ADDR + (block_idx * LLR_BLOCK_SIZE);
    uint32_t syn_src = SYN_BUFFER_ADDR + (block_idx * 144); 
    
    // Start DMA to push LLRs and first 72 bytes of Syndrome
    dma_start_transfer(llr_src, /* LDPC_LLR_FIFO */ 0x40001000, LLR_BLOCK_SIZE);
    dma_wait_complete();
    dma_start_transfer(syn_src, /* LDPC_SYN_FIFO */ 0x40002000, SYN_RATE34_SIZE);
    dma_wait_complete();
    
    // LDPC automatically starts when both buffers are full
    // Wait for ISR
    while(!ir_interrupt_flag);
    ir_interrupt_flag = false;
    
    // Verify output key hash (DMA pulls key to KEY_OUTPUT_ADDR)
    if (hash_check_2304((uint8_t*)KEY_OUTPUT_ADDR)) {
        LDPC_PULSE_HASH_OK();
        printf("[SUCCESS] Rate 3/4 Converged (Iters: %d)\n", LDPC_GET_ITERS());
        return true;
    } else {
        LDPC_PULSE_HASH_FAIL(); // Triggers hardware ir_fail_intr internally
    }
    
    // 2. Fallback to Rate 2/3
    printf("[FAILED] Rate 3/4. Falling back to Rate 2/3...\n");
    while(!ir_interrupt_flag); // Wait for hardware to assert ir_fail_intr from Hash Fail
    ir_interrupt_flag = false;
    
    LDPC_SET_RATE(RATE_2_3);
    dma_start_transfer(syn_src + SYN_RATE34_SIZE, /* LDPC_SYN_FIFO */ 0x40002000, SYN_RATE23_SIZE);
    dma_wait_complete();
    
    LDPC_PULSE_RESUME();
    
    while(!ir_interrupt_flag);
    ir_interrupt_flag = false;
    
    if (hash_check_2304((uint8_t*)KEY_OUTPUT_ADDR)) {
        LDPC_PULSE_HASH_OK();
        printf("[SUCCESS] Rate 2/3 Converged (Iters: %d)\n", LDPC_GET_ITERS());
        return true;
    } else {
        LDPC_PULSE_HASH_FAIL();
    }
    
    // 3. Fallback to Rate 1/2
    printf("[FAILED] Rate 2/3. Falling back to Rate 1/2...\n");
    while(!ir_interrupt_flag); 
    ir_interrupt_flag = false;
    
    LDPC_SET_RATE(RATE_1_2);
    dma_start_transfer(syn_src + SYN_RATE34_SIZE + SYN_RATE23_SIZE, /* LDPC_SYN_FIFO */ 0x40002000, SYN_RATE12_SIZE);
    dma_wait_complete();
    
    LDPC_PULSE_RESUME();
    
    while(!ir_interrupt_flag);
    ir_interrupt_flag = false;
    
    if (hash_check_2304((uint8_t*)KEY_OUTPUT_ADDR)) {
        LDPC_PULSE_HASH_OK();
        printf("[SUCCESS] Rate 1/2 Converged (Iters: %d)\n", LDPC_GET_ITERS());
        return true;
    } else {
        LDPC_PULSE_HASH_FAIL();
        printf("[FAILED] Block unrecoverable.\n");
        return false;
    }
}

int main() {
    printf("Starting QKD Post-Processing SoC (AE350)...\n");
    
    // Init PLIC and DMA here
    
    // Process 6 Blocks
    for (int i = 0; i < 6; i++) {
        process_qkd_block(i);
    }
    
    printf("Processing Complete.\n");
    return 0;
}
