# Nhật Ký Thay Đổi - F.Tune Pro

Tất cả các thay đổi đáng chú ý sẽ được ghi lại trong file này.

---

## [0.1.0-beta] - 2026-04-20

### ✨ Tính năng chính

- **Dashboard hiện đại** — Giao diện bento grid responsive với preview xe, thống kê nhanh và truy cập nhanh các chức năng
- **Tạo Tune tự động** — Chọn xe từ cơ sở dữ liệu FH5/FH6, nhập thông số → nhận bộ tune hoàn chỉnh (lò xo, giảm chấn, thanh cân bằng, hộp số, v.v.)
- **Garage** — Lưu trữ, ghim, xuất/nhập các tune đã tạo dưới dạng file JSON
- **Overlay trong game** — Hiển thị thông số tune dạng cửa sổ luôn nằm trên, hỗ trợ khóa vị trí và tùy chỉnh opacity
- **Hỗ trợ đa ngôn ngữ** — Tiếng Việt & Tiếng Anh, chuyển đổi tức thì
- **Welcome Tour** — Hướng dẫn người dùng mới với slides giới thiệu từng tính năng
- **Dark / Light theme** — Chuyển đổi theme tối/sáng, tùy chỉnh accent color
- **Custom background** — Đặt ảnh hoặc video làm nền dashboard
- **Tự động cập nhật** — Kiểm tra và tải phiên bản mới trực tiếp từ GitHub
- **Hỗ trợ Donate** — QR code ủng hộ tác giả

### 🛠️ Sửa lỗi

- Sửa Welcome Tour không che phủ hoàn toàn giao diện phía sau — thêm lớp scrim tối + chặn tương tác nền
- Sửa lỗi Zone mismatch khi khởi động app (đưa toàn bộ initialization vào `runZonedGuarded`)
- Ẩn dialog thông báo crash trong giai đoạn beta (chỉ log ra console)
- Giảm kích thước ảnh xe preview từ 1920px → 800px (API) và thêm `cacheWidth` cho widget

### 📦 Kỹ thuật

- Flutter Desktop (Windows) — SDK >=3.3.0
- Dữ liệu lưu trữ qua SharedPreferences + file JSON cục bộ
- Cơ chế update tự thay thế exe qua PowerShell script
- Hỗ trợ multi-window (overlay) qua `desktop_multi_window`
