import os
import sys
try:
    from dotenv import load_dotenv
    import anthropic
except ImportError:
    print("Lỗi: Thiếu thư viện. Hãy chạy lệnh sau để cài đặt:")
    print("pip install anthropic python-dotenv")
    sys.exit(1)

# Tải file .env
load_dotenv()

# Kiểm tra API Key
api_key = os.getenv("ANTHROPIC_API_KEY")
if not api_key:
    print("Lỗi: Không tìm thấy ANTHROPIC_API_KEY trong file .env")
    print("Hãy mở file .env và thêm dòng: ANTHROPIC_API_KEY=your_api_key_here")
    sys.exit(1)

# Khởi tạo client Claude
client = anthropic.Anthropic(api_key=api_key)

# Định nghĩa tính cách của Agent
SYSTEM_PROMPT = """Bạn là một Kỹ sư phần cứng cấp cao, một chuyên gia thực thụ trong việc viết, phân tích, thiết kế và gỡ lỗi mã nguồn Verilog cho FPGA/ASIC.
Nhiệm vụ của bạn là hỗ trợ người dùng giải quyết các vấn đề về thiết kế mạch số, phân tích lỗi RTL, viết testbench, và tối ưu hóa tài nguyên phần cứng. 
Hãy đưa ra các lời giải thích rõ ràng, súc tích và đính kèm code Verilog chuẩn mực khi cần thiết."""

# Mảng lưu trữ lịch sử trò chuyện
chat_history = []

print("="*60)
print("🤖 Claude-3-Opus Agent: Chuyên gia Verilog & FPGA")
print("Gõ 'exit' hoặc 'quit' để kết thúc trò chuyện.")
print("="*60)

while True:
    try:
        user_input = input("\nBạn: ")
        
        # Xử lý thoát
        if user_input.strip().lower() in ['exit', 'quit']:
            print("\nClaude: Tạm biệt! Hẹn gặp lại bạn trong các dự án FPGA tiếp theo.")
            break
            
        if not user_input.strip():
            continue

        # Thêm câu hỏi của người dùng vào lịch sử
        chat_history.append({"role": "user", "content": user_input})

        # Gọi API của Claude
        response = client.messages.create(
            model="claude-3-opus-20240229", # Sử dụng model Opus cao cấp nhất
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            messages=chat_history
        )

        # Lấy câu trả lời
        assistant_reply = response.content[0].text
        print(f"\nClaude:\n{assistant_reply}")
        
        # Thêm câu trả lời vào lịch sử để Claude nhớ bối cảnh
        chat_history.append({"role": "assistant", "content": assistant_reply})

    except KeyboardInterrupt:
        print("\nClaude: Đã ngắt kết nối. Tạm biệt!")
        break
    except Exception as e:
        print(f"\n[!] Lỗi trong quá trình gọi API: {e}")
        # Nếu lỗi (ví dụ hết tiền/hết hạn quota), xóa câu hỏi vừa rồi ra khỏi lịch sử để tránh kẹt
        if len(chat_history) > 0 and chat_history[-1]["role"] == "user":
            chat_history.pop()
