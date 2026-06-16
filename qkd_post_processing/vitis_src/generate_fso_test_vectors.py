import os
import sys
import numpy as np

# Thêm đường dẫn tới python_model để dùng lại hàm sinh ma trận H và lượng tử hóa LLR
sys.path.append(os.path.join(os.path.dirname(__file__), '../python_model'))
from qkd_ldpc_sim import load_parity_check_matrix, quantize_llr

# ============================================================
# CẤU HÌNH HỆ THỐNG ZYNQ (POST-PROCESSING)
# ============================================================
LDPC_BLOCK_SIZE = 2304
NUM_BLOCKS = 2
REQUIRED_BITS = LDPC_BLOCK_SIZE * NUM_BLOCKS

# ============================================================
# MÔ PHỎNG MẠCH DE1 (QUANTUM TRANSMISSION OVER FSO)
# ============================================================
def simulate_fso_transmission(n_required, alpha=4.198, beta=2.269, fade_thresh=38, seed=42):
    """
    Mô phỏng kênh truyền Gamma-Gamma (Level 3 - Moderate Turbulence)
    Sinh ra đủ số lượng bit hợp lệ (Sifted Key) cho Post-Processing.
    """
    rng = np.random.RandomState(seed)
    
    alice_sifted = []
    bob_sifted = []
    error_count = 0
    total_pulses = 0
    
    print(f"[DE1 Sim] Simulating FSO transmission (Level 3)...")
    
    while len(alice_sifted) < n_required:
        total_pulses += 1
        
        # 1. Tính toán suy hao khí quyển (Irradiance)
        x = rng.gamma(alpha, 1.0 / alpha)
        y = rng.gamma(beta, 1.0 / beta)
        irr_hw = min(int((x * y) * 128), 255)
        
        # 2. Tạo photon với hệ cơ sở ngẫu nhiên (BB84)
        ad = rng.randint(0, 2)
        ab = rng.randint(0, 2)
        bb = rng.randint(0, 2)
        
        # 3. Kênh truyền vật lý
        if irr_hw < fade_thresh:
            continue # Deep fade -> Mất photon
            
        # 4. Sifting (So khớp cơ sở)
        if ab == bb: # Sifting thành công
            alice_sifted.append(ad)
            # Ở môi trường thật, ngoài fade vẫn có thể có error do nhiễu detector,
            # Ta thêm một lượng nhiễu nền nhỏ (VD: 3% QBER nền)
            if rng.random() < 0.03: 
                bob_sifted.append(1 - ad)
                error_count += 1
            else:
                bob_sifted.append(ad)
                
    qber = error_count / n_required
    print(f"[DE1 Sim] Transmitted {total_pulses} pulses. Lost {total_pulses - n_required} due to deep fade.")
    print(f"[DE1 Sim] Collected {n_required} valid Sifted Key bits. Effective QBER = {qber*100:.2f}%")
    
    return np.array(alice_sifted), np.array(bob_sifted), qber

# ============================================================
# TẠO TEST VECTOR CHO ZYNQ (POST-PROCESSING)
# ============================================================
def generate_vitis_header(alice_sifted, bob_sifted, qber):
    print(f"\n[Zynq Sim] Calculating LLR and Syndrome from DE1 data...")
    
    # 1. Biến đổi bit của Bob thành xác suất LLR (BPSK mapping)
    llrs_float = np.where(bob_sifted == 0, 2.0, -2.0)
    llrs_quant = quantize_llr(llrs_float)
    
    # Ở C, mỗi byte = 1 phần tử
    llr_bytes = [int(val) & 0xFF for val in llrs_quant]
    
    # 2. Tính Syndrome từ bit gốc của Alice
    H = load_parity_check_matrix()
    
    # Do H matrix thiết kế cho 1 block 2304 bit, ta phải chia đôi mảng 4608 bit
    syndrome_1 = np.dot(H, alice_sifted[:2304]) % 2
    syndrome_2 = np.dot(H, alice_sifted[2304:]) % 2
    syndrome = np.concatenate((syndrome_1, syndrome_2))
    
    # Mã hóa Syndrome thành từng byte (mỗi byte chứa 8 bit syndrome)
    syn_bytes = np.packbits(syndrome)
    
    # 3. Ghi ra file test_data.h
    llr_size = len(llr_bytes)
    syn_size = len(syn_bytes)
    
    out_file = "test_data.h"
    with open(out_file, "w") as f:
        f.write("/*\n * AUTO-GENERATED TEST VECTORS FROM FSO SIMULATION\n")
        f.write(f" * Source: DE1 Gamma-Gamma Emulator (Level 3)\n")
        f.write(f" * QBER: {qber*100:.2f}%\n")
        f.write(" */\n\n")
        f.write("#ifndef TEST_DATA_H\n")
        f.write("#define TEST_DATA_H\n\n")
        
        f.write(f"#define LLR_ARRAY_SIZE {llr_size}\n")
        f.write(f"#define SYN_ARRAY_SIZE {syn_size}\n\n")
        
        f.write("// Real LLR data derived from Bob's Sifted Key\n")
        f.write("unsigned char llr_data[LLR_ARRAY_SIZE] = {\n")
        for i, b in enumerate(llr_bytes):
            f.write(f"0x{b:02X}, ")
            if (i+1) % 16 == 0:
                f.write("\n")
        f.write("};\n\n")
        
        f.write("// Real Syndrome data derived from Alice's Raw Key\n")
        f.write("unsigned char syn_data[SYN_ARRAY_SIZE] = {\n")
        for i, b in enumerate(syn_bytes):
            f.write(f"0x{b:02X}, ")
            if (i+1) % 16 == 0:
                f.write("\n")
        f.write("};\n\n")
        
        f.write("#endif // TEST_DATA_H\n")
        
    print(f"[Zynq Sim] Successfully exported {out_file}!")

if __name__ == "__main__":
    alice_bits, bob_bits, final_qber = simulate_fso_transmission(REQUIRED_BITS)
    generate_vitis_header(alice_bits, bob_bits, final_qber)
