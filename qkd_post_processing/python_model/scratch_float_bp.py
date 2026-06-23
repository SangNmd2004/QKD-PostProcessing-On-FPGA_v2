import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')

# Load Base Matrix
base_matrix = [
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

Zc = 96
M = 12 * Zc
N = 24 * Zc

def load_data():
    with open(os.path.join(DATA_DIR, 'llr_in.txt'), 'r') as f:
        llr_lines = [line.strip() for line in f if line.strip()]
    llrs = np.zeros(N)
    for i, line in enumerate(llr_lines[:N]):
        val = int(line, 2)
        if val >= 32: val -= 64
        llrs[i] = val / 4.0 # Convert back to float
    
    with open(os.path.join(DATA_DIR, 'syndrome_in.txt'), 'r') as f:
        syn_lines = [line.strip() for line in f if line.strip()]
    syn = np.zeros(M, dtype=int)
    for i, line in enumerate(syn_lines[:M]):
        syn[i] = int(line, 2)
        
    with open(os.path.join(DATA_DIR, 'expected_out.txt'), 'r') as f:
        exp_lines = [line.strip() for line in f if line.strip()]
    expected = np.array([int(line) for line in exp_lines[:N]])
    
    return llrs, syn, expected

llrs, syn, expected = load_data()

# Build Graph
H = np.zeros((M, N), dtype=int)
for r in range(12):
    for c in range(24):
        shift = base_matrix[r][c]
        if shift != -1:
            I = np.eye(Zc, dtype=int)
            I_shifted = np.roll(I, shift, axis=1)
            H[r*Zc:(r+1)*Zc, c*Zc:(c+1)*Zc] = I_shifted

# Float Min-Sum BP
R_mn = np.zeros((M, N))
L_n = np.copy(llrs)

for it in range(50):
    # CNU
    parity_ok = True
    for m in range(M):
        connected_n = np.where(H[m] == 1)[0]
        v2c = L_n[connected_n] - R_mn[m, connected_n]
        
        # Min-Sum
        for idx, n in enumerate(connected_n):
            others = np.delete(v2c, idx)
            sgn = np.prod(np.sign(others)) * (-1 if syn[m] == 1 else 1)
            mag = np.min(np.abs(others))
            R_mn[m, n] = sgn * mag
            
    # VNU
    L_n = llrs + np.sum(R_mn, axis=0)
    
    # Check
    decoded = (L_n < 0).astype(int)
    current_syn = np.dot(H, decoded) % 2
    if np.array_equal(current_syn, syn):
        print(f"Converged at iter {it}")
        break

errors = np.sum(decoded != expected)
print(f"Float BP errors: {errors}")
