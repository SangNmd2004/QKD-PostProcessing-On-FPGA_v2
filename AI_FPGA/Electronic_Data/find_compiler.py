import os
import glob
search_path = 'c:/Users/Admin/Downloads/AI_FPGA/Electronic_Data/**/goai_c.exe'
files = glob.glob(search_path, recursive=True)
for f in files:
    print(f)
