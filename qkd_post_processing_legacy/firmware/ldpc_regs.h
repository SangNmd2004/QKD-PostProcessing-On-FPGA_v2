#ifndef LDPC_REGS_H
#define LDPC_REGS_H

#include <stdint.h>

// ==============================================================
// AE350 AXI4-Lite Address Map (Adjust BASE_ADDR based on Gowin EDA)
// ==============================================================
#define LDPC_BASE_ADDR      0x40000000

#define LDPC_CTRL_REG       (*(volatile uint32_t*)(LDPC_BASE_ADDR + 0x00))
#define LDPC_STAT_REG       (*(volatile uint32_t*)(LDPC_BASE_ADDR + 0x04))

// ==============================================================
// Register Bit Definitions
// ==============================================================
// CTRL_REG Bits
#define CTRL_RATE_MASK      0x03
#define RATE_1_2            0x00
#define RATE_2_3            0x01
#define RATE_3_4            0x02

#define CTRL_RESUME_BIT     (1 << 2) // Write 1 to pulse resume
#define CTRL_HASH_OK_BIT    (1 << 3) // Write 1 to pulse hash_ok
#define CTRL_HASH_FAIL_BIT  (1 << 4) // Write 1 to pulse hash_fail
#define CTRL_PUNCTURE_BIT   (1 << 5) 

// STAT_REG Bits
#define STAT_IR_SUCCESS_BIT (1 << 0)
#define STAT_IR_FAIL_BIT    (1 << 1)
#define STAT_ITERS_SHIFT    8
#define STAT_ITERS_MASK     0xFF00

// ==============================================================
// Helper Macros
// ==============================================================
#define LDPC_SET_RATE(rate)        (LDPC_CTRL_REG = (LDPC_CTRL_REG & ~CTRL_RATE_MASK) | (rate))
#define LDPC_PULSE_RESUME()        (LDPC_CTRL_REG |= CTRL_RESUME_BIT)
#define LDPC_PULSE_HASH_OK()       (LDPC_CTRL_REG |= CTRL_HASH_OK_BIT)
#define LDPC_PULSE_HASH_FAIL()     (LDPC_CTRL_REG |= CTRL_HASH_FAIL_BIT)

#define LDPC_IS_SUCCESS()          (LDPC_STAT_REG & STAT_IR_SUCCESS_BIT)
#define LDPC_IS_FAIL()             (LDPC_STAT_REG & STAT_IR_FAIL_BIT)
#define LDPC_GET_ITERS()           ((LDPC_STAT_REG & STAT_ITERS_MASK) >> STAT_ITERS_SHIFT)

#endif // LDPC_REGS_H
