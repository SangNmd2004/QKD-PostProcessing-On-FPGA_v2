import random
import os

def generate_header():
    # 2 LDPC blocks cho NTT 4096 (Do scaling down)
    # LLR: 2304 byte mỗi khối
    # Syndrome: 144 byte mỗi khối
    llr_size = 2304 * 2
    syn_size = 144 * 2
    
    with open("test_data.h", "w") as f:
        f.write("/*\n * AUTO-GENERATED TEST VECTORS\n * QKD Post-Processing LLR & Syndrome Data\n */\n\n")
        f.write("#ifndef TEST_DATA_H\n")
        f.write("#define TEST_DATA_H\n\n")
        
        f.write(f"#define LLR_ARRAY_SIZE {llr_size}\n")
        f.write(f"#define SYN_ARRAY_SIZE {syn_size}\n\n")
        
        f.write("// Fake LLR data (2 LDPC blocks)\n")
        f.write("unsigned char llr_data[LLR_ARRAY_SIZE] = {\n")
        for i in range(llr_size):
            f.write(f"0x{random.randint(0, 255):02X}, ")
            if (i+1) % 16 == 0:
                f.write("\n")
        f.write("};\n\n")
        
        f.write("// Fake Syndrome data (2 LDPC blocks)\n")
        f.write("unsigned char syn_data[SYN_ARRAY_SIZE] = {\n")
        for i in range(syn_size):
            f.write(f"0x{random.randint(0, 255):02X}, ")
            if (i+1) % 16 == 0:
                f.write("\n")
        f.write("};\n\n")
        
        f.write("#endif // TEST_DATA_H\n")

if __name__ == "__main__":
    generate_header()
    print("test_data.h generated successfully!")
    print(f"File saved at: {os.path.abspath('test_data.h')}")
