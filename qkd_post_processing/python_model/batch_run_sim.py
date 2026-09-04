import os
import subprocess
import numpy as np
import pandas as pd
import math
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(SCRIPT_DIR)
from qkd_ldpc_sim import load_parity_check_matrix, quantize_llr

N = 2304
K = 1152

def generate_block(qber_target, block_index=0):
    # 1. Generate valid RS Codeword (112 info bytes -> 144 codeword bytes)
    # To keep some randomness based on the block, we use the block index
    np.random.seed(12345 + block_index)
    
    import reedsolo
    # Generate 112 random information bytes
    info_bytes = bytes([np.random.randint(0, 256) for _ in range(112)])
    rs = reedsolo.RSCodec(32) # N=255, K=223 (shortened to 144, 112)
    rs_codeword = rs.encode(info_bytes) # 144 bytes
    
    # Convert to bit array
    x_new = []
    for b in rs_codeword:
        for i in range(8):
            x_new.append((b >> i) & 1)
            
    # Pad with 0s for the remaining 1152 parity bits to make it 2304 bits total
    x_new += [0] * 1152
    alice_blk = np.array(x_new)
    bob_blk = np.copy(alice_blk)
    
    # Inject exact number of errors
    num_errors = int((qber_target / 100.0) * N)
    
    np.random.seed(42 + block_index) # different seed per block
    flip_indices = np.random.choice(N, num_errors, replace=False)
    bob_blk[flip_indices] = 1 - bob_blk[flip_indices]
    
    mismatch = np.sum(alice_blk != bob_blk)
    actual_qber = mismatch / N * 100
    
    H = load_parity_check_matrix(rate="1/2")
    
    DATA_DIR = os.path.join(SCRIPT_DIR, '../data')
    os.makedirs(DATA_DIR, exist_ok=True)
    
    with open(os.path.join(DATA_DIR, f'llr_in_{block_index}.txt'), 'w') as f_llr, \
         open(os.path.join(DATA_DIR, f'syndrome_in_{block_index}.txt'), 'w') as f_syn, \
         open(os.path.join(DATA_DIR, f'err_syndrome_in_{block_index}.txt'), 'w') as f_err_syn, \
         open(os.path.join(DATA_DIR, f'expected_out_{block_index}.txt'), 'w') as f_exp:
         
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
            
        syn = np.dot(H, alice_blk) % 2
        
        if len(syn) < 1536:
            syn_padded = np.pad(syn, (0, 1536 - len(syn)), 'constant')
        else:
            syn_padded = syn[:1536]
            
        for val in syn_padded:
            f_syn.write(f"{val}\n")
            
        err_syn = np.dot(H, (alice_blk ^ bob_blk)) % 2
        
        if len(err_syn) < 1536:
            err_syn_padded = np.pad(err_syn, (0, 1536 - len(err_syn)), 'constant')
        else:
            err_syn_padded = err_syn[:1536]
            
        for val in err_syn_padded:
            f_err_syn.write(f"{val}\n")
            
        for val in alice_blk:
            f_exp.write(f"{val}\n")
            
    return mismatch, actual_qber

if __name__ == "__main__":
    qbers_to_test = [2.0, 3.0, 4.0, 5.0, 6.0]
    for i, qber in enumerate(qbers_to_test):
        mismatch, actual_qber = generate_block(qber, block_index=i)
        print(f"Generated Block {i} - Target QBER: {qber}%, Actual QBER: {actual_qber:.2f}% ({mismatch} errors)")
        
    print("\n" + "="*60)
    print(" BATCH DATA GENERATION COMPLETED")
    print(" 5 block test vectors have been generated in data/ folder.")
    print(" You can now run tb_hw_co_design.v in Vivado.")
    print("="*60)
