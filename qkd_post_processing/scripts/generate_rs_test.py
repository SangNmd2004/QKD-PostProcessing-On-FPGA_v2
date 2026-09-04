import os
import reedsolo

# IEEE 802.16e LDPC Base Matrix - Rate 1/2 (12x24)
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
Zc = 96

# 1. Expand the parity-check matrix H
def build_H(base_matrix, z):
    rows = len(base_matrix) * z
    cols = len(base_matrix[0]) * z
    H = [[0]*cols for _ in range(rows)]
    for mb in range(len(base_matrix)):
        for nb in range(len(base_matrix[0])):
            shift = base_matrix[mb][nb]
            if shift != -1:
                for i in range(z):
                    H[mb*z + i][nb*z + ((i + shift) % z)] = 1
    return H

H = build_H(rate_1_2, Zc)

# 2. Generate random error vector E for a specific QBER
import random
random.seed(12345)

import sys
if len(sys.argv) > 1:
    QBER = float(sys.argv[1])
else:
    QBER = 0.0217 # 2.17% QBER
N_bits = 2304
N_err = int(N_bits * QBER)
print(f"Generating Test Vectors for QBER = {QBER*100:.2f}% ({N_err} errors)")

E = [0] * N_bits
error_positions = random.sample(range(N_bits), N_err)
for pos in error_positions:
    E[pos] = 1

# 3. Generate new random RS codeword
info_bytes = bytes([random.randint(0, 255) for _ in range(112)])
rs = reedsolo.RSCodec(32) # N=255, K=223 (shortened to 144, 112)
rs_codeword = rs.encode(info_bytes) # 144 bytes

x_new = []
for b in rs_codeword:
    for i in range(8):
        x_new.append((b >> i) & 1)

# pad with 0s for the remaining 1152 parity bits
x_new += [0] * 1152

# 4. Compute new syndrome
s_new = [0] * len(H)
for i in range(len(H)):
    sum_val = 0
    for j in range(len(x_new)):
        if H[i][j] == 1 and x_new[j] == 1:
            sum_val ^= 1
    s_new[i] = sum_val

# Pad syndrome to 1536 bits
s_new += [0] * (1536 - len(s_new))

# 5. Compute LLRs based on Y = X_new ^ E
llr_new = []
for i in range(N_bits):
    y = x_new[i] ^ E[i]
    # If y == 0, LLR is positive (e.g., +7). If y == 1, LLR is negative (e.g., -7)
    val = -7 if y == 1 else 7
    llr_new.append(val)

# 6. Write back to files
with open('data/expected_out.txt', 'w') as f:
    for bit in x_new:
        f.write(f"{bit}\n")

with open('data/syndrome_in.txt', 'w') as f:
    for bit in s_new:
        f.write(f"{bit}\n")

with open('data/llr_in.txt', 'w') as f:
    for val in llr_new:
        # Convert back to 6-bit two's complement
        if val < 0:
            val = (1 << 6) + val
        f.write(f"{val:06b}\n")

print("New test vectors with valid RS codeword generated successfully!")
