import os
import yaml
from ultralytics import YOLO

def export_int8_tflite():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(base_dir, "YOLO11s_Training", "train_yolo11s_416-2", "weights", "best.pt")
    calib_dir = os.path.join(base_dir, "calibration_images")
    
    if not os.path.exists(model_path):
        print(f"Error: Could not find model at {model_path}")
        return
    
    if not os.path.exists(calib_dir) or len(os.listdir(calib_dir)) == 0:
        print(f"Error: Calibration images not found in {calib_dir}")
        return

    # Tạo file config calibration YAML trỏ trực tiếp tới tập calibration 150 ảnh 416x416
    calib_yaml_path = os.path.join(base_dir, "calib_data.yaml")
    calib_data = {
        'path': calib_dir,
        'train': '.',
        'val': '.',
        'test': '.',
        'nc': 8,
        'names': {
            0: 'Button',
            1: 'Capacitor',
            2: 'IC',
            3: 'Led',
            4: 'Pot',
            5: 'Resistor',
            6: 'Sensor',
            7: 'Transistor'
        }
    }
    
    with open(calib_yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump(calib_data, f, default_flow_style=False)
        
    print(f"Created temporary calibration config at {calib_yaml_path}")
    print(f"Loading YOLOv11 model from {model_path}...")
    model = YOLO(model_path)
    
    print("Starting INT8 TFLite export (this may take 1-2 minutes for calibration)...")
    try:
        # Thực hiện export sang tflite với int8=True
        exported_path = model.export(
            format="tflite",
            int8=True,
            imgsz=416,
            data=calib_yaml_path
        )
        print(f"\nSuccess! Exported INT8 TFLite model to: {exported_path}")
    except Exception as e:
        print(f"\nError during export: {e}")

if __name__ == "__main__":
    export_int8_tflite()
