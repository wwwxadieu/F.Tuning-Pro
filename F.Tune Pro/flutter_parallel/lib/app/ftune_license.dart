import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Trạng thái license Pro.
enum LicenseStatus {
  /// Chưa kích hoạt — bản Free.
  free,

  /// Đã kích hoạt thành công — bản Pro.
  pro,

  /// Đang xác thực (loading).
  validating,
}

/// Kết quả trả về từ API khi validate license key.
class LicenseValidationResult {
  const LicenseValidationResult({
    required this.valid,
    this.message,
  });

  final bool valid;
  final String? message;

  factory LicenseValidationResult.fromJson(Map<String, dynamic> json) {
    return LicenseValidationResult(
      valid: json['valid'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }
}

/// Service xác thực license key qua API online.
///
/// **Cấu hình API endpoint:**
/// Thay đổi [apiBaseUrl] thành URL của backend xác thực license của bạn.
///
/// **API contract:**
/// ```
/// POST {apiBaseUrl}/validate
/// Body: { "licenseKey": "XXXXX-XXXXX-XXXXX-XXXXX" }
/// Response: { "valid": true/false, "message": "..." }
/// ```
class FTuneLicenseService {
  FTuneLicenseService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  // ── Cấu hình ──────────────────────────────────────────────────────────────
  // Khi deploy production: thay đổi URL này thành domain thật.
  static const String apiBaseUrl = 'http://localhost:3000';
  static const Duration _timeout = Duration(seconds: 15);

  /// Dev key — chỉ dùng để test offline, không cần server.
  static const String devKey = 'FTUNE-DEV-2026-UNLOCK-PRO';

  /// Gửi license key lên server để xác thực.
  ///
  /// Trả về [LicenseValidationResult] cho biết key hợp lệ hay không.
  /// Nếu không thể kết nối server, trả về invalid kèm message lỗi.
  Future<LicenseValidationResult> validateOnline(String licenseKey) async {
    final trimmed = licenseKey.trim();
    if (trimmed.isEmpty) {
      return const LicenseValidationResult(
        valid: false,
        message: 'License key không được để trống.',
      );
    }

    // Dev key bypass — validate offline.
    if (trimmed == devKey) {
      return const LicenseValidationResult(valid: true, message: 'Dev license activated.');
    }

    try {
      final uri = Uri.parse('$apiBaseUrl/validate');
      final response = await _http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'licenseKey': trimmed,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return LicenseValidationResult.fromJson(data);
      }

      // Server trả về lỗi
      String? serverMsg;
      try {
        final data =
            jsonDecode(response.body) as Map<String, dynamic>;
        serverMsg = data['message'] as String?;
      } catch (_) {}

      return LicenseValidationResult(
        valid: false,
        message: serverMsg ?? 'Server trả về mã ${response.statusCode}.',
      );
    } catch (e) {
      debugPrint('[FTuneLicense] Validate error: $e');
      return LicenseValidationResult(
        valid: false,
        message: 'Không thể kết nối server. Kiểm tra mạng và thử lại.',
      );
    }
  }
}
