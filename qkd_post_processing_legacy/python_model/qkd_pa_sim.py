import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')
os.makedirs(DATA_DIR, exist_ok=True)

def extGCD(a, b):
    if a == 0:
        return (b, 0, 1)
    else:
        g, y, x = extGCD(b % a, a)
        return (g, x - (b // a) * y, y)

def modinv(a, m):
    g, x, y = extGCD(a, m)
    if g != 1:
        raise Exception('Modular inverse does not exist')
    else:
        return x % m

# Tham số cấu hình NTT cho N = 512
N = 512
K = 14
# Cần tìm q nguyên tố sao cho q = 1 mod (2N). Chọn q = 12289 (dùng trong NewHope/Kyber)
q = 12289

# Tính căn nguyên thủy bậc 2N
psi = 10302
w = pow(psi, 2, q)
w_inv = modinv(w, q)
n_inv = modinv(N, q)

def bit_reverse(x, bits):
    return int('{:0{width}b}'.format(x, width=bits)[::-1], 2)

def ntt(a, q, w):
    # NTT đơn giản (O(n^2) cho python script để nhanh chóng xác thực)
    A = np.zeros(N, dtype=int)
    for i in range(N):
        for j in range(N):
            A[i] = (A[i] + a[j] * pow(w, (i * j) % N, q)) % q
    return A

def intt(A, q, w_inv, n_inv):
    a = np.zeros(N, dtype=int)
    for i in range(N):
        for j in range(N):
            a[i] = (a[i] + A[j] * pow(w_inv, (i * j) % N, q)) % q
        a[i] = (a[i] * n_inv) % q
    return a

def generate_pa_test_vectors():
    print("Generating Toeplitz Hashing via NTT test vectors...")
    # Sinh Secret Key ảo (Reconciled Key từ khối LDPC, ví dụ 256 bits, pad thành 512)
    key_bits = np.random.randint(0, 2, N//2)
    key_padded = np.pad(key_bits, (0, N//2), 'constant')
    
    # Sinh Toeplitz Vector (random bits)
    toep_bits = np.random.randint(0, 2, N)
    
    # Toeplitz Multiplication (Classical)
    # H = T * K
    T = np.zeros((N//2, N//2), dtype=int)
    for i in range(N//2):
        for j in range(N//2):
            T[i][j] = toep_bits[(N//2 - 1) - j + i]
            
    hash_classical = np.dot(T, key_bits) % 2
    
    # Toeplitz Multiplication (NTT-based Circular Convolution)
    # Vì tích chập tuyến tính có thể biểu diễn qua tích chập vòng nếu mảng đủ lớn
    # Ta giữ nguyên Toeplitz bits làm mảng circulant
    toep_circ = toep_bits.copy()
        
    NTT_K = ntt(key_padded, q, w)
    NTT_T = ntt(toep_circ, q, w)
    
    NTT_M = (NTT_K * NTT_T) % q
    hash_ntt = intt(NTT_M, q, w_inv, n_inv)
    
    # Trích xuất kết quả: Chỉ số hợp lệ bắt đầu từ N/2 - 1
    hash_extracted = np.zeros(N//2, dtype=int)
    for i in range(N//2):
        hash_extracted[i] = hash_ntt[N//2 - 1 + i] % 2
    
    # Verify
    if np.array_equal(hash_classical, hash_extracted):
        print("Verification SUCCESS! NTT-based Toeplitz matches standard matrix mult.")
    else:
        print("Verification FAILED!")
        
    # Lưu test vectors
    with open(os.path.join(DATA_DIR, 'pa_key.txt'), 'w') as f:
        for val in key_padded: f.write(f"{val:04x}\n")
    with open(os.path.join(DATA_DIR, 'pa_toep.txt'), 'w') as f:
        for val in toep_circ: f.write(f"{val:04x}\n")
    with open(os.path.join(DATA_DIR, 'pa_hash_out.txt'), 'w') as f:
        for val in hash_extracted: f.write(f"{val:04x}\n")
        
    print("Files pa_key.txt, pa_toep.txt, pa_hash_out.txt saved to data/")

if __name__ == "__main__":
    generate_pa_test_vectors()
