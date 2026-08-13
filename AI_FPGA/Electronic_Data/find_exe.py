import glob
files = glob.glob('c:/Users/Admin/Downloads/AI_FPGA/Electronic_Data/**/*.bat', recursive=True)
for f in files: print(f)
files = glob.glob('c:/Users/Admin/Downloads/AI_FPGA/Electronic_Data/**/*.exe', recursive=True)
for f in files: print(f)
