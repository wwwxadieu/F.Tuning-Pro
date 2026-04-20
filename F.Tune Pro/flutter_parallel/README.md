# F.Tune Pro

> Ứng dụng tạo tune xe tự động cho Forza Horizon 5 & 6 — chạy trên Windows.

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Flutter](https://img.shields.io/badge/Flutter-Desktop-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-Beta-orange)

---

## Giới thiệu

**F.Tune Pro** là công cụ hỗ trợ người chơi Forza Horizon tạo bộ tune (thiết lập) cho xe một cách nhanh chóng và chính xác. Chỉ cần chọn xe, nhập thông số cơ bản — ứng dụng sẽ tính toán và đưa ra bộ tune hoàn chỉnh bao gồm:

- Lò xo & Giảm chấn (Springs & Damping)
- Thanh cân bằng (Anti-Roll Bars)
- Hộp số (Gearing)
- Căn chỉnh (Alignment)
- Khí động học (Aero)
- Phanh (Brakes)

## Tính năng

| Tính năng | Mô tả |
|-----------|-------|
| 🏎️ **Tạo Tune** | Chọn xe từ database FH5/FH6, nhập thông số → nhận tune hoàn chỉnh |
| 🏠 **Dashboard** | Giao diện bento grid hiện đại với preview xe và truy cập nhanh |
| 🗃️ **Garage** | Lưu, ghim, xuất/nhập tune dưới dạng JSON |
| 🖥️ **Overlay** | Cửa sổ hiển thị tune luôn nằm trên game |
| 🌐 **Đa ngôn ngữ** | Tiếng Việt & Tiếng Anh |
| 🎨 **Tùy biến** | Dark/Light theme, accent color, ảnh/video nền |
| 🔄 **Tự cập nhật** | Kiểm tra & tải bản mới trực tiếp từ GitHub |
| 👋 **Welcome Tour** | Hướng dẫn người dùng mới qua từng tính năng |

## Cài đặt

### Installer (khuyên dùng)
Tải file **F.Tune-Pro-Setup.exe** từ [Releases](https://github.com/wwwxadieu/F.Tuning-Pro/releases/latest) và cài đặt bình thường.

### Portable
Tải file **F.Tune-Pro-Portable.zip**, giải nén và chạy trực tiếp — không cần cài đặt.

## Build từ source

Yêu cầu: [Flutter SDK](https://flutter.dev) ≥ 3.3.0

```powershell
cd flutter_parallel
flutter pub get
flutter run -d windows          # Debug
flutter build windows --release # Release
```

### Build Installer (cần Inno Setup 6)
```powershell
.\tool\build_installer.ps1
```

### Build Portable
```powershell
.\tool\build_portable.ps1
```

## Cấu trúc dự án

```
lib/
├── main.dart                  # Entry point
├── app/
│   ├── ftune_app.dart         # MaterialApp
│   ├── ftune_shell.dart       # Shell + Welcome Tour + Update Banner
│   ├── ftune_app_controller.dart  # State management
│   ├── ftune_storage.dart     # SharedPreferences + file I/O
│   ├── ftune_update_checker.dart  # Kiểm tra phiên bản mới
│   └── ftune_updater.dart     # Tải & cài đặt update
└── features/
    ├── create/                # Tạo tune mới
    ├── dashboard/             # Trang chính
    └── settings/              # Cài đặt & donate
```

## Ủng hộ

Nếu bạn thấy ứng dụng hữu ích, hãy ủng hộ tác giả qua tính năng **Donate** trong phần Cài đặt của app.

## Liên hệ

- GitHub: [@wwwxadieu](https://github.com/wwwxadieu)
- Email: contact.vndrift@gmail.com
