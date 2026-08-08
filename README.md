# F.VNN

Ứng dụng web desktop tổng hợp tin tức công nghệ theo thời gian thực, giao diện lấy cảm hứng từ Apple.

## Tính năng

- **Tổng hợp tin tức tự động** — lấy tin từ TechCrunch, The Verge, Ars Technica, Wired, Engadget, 9to5Mac, The Hacker News, VentureBeat qua RSS
- **Giao diện Apple style** — nền tối, kính mờ (glassmorphism), typography lớn, chuyển động mượt theo chuẩn easing của Apple
- **3D animation khi cuộn** — hero section có hiệu ứng parallax 3D (rotateX, scale, lớp orb chuyển động), thẻ tin tức nghiêng 3D theo con trỏ chuột và xuất hiện với hiệu ứng cuộn
- **Sắp xếp theo thẻ** — lọc tin theo chủ đề: AI, Apple, Bảo mật, Di động, Phần mềm, Phần cứng, Gaming, Startup, Big Tech
- **Thông báo tin mới** — dùng Web Notifications API, tự động kiểm tra tin mới mỗi 3 phút và báo cho người dùng

## Công nghệ

- Next.js 16 (App Router) + TypeScript
- Tailwind CSS
- Framer Motion (scroll & 3D animation)
- rss-parser (tổng hợp RSS phía server)

## Chạy dự án

```bash
npm install
npm run dev
```

Mở [http://localhost:3000](http://localhost:3000).

API tổng hợp tin tức: `GET /api/news` (cache 5 phút, chạy trên Node runtime).

## Build ứng dụng desktop (Windows / macOS)

TechWave chạy trong Electron, đóng gói kèm server Next.js standalone nên không cần cài Node.js hay mở trình duyệt riêng.

```bash
npm install

# Windows: tạo installer NSIS + bản portable trong release/
npm run electron:dist:win

# macOS: tạo .app (zip) cho Intel + Apple Silicon, và .dmg nếu build trên máy macOS thật
npm run electron:dist:mac

# Cả hai nền tảng
npm run electron:dist
```

Kết quả nằm trong thư mục `release/`. Lưu ý:

- Build cho Windows (NSIS `.exe` + portable `.exe`) có thể thực hiện trên Linux/macOS/Windows nhờ `electron-builder` (trên Linux cần cài `wine`).
- Build `.dmg` cho macOS bắt buộc phải chạy trên máy macOS thật (phụ thuộc công cụ `sips`/`hdiutil` của Apple) — trên nền tảng khác chỉ tạo được bản `.zip` chứa `TechWave.app`.
- Các file trong `release/` không được ký (unsigned) nên Windows SmartScreen / macOS Gatekeeper sẽ cảnh báo khi chạy lần đầu; người dùng cần chọn "Run anyway" / "Open Anyway".
