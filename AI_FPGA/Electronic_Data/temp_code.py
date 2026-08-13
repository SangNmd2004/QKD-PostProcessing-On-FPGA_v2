from google.colab import drive
drive.mount('/content/drive')

!pip install -q ultralytics
!mkdir -p /content/dataset/electronic_components
!unzip -q "/content/drive/MyDrive/Electronic Components.v2i.yolov11.zip" -d /content/dataset/electronic_components
print("Giải nén dataset thành công!")

import yaml

yaml_path = '/content/dataset/electronic_components/data.yaml'

with open(yaml_path, 'r', encoding='utf-8') as f:
    data = yaml.safe_load(f)

# Thiết lập thư mục gốc tuyệt đối của dataset trên Colab
data['path'] = '/content/dataset/electronic_components'
# Chuẩn hóa các đường dẫn tập train, val, test
data['train'] = 'train/images'
data['val'] = 'valid/images'
data['test'] = 'test/images'

with open(yaml_path, 'w', encoding='utf-8') as f:
    yaml.dump(data, f, allow_unicode=True)

print("Đã cấu hình lại data.yaml thành công:")
print("-" * 40)
print(yaml.dump(data, allow_unicode=True))

import os
from ultralytics import YOLO

# 1. Định nghĩa thư mục lưu trữ trên Google Drive để CHỐNG MẤT DỮ LIỆU khi mất điện/rớt mạng Colab
project_dir = '/content/drive/MyDrive/electronic_components_yolo'
run_name = 'train_416'
last_checkpoint = f"{project_dir}/{run_name}/weights/last.pt"

# 2. Kiểm tra xem trước đó có đang train dở dang (bị ngắt kết nối do mất điện/hết timeout) hay không
if os.path.exists(last_checkpoint):
    print(f"🔄 Phát hiện checkpoint cũ tại Google Drive: {last_checkpoint}")
    print("🚀 Đang tự động khôi phục (RESUME) quá trình huấn luyện từ epoch bị gián đoạn...")
    model = YOLO(last_checkpoint)
    results = model.train(resume=True)
else:
    print("🌟 Bắt đầu huấn luyện mới từ đầu với mô hình YOLOv11 Nano...")
    model = YOLO('yolo11n.pt')
    results = model.train(
        data='/content/dataset/electronic_components/data.yaml',
        epochs=100,
        imgsz=416,           # Kích thước 416x416 tối ưu tốc độ inference trên FPGA
        batch=64,            # Tăng batch lên 64 giúp tận dụng VRAM GPU và train nhanh hơn
        workers=8,           # Sử dụng 8 luồng CPU của Colab để đọc dữ liệu siêu nhanh
        amp=True,            # Kích hoạt Mixed Precision (FP16) giúp tăng tốc train
        save=True,           # Tự động lưu checkpoint sau mỗi epoch
        project=project_dir, # LƯU THẲNG VÀO GOOGLE DRIVE: Vĩnh viễn không mất dữ liệu khi mất điện/rớt mạng
        name=run_name
    )

# 3. Export sang định dạng ONNX tối ưu cho FPGA
onnx_path = model.export(format='onnx', imgsz=416, opset=12, simplify=True)

print("=" * 60)
print(f"HOÀN TẤT! File ONNX đã được tạo tại: {onnx_path}")
print("Bạn hãy mở Google Drive của bạn ra, vào thư mục: electronic_components_yolo -> train_416 -> weights/")
print("Tải file best.onnx và best.pt về máy để chuẩn bị bước tiếp theo cho FPGA!")

# Tạo thư mục backup trên Google Drive
!mkdir -p "/content/drive/MyDrive/FOD_YOLO_Backup_All"

# Copy toàn bộ thư mục runs (và cả thư mục project cũ nếu có) sang Google Drive
!cp -r /content/runs/* "/content/drive/MyDrive/FOD_YOLO_Backup_All/" 2>/dev/null || true
!cp -r /content/electronic_components_yolo/* "/content/drive/MyDrive/FOD_YOLO_Backup_All/" 2>/dev/null || true

print("=" * 60)
print("✅ Đã sao chép toàn bộ dữ liệu huấn luyện và mô hình sang Google Drive!")
print("📂 Vui lòng vào Google Drive của bạn, kiểm tra thư mục: MyDrive -> FOD_YOLO_Backup_All")