import numpy as np
import time
import os

# --- Parameters matching RTL ---
Zc = 96
data_w = 8
res_w = 8
ext_w = 2
D_cnu = 8
NUM_LAYERS = 12
NUM_COLS = 24
MAX_ITER = 50

LLR_MAX = (1 << (data_w - 1)) - 1
LLR_MIN = -(1 << (data_w - 1))
C2V_MAX = (1 << (res_w - 1)) - 1
C2V_MIN = -(1 << (res_w - 1))
V2C_BITS = res_w + ext_w
MAX_POS_VAL = (1 << (V2C_BITS - 1)) - 1

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

def saturate(val, min_val, max_val):
    if val > max_val: return max_val
    if val < min_val: return min_val
    return val

def barrel_shift(data_array, shift_amt):
    result = np.zeros_like(data_array)
    for j in range(Zc):
        result[j] = data_array[(j + shift_amt) % Zc]
    return result

def cnu_process(q_in_D, iteration):
    D = D_cnu
    qsgn = np.zeros(D, dtype=int)
    qmag = np.zeros(D, dtype=int)
    for i in range(D):
        val = q_in_D[i]
        if val < 0:
            qsgn[i] = 1
            qmag[i] = -val
        else:
            qsgn[i] = 0
            qmag[i] = val
            
    sorted_indices = np.argsort(qmag)
    min_idx = sorted_indices[0]
    min_val = qmag[min_idx]
    min2_val = qmag[sorted_indices[1]]
    
    # In QKD CV-QKD reverse reconciliation, syndrome is already embedded in LLR or we use explicit syndrome.
    # We will assume Alice's syndrome is 0 for simplicity in this exact sim since Alice data is clean.
    syn_bit = 0 
    rsgn = (np.bitwise_xor.reduce(qsgn) ^ syn_bit) & 1
    
    min_adj = 1 if min_val == 0 else min_val
    min2_adj = 1 if min2_val == 0 else min2_val
    
    offset_val = 2 if iteration < 25 else 1
    tmin_scaled = max(0, min_adj - offset_val)
    tmin2_scaled = max(0, min2_adj - offset_val)
    
    r_out = np.zeros(D, dtype=int)
    for i in range(D):
        mag = tmin2_scaled if min_idx == i else tmin_scaled
        if (rsgn ^ qsgn[i]) & 1:
            r_out[i] = -mag
        else:
            r_out[i] = mag
        r_out[i] = saturate(r_out[i], C2V_MIN, C2V_MAX)
    return r_out, rsgn

def decode_block(llrs, max_iter=MAX_ITER):
    """Decodes a single block of LLRs. Returns (iterations_used, success, initial_shw)."""
    llr_ram = np.zeros((NUM_COLS, Zc), dtype=int)
    for col in range(NUM_COLS):
        llr_ram[col] = llrs[col * Zc : (col + 1) * Zc]
        
    c2v_ram = np.zeros((NUM_LAYERS, D_cnu, Zc), dtype=int)
    initial_shw = -1
    
    for iteration in range(max_iter):
        all_layers_parity_ok = True
        layer_parity = []
        
        for layer in range(NUM_LAYERS):
            connected_cols = [(col, base_matrix[layer][col]) for col in range(NUM_COLS) if base_matrix[layer][col] != -1]
            q_in_buffer = np.full((D_cnu, Zc), MAX_POS_VAL, dtype=int)
            degree_map = []
            
            for degree_idx, (col, shift_val) in enumerate(connected_cols):
                if degree_idx >= D_cnu: break
                v2c_block = llr_ram[col] - c2v_ram[layer][degree_idx]
                q_in_buffer[degree_idx] = barrel_shift(v2c_block, shift_val)
                degree_map.append((col, shift_val))
                
            cnu_r_out = np.zeros((D_cnu, Zc), dtype=int)
            parity_vector = np.zeros(Zc, dtype=int)
            
            for z in range(Zc):
                q_in_D = q_in_buffer[:, z]
                r_out_D, rsgn = cnu_process(q_in_D, iteration)
                cnu_r_out[:, z] = r_out_D
                parity_vector[z] = rsgn
                
            if np.any(parity_vector != 0):
                all_layers_parity_ok = False
                
            layer_parity.extend(parity_vector.tolist())
                
            for degree_idx, (col, shift_val) in enumerate(degree_map):
                if degree_idx >= D_cnu: break
                llr_new_shifted = q_in_buffer[degree_idx] + cnu_r_out[degree_idx]
                inv_shift = 0 if shift_val == 0 else (Zc - shift_val)
                llr_new_unshifted = barrel_shift(llr_new_shifted, inv_shift)
                
                for z in range(Zc):
                    llr_ram[col][z] = saturate(llr_new_unshifted[z], LLR_MIN, LLR_MAX)
                    c2v_ram[layer][degree_idx][z] = saturate(barrel_shift(cnu_r_out[degree_idx], inv_shift)[z], C2V_MIN, C2V_MAX)
                    
        if iteration == 0:
            initial_shw = sum(layer_parity)
            
        if all_layers_parity_ok:
            return iteration + 1, True, initial_shw
            
    return max_iter, False, initial_shw

import multiprocessing

def process_single_block(args):
    i, bob_data_i, actual_qber_i = args
    # Add Gaussian noise
    base_llrs = np.where(bob_data_i == 0, 15, -15)
    llrs = base_llrs + np.random.normal(0, 5, size=2304)
    llrs = np.clip(llrs, -128, 127).astype(int)
    
    iters, success, shw = decode_block(llrs, MAX_ITER)
    return (i, actual_qber_i, shw, iters, success)

def run_bruteforce(num_test=1000):
    print(f"Loading dataset...")
    data = np.load("qkd_blocks.npz")
    bob_data = data["bob_data"][:num_test]
    actual_qber = data["actual_qber"][:num_test]
    
    start_time = time.time()
    print(f"Running exact HW simulation for {num_test} blocks using Multiprocessing...")
    
    # Prepare arguments for multiprocessing
    args_list = [(i, bob_data[i], actual_qber[i]) for i in range(num_test)]
    
    # Run with all available CPU cores
    num_cores = multiprocessing.cpu_count()
    print(f"Using {num_cores} CPU cores...")
    
    with multiprocessing.Pool(processes=num_cores) as pool:
        results = pool.map(process_single_block, args_list)
        
    print(f"Simulation done in {time.time() - start_time:.2f} seconds.")
    
    # Analyze SHW vs Iterations
    print("\n--- Summary: SHW vs Optimal Iterations ---")
    shw_dict = {}
    for i, qber, shw, iters, success in results:
        if success:
            if shw not in shw_dict:
                shw_dict[shw] = []
            shw_dict[shw].append(iters)
            
    # We want to find the MAX iterations needed for ranges of SHW to build LUT
    shw_keys = sorted(shw_dict.keys())
    if not shw_keys:
        print("No blocks converged successfully!")
        return
        
    print(f"Found {len(shw_keys)} unique SHW values that converged.")
    for shw in shw_keys:
        max_iter = max(shw_dict[shw])
        # print(f"SHW: {shw:3d} -> Max Iter: {max_iter:2d}")
        
    # Generate LUT thresholds (Task 1.3)
    print("\n--- LUT Extraction (Task 1.3) ---")
    print("If SHW <= X, iter_max = Y")
    bins = [(0, 100), (101, 150), (151, 200), (201, 250), (251, 300)]
    for b_min, b_max in bins:
        max_in_bin = -1
        for shw in shw_keys:
            if b_min <= shw <= b_max:
                max_in_bin = max(max_in_bin, max(shw_dict[shw]))
        if max_in_bin != -1:
            # We add a safety margin of +2 iterations for hardware
            safe_iter = min(50, max_in_bin + 2)
            print(f"If SHW in [{b_min:3d}, {b_max:3d}] -> Set iter_max = {safe_iter}")

if __name__ == "__main__":
    run_bruteforce(num_test=50)
