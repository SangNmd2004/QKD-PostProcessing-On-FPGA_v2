import os
import sys
import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')
os.makedirs(DATA_DIR, exist_ok=True)

import math
from qkd_ldpc_sim import load_parity_check_matrix, quantize_llr

N = 2304
K = 1152
NUM_BLOCKS = 10 # 10 blocks as requested

def generate_from_csv():
    # Use the clean FPGA CSV as the source
    csv_file = os.path.join(os.path.dirname(__file__), '../../bb84_key_test_FPGA_20260618_161844.csv')
    print(f"Reading CLEAN CSV for noise injection: {csv_file}")
    df = pd.read_csv(csv_file)
    
    alice_bits = ""
    for index, row in df.iterrows():
        alice_bits += str(row['key_alice'])
        
    alice_arr_full = np.array([int(b) for b in alice_bits])
    
    selected_alice_blocks = []
    selected_bob_blocks = []
    
    print(f"Injecting random noise (4-6% QBER) into {NUM_BLOCKS} blocks...")
    
    np.random.seed(42) # For reproducibility
    
    for b in range(NUM_BLOCKS):
        alice_blk = alice_arr_full[b*N : (b+1)*N]
        bob_blk = np.copy(alice_blk)
        
        # Randomly choose number of errors between 92 (4%) and 138 (6%)
        num_errors = np.random.randint(92, 139)
        
        # Randomly choose positions to flip
        flip_indices = np.random.choice(N, num_errors, replace=False)
        bob_blk[flip_indices] = 1 - bob_blk[flip_indices]
        
        mismatch = np.sum(alice_blk != bob_blk)
        qber = mismatch / N * 100
        
        print(f"  -> Generated Block {b}: {mismatch} errors ({qber:.2f}%)")
        selected_alice_blocks.append(alice_blk)
        selected_bob_blocks.append(bob_blk)
        
    alice_arr = np.concatenate(selected_alice_blocks)
    bob_arr = np.concatenate(selected_bob_blocks)
    
    H = load_parity_check_matrix(rate="1/2")
    
    with open(os.path.join(DATA_DIR, 'llr_in.txt'), 'w') as f_llr, \
         open(os.path.join(DATA_DIR, 'syndrome_in.txt'), 'w') as f_syn, \
         open(os.path.join(DATA_DIR, 'expected_out.txt'), 'w') as f_exp:
         
        llr_bytes = []
        syn_bytes = []
        
        for b in range(NUM_BLOCKS):
            alice_blk = selected_alice_blocks[b]
            bob_blk = selected_bob_blocks[b]
            
            actual_mismatch = np.sum(alice_blk != bob_blk)
            print(f"Block {b}: ACTUAL mismatch bits to simulate: {actual_mismatch}")
            
            # TÍNH LLR CHUẨN CHO FIXED-POINT LDPC
            llr_mag = 2.7
            
            llr = np.zeros(N)
            for i in range(N):
                if bob_blk[i] == 0:
                    llr[i] = llr_mag 
                else:
                    llr[i] = -llr_mag
                    
            llr_q = quantize_llr(llr, w=8, frac=2)
            for val in llr_q:
                bin_str = format(val & 0xFF, '08b')
                f_llr.write(f"{bin_str}\n")
                llr_bytes.append(val & 0xFF)
                
            syn = np.dot(H, alice_blk) % 2
            
            if len(syn) < 1152:
                syn_padded = np.pad(syn, (0, 1152 - len(syn)), 'constant')
            else:
                syn_padded = syn[:1152]
            
            for i in range(0, len(syn_padded), 8):
                byte_val = 0
                for bit in range(8):
                    if i + bit < len(syn_padded):
                        byte_val |= (syn_padded[i + bit] << bit)
                syn_bytes.append(byte_val)
                
            for val in syn_padded:
                f_syn.write(f"{val}\n")
                
            for val in alice_blk:
                f_exp.write(f"{val}\n")
                
    # 3. Ghi ra file test_data.h
    llr_size = len(llr_bytes)
    syn_size = len(syn_bytes)
    out_file = os.path.join(SCRIPT_DIR, '../../vitis_src/test_data.h')
    with open(out_file, "w") as f:
        f.write("/*\n * AUTO-GENERATED TEST VECTORS FROM CSV FSO DATA (QBER < 6%)\n")
        f.write(" */\n\n")
        f.write("#ifndef TEST_DATA_H\n")
        f.write("#define TEST_DATA_H\n\n")
        f.write(f"#define LLR_ARRAY_SIZE {llr_size}\n")
        f.write(f"#define SYN_ARRAY_SIZE {syn_size}\n\n")
        f.write("unsigned char llr_data[LLR_ARRAY_SIZE] = {\n")
        for i, b in enumerate(llr_bytes):
            f.write(f"0x{b:02X}, ")
            if (i+1) % 16 == 0: f.write("\n")
        f.write("};\n\n")
        f.write("unsigned char syn_data[SYN_ARRAY_SIZE] = {\n")
        for i, b in enumerate(syn_bytes):
            f.write(f"0x{b:02X}, ")
            if (i+1) % 16 == 0: f.write("\n")
        f.write("};\n\n")
        f.write("#endif // TEST_DATA_H\n")
                
    print("Successfully generated llr_in.txt, syndrome_in.txt, and expected_out.txt from FSO CSV data!")

if __name__ == "__main__":
    generate_from_csv()
