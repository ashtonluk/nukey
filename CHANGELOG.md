# Nhật ký thay đổi

Mọi thay đổi đáng chú ý của NuKey được ghi lại tại đây.

## 0.1.1 — 15/11/2026

### Sửa lỗi

- Đặt dấu móc theo cụm nguyên âm cho cả VNI và Telex: `cuu71` → `cứu` (trước đây ra `cuứ`), `ruou75` → `rượu`, `huu7` → `hưu`.
- Số `0` trong VNI luôn giữ nguyên là số 0: `co0` → `co0`. Bỏ chức năng dùng `0` để xóa dấu thanh.
- Khi macOS tạm tắt việc bắt phím vì NuKey phản hồi chậm (thường do máy thiếu RAM), NuKey bỏ từ đang gõ dở để không xóa nhầm chữ, và ghi lại sự kiện vào `~/Library/Logs/NuKey.log`.

### Cải tiến

- Tự giữ nguyên phím đã gõ khi từ không phải âm tiết tiếng Việt: `melbourne1` → `melbourne1`, `me2lbourne1` → `me2lbourne1`, `hello2` → `hello2`.

## 0.1.0 — 12/11/2026

Bản phát hành đầu tiên.

- Gõ tiếng Việt theo VNI hoặc Simple Telex, chạy trên thanh menu.
- Chuyển ENG / tiếng Việt bằng thanh chọn hoặc phím tắt (Control + Shift, Command + Shift, Option + Shift).
- Từ thay thế, nhập và xuất danh sách bằng tệp TXT.
- Tùy chọn khởi động cùng máy Mac.
- Trình cài đặt bằng Terminal có kiểm tra SHA-256.
