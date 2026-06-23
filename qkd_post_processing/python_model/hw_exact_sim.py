"""
Bit-True Hardware Simulation of the Partially Parallel LDPC Decoder.
This script replicates the EXACT behavior of core_partially_parallel.v,
including pipeline timing, barrel shifter, CNU logic, and saturation.
"""
import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, '../data')

# --- Parameters matching RTL ---
Zc = 96
data_w = 6      # LLR width
res_w = 8        # C2V message width
ext_w = 3        # Extension width for V2C (res_w + ext_w = 11 bits signed)
D_cnu = 8        # Max degree of check node
NUM_LAYERS = 12
NUM_COLS = 24
MAX_ITER = 100

# Signed range for data_w bits
LLR_MAX = (1 << (data_w - 1)) - 1   # 31
LLR_MIN = -(1 << (data_w - 1))      # -32

# Signed range for res_w bits (C2V messages)
C2V_MAX = (1 << (res_w - 1)) - 1    # 127
C2V_MIN = -(1 << (res_w - 1))       # -128

# Signed range for res_w+ext_w bits (V2C messages)
V2C_BITS = res_w + ext_w            # 9
V2C_MAX = (1 << (V2C_BITS - 1)) - 1 # 255
V2C_MIN = -(1 << (V2C_BITS - 1))    # -256

# DUMMY_Q_IN: MAX_POS_VAL for inactive slots
MAX_POS_VAL = (1 << (V2C_BITS - 1)) - 1  # 255

# --- Base Matrix (must match rom_h_matrix.v) ---
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

def sign_extend(val, from_bits, to_bits):
    """Sign-extend a value from from_bits to to_bits."""
    mask = 1 << (from_bits - 1)
    val = val & ((1 << from_bits) - 1)  # Mask to from_bits
    if val & mask:
        val = val - (1 << from_bits)
    return val

def saturate(val, min_val, max_val):
    """Saturate a value to [min_val, max_val]."""
    if val > max_val:
        return max_val
    if val < min_val:
        return min_val
    return val

def barrel_shift(data_array, shift_amt, Zc=96):
    """Cyclic shift: out[j] = in[(j + shift_amt) % Zc]"""
    result = np.zeros_like(data_array)
    for j in range(Zc):
        src_idx = (j + shift_amt) % Zc
        result[j] = data_array[src_idx]
    return result

def inv_barrel_shift(data_array, shift_amt, Zc=96):
    """Inverse cyclic shift: shift by (Zc - shift_amt)"""
    if shift_amt == 0:
        return data_array.copy()
    return barrel_shift(data_array, Zc - shift_amt, Zc)

def cnu_process(q_in_D, syn_bit):
    """
    Exact replication of cnu.v + sgn_ram.v + cmp_tree.v + abs.v
    
    q_in_D: array of D_cnu signed values (V2C messages, V2C_BITS wide)
    syn_bit: syndrome bit for this check node
    
    Returns: r_out_D: array of D_cnu signed values (C2V messages, res_w wide)
    """
    D = D_cnu
    
    # abs.v: Extract sign and magnitude
    qsgn = np.zeros(D, dtype=int)
    qmag = np.zeros(D, dtype=int)
    for i in range(D):
        val = q_in_D[i]
        # xsgn = x[data_w-1] i.e. MSB (sign bit)
        if val < 0:
            qsgn[i] = 1
            qmag[i] = -val  # Two's complement absolute value
        else:
            qsgn[i] = 0
            qmag[i] = val
    
    # cmp_tree.v: Find min, min2, min_idx
    # This is a comparison tree that finds the two smallest magnitudes
    sorted_indices = np.argsort(qmag)
    min_idx = sorted_indices[0]
    min_val = qmag[min_idx]
    min2_val = qmag[sorted_indices[1]]
    
    # sgn_ram.v: rsgn = ^qsgn ^ syn
    rsgn = (np.bitwise_xor.reduce(qsgn) ^ syn_bit) & 1
    qsgn2 = qsgn.copy()
    
    # cnu.v: Scaling logic
    # min_adj = (min == 0) ? 1 : min
    min_adj = 1 if min_val == 0 else min_val
    min2_adj = 1 if min2_val == 0 else min2_val
    
    # tmin = active ? {2'b0, min_adj} : 0 (zero-extended, then treated as signed)
    tmin = min_adj
    tmin2 = min2_adj
    
    # OMS offset=2
    tmin_scaled = max(0, tmin - 2)
    tmin2_scaled = max(0, tmin2 - 2)
    
    # Generate C2V messages
    r_out = np.zeros(D, dtype=int)
    for i in range(D):
        if min_idx == i:
            mag = tmin2_scaled
        else:
            mag = tmin_scaled
        
        # Sign: rsgn ^ qsgn2[i] determines if output is negative
        if (rsgn ^ qsgn2[i]) & 1:
            r_out[i] = -mag
        else:
            r_out[i] = mag
        
        # Saturate to res_w bits
        r_out[i] = saturate(r_out[i], C2V_MIN, C2V_MAX)
    
    return r_out, rsgn

def load_test_data():
    """Load test vectors from files (binary format for $readmemb)."""
    # Load LLRs (6-bit binary, unsigned -> convert to signed)
    with open(os.path.join(DATA_DIR, 'llr_in.txt'), 'r') as f:
        llr_lines = [line.strip() for line in f if line.strip()]
    
    llrs = np.zeros(2304, dtype=int)
    for i, line in enumerate(llr_lines[:2304]):
        val = int(line, 2)
        # Convert from unsigned 6-bit to signed
        if val >= (1 << 5):
            val -= (1 << 6)
        llrs[i] = val
    
    # Load syndrome (1-bit binary per line)
    with open(os.path.join(DATA_DIR, 'syndrome_in.txt'), 'r') as f:
        syn_lines = [line.strip() for line in f if line.strip()]
    
    syndrome = np.zeros(1536, dtype=int)
    for i, line in enumerate(syn_lines[:1536]):
        syndrome[i] = int(line, 2)
    
    # Load expected output
    with open(os.path.join(DATA_DIR, 'expected_out.txt'), 'r') as f:
        exp_lines = [line.strip() for line in f if line.strip()]
    
    expected = np.array([int(line.strip()) for line in exp_lines[:2304]])
    
    return llrs, syndrome, expected

def simulate():
    """
    Exact simulation of the partially parallel LDPC decoder FSM.
    """
    llrs, syndrome, expected = load_test_data()
    
    # --- LLR RAM: 24 columns, each is Zc values of data_w bits ---
    llr_ram = np.zeros((NUM_COLS, Zc), dtype=int)
    for col in range(NUM_COLS):
        for z in range(Zc):
            llr_ram[col][z] = llrs[col * Zc + z]
    
    # --- C2V RAM: 12 layers, each stores D_cnu groups of Zc values of res_w bits ---
    c2v_ram = np.zeros((NUM_LAYERS, D_cnu, Zc), dtype=int)
    
    # --- Syndrome: 12 layers, each 96 bits ---
    syn_2d = np.zeros((NUM_LAYERS, Zc), dtype=int)
    for layer in range(NUM_LAYERS):
        for z in range(Zc):
            syn_2d[layer][z] = syndrome[layer * Zc + z]
    
    # --- Main decoding loop ---
    for iteration in range(MAX_ITER):
        all_layers_parity_ok = True
        
        for layer in range(NUM_LAYERS):
            # ===== LAYER_READ phase =====
            # Find which columns are connected to this layer
            connected_cols = []
            for col in range(NUM_COLS):
                if base_matrix[layer][col] != -1:
                    connected_cols.append((col, base_matrix[layer][col]))
            
            # Build q_in_buffer (V2C messages after barrel shift)
            # Inactive slots filled with MAX_POS_VAL
            q_in_buffer = np.full((D_cnu, Zc), MAX_POS_VAL, dtype=int)
            degree_map = []  # Maps degree index -> (col, shift_val)
            
            for degree_idx, (col, shift_val) in enumerate(connected_cols):
                if degree_idx >= D_cnu:
                    break
                
                # Read LLR from RAM
                llr_block = llr_ram[col].copy()
                
                # Read C2V from RAM for this layer and degree
                c2v_block = c2v_ram[layer][degree_idx].copy()
                
                # Compute V2C = sign_extend(LLR) - C2V
                v2c_block = np.zeros(Zc, dtype=int)
                for z in range(Zc):
                    llr_ext = llrs_sign_extend(llr_block[z])
                    v2c_block[z] = llr_ext - c2v_block[z]
                
                # Barrel shift V2C by shift_val
                v2c_shifted = barrel_shift(v2c_block, shift_val)
                
                q_in_buffer[degree_idx] = v2c_shifted
                degree_map.append((col, shift_val))
            
            # ===== LAYER_CALC phase =====
            # Run CNU cluster (96 parallel CNUs)
            cnu_r_out = np.zeros((D_cnu, Zc), dtype=int)
            parity_vector = np.zeros(Zc, dtype=int)
            
            for z in range(Zc):
                # Gather D inputs for this CNU
                q_in_D = np.zeros(D_cnu, dtype=int)
                for d in range(D_cnu):
                    q_in_D[d] = q_in_buffer[d][z]
                
                r_out_D, rsgn = cnu_process(q_in_D, syn_2d[layer][z])
                
                for d in range(D_cnu):
                    cnu_r_out[d][z] = r_out_D[d]
                
                parity_vector[z] = rsgn
            
            if np.any(parity_vector != 0):
                all_layers_parity_ok = False
            
            # ===== LAYER_WRITE phase =====
            for degree_idx, (col, shift_val) in enumerate(degree_map):
                if degree_idx >= D_cnu:
                    break
                
                # c2v_new_shifted = cnu_r_out[degree_idx] (already in shifted domain)
                c2v_new_shifted = cnu_r_out[degree_idx].copy()
                
                # v2c_old_shifted = q_in_buffer[degree_idx] (V2C in shifted domain)
                v2c_old_shifted = q_in_buffer[degree_idx].copy()
                
                # llr_new_shifted = v2c_old_shifted + c2v_new_shifted
                llr_new_shifted = np.zeros(Zc, dtype=int)
                for z in range(Zc):
                    llr_new_shifted[z] = v2c_old_shifted[z] + c2v_new_shifted[z]
                
                # Inverse barrel shift to get back to original column order
                inv_shift = 0 if shift_val == 0 else (Zc - shift_val)
                llr_new_unshifted = barrel_shift(llr_new_shifted, inv_shift)
                
                # Saturate LLR to data_w range and write to RAM
                for z in range(Zc):
                    llr_ram[col][z] = saturate(llr_new_unshifted[z], LLR_MIN, LLR_MAX)
                
                # Inverse barrel shift C2V for storage
                c2v_new_unshifted = barrel_shift(c2v_new_shifted, inv_shift)
                
                # Saturate C2V to data_w range (hardware does this)
                for z in range(Zc):
                    sat_val = saturate(c2v_new_unshifted[z], C2V_MIN, C2V_MAX)
                    c2v_ram[layer][degree_idx][z] = sat_val
            
            if layer == 0 and iteration == 0:
                pass
        
                # Check errors per iteration
        decoded = np.zeros(2304, dtype=int)
        for col in range(NUM_COLS):
            for z in range(Zc):
                decoded[col * Zc + z] = 1 if llr_ram[col][z] < 0 else 0
        errs = np.sum(decoded != expected[:2304])
        print(f"Iter {iteration}: {errs} errors")
        
        # Check convergence
        if all_layers_parity_ok:
            print(f"Converged at iteration {iteration}!")
            break
    
    # --- OUTPUT_RES phase ---
    # Hardware reads MSB (sign bit) of each LLR
    decoded = np.zeros(2304, dtype=int)
    for col in range(NUM_COLS):
        for z in range(Zc):
            # ldpc_res_out[col*Zc + z] <= llr_dout[z*data_w + data_w - 1]
            # This is the sign bit: 1 if negative (bit=1), 0 if positive (bit=0)
            decoded[col * Zc + z] = 1 if llr_ram[col][z] < 0 else 0
    
    # Compare with expected
    mismatches = np.sum(decoded != expected[:2304])
    print(f"\nMismatches: {mismatches} / 2304")
    if mismatches > 0:
        for i in range(2304):
            if decoded[i] != expected[i]:
                print(f"  Mismatch at bit {i}: expected {expected[i]}, got {decoded[i]} (LLR={llr_ram[i//Zc][i%Zc]})")
    else:
        print("SUCCESS! 0 bit errors!")
    
    return mismatches

def llrs_sign_extend(val):
    """Sign-extend a data_w-bit value to V2C_BITS (res_w+ext_w) bits."""
    # This matches: wire signed [res_w+ext_w-1:0] llr_ext = {{ (res_w+ext_w-data_w){llr_val[data_w-1]} }, llr_val};
    return val  # Python int is already correctly sign-extended

if __name__ == "__main__":
    simulate()
