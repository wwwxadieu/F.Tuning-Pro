import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TechWave — Tổng hợp tin công nghệ",
  description:
    "Tổng hợp tin tức công nghệ mới nhất theo thời gian thực, phân loại theo thẻ, giao diện lấy cảm hứng từ Apple.",
};

export const viewport: Viewport = {
  themeColor: "#0a0a0c",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="vi">
      <body className="min-h-screen bg-ink font-display antialiased">
        {children}
      </body>
    </html>
  );
}
