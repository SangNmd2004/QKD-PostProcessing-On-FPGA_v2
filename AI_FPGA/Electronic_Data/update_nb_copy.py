import json

path = 'YOLO11s_Training/train_yolo11s_for_FPGA.ipynb'
with open(path, 'r', encoding='utf-8') as f:
    nb = json.load(f)

# The TFLite export is in cell index 3. Let's add the copy command there.
# But wait, tflite_path is a variable. We can use python's shutil or !cp in colab via f-string.
# It is better to just append to the 4th cell (index 3).
source = nb['cells'][3]['source']
source.append('\n')
source.append('# COPY FILE TFLITE RA THƯ MỤC RIÊNG TRÊN GOOGLE DRIVE ĐỂ DỄ LẤY\n')
source.append('import shutil\n')
source.append('import os\n')
source.append('export_dir = "/content/drive/MyDrive/YOLO11s_TFLite_Export"\n')
source.append('os.makedirs(export_dir, exist_ok=True)\n')
source.append('shutil.copy(tflite_path, os.path.join(export_dir, "yolo11s_int8.tflite"))\n')
source.append('print(f"✅ ĐÃ LƯU FILE TFLITE VÀO: {export_dir}/yolo11s_int8.tflite")\n')
nb['cells'][3]['source'] = source

with open(path, 'w', encoding='utf-8') as f:
    json.dump(nb, f, ensure_ascii=False, indent=2)

print("Notebook updated with TFLite copy command!")
