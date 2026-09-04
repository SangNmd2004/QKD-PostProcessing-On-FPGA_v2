import os
import sys
import numpy as np
import pandas as pd
from qkd_ldpc_sim import load_parity_check_matrix, quantize_llr

N = 2304
K = 1152

def run():
    csv_file = os.path.join(os.path.dirname(__file__), '../../bb84_key_test_FPGA_20260618_161844.csv')
    df = pd.read_csv(csv_file)
    alice_bits = "".join(df['key_alice'].astype(str).tolist())[:N]
    
    alice_arr = np.array([int(b) for b in alice_bits])
    
    # PERFECT BOB BLK (0 errors)
    bob_arr = alice_arr.copy()
    
    H = load_parity_check_matrix()
    syn = np.dot(H, alice_arr) % 2
    
    # Check parity manually
    syn_bob = np.dot(H, bob_arr) % 2
    if not np.array_equal(syn, syn_bob):
        print("Math error in Python!")
        return

    # LLRs for 0 errors
    llr = np.zeros(N)
    for i in range(N):
        if bob_arr[i] == 0:
            llr[i] = 15 # Max positive
        else:
            llr[i] = -15 # Max negative
            
    llr_q = quantize_llr(llr, w=5, frac=0)
    
    # Pack Syndrome
    syn_bytes = []
    for i in range(0, K, 8):
        byte_val = 0
        for bit in range(8):
            if i + bit < K:
                byte_val |= (syn[i + bit] << bit)
        syn_bytes.append(byte_val)
        
    # Pack LLR
    llr_bytes = []
    for val in llr_q:
        llr_bytes.append(val & 0xFF)
        
    # Generate C header
    out_file = os.path.join(os.path.dirname(__file__), '../../vitis_src/test_data_perfect.h')
    with open(out_file, 'w') as f:
        f.write('#ifndef TEST_DATA_PERFECT_H\n#define TEST_DATA_PERFECT_H\n\n')
        f.write(f'#define LLR_PERFECT_SIZE {len(llr_bytes)}\n')
        f.write(f'#define SYN_PERFECT_SIZE {len(syn_bytes)}\n\n')
        
        f.write('const unsigned char llr_perfect_data[] = {\n')
        for i in range(0, len(llr_bytes), 16):
            chunk = llr_bytes[i:i+16]
            f.write('    ' + ', '.join(f'0x{b:02X}' for b in chunk) + ',\n')
        f.write('};\n\n')
        
        f.write('const unsigned char syn_perfect_data[] = {\n')
        for i in range(0, len(syn_bytes), 16):
            chunk = syn_bytes[i:i+16]
            f.write('    ' + ', '.join(f'0x{b:02X}' for b in chunk) + ',\n')
        f.write('};\n\n')
        
        f.write('#endif\n')
        
    print(f"test_data_perfect.h generated successfully at {out_file}")

if __name__ == '__main__':
    run()
