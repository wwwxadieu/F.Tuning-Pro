# TechWave

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
