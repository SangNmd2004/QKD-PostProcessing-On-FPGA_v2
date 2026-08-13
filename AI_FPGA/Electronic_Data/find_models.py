import os
import glob

search_path = 'c:/Users/Admin/Downloads/AI_FPGA/Electronic_Data/**/*'
files = glob.glob(search_path, recursive=True)

for f in files:
    if 'yolo' in f.lower() or '.tflite' in f.lower():
        print(f)
