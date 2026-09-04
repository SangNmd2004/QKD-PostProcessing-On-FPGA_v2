import os
import re

rs_core_dir = os.path.join(os.path.dirname(__file__), '../rtl/rs_core')

def patch_file(filename, replacements):
    filepath = os.path.join(rs_core_dir, filename)
    if not os.path.exists(filepath):
        print(f"File not found: {filename}")
        return
    with open(filepath, 'r') as f:
        content = f.read()
    
    original_content = content
    for old, new in replacements:
        content = re.sub(old, new, content, flags=re.IGNORECASE | re.MULTILINE)
        
    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Patched {filename}")
    else:
        print(f"No changes made to {filename}")

patches = {
    'single_port_2D_ram.vhd': [
        (r'NUMBER_OF_ELEMENTS\s*:\s*natural\s*;', r'NUMBER_OF_ELEMENTS : natural := 1;'),
        (r'NUMBER_OF_LINES\s*:\s*natural\s*;', r'NUMBER_OF_LINES : natural := 1;'),
        (r'WORD_LENGTH\s*:\s*natural\s*\)', r'WORD_LENGTH : natural := 8)')
    ],
    'single_port_ram.vhd': [
        (r'NUMBER_OF_ELEMENTS\s*:\s*natural\s*;', r'NUMBER_OF_ELEMENTS : natural := 1;'),
        (r'WORD_LENGTH\s*:\s*natural\s*\)', r'WORD_LENGTH : natural := 8)')
    ],
    'sync_dff_gen_rst.vhd': [
        (r'WORD_LENGTH\s*:\s*integer\s*\)', r'WORD_LENGTH : integer := 8)')
    ],
    'two_input_size_generic_buffer.vhd': [
        (r'INPUT_1_LENGTH\s*:\s*natural\s*;', r'INPUT_1_LENGTH : natural := 8;'),
        (r'INPUT_2_LENGTH\s*:\s*natural\s*;', r'INPUT_2_LENGTH : natural := 8;'),
        (r'OUTPUT_LENGTH\s*:\s*natural\s*;', r'OUTPUT_LENGTH : natural := 8;'),
        (r'NUM_OF_OUTPUT_ELEMENTS\s*:\s*natural\s*\)', r'NUM_OF_OUTPUT_ELEMENTS : natural := 1)')
    ],
    'up_counter.vhd': [
        (r'WORD_LENGTH\s*:\s*natural\s*\)', r'WORD_LENGTH : natural := 8)')
    ],
    'up_down_counter.vhd': [
        (r'WORD_LENGTH\s*:\s*natural\s*\)', r'WORD_LENGTH : natural := 8)')
    ],
    'rs_codec.vhd': [
        (r'n\s*:\s*natural\s*;', r'n : natural := 255;'),
        (r'k\s*:\s*natural\s*\)', r'k : natural := 223)')
    ],
    'rs_encoder_wrapper.vhd': [
        (r'n\s*:\s*natural\s*;', r'n : natural := 255;'),
        (r'k\s*:\s*natural\s*\)', r'k : natural := 223)')
    ],
    'shifter_left.vhd': [
        (r'N\s*:\s*natural\s*;', r'N : natural := 8;'),
        (r'S\s*:\s*natural\s*\)', r'S : natural := 1)')
    ],
    'adder.vhd': [
        (r'WORD_LENGTH\s*:\s*(natural|integer)\s*\)', r'WORD_LENGTH : \1 := 8)')
    ],
    'async_dff_array.vhd': [
        (r'NUM_OF_ELEMENTS\s*:\s*(natural|integer)(?:\s+range\s+[^;]+)?\s*;', r'NUM_OF_ELEMENTS : \1 := 1;'),
        (r'WORD_LENGTH\s*:\s*(natural|integer)(?:\s+range\s+[^;)]+)?\s*\)', r'WORD_LENGTH : \1 := 8)')
    ],
    'async_dff_gen_rst.vhd': [
        (r'WORD_LENGTH\s*:\s*(natural|integer)(?:\s+range\s+[^;)]+)?\s*\)', r'WORD_LENGTH : \1 := 8)')
    ],
    'comparator.vhd': [
        (r'WORD_LENGTH\s*:\s*(natural|integer)\s*\)', r'WORD_LENGTH : \1 := 8)')
    ],
    'demultiplexer_array.vhd': [
        (r'WORD_LENGTH\s*:\s*(natural|integer)\s*:=\s*4\s*;', r'WORD_LENGTH : \1 := 8;')
    ],
    'multiplexer_array.vhd': [
        (r'WORD_LENGTH\s*:\s*(natural|integer)\s*:=\s*4\s*;', r'WORD_LENGTH : \1 := 8;')
    ],
    'dual_clock_generic_buffer.vhd': [
        (r'INPUT_LENGTH\s*:\s*(natural|integer)\s*;', r'INPUT_LENGTH : \1 := 8;'),
        (r'OUTPUT_LENGTH\s*:\s*(natural|integer)\s*\)', r'OUTPUT_LENGTH : \1 := 8)')
    ],
    'mem_fifo.vhd': [
        (r'O_SIZE\s*:\s*(natural|integer)\s*;', r'O_SIZE : \1 := 8;'),
        (r'I_SIZE\s*:\s*(natural|integer)\s*;', r'I_SIZE : \1 := 8;'),
        (r'MEM_SIZE\s*:\s*(natural|integer)\s*\)', r'MEM_SIZE : \1 := 8)')
    ]
}

for filename, reps in patches.items():
    patch_file(filename, reps)

# Special handling for generic_functions.vhd
func_file = 'generic_functions.vhd'
func_path = os.path.join(rs_core_dir, func_file)
if os.path.exists(func_path):
    with open(func_path, 'r') as f:
        c = f.read()
        
    # Replace A, B: natural with A: natural := 0; B: natural := 0
    c = re.sub(r'function\s+max\s*\(\s*A\s*,\s*B\s*:\s*natural\s*\)\s*return\s*natural', r'function max(A: natural := 0; B: natural := 0) return natural', c, flags=re.IGNORECASE)
    c = re.sub(r'function\s+ceil_division\s*\(\s*A\s*,\s*B\s*:\s*natural\s*\)\s*return\s*natural', r'function ceil_division(A: natural := 0; B: natural := 1) return natural', c, flags=re.IGNORECASE)
    
    # Replace N: natural with N: natural := 1
    c = re.sub(r'function\s+get_log_round\s*\(\s*N\s*:\s*natural\s*\)\s*return\s*natural', r'function get_log_round(N: natural := 1) return natural', c, flags=re.IGNORECASE)
    
    with open(func_path, 'w') as f:
        f.write(c)
    print(f"Patched {func_file}")
