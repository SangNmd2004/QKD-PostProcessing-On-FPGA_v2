import os

# Define paths
DATA_DIR = os.path.join(os.path.dirname(__file__), '../data')
EXPECTED_FILE = os.path.join(DATA_DIR, 'expected_out.txt')
DECODED_FILE = os.path.join(DATA_DIR, 'decoded_out.txt')

def compare_all():
    if not os.path.exists(EXPECTED_FILE):
        print(f"Error: Could not find {EXPECTED_FILE}")
        return
        
    if not os.path.exists(DECODED_FILE):
        print(f"Error: Could not find {DECODED_FILE}")
        return

    with open(EXPECTED_FILE, 'r') as f1, open(DECODED_FILE, 'r') as f2:
        expected = f1.read().splitlines()
        decoded = f2.read().splitlines()
        
    # Testbench simulates 1 block = 2304 bits.
    # expected_out.txt might have multiple blocks, so we only compare the length of decoded.
    num_bits = len(decoded)
    print(f"Comparing {num_bits} bits...")
    
    mismatches = 0
    for i in range(num_bits):
        if expected[i] != decoded[i]:
            mismatches += 1
            if mismatches <= 10:
                print(f"Mismatch at bit {i}: expected {expected[i]}, got {decoded[i]}")
                
    if mismatches == 0:
        print("==================================================")
        print("SUCCESS! 100% PERFECT MATCH!")
        print(f"All {num_bits} bits (Information + Parity) perfectly match Alice's original key.")
        print("==================================================")
    else:
        print("==================================================")
        print(f"FAILED! Found {mismatches} mismatched bits out of {num_bits}.")
        print("==================================================")

if __name__ == "__main__":
    compare_all()
