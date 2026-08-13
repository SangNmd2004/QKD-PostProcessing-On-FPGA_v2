import os
import time
filepath = 'c:/Users/Admin/Downloads/AI_FPGA/Electronic_Data/best_int8.h'
mtime = os.path.getmtime(filepath)
print("Modified time:", time.ctime(mtime))
