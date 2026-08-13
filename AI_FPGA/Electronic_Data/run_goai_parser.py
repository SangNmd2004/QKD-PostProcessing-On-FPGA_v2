import os
import glob
import subprocess
import shutil

def run_parser():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 1. Tìm file .tflite đã được export ở bước trước (YOLO11s)
    tflite_files = glob.glob(os.path.join(base_dir, "YOLO11s_Training", "**", "weights", "**", "*.tflite"), recursive=True)
    if not tflite_files:
        tflite_files = glob.glob(os.path.join(base_dir, "**", "*.tflite"), recursive=True)
        
    if not tflite_files:
        print("Error: Could not find any .tflite model file! Please run export_tflite_int8.py first.")
        return
        
    # Ưu tiên chọn file có chữ integer_quant trong tên để đảm bảo Full Integer Quantization
    tflite_model = tflite_files[0]
    for f in tflite_files:
        if "integer_quant" in f.lower():
            tflite_model = f
            break
            
    print(f"Found TFLite model: {tflite_model}")
    
    # 2. Định vị công cụ model_parser.py của Gowin GoAI 3.0 SDK
    ai_fpga_dir = os.path.dirname(base_dir) # C:\Users\Admin\Downloads\AI_FPGA
    goai_parser_dir = os.path.join(ai_fpga_dir, "Go AI 3.0", "GoAI3.0_SDK_V1.0", "GoAI3.0_SDK_V1.0", "tool", "model_parser")
    parser_script = os.path.join(goai_parser_dir, "bin", "model_parser.py")
    output_dir = os.path.join(goai_parser_dir, "output")
    
    if not os.path.exists(parser_script):
        print(f"Error: GoAI 3.0 model_parser.py not found at: {parser_script}")
        return
        
    print(f"\nRunning GoAI 3.0 Model Parser on {tflite_model}...")
    print(f"Parser directory: {os.path.join(goai_parser_dir, 'bin')}")
    
    try:
        # Chạy model_parser.py của Gowin trong thư mục bin của nó
        cmd = ["python", "model_parser.py", "--tflite_model_file", tflite_model]
        res = subprocess.run(cmd, cwd=os.path.join(goai_parser_dir, "bin"), capture_output=True, text=True)
        print("--- Parser Output ---")
        print(res.stdout)
        if res.stderr:
            print("--- Parser Errors ---")
            print(res.stderr)
            
        if res.returncode == 0:
            print("\nGoAI 3.0 Model Parsing completed successfully!")
            # Kiểm tra file sinh ra trong thư mục output
            if os.path.exists(output_dir):
                out_files = os.listdir(output_dir)
                print(f"Generated files in {output_dir}: {out_files}")
                
                # Copy file .h và .bin về thư mục làm việc hiện tại để tiện sử dụng
                for f in out_files:
                    if f.endswith(".h") or f.endswith(".bin"):
                        shutil.copy2(os.path.join(output_dir, f), os.path.join(base_dir, f))
                        print(f"-> Copied {f} to {base_dir}")
        else:
            print(f"Parser failed with return code {res.returncode}")
    except Exception as e:
        print(f"Exception while running parser: {e}")

if __name__ == "__main__":
    run_parser()
