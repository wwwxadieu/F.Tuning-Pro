import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_windows/webview_windows.dart';

import '../../app/ftune_license.dart';
import '../../app/ftune_ui.dart';

/// Cửa sổ thanh toán PayOS nhúng trong app qua WebView.
///
/// Flow:
/// 1. Gọi backend `/create-checkout-session` → lấy `checkoutUrl` + `orderCode`
/// 2. Mở WebView với `checkoutUrl` (PayOS checkout page)
/// 3. Sau khi thanh toán, PayOS redirect đến `/payment/success?orderCode=...`
/// 4. WebView detect URL chứa `/payment/success` → gọi `/license/{orderCode}`
/// 5. Nhận license key → tự động activate
class FTunePaymentPage extends StatefulWidget {
  const FTunePaymentPage({
    super.key,
    required this.onLicenseKeyObtained,
  });

  /// Callback khi lấy được license key từ payment flow.
  final ValueChanged<String> onLicenseKeyObtained;

  @override
  State<FTunePaymentPage> createState() => _FTunePaymentPageState();
}

class _FTunePaymentPageState extends State<FTunePaymentPage> {
  final _webviewController = WebviewController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isWebViewReady = false;
  bool _showEmailStep = true;
  String? _error;
  String? _orderCode;
  bool _licenseObtained = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    if (_isWebViewReady) {
      _webviewController.dispose();
    }
    super.dispose();
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    // Cho phép bỏ trống email (optional), nhưng nếu nhập thì phải hợp lệ
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => _error = 'Email không hợp lệ.');
      return;
    }
    setState(() {
      _showEmailStep = false;
      _isLoading = true;
      _error = null;
    });
    _initPayment(email: email.isEmpty ? null : email);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _initPayment({String? email}) async {
    try {
      // 1. Tạo checkout session từ backend (gửi kèm email nếu có)
      final response = await http
          .post(
            Uri.parse('${FTuneLicenseService.apiBaseUrl}/create-checkout-session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({if (email != null) 'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Server trả về mã ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final checkoutUrl = data['checkoutUrl'] as String?;
      _orderCode = data['orderCode'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('Không nhận được URL thanh toán từ server.');
      }

      // 2. Khởi tạo WebView
      await _webviewController.initialize();
      _isWebViewReady = true;

      // 3. Lắng nghe URL thay đổi để detect success/cancel
      _webviewController.url.listen(_onUrlChanged);

      // 4. Load checkout URL
      await _webviewController.loadUrl(checkoutUrl);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _onUrlChanged(String url) {
    if (_licenseObtained) return;

    if (url.contains('/payment/success')) {
      _handlePaymentSuccess();
    } else if (url.contains('/payment/cancel')) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_licenseObtained || _orderCode == null) return;
    _licenseObtained = true;

    // Chờ webhook xử lý (PayOS webhook có thể mất vài giây)
    // Retry tối đa 10 lần, mỗi lần cách 2 giây
    String? licenseKey;
    for (int i = 0; i < 10; i++) {
      try {
        final response = await http
            .get(Uri.parse(
                '${FTuneLicenseService.apiBaseUrl}/license/$_orderCode'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          licenseKey = data['licenseKey'] as String?;
          if (licenseKey != null && licenseKey.isNotEmpty) break;
        }
      } catch (_) {}

      await Future<void>.delayed(const Duration(seconds: 2));
    }

    if (licenseKey != null && licenseKey.isNotEmpty) {
      widget.onLicenseKeyObtained(licenseKey);
    } else if (mounted) {
      setState(() {
        _error = 'Không thể lấy mã kích hoạt. Vui lòng liên hệ hỗ trợ.';
      });
    }
  }

  Widget _buildEmailStep(FTuneElectronPaletteData palette) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined,
                  size: 48, color: palette.accent),
              const SizedBox(height: 16),
              Text(
                'Nhập email để nhận mã kích hoạt',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Mã kích hoạt sẽ được gửi về email này để backup, '
                'phòng trường hợp bạn cần cài lại app.',
                style: TextStyle(color: palette.muted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: palette.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'your@email.com (không bắt buộc)',
                  hintStyle: TextStyle(color: palette.muted),
                  filled: true,
                  fillColor: palette.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.accent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  prefixIcon: Icon(Icons.mail_outline_rounded,
                      color: palette.muted, size: 20),
                ),
                onSubmitted: (_) => _submitEmail(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitEmail,
                  icon: const Icon(Icons.payment_rounded, size: 18),
                  label: const Text('Tiếp tục thanh toán'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);

    return Scaffold(
      backgroundColor: palette.surface,
      appBar: AppBar(
        backgroundColor: palette.chromeTop,
        foregroundColor: palette.text,
        title: const Text(
          'Nâng cấp lên Pro',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: _buildBody(palette),
    );
  }

  Widget _buildBody(FTuneElectronPaletteData palette) {
    if (_showEmailStep) {
      return _buildEmailStep(palette);
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Đang kết nối đến cổng thanh toán...',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.text, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _showEmailStep = true;
                    _isLoading = false;
                    _error = null;
                    _licenseObtained = false;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isWebViewReady) {
      return const Center(child: CircularProgressIndicator());
    }

    return Webview(_webviewController);
  }
}
