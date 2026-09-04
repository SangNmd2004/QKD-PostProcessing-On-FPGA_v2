import numpy as np
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from qkd_ldpc_sim import load_parity_check_matrix

def bin2int(b_str):
    val = int(b_str, 2)
    return val - 256 if val >= 128 else val

def analyze_block(block_idx):
    with open('../../data/llr_in.txt', 'r') as f:
        llr_lines = f.readlines()
    with open('../../data/expected_out.txt', 'r') as f:
        exp_lines = f.readlines()

    start = block_idx * 2304
    end = (block_idx + 1) * 2304
    llr_bin = [l.strip() for l in llr_lines[start:end]]
    exp_bits = np.array([int(l.strip()) for l in exp_lines[start:end]])
    llr_int = np.array([bin2int(b) for b in llr_bin])

    H = load_parity_check_matrix('1/2')
    rows, cols = np.where(H == 1)
    num_edges = len(rows)

    # Initialize messages Check-to-Variable (L_r)
    L_r = np.zeros(num_edges, dtype=int)

    for it in range(50):
        # Hardware: AOMS Schedule
        if it < 10: offset = 3
        elif it < 30: offset = 2
        else: offset = 1

        # Hardware: Dynamic Saturation
        if it < 20: sat = 31
        elif it < 40: sat = 63
        else: sat = 127

        # Variable to Check (L_q)
        L_q = np.zeros(num_edges, dtype=int)
        L_total = np.copy(llr_int)
        for c in range(2304):
            idx = np.where(cols == c)[0]
            L_total[c] += np.sum(L_r[idx])
            
            for i in idx:
                val = L_total[c] - L_r[i]
                if val > sat: val = sat
                elif val < -sat: val = -sat
                L_q[i] = val

        # Check to Variable (L_r)
        L_r_new = np.zeros(num_edges, dtype=int)
        for r in range(1152):
            idx = np.where(rows == r)[0]
            if len(idx) == 0: continue
            
            for i in idx:
                min_val = 9999
                sgn = 1
                for j in idx:
                    if i == j: continue
                    val = L_q[j]
                    min_val = min(min_val, abs(val))
                    if val < 0: sgn = -sgn
                mag = max(0, min_val - offset)
                L_r_new[i] = sgn * mag
        L_r = L_r_new

        # Check parity
        hd_out = (L_total < 0).astype(int)
        errs = np.sum(hd_out != exp_bits)
        if errs == 0:
            print(f'Block {block_idx}: Converged at iter {it}')
            return errs, []

    print(f'Block {block_idx}: Failed with {errs} errors.')
    err_idx = np.where(hd_out != exp_bits)[0]
    return errs, err_idx

failed_blocks = [0, 3, 6, 7, 8, 9]
for b in failed_blocks:
    errs, pos = analyze_block(b)
    info_errs = np.sum(pos < 1152)
    parity_errs = np.sum(pos >= 1152)
    print(f"   -> {info_errs} Information Errors, {parity_errs} Parity Errors")
