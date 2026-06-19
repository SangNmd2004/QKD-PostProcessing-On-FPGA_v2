import os
import sys
import numpy as np
import pandas as pd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')
os.makedirs(DATA_DIR, exist_ok=True)

from qkd_ldpc_sim import load_parity_check_matrix, quantize_llr

N = 2304
K = 1152
NUM_BLOCKS = 2 # S' lAE°á»£ng block cáº§n thiáº¿t cho Vivado simulation (testbench = 2 blocks)
REQUIRED_BITS = N * NUM_BLOCKS

def generate_from_csv():
    csv_file = os.path.join(SCRIPT_DIR, '../../bb84_key_test_FPGA_20260618_161844.csv')
    print(f"Reading CSV: {csv_file}")
    df = pd.read_csv(csv_file)
    
    alice_bits = ""
    bob_bits = ""
    qber_sum = 0
    qber_count = 0
    
    for index, row in df.iterrows():
        if index < 200:
            continue
        alice_bits += str(row['key_alice'])
        bob_bits += str(row['key_bob'])
        qber_sum += float(row['QBER_eff_pct'])
        qber_count += 1
        
        if len(alice_bits) >= REQUIRED_BITS:
            break
            
    if len(alice_bits) < REQUIRED_BITS:
        print(f"Error: CSV file only has {len(alice_bits)} bits, need {REQUIRED_BITS} bits.")
        return
        
    alice_bits = alice_bits[:REQUIRED_BITS]
    bob_bits = bob_bits[:REQUIRED_BITS]
    avg_qber = (qber_sum / qber_count) / 100.0 # Convert % to decimal
    
    print(f"Extracted {REQUIRED_BITS} bits. Average QBER: {avg_qber*100:.2f}%")
    
    # Generate data
    alice_arr = np.array([int(b) for b in alice_bits])
    bob_arr = np.array([int(b) for b in bob_bits])
    
    H = load_parity_check_matrix()
    
    with open(os.path.join(DATA_DIR, 'llr_in.txt'), 'w') as f_llr, \
         open(os.path.join(DATA_DIR, 'syndrome_in.txt'), 'w') as f_syn, \
         open(os.path.join(DATA_DIR, 'expected_out.txt'), 'w') as f_exp:
         
        llr_bytes = []
        syn_bytes = []
        
        for b in range(NUM_BLOCKS):
            alice_blk = alice_arr[b*N : (b+1)*N]
            bob_blk = bob_arr[b*N : (b+1)*N]
            
            # TÃ­nh LLR cho Bob
            # Lá»—i xáº£y ra khi bit 1 nhÆ°ng bÃ¡o 0 vÃ  ngÆ°á»£c láº¡i
            llr = np.zeros(N)
            for i in range(N):
                if bob_blk[i] == 0:
                    llr[i] = np.log((1 - avg_qber) / (avg_qber + 1e-10))
                else:
                    llr[i] = np.log(avg_qber / (1 - avg_qber + 1e-10))
                    
            llr_q = quantize_llr(llr, w=5, frac=2)
            for val in llr_q:
                # Convert signed 5-bit to binary string
                bin_str = format(val & 0x1F, '05b')
                f_llr.write(f"{bin_str}\n")
                llr_bytes.append(val & 0xFF) # Add to bytes for C header
                
            # TÃ­nh Syndrome cho Alice
            syn = np.dot(H, alice_blk) % 2
            
            # Pack 8 bits of syndrome into 1 byte (LSB first to match FPGA AXI-to-Parallel)
            for i in range(0, len(syn), 8):
                byte_val = 0
                for bit in range(8):
                    if i + bit < len(syn):
                        byte_val |= (syn[i + bit] << bit)
                syn_bytes.append(byte_val)
                
            for val in syn:
                f_syn.write(f"{val}\n")
                
            # Káº¿t quáº£ kÃ¬ vá» ng (Expected) phi lÃ  khÃ³a gá»‘c cá»§a Alice (khÃ´ng lá»—i)
            for val in alice_blk:
                f_exp.write(f"{val}\n")
                
    # 3. Ghi ra file test_data.h
    llr_size = len(llr_bytes)
    syn_size = len(syn_bytes)
    out_file = os.path.join(SCRIPT_DIR, '../../vitis_src/test_data.h')
    with open(out_file, "w") as f:
        f.write("/*\n * AUTO-GENERATED TEST VECTORS FROM CSV FSO DATA\n")
        f.write(f" * QBER: {avg_qber*100:.2f}%\n")
        f.write(" */\n\n")
        f.write("#ifndef TEST_DATA_H\n")
        f.write("#define TEST_DATA_H\n\n")
        f.write(f"#define LLR_ARRAY_SIZE {llr_size}\n")
        f.write(f"#define SYN_ARRAY_SIZE {syn_size}\n\n")
        f.write("// Real LLR data derived from Bob's Sifted Key\n")
        f.write("unsigned char llr_data[LLR_ARRAY_SIZE] = {\n")
        for i, b in enumerate(llr_bytes):
            f.write(f"0x{b:02X}, ")
            if (i+1) % 16 == 0: f.write("\n")
        f.write("};\n\n")
        f.write("// Real Syndrome data derived from Alice's Raw Key\n")
        f.write("unsigned char syn_data[SYN_ARRAY_SIZE] = {\n")
        for i, b in enumerate(syn_bytes):
            f.write(f"0x{b:02X}, ")
            if (i+1) % 16 == 0: f.write("\n")
        f.write("};\n\n")
        f.write("#endif // TEST_DATA_H\n")
                
    print("Successfully generated llr_in.txt, syndrome_in.txt, and expected_out.txt from FSO CSV data!")
    print(f"Successfully generated C header: {out_file}")

if __name__ == "__main__":
    generate_from_csv()
