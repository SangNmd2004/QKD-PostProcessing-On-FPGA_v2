import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')
os.makedirs(DATA_DIR, exist_ok=True)

# Các tham số QC-LDPC của module hardware
Z = 96
R = 24  # Số cột block
C = 16  # Số hàng block
N = Z * R  # Chiều dài codeword (2.54)
K = N - (Z * C) # Chiều dài bản tin (1152)

# LLR Quantization: data_w = 6 bit, Q(6,2) = 1 sign bit, 3 integer, 2 fraction
def quantize_llr(llr, w=6, frac=2):
    max_val = (2**(w-1)) - 1
    min_val = -(2**(w-1))
    
    # Scale to fractional bits
    val = np.round(llr * (2**frac))
    val = np.clip(val, min_val, max_val).astype(int)
    
    # Chuyển sang bù 2 (2's complement) dạng w bit
    return np.where(val < 0, val + (1 << w), val)

def load_parity_check_matrix(rate="3/4"):
    # Base Matrices cho các Rate
    rate_1_2 = [
        [-1, 94, 73, -1, -1, -1, -1, -1, 55, 83, -1, -1,  7,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        [-1, 27, -1, -1, -1, 22, 79,  9, -1, -1, -1, 12, -1,  0,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1],
        [-1, -1, -1, 24, 22, 81, -1, 33, -1, -1, -1,  0, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1, -1, -1],
        [61, -1, 47, -1, -1, -1, -1, -1, 65, 25, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1, -1],
        [-1, -1, 39, -1, -1, -1, 84, -1, -1, 41, 72, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1, -1],
        [-1, -1, -1, -1, 46, 40, -1, 82, -1, -1, -1, 79,  0, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1, -1],
        [-1, -1, 95, 53, -1, -1, -1, -1, -1, 14, 18, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1, -1],
        [-1,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1, -1],
        [80, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1, -1],
        [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0, -1],
        [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,  0],
        [92, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0]
    ]

    rate_2_3 = [
        [ 2, -1, 19, -1, 47, -1, 48, -1, 36, -1, 82, -1, 47, -1, 15, -1, 95,  0, -1, -1, -1, -1, -1, -1],
        [-1, 69, -1, 88, -1, 33, -1,  3, -1, 16, -1, 37, -1, 40, -1, 48, -1,  0,  0, -1, -1, -1, -1, -1],
        [10, -1, 86, -1, 62, -1, 28, -1, 85, -1, 16, -1, 34, -1, 73, -1, -1, -1,  0,  0, -1, -1, -1, -1],
        [-1, 28, -1, 32, -1, 81, -1, 27, -1, 88, -1,  5, -1, 56, -1, 37, -1, -1, -1,  0,  0, -1, -1, -1],
        [23, -1, 29, -1, 15, -1, 30, -1, 66, -1, 24, -1, 50, -1, 62, -1, -1, -1, -1, -1,  0,  0, -1, -1],
        [-1, 30, -1, 65, -1, 54, -1, 14, -1,  0, -1, 30, -1, 74, -1,  0, -1, -1, -1, -1, -1,  0,  0, -1],
        [32, -1,  0, -1, 15, -1, 56, -1, 85, -1,  5, -1,  6, -1, 52, -1,  0, -1, -1, -1, -1, -1,  0,  0],
        [-1,  0, -1, 47, -1, 13, -1, 61, -1, 84, -1, 55, -1, 78, -1, 41, 95, -1, -1, -1, -1, -1, -1,  0]
    ]

    rate_3_4 = [
        [-1, 81, -1, 28, -1, -1, 14, 25, 17, -1, -1, 85, 29, 52, 78, 95, 22, 92,   0,   0,  -1,  -1,  -1,  -1],
        [42, -1, 14, -1, 25, 31, -1, -1, 85, 86, -1, -1, 40, 88, 54, 15, 54,  7,  -1,   0,   0,  -1,  -1,  -1],
        [-1, 53, 73, -1, -1, 64, -1, 39, -1, -1, 48, -1, 54, 74, 31, 83, 47, 41,  -1,  -1,   0,   0,  -1,  -1],
        [43, -1, -1, 86, 52, -1, 89, -1, -1, 71, -1, 39, 58, 44, 28, 53, -1, -1,  -1,  -1,  -1,   0,   0,  -1],
        [-1, 69, -1, -1, -1, 63, -1, 43, -1, 37, 40, -1, 48, -1, 33, 22, 89, 24,   0,  -1,  -1,  -1,   0,   0],
        [62, -1, 60, -1, 46, -1, 34, -1, 48, -1, 67, -1, 13, -1, 35, -1, 66, 11,   0,  -1,  -1,  -1,  -1,   0]
    ]

    if rate == "1/2":
        base_matrix = rate_1_2
    elif rate == "2/3":
        base_matrix = rate_2_3
    elif rate == "3/4":
        base_matrix = rate_3_4
    else:
        base_matrix = rate_1_2
    
    rows = len(base_matrix)
    H = np.zeros((rows * Z, N), dtype=int)
    for r in range(rows):
        for c in range(R):
            shift = base_matrix[r][c]
            if shift != -1:
                # Tạo identity matrix kích thước ZxZ và dịch vòng
                I = np.eye(Z, dtype=int)
                I_shifted = np.roll(I, shift, axis=1)
                H[r*Z:(r+1)*Z, c*Z:(c+1)*Z] = I_shifted
                
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
    
    # 4. BPSK mapping cho Bob's LLR (0 -> +1.75, 1 -> -1.75)
    llrs_float = np.where(sifted_key == 0, 1.75, -1.75)
    llrs_quant = quantize_llr(llrs_float)
    
    # 5. Lưu dữ liệu cho Testbench
    # Lưu LLR
    with open(os.path.join(DATA_DIR, 'llr_in.txt'), 'w') as f:
        for val in llrs_quant:
            f.write(f"{val:06b}\n")
            
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
    generate_test_vector(qber=0.01, code_rate='1/2') # 4% QBER with Rate 1/2






