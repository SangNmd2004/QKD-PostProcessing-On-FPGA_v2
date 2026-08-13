import json

cells = [
    {
        'cell_type': 'code',
        'metadata': {},
        'execution_count': None,
        'outputs': [],
        'source': [
            'from google.colab import drive\n',
            'drive.mount(' + chr(39) + '/content/drive' + chr(39) + ')\n',
            '\n',
            '!pip install -q ultralytics\n',
            '!mkdir -p /content/dataset/electronic_components\n',
            '!unzip -q "/content/drive/MyDrive/Electronic Components.v2i.yolov11.zip" -d /content/dataset/electronic_components\n',
            'print("Giải nén dataset thành công!")\n'
        ]
    },
    {
        'cell_type': 'code',
        'metadata': {},
        'execution_count': None,
        'outputs': [],
        'source': [
            'import yaml\n',
            '\n',
            'yaml_path = ' + chr(39) + '/content/dataset/electronic_components/data.yaml' + chr(39) + '\n',
            '\n',
            'with open(yaml_path, ' + chr(39) + 'r' + chr(39) + ', encoding=' + chr(39) + 'utf-8' + chr(39) + ') as f:\n',
            '    data = yaml.safe_load(f)\n',
            '\n',
            'data[' + chr(39) + 'path' + chr(39) + '] = ' + chr(39) + '/content/dataset/electronic_components' + chr(39) + '\n',
            'data[' + chr(39) + 'train' + chr(39) + '] = ' + chr(39) + 'train/images' + chr(39) + '\n',
            'data[' + chr(39) + 'val' + chr(39) + '] = ' + chr(39) + 'valid/images' + chr(39) + '\n',
            'data[' + chr(39) + 'test' + chr(39) + '] = ' + chr(39) + 'test/images' + chr(39) + '\n',
            '\n',
            'with open(yaml_path, ' + chr(39) + 'w' + chr(39) + ', encoding=' + chr(39) + 'utf-8' + chr(39) + ') as f:\n',
            '    yaml.dump(data, f, allow_unicode=True)\n',
            '\n',
            'print("Đã cấu hình lại data.yaml thành công!")\n'
        ]
    },
    {
        'cell_type': 'code',
        'metadata': {},
        'execution_count': None,
        'outputs': [],
        'source': [
            'import os\n',
            'from ultralytics import YOLO\n',
            '\n',
            'project_dir = ' + chr(39) + '/content/drive/MyDrive/electronic_components_yolo' + chr(39) + '\n',
            'run_name = ' + chr(39) + 'train_yolo11s_416' + chr(39) + '\n',
            'last_checkpoint = f"{project_dir}/{run_name}/weights/last.pt"\n',
            '\n',
            'if os.path.exists(last_checkpoint):\n',
            '    print(f"🔄 Đã tìm thấy Checkpoint! Phục hồi huấn luyện tránh mất điện...")\n',
            '    model = YOLO(last_checkpoint)\n',
            '    results = model.train(resume=True)\n',
            'else:\n',
            '    print("🌟 Bắt đầu huấn luyện mới với YOLOv11s...")\n',
            '    model = YOLO(' + chr(39) + 'yolo11s.pt' + chr(39) + ') # Sử dụng bản Small (s)\n',
            '    results = model.train(\n',
            '        data=' + chr(39) + '/content/dataset/electronic_components/data.yaml' + chr(39) + ',\n',
            '        epochs=100,\n',
            '        imgsz=416,           # Giữ nguyên 416x416\n',
            '        batch=64,            # TĂNG BATCH SIZE lên 64 theo yêu cầu để tận dụng tối đa VRAM GPU\n',
            '        workers=8,\n',
            '        amp=True,\n',
            '        save=True,           # Lưu model liên tục\n',
            '        project=project_dir, # Lưu thẳng lên Google Drive, rớt mạng không lo mất!\n',
            '        name=run_name\n',
            '    )\n'
        ]
    },
    {
        'cell_type': 'code',
        'metadata': {},
        'execution_count': None,
        'outputs': [],
        'source': [
            '# Export sang TFLite INT8 (Bắt buộc cho FPGA)\n',
            'print("Đang tiến hành Lượng tử hóa INT8 (INT8 Quantization) cho FPGA...")\n',
            'tflite_path = model.export(\n',
            '    format=' + chr(39) + 'tflite' + chr(39) + ',\n',
            '    int8=True,\n',
            '    data=' + chr(39) + '/content/dataset/electronic_components/data.yaml' + chr(39) + ', # Ép dùng tập dataset này để Quantize\n',
            '    imgsz=416\n',
            ')\n',
            '\n',
            'print("HOÀN TẤT! File TFLite INT8 đã được tạo tại:", tflite_path)\n'
        ]
    },
    {
        'cell_type': 'code',
        'metadata': {},
        'execution_count': None,
        'outputs': [],
        'source': [
            '# CƠ CHẾ BACKUP BỔ SUNG\n',
            '!mkdir -p "/content/drive/MyDrive/FOD_YOLO_Backup_All"\n',
            '!cp -r /content/runs/* "/content/drive/MyDrive/FOD_YOLO_Backup_All/" 2>/dev/null || true\n',
            '!cp -r /content/electronic_components_yolo/* "/content/drive/MyDrive/FOD_YOLO_Backup_All/" 2>/dev/null || true\n',
            '\n',
            'print("✅ Đã sao chép toàn bộ dữ liệu huấn luyện (Biểu đồ, log, weights) sang Google Drive để dự phòng an toàn tuyệt đối!")\n'
        ]
    }
]

notebook = {
    'cells': cells,
    'metadata': {
        'colab': {'provenance': []},
        'kernelspec': {'name': 'python3', 'display_name': 'Python 3'},
        'language_info': {'name': 'python'}
    },
    'nbformat': 4,
    'nbformat_minor': 0
}

with open('YOLO11s_Training/train_yolo11s_for_FPGA.ipynb', 'w', encoding='utf-8') as f:
    json.dump(notebook, f, ensure_ascii=False, indent=2)

print("Notebook updated successfully!")
