import glob
files = glob.glob('c:/Users/Admin/Downloads/AI_FPGA/Electronic_Data/**/*.gprj', recursive=True)
for f in files: print(f)
