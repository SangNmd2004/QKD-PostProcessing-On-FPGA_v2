import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')
os.makedirs(DATA_DIR, exist_ok=True)

# Các tham số QC-LDPC của module hardware
Z = 96
R = 24  # Số cột block
C = 12  # Số hàng block
N = Z * R  # Chiều dài codeword (2304)
K = N - (Z * C) # Chiều dài bản tin (1152)

# LLR Quantization: data_w = 5 bit, Q(5,2) = 1 sign bit, 2 integer, 2 fraction
def quantize_llr(llr, w=5, frac=2):
    max_val = (2**(w-1)) - 1
    min_val = -(2**(w-1))
    
    # Scale to fractional bits
    val = np.round(llr * (2**frac))
    val = np.clip(val, min_val, max_val).astype(int)
    
    # Chuyển sang bù 2 (2's complement) dạng w bit
    return np.where(val < 0, val + (1 << w), val)

def load_parity_check_matrix():
    # Đọc file config để lấy ma trận H
    config_path = os.path.join(SCRIPT_DIR, '../rtl/ir_qc_ldpc/matlinsas_LDPC/core_gen/config')
    H = np.zeros((N - K, N), dtype=int)
    try:
        with open(config_path, 'r') as f:
            lines = f.readlines()
        for i in range(N - K):
            cols = lines[i+2].split()
            for c in cols:
                c = int(c)
                if c != -1:
                    H[i, c] = 1
    except FileNotFoundError:
        print("Warning: config file not found, assuming all-zero syndrome!")
    return H

def generate_test_vector(qber=0.05, code_rate='1/2'):
    """
    Sinh Sifted Key có lỗi lượng tử QBER và Syndrome cho Phase 2 & 3.
    """
    print(f"Generating Syndrome-Based Test Vector with QBER={qber*100}%, Rate={code_rate}")
    
    # 1. Sinh ngẫu nhiên Alice's Key (Bản tin gốc)
    alice_key = np.random.randint(0, 2, N)
    
    # 2. Tính Syndrome S = H * Alice_Key
    H = load_parity_check_matrix()
    syndrome = np.dot(H, alice_key) % 2
    
    # Áp dụng Optimal Puncturing/Disabling theo Code Rate (Grouping and Sorting pattern)
    if code_rate == '2/3':
        # Vô hiệu hóa blocks 0, 2, 4, 11
        for b in [0, 2, 4, 11]:
            syndrome[b*96:(b+1)*96] = 0
    elif code_rate == '3/4':
        # Vô hiệu hóa blocks 0, 2, 4, 7, 9, 11
        for b in [0, 2, 4, 7, 9, 11]:
            syndrome[b*96:(b+1)*96] = 0
    elif code_rate == '5/6':
        # Vô hiệu hóa blocks 0, 2, 3, 4, 5, 7, 9, 11
        for b in [0, 2, 3, 4, 5, 7, 9, 11]:
            syndrome[b*96:(b+1)*96] = 0
    
    # 3. Tạo lỗi lượng tử để sinh Bob's Sifted Key
    error_mask = np.random.rand(N) < qber
    sifted_key = alice_key ^ error_mask
    
    # 4. BPSK mapping cho Bob's LLR (0 -> +2.0, 1 -> -2.0)
    llrs_float = np.where(sifted_key == 0, 2.0, -2.0)
    llrs_quant = quantize_llr(llrs_float)
    
    # 5. Lưu dữ liệu cho Testbench
    # Lưu LLR
    with open(os.path.join(DATA_DIR, 'llr_in.txt'), 'w') as f:
        for val in llrs_quant:
            f.write(f"{val:05b}\n")
            
    # Lưu Syndrome
    with open(os.path.join(DATA_DIR, 'syndrome_in.txt'), 'w') as f:
        for val in syndrome:
            f.write(f"{val:01b}\n")
    
    # Lưu expected result (Alice_Key)
    with open(os.path.join(DATA_DIR, 'expected_out.txt'), 'w') as f:
        for val in alice_key:
            f.write(f"{val}\n")
            
    print(f"Number of errors introduced: {np.sum(error_mask)} / {N}")
    print("Files llr_in.txt, syndrome_in.txt, and expected_out.txt generated in data/")

if __name__ == "__main__":
    generate_test_vector(qber=0.02, code_rate='1/2') # 2% QBER with Rate 1/2
