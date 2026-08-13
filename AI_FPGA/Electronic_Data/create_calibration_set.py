import os
import random
import shutil
import glob
import cv2

def create_calibration_set():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    valid_images_dir = os.path.join(base_dir, "Electronic Components.v2i.yolov11", "valid", "images")
    output_dir = os.path.join(base_dir, "calibration_images")

    if not os.path.exists(valid_images_dir):
        print(f"Error: Could not find valid images folder at {valid_images_dir}")
        return

    os.makedirs(output_dir, exist_ok=True)

    # Tìm toàn bộ file ảnh trong mục valid
    extensions = ('*.jpg', '*.jpeg', '*.png', '*.bmp')
    image_files = []
    for ext in extensions:
        image_files.extend(glob.glob(os.path.join(valid_images_dir, ext)))

    print(f"Found {len(image_files)} images in {valid_images_dir}.")
    if len(image_files) == 0:
        print("Error: No images found to create calibration set.")
        return

    # Lấy ngẫu nhiên tối đa 150 ảnh để làm tập calibration
    num_samples = min(150, len(image_files))
    selected_files = random.sample(image_files, num_samples)

    print(f"Selecting {num_samples} random images for INT8 calibration...")
    for i, src_path in enumerate(selected_files):
        filename = f"calib_elec_{i:03d}.jpg"
        dest_path = os.path.join(output_dir, filename)
        
        # Đọc ảnh, chuyển về chuẩn 416x416 cho mạng NPU/GEMM và lưu
        try:
            img = cv2.imread(src_path)
            if img is not None:
                if img.shape[0] != 416 or img.shape[1] != 416:
                    img = cv2.resize(img, (416, 416))
                cv2.imwrite(dest_path, img)
            else:
                shutil.copy2(src_path, dest_path)
        except Exception as e:
            shutil.copy2(src_path, dest_path)

    calib_count = len(glob.glob(os.path.join(output_dir, "*.*")))
    print(f"\nSuccess! Generated calibration dataset with {calib_count} images in '{output_dir}'.")

if __name__ == "__main__":
    create_calibration_set()
