---
name: code-review
description: Hướng dẫn review code theo chuẩn team. Dùng khi được yêu cầu review PR hoặc code mới.
argument-hint: [file] [options]
user-invocable: true
---

# Code Review Skill

## Khi nào dùng
Dùng skill này khi:
- Được yêu cầu review pull request
- Cần kiểm tra code trước khi commit
- Tìm bug hoặc vấn đề bảo mật

## Quy trình review

1. **Kiểm tra cấu trúc**: Đảm bảo code tuân theo architecture đã định nghĩa
2. **Đọc logic chính**: Tập trung vào hàm/function chính
3. **Kiểm tra edge cases**: Tìm các trường hợp biên
4. **Gợi ý cải thiện**: Đề xuất refactor nếu cần

## Checklist
- [ ] Code có test coverage đủ không?
- [ ] Có xử lý lỗi đúng cách không?
- [ ] Tên biến/hàm có rõ nghĩa không?
- [ ] Có comment giải thích logic phức tạp không?

## Tham chiếu
- [Coding standards](./coding-standards.md)
- [Security checklist](./security-checklist.md)
