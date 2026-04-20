import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../../app/ftune_license.dart';
import '../../app/ftune_models.dart';
import '../../app/ftune_ui.dart';
import '../../features/payment/payment_page.dart';
import '../dashboard/widgets/bento_glass_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.languageCode,
    required this.preferences,
    required this.hasCustomBackground,
    required this.onBack,
    required this.onChanged,
    required this.onPickBackground,
    required this.onClearBackground,
    required this.onDropBackground,
    required this.onOpenWelcomeTour,
    this.isPro = false,
    this.licenseStatus,
    this.licenseKey,
    this.onActivateLicense,
    this.onDeactivateLicense,
  });

  final String languageCode;
  final AppPreferences preferences;
  final bool hasCustomBackground;
  final VoidCallback onBack;
  final ValueChanged<AppPreferences> onChanged;
  final Future<void> Function() onPickBackground;
  final Future<void> Function() onClearBackground;
  final Future<bool> Function(String path) onDropBackground;
  final VoidCallback onOpenWelcomeTour;
  final bool isPro;
  final Object? licenseStatus;
  final String? licenseKey;
  final Future<String?> Function(String key)? onActivateLicense;
  final Future<void> Function()? onDeactivateLicense;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Resend API key — revoke at https://resend.com/api-keys if compromised
  static const String _resendApiKey = 're_ae9uHyYM_Dj7KfQ9BsVHjwkz9yAEyLjZY';
  static const String _resendSenderFrom = 'MrBeoHP - F.Tuning Pro <onboarding@resend.dev>';
  static const String _resendInboxEmail = 'contact.vndrift@gmail.com';

  static Map<String, String> get _resendHeaders => <String, String>{
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_resendApiKey',
  };

  // EmailJS — thank-you emails to any user address (no domain required)
  static const String _emailJsServiceId = 'service_olcoahg';
  static const String _emailJsTemplateId = 'template_65qjz6j';
  static const String _emailJsPublicKey = '5Jyr7nIFXkcSfF-VS';



  static const List<Color> _accentOptions = <Color>[
    Color(0xFFCAFF03),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF00BCD4),
  ];
  static const String _welcomeActivationCode = '425271';

  final TextEditingController _welcomeCodeController = TextEditingController();

  static final RegExp _emailRegex = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );
  static const Set<String> _allowedFeedbackDomains = <String>{
    'gmail.com',
    'googlemail.com',
    'outlook.com',
    'hotmail.com',
    'live.com',
    'msn.com',
    'yahoo.com',
    'icloud.com',
    'me.com',
    'proton.me',
    'protonmail.com',
    'aol.com',
    'zoho.com',
    'gmx.com',
    'yandex.com',
  };

  bool _isAllowedFeedbackEmail(String email) {
    final atIndex = email.lastIndexOf('@');
    if (atIndex <= 0 || atIndex >= email.length - 1) return false;
    final domain = email.substring(atIndex + 1).toLowerCase();
    return _allowedFeedbackDomains.contains(domain);
  }

  @override
  void dispose() {
    _welcomeCodeController.dispose();
    super.dispose();
  }

  void _openWelcomeUnlockDialog() {
    final copy = _SettingsCopy.forLanguage(widget.languageCode);
    final palette = FTuneElectronPaletteData.of(context);
    _welcomeCodeController.clear();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        void submit(StateSetter setModalState) {
          final value = _welcomeCodeController.text.trim();
          if (value != _welcomeActivationCode) {
            setModalState(() {
              errorText = copy.isVietnamese ? 'Mã không đúng.' : 'Invalid code.';
            });
            return;
          }

          FocusScope.of(dialogContext).unfocus();
          Navigator.of(dialogContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onOpenWelcomeTour();
            }
          });
        }

        return StatefulBuilder(
          builder: (context, setModalState) => _buildModalDialog(
            context,
            copy,
            palette,
            title: copy.isVietnamese
                ? 'Mở lại Welcome Tour'
                : 'Unlock Welcome Tour',
            icon: Icons.lock_open_rounded,
            width: 420,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  copy.isVietnamese
                      ? 'Nhập mã riêng để hiện lại màn hình welcome.'
                      : 'Enter the private code to show the welcome screens again.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _welcomeCodeController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: copy.isVietnamese
                        ? 'Mã kích hoạt'
                        : 'Activation code',
                    errorText: errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setModalState(() => errorText = null);
                    }
                  },
                  onSubmitted: (_) => submit(setModalState),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(copy.close),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => submit(setModalState),
                child: Text(copy.isVietnamese ? 'Xác nhận' : 'Confirm'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = _SettingsCopy.forLanguage(widget.languageCode);
    final palette = FTuneElectronPaletteData.of(context);
    final isDark = palette.isDark;
    final text = isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1A1E28);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final twoColumn = constraints.maxWidth >= 920;
        final cardWidth = twoColumn
            ? (constraints.maxWidth - spacing) / 2
            : constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              BentoGlassContainer(
                borderRadius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                fillOpacity: palette.isDark ? 0.16 : 0.22,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _settingsHeroLead(copy, palette, text),
                    ),
                    const SizedBox(width: 12),
                    _heroActionButton(
                      icon: Icons.arrow_back_rounded,
                      label: copy.back,
                      onTap: widget.onBack,
                      palette: palette,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: <Widget>[
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _licenseCard(copy),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _settingsCard(
                      title: copy.appearanceTitle,
                      icon: Icons.palette_rounded,
                      subtitle: copy.appearanceCardSubtitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _themeMode(copy),
                          const SizedBox(height: 14),
                          _language(copy),
                          const SizedBox(height: 14),
                          _accentColor(copy),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _settingsCard(
                      title: copy.tuningTitle,
                      icon: Icons.tune_rounded,
                      subtitle: copy.tuningCardSubtitle,
                      child: Column(
                        children: <Widget>[
                          _switchLine(
                            label: copy.autoSave,
                            icon: Icons.save_outlined,
                            value: widget.preferences.autoSaveGarage,
                            onChanged: (value) {
                              widget.onChanged(
                                widget.preferences
                                    .copyWith(autoSaveGarage: value),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _switchLine(
                            label: copy.autoBackgroundFromCar,
                            icon: Icons.auto_awesome_rounded,
                            value:
                                widget.preferences.autoBackgroundFromCarColor,
                            onChanged: (value) {
                              widget.onChanged(
                                widget.preferences.copyWith(
                                  autoBackgroundFromCarColor: value,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _settingsCard(
                      title: copy.overlayTitle,
                      icon: Icons.open_in_new_rounded,
                      subtitle: copy.overlayCardSubtitle,
                      child: _overlaySettings(copy),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _settingsCard(
                      title: copy.supportTitle,
                      icon: Icons.help_outline_rounded,
                      subtitle: copy.supportCardSubtitle,
                      child: _supportActions(copy),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsHeroLead(
    _SettingsCopy copy,
    FTuneElectronPaletteData palette,
    Color text,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.accent.withAlpha(28),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.settings_rounded,
            size: 18,
            color: palette.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onDoubleTap: _openWelcomeUnlockDialog,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  copy.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: text,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required FTuneElectronPaletteData palette,
    bool filled = false,
  }) {
    final button = filled ? FilledButton.icon : OutlinedButton.icon;
    return button(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(110, 42)),
      ),
    );
  }

  Widget _sectionLabel(String title, FTuneElectronPaletteData palette,
      {IconData? icon}) {
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 13, color: palette.accent),
          const SizedBox(width: 6),
        ],
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: palette.accent,
          ),
        ),
      ],
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _sectionLabel(title, palette, icon: icon),
          if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: palette.muted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    final palette = FTuneElectronPaletteData.of(context);
    return BentoGlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      fillOpacity: palette.isDark ? 0.16 : 0.22,
      child: child,
    );
  }

  // ── License / Pro Activation ──────────────────────────────────────────────

  Widget _licenseCard(_SettingsCopy copy) {
    final palette = FTuneElectronPaletteData.of(context);
    final isPro = widget.isPro;
    final isValidating = widget.licenseStatus == LicenseStatus.validating;
    final licenseTitle =
        copy.isVietnamese ? 'Phiên bản Pro' : 'Pro License';
    final licenseSubtitle = copy.isVietnamese
        ? 'Kích hoạt để mở khóa tính năng cao cấp'
        : 'Activate to unlock premium features';

    return _settingsCard(
      title: licenseTitle,
      icon: isPro ? Icons.verified_rounded : Icons.workspace_premium_rounded,
      subtitle: licenseSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPro
                  ? const Color(0xFF4CAF50).withAlpha(24)
                  : palette.accent.withAlpha(16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPro
                    ? const Color(0xFF4CAF50).withAlpha(80)
                    : palette.border,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  isPro ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  size: 20,
                  color: isPro ? const Color(0xFF4CAF50) : palette.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isPro
                            ? (copy.isVietnamese ? 'Đã kích hoạt Pro' : 'Pro Activated')
                            : (copy.isVietnamese ? 'Bản Free' : 'Free Version'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPro ? const Color(0xFF4CAF50) : palette.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPro
                            ? (copy.isVietnamese
                                ? 'Tất cả tính năng đã được mở khóa'
                                : 'All features unlocked')
                            : (copy.isVietnamese
                                ? 'FH6 bị khóa · Garage tối đa 15 tune'
                                : 'FH6 locked · Garage max 15 tunes'),
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Pro features list
          if (!isPro) ...<Widget>[
            _proFeatureRow(
              icon: Icons.sports_esports_rounded,
              label: copy.isVietnamese
                  ? 'Mở khóa xe Forza Horizon 6'
                  : 'Unlock Forza Horizon 6 cars',
              palette: palette,
            ),
            const SizedBox(height: 6),
            _proFeatureRow(
              icon: Icons.all_inclusive_rounded,
              label: copy.isVietnamese
                  ? 'Garage không giới hạn (hiện tại: tối đa 15)'
                  : 'Unlimited garage (currently: max 15)',
              palette: palette,
            ),
            const SizedBox(height: 12),
          ],
          // Action buttons
          Row(
            children: <Widget>[
              if (!isPro) ...<Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isValidating
                        ? null
                        : () => _openPaymentPage(copy),
                    icon: const Icon(Icons.shopping_cart_rounded, size: 16),
                    label: Text(
                      copy.isVietnamese ? 'Mua Pro' : 'Buy Pro',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isValidating
                        ? null
                        : () => _showLicenseActivationDialog(copy),
                    icon: isValidating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key_rounded, size: 16),
                    label: Text(
                      copy.isVietnamese ? 'Nhập mã' : 'Enter code',
                    ),
                  ),
                ),
              ],
              if (isPro)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDeactivateConfirmDialog(copy),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: Text(
                      copy.isVietnamese ? 'Hủy kích hoạt' : 'Deactivate',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _proFeatureRow({
    required IconData icon,
    required String label,
    required FTuneElectronPaletteData palette,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: palette.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.text),
          ),
        ),
      ],
    );
  }

  void _openPaymentPage(_SettingsCopy copy) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FTunePaymentPage(
          onLicenseKeyObtained: (key) async {
            // Quay lại trang settings
            if (mounted) Navigator.of(context).pop();

            // Chờ animation pop xong
            await Future<void>.delayed(const Duration(milliseconds: 350));
            if (!mounted) return;

            // Tự động activate
            final errorMsg = await widget.onActivateLicense?.call(key);
            if (!mounted) return;

            final messenger = ScaffoldMessenger.maybeOf(context);
            if (errorMsg == null) {
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(
                    copy.isVietnamese
                        ? 'Kích hoạt Pro thành công! 🎉'
                        : 'Pro activated successfully! 🎉',
                  ),
                ),
              );
            } else {
              messenger?.showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _showLicenseActivationDialog(_SettingsCopy copy) {
    final palette = FTuneElectronPaletteData.of(context);
    final licenseCodeController = TextEditingController();

    showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setModalState) => _buildModalDialog(
            context,
            copy,
            palette,
            title: copy.isVietnamese
                ? 'Kích hoạt Pro'
                : 'Activate Pro',
            icon: Icons.workspace_premium_rounded,
            width: 440,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  copy.isVietnamese
                      ? 'Nhập mã kích hoạt Pro bạn đã nhận được sau khi thanh toán.'
                      : 'Enter the Pro activation code you received after payment.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: licenseCodeController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'XXXXX-XXXXX-XXXXX-XXXXX',
                    errorText: errorText,
                    prefixIcon: const Icon(Icons.key_rounded, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) {
                    if (errorText != null) {
                      setModalState(() => errorText = null);
                    }
                  },
                  onSubmitted: (_) {
                    final key = licenseCodeController.text.trim();
                    if (key.isEmpty) {
                      setModalState(() {
                        errorText = copy.isVietnamese
                            ? 'Vui lòng nhập mã.'
                            : 'Please enter a code.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(key);
                  },
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(copy.close),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  final key = licenseCodeController.text.trim();
                  if (key.isEmpty) {
                    setModalState(() {
                      errorText = copy.isVietnamese
                          ? 'Vui lòng nhập mã.'
                          : 'Please enter a code.';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(key);
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  copy.isVietnamese ? 'Kích hoạt' : 'Activate',
                ),
              ),
            ],
          ),
        );
      },
    ).then((key) async {
      licenseCodeController.dispose();
      if (key == null || key.isEmpty || !mounted) return;

      // Chờ dialog exit animation hoàn tất (~300ms) để tránh xung đột
      // build scope khi activateLicense gọi notifyListeners().
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final errorMsg = await widget.onActivateLicense?.call(key);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (errorMsg == null) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              copy.isVietnamese
                  ? 'Kích hoạt Pro thành công! 🎉'
                  : 'Pro activated successfully! 🎉',
            ),
          ),
        );
      } else {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });
  }

  void _showDeactivateConfirmDialog(_SettingsCopy copy) {
    final palette = FTuneElectronPaletteData.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _buildModalDialog(
        dialogContext,
        copy,
        palette,
        title: copy.isVietnamese ? 'Hủy kích hoạt Pro' : 'Deactivate Pro',
        icon: Icons.warning_amber_rounded,
        width: 400,
        content: Text(
          copy.isVietnamese
              ? 'Bạn có chắc muốn hủy kích hoạt? Bạn sẽ mất quyền truy cập các tính năng Pro.'
              : 'Are you sure you want to deactivate? You will lose access to Pro features.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: palette.text,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(copy.close),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Chờ dialog deactivate xong rồi mới gọi notifyListeners().
              SchedulerBinding.instance.addPostFrameCallback((_) {
                widget.onDeactivateLicense?.call();
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      copy.isVietnamese
                          ? 'Đã hủy kích hoạt Pro.'
                          : 'Pro deactivated.',
                    ),
                  ),
                );
              });
            },
            child: Text(
              copy.isVietnamese ? 'Hủy kích hoạt' : 'Deactivate',
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportActions(_SettingsCopy copy) {
    final palette = FTuneElectronPaletteData.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= 420;
        final buttonWidth =
            twoColumn ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;

        Widget actionButton({
          required Widget child,
        }) {
          return SizedBox(width: buttonWidth, child: child);
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            actionButton(
              child: OutlinedButton.icon(
                onPressed: () => _showFeedbackModal(context, copy, palette),
                icon: const Icon(Icons.feedback_outlined),
                label: Text(copy.feedbackTitle),
              ),
            ),
            actionButton(
              child: OutlinedButton.icon(
                onPressed: () => _showDonateModal(context, copy, palette),
                icon: const Icon(Icons.favorite_outline_rounded),
                label: Text(copy.donateTitle),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _themeMode(_SettingsCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.themeMode),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'system', label: Text(copy.system)),
            ButtonSegment<String>(value: 'light', label: Text(copy.light)),
            ButtonSegment<String>(value: 'dark', label: Text(copy.dark)),
          ],
          selected: <String>{widget.preferences.themeMode},
          onSelectionChanged: (selection) {
            widget.onChanged(
                widget.preferences.copyWith(themeMode: selection.first));
          },
        ),
      ],
    );
  }

  Widget _language(_SettingsCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.language),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: <ButtonSegment<String>>[
            ButtonSegment<String>(value: 'en', label: Text(copy.en)),
            ButtonSegment<String>(value: 'vi', label: Text(copy.vi)),
          ],
          selected: <String>{widget.preferences.languageCode},
          onSelectionChanged: (selection) {
            widget.onChanged(
              widget.preferences.copyWith(languageCode: selection.first),
            );
          },
        ),
      ],
    );
  }

  Widget _accentColor(_SettingsCopy copy) {
    final currentColor = Color(widget.preferences.accentColorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.accentColorLabel),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _accentOptions
              .map(
                (color) => InkWell(
                  onTap: () => widget.onChanged(
                    widget.preferences.copyWith(
                      accentColorValue: color.toARGB32(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.toARGB32() == currentColor.toARGB32()
                            ? (color.computeLuminance() > 0.5
                                ? const Color(0xFF111111)
                                : Colors.white)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: color.withAlpha(60),
                          blurRadius: 10,
                          spreadRadius: -3,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _overlaySettings(_SettingsCopy copy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _switchLine(
          label: copy.overlayEnabled,
          icon: Icons.open_in_new_rounded,
          value: widget.preferences.overlayPreviewEnabled,
          onChanged: (value) {
            widget.onChanged(
              widget.preferences.copyWith(overlayPreviewEnabled: value),
            );
          },
        ),
        const SizedBox(height: 6),
        _switchLine(
          label: copy.overlayOnTop,
          icon: Icons.vertical_align_top_rounded,
          value: widget.preferences.overlayOnTop,
          onChanged: (value) {
            widget.onChanged(widget.preferences.copyWith(overlayOnTop: value));
          },
        ),
        const SizedBox(height: 12),
        Text(copy.overlayLayout),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: 'vertical',
              label: Text(copy.vertical),
            ),
            ButtonSegment<String>(
              value: 'horizontal',
              label: Text(copy.horizontal),
            ),
            ButtonSegment<String>(
              value: 'compact',
              label: Text(copy.compact),
            ),
          ],
          selected: <String>{widget.preferences.overlayLayout},
          onSelectionChanged: (selection) {
            widget.onChanged(
              widget.preferences.copyWith(overlayLayout: selection.first),
            );
          },
        ),
      ],
    );
  }

  Widget _switchLine({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: icon != null
          ? Row(
              children: <Widget>[
                Icon(icon, size: 16, color: palette.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
              ],
            )
          : Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildModalDialog(
    BuildContext context,
    _SettingsCopy copy,
    FTuneElectronPaletteData palette, {
    required String title,
    required IconData icon,
    required Widget content,
    List<Widget>? actions,
    double width = 500,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: palette.shadow,
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: palette.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FTuneRoundIconButton(
                    icon: Icons.close_rounded,
                    tooltip: copy.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: content,
              ),
            ),
            if (actions != null) ...<Widget>[
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDonateModal(BuildContext context, _SettingsCopy copy,
      FTuneElectronPaletteData palette) {
    showDialog<void>(
      context: context,
      builder: (context) => _buildModalDialog(
        context,
        copy,
        palette,
        title: copy.donateTitle,
        icon: Icons.favorite_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(copy.donateSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/donate-qr.jpg',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFeedbackModal(BuildContext context, _SettingsCopy copy,
      FTuneElectronPaletteData palette) {
    final titleCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.maybeOf(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setModalState) => _buildModalDialog(
            context,
            copy,
            palette,
            title: copy.feedbackTitle,
            width: 600,
            icon: Icons.feedback_outlined,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.feedbackSubtitle,
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  enabled: !isSending,
                  decoration:
                      InputDecoration(hintText: copy.feedbackTitlePlaceholder),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        enabled: !isSending,
                        decoration: InputDecoration(
                          hintText: copy.feedbackNamePlaceholder,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        enabled: !isSending,
                        decoration: InputDecoration(
                          hintText: copy.feedbackEmailPlaceholder,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: msgCtrl,
                  enabled: !isSending,
                  maxLines: 7,
                  decoration:
                      InputDecoration(hintText: copy.feedbackMessagePlaceholder),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSending ? null : () => Navigator.of(context).pop(),
                child: Text(copy.feedbackCancel),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isSending
                    ? null
                    : () async {
                        final title = titleCtrl.text.trim();
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();
                        final message = msgCtrl.text.trim();

                        if (email.isEmpty || !_emailRegex.hasMatch(email)) {
                          messenger?.showSnackBar(
                            SnackBar(content: Text(copy.feedbackInvalidEmail)),
                          );
                          return;
                        }
                        if (!_isAllowedFeedbackEmail(email)) {
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                copy.feedbackUnsupportedEmailDomain,
                              ),
                            ),
                          );
                          return;
                        }
                        if (message.isEmpty) {
                          messenger?.showSnackBar(
                            SnackBar(content: Text(copy.feedbackInvalidMessage)),
                          );
                          return;
                        }

                        setModalState(() => isSending = true);
                        final sent = await _sendFeedbackDirect(
                          title: title,
                          name: name,
                          email: email,
                          message: message,
                        );
                        if (context.mounted) {
                          setModalState(() => isSending = false);
                          if (sent) {
                            Navigator.of(context).pop(true);
                          } else {
                            messenger?.showSnackBar(
                              SnackBar(content: Text(copy.feedbackSendFailure)),
                            );
                          }
                        }
                      },
                icon: isSending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.surface,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(isSending ? copy.feedbackSending : copy.feedbackSend),
              ),
            ],
          ),
        );
      },
    ).then((sent) {
      // Dispose after dialog close animation to avoid controller access races.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          titleCtrl.dispose();
          nameCtrl.dispose();
          emailCtrl.dispose();
          msgCtrl.dispose();
        }),
      );

      if (sent == true) {
        messenger?.showSnackBar(
          SnackBar(content: Text(copy.feedbackSendSuccess)),
        );
      }
    });
  }

  Future<bool> _sendFeedbackDirect({
    required String title,
    required String name,
    required String email,
    required String message,
  }) async {
    final reporterName = name.isEmpty ? 'Anonymous User' : name;
    final subject = title.trim().isEmpty
        ? '[F.Tuning Pro] Feedback moi'
        : '[F.Tuning Pro Feedback] ${title.trim()}';
    final ipAddress = await _resolveClientIpAddress();
    final osInfo = _resolveOperatingSystemInfo();
    final sentAt = DateTime.now();

    final payload = <String, dynamic>{
      'from': _resendSenderFrom,
      'to': <String>[_resendInboxEmail],
      'reply_to': email,
      'subject': subject,
      'text': _buildFeedbackMessageWithMetadata(
        title: title,
        senderName: reporterName,
        senderEmail: email,
        message: message,
        osInfo: osInfo,
        ipAddress: ipAddress,
        sentAt: sentAt,
      ),
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://api.resend.com/emails'),
            headers: _resendHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) {
        return false;
      }

      unawaited(_sendFeedbackThankYouCopy(
        recipientEmail: email,
        recipientName: reporterName,
        feedbackTitle: title,
        sentAt: sentAt,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _resolveClientIpAddress() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final ip = (parsed['ip'] as String? ?? '').trim();
        if (ip.isNotEmpty) {
          return ip;
        }
      }
    } catch (_) {
      // Fallback below.
    }

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.address.isNotEmpty) {
            return address.address;
          }
        }
      }
    } catch (_) {
      // Ignore and use fallback.
    }

    return 'Unknown';
  }

  String _resolveOperatingSystemInfo() {
    try {
      return '${Platform.operatingSystem} (${Platform.operatingSystemVersion})';
    } catch (_) {
      return 'Unknown';
    }
  }

  String _buildFeedbackMessageWithMetadata({
    required String title,
    required String senderName,
    required String senderEmail,
    required String message,
    required String osInfo,
    required String ipAddress,
    required DateTime sentAt,
  }) {
    final normalizedTitle =
        title.trim().isEmpty ? '(Khong co tieu de)' : title.trim();
    final trimmedMessage = message.trim();
    final ticketId = 'FT-${sentAt.millisecondsSinceEpoch % 100000}';

    return '====================================\n'
        'F.TUNE PRO  |  FEEDBACK TICKET\n'
        '====================================\n\n'
        'Ticket ID  : #$ticketId\n'
        'Thoi gian  : ${_formatLocalTimestamp(sentAt)}\n'
        'Tieu de    : $normalizedTitle\n\n'
        '------------------------------------\n'
        'NGUOI GUI\n'
        '------------------------------------\n'
        'Ten   : $senderName\n'
        'Email : $senderEmail\n\n'
        '------------------------------------\n'
        'NOI DUNG PHAN HOI\n'
        '------------------------------------\n'
        '$trimmedMessage\n\n'
        '------------------------------------\n'
        'THONG TIN HE THONG\n'
        '------------------------------------\n'
        'OS     : $osInfo\n'
        'IP     : $ipAddress\n'
        'Source : F.Tune Pro Desktop App\n\n'
        '====================================';
  }

  String _formatLocalTimestamp(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  Future<void> _sendFeedbackThankYouCopy({
    required String recipientEmail,
    required String recipientName,
    required String feedbackTitle,
    required DateTime sentAt,
  }) async {
    final payload = <String, dynamic>{
      'service_id': _emailJsServiceId,
      'template_id': _emailJsTemplateId,
      'user_id': _emailJsPublicKey,
      'template_params': <String, String>{
        'to_name': recipientName.isEmpty ? 'bạn' : recipientName,
        'to_email': recipientEmail,
        'feedback_title': feedbackTitle.trim().isEmpty
            ? '(Không có tiêu đề)'
            : feedbackTitle.trim(),
        'sent_at': _formatLocalTimestamp(sentAt),
      },
    };

    try {
      await http
          .post(
            Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'origin': 'https://ftune.app',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Keep feedback submission successful even if thank-you copy fails.
    }
  }

}

class _SettingsCopy {
  const _SettingsCopy._({required this.isVietnamese});

  factory _SettingsCopy.forLanguage(String languageCode) {
    return _SettingsCopy._(
        isVietnamese: languageCode.trim().toLowerCase() == 'vi');
  }

  final bool isVietnamese;

  String get title => isVietnamese ? 'Cài đặt' : 'Settings';
  String get subtitle => isVietnamese
      ? 'Tùy chỉnh giao diện, overlay cửa sổ riêng và các hành vi chính của dashboard.'
      : 'Adjust the current dashboard look, separate overlay window behavior, and key app preferences.';
  String get back => isVietnamese ? 'Quay lại' : 'Back';

  String get appearanceTitle => isVietnamese ? 'Giao diện' : 'Appearance';
  String get appearanceCardSubtitle => isVietnamese
      ? 'Theme, ngôn ngữ và màu nhấn cho giao diện hiện tại.'
      : 'Theme, language, and accent color for the current interface.';
  String get themeMode => isVietnamese ? 'Chế độ giao diện' : 'Theme mode';
  String get system => isVietnamese ? 'Theo hệ thống' : 'System';
  String get light => isVietnamese ? 'Sáng' : 'Light';
  String get dark => isVietnamese ? 'Tối' : 'Dark';
  String get language => isVietnamese ? 'Ngôn ngữ' : 'Language';
  String get en => 'English';
  String get vi => 'Tiếng Việt';
    String get accentColorLabel => isVietnamese ? 'Màu nhấn' : 'Accent color';

  String get tuningTitle => isVietnamese ? 'Tuning' : 'Tuning';
  String get tuningCardSubtitle => isVietnamese
      ? 'Các tùy chọn hỗ trợ thao tác và phối màu theo xe.'
      : 'Behavior preferences that support tuning flow and car-driven theming.';
  String get autoSave => isVietnamese
      ? 'Tự động gợi ý lưu Garage'
      : 'Enable garage autosave helpers';
  String get autoBackgroundFromCar => isVietnamese
      ? 'Đổi nền theo màu xe đã chọn'
      : 'Adapt background to selected car color';

  String get overlayTitle => 'Overlay';
  String get overlayCardSubtitle => isVietnamese
    ? 'Quản lý overlay ở cửa sổ riêng và hành vi hiển thị của nó.'
    : 'Manage the standalone overlay window and how it behaves.';
  String get overlayEnabled =>
    isVietnamese ? 'Bật overlay cửa sổ riêng' : 'Enable separate overlay window';
  String get overlayOnTop =>
      isVietnamese ? 'Overlay luôn ở trên' : 'Keep overlay always on top';
  String get overlayLayout =>
      isVietnamese ? 'Bố cục overlay' : 'Overlay layout';
  String get vertical => isVietnamese ? 'Dọc' : 'Vertical';
  String get horizontal => isVietnamese ? 'Ngang' : 'Horizontal';
  String get compact => isVietnamese ? 'Gọn' : 'Compact';

  String get supportTitle => isVietnamese ? 'Hỗ trợ' : 'Support';
  String get supportCardSubtitle => isVietnamese
      ? 'Tài liệu, phản hồi và các mục hỗ trợ nhanh.'
      : 'Guides, feedback, and quick support actions.';

  String get feedbackTitle => isVietnamese ? 'Gửi Phản hồi' : 'Send Feedback';
  String get donateTitle => isVietnamese ? 'Ủng hộ' : 'Donate';
  String get close => isVietnamese ? 'Đóng' : 'Close';

  // Donate modal
  String get donateSubtitle => isVietnamese
      ? 'Quét mã QR để ủng hộ phát triển ứng dụng'
      : 'Scan QR to donate for app development';

  // Feedback modal
  String get feedbackSubtitle => isVietnamese
      ? 'Chia sẻ phản hồi trực tiếp từ ứng dụng.'
      : 'Share your feedback directly from the app.';
  String get feedbackTitlePlaceholder =>
      isVietnamese ? 'Tiêu đề' : 'Feedback title';
  String get feedbackNamePlaceholder =>
      isVietnamese ? 'Tên của bạn (không bắt buộc)' : 'Your name (optional)';
  String get feedbackEmailPlaceholder =>
      isVietnamese ? 'Email (bắt buộc)' : 'Your email (required)';
  String get feedbackMessagePlaceholder =>
      isVietnamese ? 'Nhập nội dung phản hồi...' : 'Type your feedback...';
  String get feedbackCancel => isVietnamese ? 'Hủy' : 'Cancel';
  String get feedbackSending => isVietnamese ? 'Đang gửi...' : 'Sending...';
  String get feedbackSend => isVietnamese ? 'Gửi' : 'Send';
  String get feedbackInvalidEmail => isVietnamese
      ? 'Vui lòng nhập email hợp lệ.'
      : 'Please enter a valid email address.';
  String get feedbackUnsupportedEmailDomain => isVietnamese
      ? 'Chỉ hỗ trợ email từ các dịch vụ lớn (ví dụ: Gmail, Outlook, Yahoo, iCloud).'
      : 'Only major email providers are supported (e.g. Gmail, Outlook, Yahoo, iCloud).';
  String get feedbackInvalidMessage => isVietnamese
      ? 'Vui lòng nhập nội dung phản hồi.'
      : 'Please enter your feedback message.';
  String get feedbackSendSuccess => isVietnamese
      ? 'Đã gửi phản hồi thành công. Email cảm ơn đã được gửi tới hộp thư của bạn.'
      : 'Feedback sent successfully. A thank-you email has been sent to your inbox.';
  String get feedbackSendFailure => isVietnamese
      ? 'Gửi phản hồi thất bại. Vui lòng thử lại sau.'
      : 'Failed to send feedback. Please try again later.';

}
