import numpy as np
import os
import argparse
import time

def generate_qkd_blocks(num_blocks=10000, n_bits=2304, min_qber=0.01, max_qber=0.08, output_file="qkd_blocks.npz"):
    """
    Generates QKD blocks with simulated channel noise (QBER).
    
    Args:
        num_blocks: Number of blocks to generate.
        n_bits: Number of bits per block (Block size N).
        min_qber: Minimum QBER (e.g., 1%).
        max_qber: Maximum QBER (e.g., 8%).
        output_file: Output file path to save the blocks.
    """
    print(f"Generating {num_blocks} blocks with N={n_bits}...")
    start_time = time.time()
    
    # 1. Generate clean blocks (Alice's data) - purely random bits for simulation
    # Using All-Zero Codeword for simulation to ensure valid decoding with target syndrome 0
    alice_data = np.zeros((num_blocks, n_bits), dtype=np.uint8)
    
    # 2. Generate random QBERs for each block simulating FSO channel fluctuations
    qber_array = np.random.uniform(min_qber, max_qber, size=num_blocks)
    
    # 3. Inject noise (Bob's data)
    # Generate random matrix to flip bits based on the QBER for each block
    noise_matrix = np.random.rand(num_blocks, n_bits)
    error_mask = (noise_matrix < qber_array[:, np.newaxis]).astype(np.uint8)
    
    # Bob's received data (Raw Key with errors)
    bob_data = np.bitwise_xor(alice_data, error_mask)
    
    # Calculate actual errors per block for verification
    actual_errors = np.sum(error_mask, axis=1)
    actual_qber = actual_errors / n_bits
    
    # Save the dataset
    np.savez_compressed(
        output_file,
        alice_data=alice_data,
        bob_data=bob_data,
        target_qber=qber_array,
        actual_qber=actual_qber,
        error_mask=error_mask
    )
    
    print(f"Dataset generated in {time.time() - start_time:.2f} seconds.")
    print(f"Saved to {output_file}")
    print(f"Average Actual QBER: {np.mean(actual_qber):.4f}")
    print(f"Min QBER: {np.min(actual_qber):.4f}, Max QBER: {np.max(actual_qber):.4f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate FSO QKD blocks with noise.")
    parser.add_argument("--num_blocks", type=int, default=10000, help="Number of blocks")
    parser.add_argument("--n_bits", type=int, default=2304, help="Block size N (default: 2304 for Rate 1/2 with M=1152)")
    parser.add_argument("--out", type=str, default="qkd_blocks.npz", help="Output file")
    
    args = parser.parse_args()
    
    # Set seed for reproducibility
    np.random.seed(42)
    
    generate_qkd_blocks(
        num_blocks=args.num_blocks, 
        n_bits=args.n_bits,
        output_file=args.out
    )
