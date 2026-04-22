import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/dashboard/dashboard_page.dart';
import 'ftune_app_controller.dart';
import 'ftune_models.dart';
import 'ftune_overlay_window.dart';
import 'ftune_ui.dart';
import 'ftune_update_checker.dart';
import 'ftune_updater.dart';

class FTuneShell extends StatefulWidget {
  const FTuneShell({
    super.key,
    required this.controller,
  });

  final FTuneAppController controller;

  @override
  State<FTuneShell> createState() => _FTuneShellState();
}

class _FTuneShellState extends State<FTuneShell> {
  FTuneRemoteVersion? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    // Delay slightly so it doesn't run in the very first frame.
    Future<void>.delayed(const Duration(seconds: 3), _checkForUpdate);
  }

  Future<void> _checkForUpdate() async {
    final update = await FTuneUpdateChecker.instance.checkForUpdate();
    if (update != null && mounted) {
      setState(() => _pendingUpdate = update);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final copy = _ShellCopy.forLanguage(controller.preferences.languageCode);
        final initialTab = switch (controller.section) {
          AppSection.garage => 1,
          AppSection.settings => 2,
          _ => 0,
        };
        final showInlineOverlay = controller.preferences.overlayPreviewEnabled &&
            (!controller.preferences.overlayOnTop ||
                !FTuneOverlayWindowService.instance.isSupported);
        final messenger = ScaffoldMessenger.maybeOf(context);

        unawaited(
          FTuneOverlayWindowService.instance.bind(
            onOverlayClosed: () async {
              await controller.clearOverlayTune();
            },
            onOverlayLockedChanged: (locked) async {
              await controller.setOverlayLocked(locked);
            },
          ),
        );
        unawaited(
          FTuneOverlayWindowService.instance.sync(
            record: controller.preferences.overlayOnTop
                ? controller.activeOverlayTune
                : null,
            preferences: controller.preferences,
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DashboardPage(
              key: ValueKey<int>(initialTab),
              languageCode: controller.preferences.languageCode,
              accentColorValue: controller.preferences.accentColorValue,
              isDarkMode: Theme.of(context).brightness == Brightness.dark,
              initialTab: initialTab,
              onCreateTune: controller.startNewTune,
              onOpenGarage: () => controller.goTo(AppSection.garage),
              onOpenSettings: () => controller.goTo(AppSection.settings),
              initialMetric: controller.preferences.useMetric,
              pendingCreateSession: controller.pendingCreateSession,
              overlayOnTop: controller.preferences.overlayOnTop,
              themeMode: controller.preferences.themeMode,
              backgroundImagePath: controller.customBackgroundPath,
              onMetricChanged: (value) {
                unawaited(controller.setMeasurementSystem(value));
              },
              onAccentChange: (value) {
                unawaited(controller.setAccentColor(value));
              },
              onSaveTune: controller.saveTune,
              onOpenOverlayTune: controller.setActiveOverlayTune,
              onLanguageChanged: (value) {
                unawaited(controller.setLanguageCode(value));
              },
              onThemeModeChanged: (value) {
                unawaited(controller.setThemeMode(value));
              },
              onOverlayOnTopChanged: (value) {
                unawaited(controller.setOverlayOnTop(value));
              },
              garageTunes: controller.garageTunes,
              overlayPreviewEnabled: controller.preferences.overlayPreviewEnabled,
              onDeleteTune: (id) {
                unawaited(controller.deleteTune(id));
              },
              onTogglePinnedTune: (id) {
                unawaited(controller.togglePinned(id));
              },
              onImportTune: () async {
                final importedCount = await controller.importGarageTunes();
                if (messenger == null) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      importedCount > 0
                          ? copy.importDone(importedCount)
                          : copy.importNone,
                    ),
                  ),
                );
              },
              onExportTune: (records) async {
                final path = await controller.exportGarageTunes(records);
                if (messenger == null) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      path == null ? copy.exportCanceled : copy.exportDone(path),
                    ),
                  ),
                );
              },
              onSetOverlayTune: controller.setActiveOverlayTune,
              preferences: controller.preferences,
              hasCustomBackground: controller.customBackgroundPath != null,
              onPreferencesChanged: (preferences) {
                unawaited(controller.updatePreferences(preferences));
              },
              onPickBackground: () async {
                await controller.pickCustomBackground();
                if (messenger == null) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(copy.backgroundUpdated)),
                );
              },
              onClearBackground: () async {
                await controller.clearCustomBackground();
                if (messenger == null) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(copy.backgroundCleared)),
                );
              },
              onDropBackground: controller.setCustomBackgroundFromPath,
              onOpenWelcomeTour: () {
                // Schedule outside the current build/animation frame to avoid
                // InheritedWidget dependency assertions when the overlay appears.
                Future<void>.delayed(Duration.zero, controller.reopenWelcome);
              },
              isPro: controller.isPro,
              licenseStatus: controller.licenseStatus,
              licenseKey: controller.licenseKey,
              onActivateLicense: controller.activateLicense,
              onDeactivateLicense: controller.deactivateLicense,
              garageLimit: FTuneAppController.freeGarageLimit,
            ),
            if (showInlineOverlay &&
                controller.activeOverlayTune != null &&
                controller.preferences.overlayPreviewEnabled)
              Positioned(
                right: 14,
                bottom: 52,
                child: _OverlayPreviewPanel(
                  record: controller.activeOverlayTune!,
                  preferences: controller.preferences,
                  onLockChanged: (locked) {
                    unawaited(controller.setOverlayLocked(locked));
                  },
                  onClose: () {
                    unawaited(controller.clearOverlayTune());
                  },
                ),
              ),
            if (controller.showWelcome)
              Positioned.fill(
                child: _WelcomeTourOverlay(
                  preferences: controller.preferences,
                  onChanged: (preferences) {
                    unawaited(controller.updatePreferences(preferences));
                  },
                  onDismiss: (dontShowAgain) {
                    unawaited(controller.completeWelcome(dontShowAgain: dontShowAgain));
                  },
                ),
              ),
            if (_pendingUpdate != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _UpdateBanner(
                  update: _pendingUpdate!,
                  languageCode: controller.preferences.languageCode,
                  onDismiss: () => setState(() => _pendingUpdate = null),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Update banner
// ──────────────────────────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.update,
    required this.languageCode,
    required this.onDismiss,
  });

  final FTuneRemoteVersion update;
  final String languageCode;
  final VoidCallback onDismiss;

  bool get _isVi => languageCode == 'vi';

  Future<void> _startUpdate(BuildContext context) async {
    // If no direct exe URL, fall back to browser.
    if (update.exeDownloadUrl.isEmpty) {
      await launchUrl(Uri.parse(update.downloadUrl));
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateProgressDialog(
        update: update,
        languageCode: languageCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _isVi
        ? 'Có phiên bản mới: ${update.version} — ${update.releaseNotes(languageCode)}'
        : 'New version available: ${update.version} — ${update.releaseNotes(languageCode)}';
    final updateLabel = _isVi ? 'Cập nhật ngay' : 'Update now';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0A7C5A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            const Icon(Icons.system_update_alt_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _startUpdate(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(updateLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.all(4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: _isVi ? 'Nhắc sau' : 'Later',
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Update progress dialog
// ──────────────────────────────────────────────────────────────────────────────

class _UpdateProgressDialog extends StatefulWidget {
  const _UpdateProgressDialog({
    required this.update,
    required this.languageCode,
  });

  final FTuneRemoteVersion update;
  final String languageCode;

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0;
  bool _failed = false;

  bool get _isVi => widget.languageCode == 'vi';

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final success = await FTuneUpdater.instance.downloadAndApply(
      exeUrl: widget.update.exeDownloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    // If we reach here, download failed (success = true exits the app).
    if (mounted) setState(() => _failed = !success);
  }

  @override
  Widget build(BuildContext context) {
    final title = _failed
        ? (_isVi ? 'Cập nhật thất bại' : 'Update failed')
        : (_isVi ? 'Đang tải bản cập nhật…' : 'Downloading update…');
    final sub = _failed
        ? (_isVi
            ? 'Không thể tải file. Vui lòng thử lại sau.'
            : 'Could not download the update. Please try again later.')
        : (_isVi
            ? 'App sẽ tự khởi động lại khi hoàn tất.'
            : 'The app will restart automatically when done.');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(sub,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            if (!_failed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      minHeight: 6,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0A7C5A)),
                    ),
                  ),
                  if (_progress > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
      actions: _failed
          ? <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_isVi ? 'Đóng' : 'Close'),
              ),
            ]
          : null,
    );
  }
}

class FTuneWelcomeTourPreview extends StatelessWidget {
  const FTuneWelcomeTourPreview({
    super.key,
    required this.preferences,
    this.initialPage = 0,
  });

  final AppPreferences preferences;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    return _WelcomeTourOverlay(
      preferences: preferences,
      initialPage: initialPage,
      onChanged: (_) {},
      onDismiss: (_) {},
    );
  }
}

class _WelcomeTourOverlay extends StatefulWidget {
  const _WelcomeTourOverlay({
    required this.preferences,
    required this.onChanged,
    required this.onDismiss,
    this.initialPage = 0,
  });

  final AppPreferences preferences;
  final ValueChanged<AppPreferences> onChanged;
  final ValueChanged<bool> onDismiss;
  final int initialPage;

  @override
  State<_WelcomeTourOverlay> createState() => _WelcomeTourOverlayState();
}

class _WelcomeTourOverlayState extends State<_WelcomeTourOverlay> {
  late bool _metric;
  late String _language;
  late String _theme;
  late int _page;
  int _pageDirection = 1;
  bool _dontShowAgain = true;

  @override
  void initState() {
    super.initState();
    _syncLocalPreferences(widget.preferences);
    _page = widget.initialPage < 0 ? 0 : widget.initialPage;
  }

  @override
  void didUpdateWidget(covariant _WelcomeTourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.useMetric != widget.preferences.useMetric ||
        oldWidget.preferences.languageCode != widget.preferences.languageCode ||
        oldWidget.preferences.themeMode != widget.preferences.themeMode) {
      _syncLocalPreferences(widget.preferences);
    }
    if (oldWidget.initialPage != widget.initialPage) {
      _page = widget.initialPage < 0 ? 0 : widget.initialPage;
    }
  }

  void _syncLocalPreferences(AppPreferences preferences) {
    _metric = preferences.useMetric;
    _language =
        preferences.languageCode.trim().toLowerCase() == 'vi' ? 'vi' : 'en';
    final themeMode = preferences.themeMode.trim().toLowerCase();
    _theme = themeMode == 'light' ? 'light' : 'dark';
  }

  void _commitLocalPreferences() {
    widget.onChanged(
      widget.preferences.copyWith(
        useMetric: _metric,
        languageCode: _language,
        themeMode: _theme,
      ),
    );
  }

  void _dismissWelcome() {
    _commitLocalPreferences();
    widget.onDismiss(_dontShowAgain);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _NeoPalette.of(context);
    final copy = _ShellCopy.forLanguage(_language);
    final slides = copy.welcomeSlides;
    final page = _page.clamp(0, slides.length);
    final isSetup = page == 0;
    final isLastPage = page == slides.length;
    final totalPages = slides.length + 1;
    final activeIndex = isSetup ? 0 : page - 1;
    final activeSlide = slides[activeIndex];

    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.92 + (0.08 * value),
                child: child,
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? const Color(0xDD000000)
                      : const Color(0xCC000000),
                ),
                child: const SizedBox.expand(),
              ),
              SafeArea(
              minimum: const EdgeInsets.all(32),
              child: Center(
                child: _WelcomeGlassPanel(
                    palette: palette,
                    child: Stack(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Expanded(
                              child: _buildAnimatedWelcomeSection(
                                pageKey: 'page-$page',
                                child: isSetup
                                    ? _buildSetupPage(
                                        copy: copy,
                                        palette: palette,
                                      )
                                    : _buildFeaturePage(
                                        copy: copy,
                                        palette: palette,
                                        activeSlide: activeSlide,
                                        activeIndex: activeIndex,
                                      ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 12, 24, 20),
                              child: _buildWelcomeFooter(
                                copy: copy,
                                palette: palette,
                                page: page,
                                totalPages: totalPages,
                                isLastPage: isLastPage,
                                onContinue: isLastPage
                                    ? _dismissWelcome
                                    : () => _moveWelcomeToNextPage(
                                          slides.length,
                                        ),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _buildWelcomeTopBar(
                              palette: palette,
                              page: page,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSetupPage({
    required _ShellCopy copy,
    required _NeoPalette palette,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        final dense = constraints.maxHeight < 460;
        final optionWidth = compact
            ? constraints.maxWidth - 32
            : (constraints.maxWidth - 72) / 3;

        final hPad = compact ? 16.0 : 24.0;

        return Column(
          children: <Widget>[
            Expanded(
              child: _buildOnboardingReveal(
                motionKey: 'setup-hero-$_page',
                beginOffset: const Offset(0, 24),
                beginScale: 0.94,
                durationMs: 680,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildSupportedGamesHero(
                      copy: copy,
                      compact: compact,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: <Color>[
                                palette.isDark
                                    ? const Color(0xFF0E1117)
                                    : const Color(0xFFE8ECF0),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: dense ? 16 : 22),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _buildOnboardingReveal(
                motionKey: 'setup-title-$_page',
                beginOffset: const Offset(0, 16),
                durationMs: 520,
                child: Text(
                  copy.welcomeSetupTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 20 : (dense ? 22 : 26),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.08,
                    color: palette.text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _buildOnboardingReveal(
                motionKey: 'setup-desc-$_page',
                beginOffset: const Offset(0, 12),
                durationMs: 560,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Text(
                    copy.welcomeSetupDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: palette.muted,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: dense ? 14 : 22),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: optionWidth,
                    child: _welcomeChoiceCard(
                      palette: palette,
                      title: copy.languageLabel,
                      options: <Widget>[
                        _choiceChip(
                          copy.englishLabel,
                          _language == 'en',
                          () => setState(() => _language = 'en'),
                          palette,
                        ),
                        _choiceChip(
                          copy.vietnameseLabel,
                          _language == 'vi',
                          () => setState(() => _language = 'vi'),
                          palette,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: optionWidth,
                    child: _welcomeChoiceCard(
                      palette: palette,
                      title: copy.measurementLabel,
                      options: <Widget>[
                        _choiceChip(
                          copy.metricLabel,
                          _metric,
                          () => setState(() => _metric = true),
                          palette,
                        ),
                        _choiceChip(
                          copy.imperialLabel,
                          !_metric,
                          () => setState(() => _metric = false),
                          palette,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: optionWidth,
                    child: _welcomeChoiceCard(
                      palette: palette,
                      title: copy.themeLabel,
                      options: <Widget>[
                        _choiceChip(
                          copy.lightLabel,
                          _theme == 'light',
                          () => setState(() => _theme = 'light'),
                          palette,
                        ),
                        _choiceChip(
                          copy.darkLabel,
                          _theme == 'dark',
                          () => setState(() => _theme = 'dark'),
                          palette,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturePage({
    required _ShellCopy copy,
    required _NeoPalette palette,
    required _WelcomeSlideData activeSlide,
    required int activeIndex,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 540;
        final dense = constraints.maxHeight < 400;

        final hPad = compact ? 16.0 : 24.0;

        return Column(
          children: <Widget>[
            Expanded(
              child: _buildOnboardingReveal(
                motionKey: 'feature-preview-$activeIndex',
                beginOffset: Offset(_pageDirection * 18, 14),
                beginScale: 0.95,
                durationMs: 680,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: _withAlpha(Colors.black, 0.24),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _WelcomePreviewScene(
                      palette: palette,
                      type: activeSlide.previewType,
                      isVietnamese: copy.isVietnamese,
                    ),
                  ),
                ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(22),
                              bottomRight: Radius.circular(22),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: <Color>[
                                palette.isDark
                                    ? const Color(0xFF0E1117)
                                    : const Color(0xFFE8ECF0),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: dense ? 14 : 22),
            _buildOnboardingReveal(
              motionKey: 'feature-chip-$activeIndex',
                beginOffset: const Offset(0, 10),
                durationMs: 420,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _withAlpha(palette.accent, 0.12),
                    border: Border.all(
                      color: _withAlpha(palette.accent, 0.24),
                    ),
                  ),
                  child: Text(
                    copy.flowLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _withAlpha(palette.accent, 0.90),
                    ),
                  ),
                ),
              ),
            SizedBox(height: dense ? 8 : 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _buildOnboardingReveal(
                motionKey: 'feature-title-$activeIndex',
                beginOffset: Offset(_pageDirection * 14, 12),
                durationMs: 560,
                child: Text(
                  activeSlide.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 22 : (dense ? 24 : 28),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.06,
                    color: palette.text,
                  ),
                ),
              ),
            ),
            SizedBox(height: dense ? 6 : 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: _buildOnboardingReveal(
                motionKey: 'feature-desc-$activeIndex',
                beginOffset: const Offset(0, 10),
                durationMs: 600,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Text(
                    activeSlide.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: palette.muted,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: dense ? 4 : 8),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedWelcomeSection({
    required String pageKey,
    required Widget child,
  }) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 480),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final scale = Tween<double>(
            begin: 0.96,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<String>(pageKey),
          child: child,
        ),
      ),
    );
  }

  Widget _buildOnboardingReveal({
    required String motionKey,
    required Widget child,
    Offset beginOffset = const Offset(0, 18),
    int durationMs = 560,
    double beginScale = 0.98,
    Curve curve = Curves.easeOutCubic,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(motionKey),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: durationMs),
      curve: curve,
      builder: (context, value, child) {
        final progress = value.clamp(0, 1).toDouble();
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: beginOffset * (1 - progress),
            child: Transform.scale(
              scale: beginScale + ((1 - beginScale) * progress),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildWelcomeTopBar({
    required _NeoPalette palette,
    required int page,
  }) {
    return Row(
      children: <Widget>[
        if (page > 0)
          _WelcomeTopBarButton(
            palette: palette,
            icon: Icons.arrow_back_rounded,
            onTap: _moveWelcomeToPreviousPage,
          )
        else
          const SizedBox(width: 40, height: 40),
        const Spacer(),
        _WelcomeTopBarButton(
          palette: palette,
          icon: Icons.close_rounded,
          onTap: _dismissWelcome,
        ),
      ],
    );
  }

  Widget _buildSupportedGamesHero({
    required _ShellCopy copy,
    required bool compact,
  }) {
    final radius = compact ? 28.0 : 34.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _withAlpha(Colors.black, 0.30),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildWelcomeHeroImage(
              source: 'assets/images/fh6-hero.jpg',
              motionKey: 'fh6-hero',
              accentColor: const Color(0xFFFF8A3D),
              alignment: Alignment.centerRight,
              horizontalDrift: compact ? -18 : -26,
              verticalDrift: 18,
            ),
            ClipPath(
              clipper: const _WelcomeDiagonalHeroClipper(),
              child: _buildWelcomeHeroImage(
                source: 'assets/images/fh5-hero.jpeg',
                motionKey: 'fh5-hero',
                accentColor: const Color(0xFFFF4D4D),
                alignment: const Alignment(-0.10, 0),
                horizontalDrift: compact ? 22 : 30,
                verticalDrift: 10,
              ),
            ),
            Positioned(
              top: compact ? -20 : -28,
              left: compact ? -40 : -24,
              right: compact ? -40 : -24,
              height: compact ? 120 : 168,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.9),
                      radius: 1.0,
                      colors: <Color>[
                        _withAlpha(Colors.white, 0.18),
                        _withAlpha(const Color(0xFF0A0D14), 0.00),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[
                    _withAlpha(const Color(0xFF090B11), 0.92),
                    _withAlpha(const Color(0xFF090B11), 0.56),
                    _withAlpha(const Color(0xFF090B11), 0.16),
                    _withAlpha(const Color(0xFF090B11), 0.00),
                  ],
                  stops: const <double>[0, 0.24, 0.62, 1],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _WelcomeDiagonalDividerPainter(
                    shadowColor: _withAlpha(Colors.black, 0.36),
                  ),
                ),
              ),
            ),
            Positioned(
              left: compact ? 16 : 24,
              right: compact ? 16 : 24,
              bottom: compact ? 16 : 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 220 : 280,
                        ),
                        child: _buildSupportedGameCallout(
                          title: copy.fh5CoverTitle,
                          subtitle: copy.fh5CoverSubtitle,
                          caption: copy.fh5CoverCaption,
                          accentColor: const Color(0xFFFF4D4D),
                          alignEnd: false,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 14 : 18),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: compact ? 220 : 280,
                        ),
                        child: _buildSupportedGameCallout(
                          title: copy.fh6CoverTitle,
                          subtitle: copy.fh6CoverSubtitle,
                          caption: copy.fh6CoverCaption,
                          accentColor: const Color(0xFFFF8A3D),
                          alignEnd: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeroImage({
    required String source,
    required String motionKey,
    required Color accentColor,
    required Alignment alignment,
    double horizontalDrift = 0,
    double verticalDrift = 0,
  }) {
    final provider = source.startsWith('http')
        ? NetworkImage(source)
        : AssetImage(source) as ImageProvider<Object>;

    return ClipRect(
      child: TweenAnimationBuilder<double>(
        key: ValueKey<String>(motionKey),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 860),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final progress = value.clamp(0, 1).toDouble();
          return Transform.translate(
            offset: Offset(
              horizontalDrift * (1 - progress),
              verticalDrift * (1 - progress),
            ),
            child: Transform.scale(
              scale: 1.08 - (0.08 * progress),
              child: child,
            ),
          );
        },
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _withAlpha(accentColor, 0.72),
                  _withAlpha(const Color(0xFF10141D), 0.94),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportedGameCallout({
    required String title,
    required String subtitle,
    required String caption,
    required Color accentColor,
    required bool alignEnd,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _withAlpha(Colors.white, 0.12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _withAlpha(const Color(0xFF090B11), 0.60),
            _withAlpha(const Color(0xFF090B11), 0.30),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            subtitle,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: _withAlpha(Colors.white, 0.76),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeFooter({
    required _ShellCopy copy,
    required _NeoPalette palette,
    required int page,
    required int totalPages,
    required bool isLastPage,
    required VoidCallback onContinue,
  }) {
    final buttonLabel = isLastPage ? copy.startTuneLabel : copy.nextLabel;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(totalPages, (index) {
            final active = index == page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: active ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: active
                    ? Colors.white
                    : _withAlpha(Colors.white, 0.28),
                boxShadow: active
                    ? <BoxShadow>[
                        BoxShadow(
                          color: _withAlpha(Colors.white, 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        if (isLastPage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Checkbox(
                    value: _dontShowAgain,
                    onChanged: (v) =>
                        setState(() => _dontShowAgain = v ?? true),
                    side: BorderSide(
                      color: _withAlpha(Colors.white, 0.5),
                    ),
                    checkColor: Colors.black,
                    activeColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    copy.welcomeDontShowAgain,
                    style: TextStyle(
                      fontSize: 12,
                      color: _withAlpha(Colors.white, 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: _WelcomeActionButton(
            palette: palette,
            label: buttonLabel,
            onTap: onContinue,
          ),
        ),
      ],
    );
  }

  Widget _welcomeChoiceCard({
    required _NeoPalette palette,
    required String title,
    required List<Widget> options,
  }) {
    final children = <Widget>[];
    for (var index = 0; index < options.length; index += 1) {
      if (index > 0) {
        children.add(const SizedBox(height: 8));
      }
      children.add(options[index]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.48,
            color: _withAlpha(Colors.white, 0.74),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _withAlpha(Colors.white, 0.12)),
            color: _withAlpha(Colors.black, palette.isDark ? 0.18 : 0.10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                _withAlpha(Colors.white, 0.03),
                _withAlpha(Colors.white, 0.01),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _choiceChip(
    String label,
    bool active,
    VoidCallback onTap,
    _NeoPalette palette,
  ) {
    return _WelcomeChoiceButton(
      label: label,
      selected: active,
      palette: palette,
      onTap: onTap,
    );
  }

  void _moveWelcomeToPreviousPage() {
    if (_page <= 0) {
      return;
    }
    setState(() {
      _pageDirection = -1;
      _page -= 1;
    });
  }

  void _moveWelcomeToNextPage(int slideCount) {
    if (_page == 0) {
      _commitLocalPreferences();
      setState(() {
        _pageDirection = 1;
        _page = 1;
      });
      return;
    }

    if (_page >= slideCount) {
      return;
    }

    setState(() {
      _pageDirection = 1;
      _page += 1;
    });
  }
}

class _OverlayLineData {
  const _OverlayLineData({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;
}

class _OverlayPreviewPanel extends StatelessWidget {
  const _OverlayPreviewPanel({
    required this.record,
    required this.preferences,
    required this.onLockChanged,
    required this.onClose,
  });

  final SavedTuneRecord record;
  final AppPreferences preferences;
  final ValueChanged<bool> onLockChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = _NeoPalette.of(context);
    final copy = _ShellCopy.forLanguage(preferences.languageCode);
    final lines = <_OverlayLineData>[
      _OverlayLineData(title: 'PI', value: record.piClass),
      _OverlayLineData(
        title: copy.isVietnamese ? 'Tốc độ' : 'Top Speed',
        value: record.topSpeedDisplay,
      ),
      _OverlayLineData(
        title: copy.isVietnamese ? 'Lốp' : 'Tire',
        value: record.result.overview.tireType,
      ),
      _OverlayLineData(
        title: 'Diff',
        value: record.result.overview.differentialType,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _withAlpha(Colors.white, 0.12)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _withAlpha(Colors.black, palette.isDark ? 0.34 : 0.18),
                _withAlpha(palette.surface, palette.isDark ? 0.82 : 0.72),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _withAlpha(Colors.black, palette.isDark ? 0.28 : 0.14),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.brand} ${record.model} • ${record.driveType} • ${record.surface}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _OverlayHeaderButton(
                    palette: palette,
                    icon: preferences.overlayLocked
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    tooltip: copy.overlayLocked,
                    onTap: () => onLockChanged(!preferences.overlayLocked),
                  ),
                  const SizedBox(width: 8),
                  _OverlayHeaderButton(
                    palette: palette,
                    icon: Icons.close_rounded,
                    tooltip: copy.overlayClose,
                    onTap: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: lines
                    .map(
                      (line) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: palette.surfaceAlt,
                          border: Border.all(color: palette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              line.title,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              line.value,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: palette.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeSlideData {
  const _WelcomeSlideData({
    required this.title,
    required this.text,
    required this.previewType,
  });

  final String title;
  final String text;
  final _WelcomePreviewType previewType;
}

enum _WelcomePreviewType {
  create,
  calculate,
  garage,
  settings,
}

String _welcomePreviewAsset(_WelcomePreviewType type) {
  return switch (type) {
    _WelcomePreviewType.create =>
      'assets/images/welcome/home_create.png',
    _WelcomePreviewType.calculate =>
      'assets/images/welcome/home_calculate.png',
    _WelcomePreviewType.garage =>
      'assets/images/welcome/garage_overview.png',
    _WelcomePreviewType.settings =>
      'assets/images/welcome/settings_overview.png',
  };
}

class _WelcomeDiagonalHeroClipper extends CustomClipper<Path> {
  const _WelcomeDiagonalHeroClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.66, 0)
      ..lineTo(size.width * 0.38, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WelcomeDiagonalHeroClipper oldClipper) => false;
}

class _WelcomeDiagonalDividerPainter extends CustomPainter {
  const _WelcomeDiagonalDividerPainter({required this.shadowColor});

  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.66, 0);
    final end = Offset(size.width * 0.38, size.height);
    final shadowPaint = Paint()
      ..color = shadowColor
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final linePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xF2FFFFFF),
          Color(0x99FFFFFF),
        ],
      ).createShader(Rect.fromPoints(start, end))
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, shadowPaint);
    canvas.drawLine(start, end, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WelcomeDiagonalDividerPainter oldDelegate) {
    return oldDelegate.shadowColor != shadowColor;
  }
}

class _ShellCopy {
  const _ShellCopy._({required this.isVietnamese});

  factory _ShellCopy.forLanguage(String languageCode) {
    return _ShellCopy._(
      isVietnamese: languageCode.trim().toLowerCase() == 'vi',
    );
  }

  final bool isVietnamese;

  String get overlayLocked =>
      isVietnamese ? 'Overlay đang được khóa' : 'Overlay is locked';
  String get overlayClose =>
      isVietnamese ? 'Đóng cửa sổ overlay' : 'Close overlay window';
  String get welcomeTitle => isVietnamese
      ? 'Chào mừng đến với F.Tune Pro'
      : 'Welcome to F.Tune Pro';
  String get welcomeSubtitle => isVietnamese
      ? 'Xem nhanh giao diện, luồng tune và các mục chính của ứng dụng.'
      : 'A quick look at the interface, tuning flow, and main sections of the app.';
    String get welcomeSetupHeadline =>
      isVietnamese ? 'Thiết lập F.Tune Pro' : 'Set Up F.Tune Pro';
  String get welcomeSetupTitle => isVietnamese
      ? 'F.Tune Pro hỗ trợ Forza Horizon 5 và 6'
      : 'F.Tune Pro supports Forza Horizon 5 and 6';
    String get welcomeSetupDescription => isVietnamese
      ? 'Chọn ngôn ngữ, đơn vị đo và giao diện trước khi bắt đầu. Bạn có thể đổi lại mọi thứ trong Settings bất cứ lúc nào.'
      : 'Choose your language, measurement system, and theme before you begin. You can change everything again later in Settings.';
    String get supportedGamesLabel =>
      isVietnamese ? 'GAME ĐƯỢC HỖ TRỢ' : 'SUPPORTED GAMES';
    String get fh5CoverTitle => 'FH5';
    String get fh6CoverTitle => 'FH6';
    String get fh5CoverSubtitle => 'Forza Horizon 5';
    String get fh6CoverSubtitle => 'Forza Horizon 6';
    String get fh5CoverCaption => isVietnamese
      ? 'Luồng create tune, dữ liệu xe và kho tune cho FH5.'
      : 'Create-tune flow, car data, and garage workflow for FH5.';
    String get fh6CoverCaption => isVietnamese
      ? 'Sẵn sàng cho bố cục chào mừng và trải nghiệm FH6.'
      : 'Ready for the welcome layout and FH6 experience.';
    String get flowLabel =>
      isVietnamese ? 'TÍNH NĂNG CHÍNH' : 'FEATURE HIGHLIGHTS';
    String get languageLabel => isVietnamese ? 'Ngôn ngữ' : 'Language';
    String get measurementLabel => isVietnamese ? 'Đơn vị' : 'Measurement';
    String get themeLabel => isVietnamese ? 'Giao diện' : 'Theme';
    String get englishLabel => 'English';
    String get vietnameseLabel => 'Tiếng Việt';
    String get metricLabel => 'Metric';
    String get imperialLabel => 'Imperial';
    String get lightLabel => isVietnamese ? 'Sáng' : 'Light';
    String get darkLabel => isVietnamese ? 'Tối' : 'Dark';
    String get backLabel => isVietnamese ? 'Quay lại' : 'Back';
    String get nextLabel => isVietnamese ? 'Tiếp tục' : 'Continue';
    String get startTuneLabel => isVietnamese ? 'Bắt đầu' : 'Start Tune';
    String get finishLabel => isVietnamese ? 'Hoàn tất' : 'Finish';
    String get closeLabel => isVietnamese ? 'Đóng' : 'Close';
    String get welcomeDontShowAgain => isVietnamese
      ? 'Không hiển thị lại ở lần sau'
      : 'Do not show again next time';
    String get importNone =>
      isVietnamese ? 'Không có tune nào được nhập.' : 'No tunes were imported.';
    String importDone(int count) =>
      isVietnamese ? 'Đã nhập $count tune.' : 'Imported $count tune(s).';
    String get exportCanceled =>
      isVietnamese ? 'Đã hủy xuất file.' : 'Export canceled.';
    String exportDone(String path) =>
      isVietnamese ? 'Đã xuất tune tới $path' : 'Exported tunes to $path';
    String get backgroundUpdated => isVietnamese
      ? 'Đã cập nhật background tùy chỉnh.'
      : 'Custom background updated.';
    String get backgroundCleared => isVietnamese
      ? 'Đã xóa background tùy chỉnh.'
      : 'Custom background cleared.';

  List<_WelcomeSlideData> get welcomeSlides => isVietnamese
      ? const <_WelcomeSlideData>[
          _WelcomeSlideData(
            title: 'Tạo Tune Mới',
            text:
                'Chọn xe, nhập dữ liệu hiệu năng và cấu hình tune trong một bố cục gọn, rõ ràng và tập trung hơn.',
            previewType: _WelcomePreviewType.create,
          ),
          _WelcomeSlideData(
            title: 'Tính Toán Tune',
            text:
                'Nút Tính toán và Lưu xuất hiện đúng lúc khi dữ liệu đã đủ, giúp thao tác nhanh và ít rối hơn.',
            previewType: _WelcomePreviewType.calculate,
          ),
          _WelcomeSlideData(
            title: 'Kho Tune',
            text:
                'Quản lý tune đã lưu ở dạng bảng, ghim mục quan trọng và import hoặc export chỉ với vài thao tác.',
            previewType: _WelcomePreviewType.garage,
          ),
          _WelcomeSlideData(
            title: 'Cài Đặt',
            text:
                'Điều chỉnh giao diện, đơn vị đo, màu nhấn và hành vi nền trong cùng một phong cách nhất quán.',
            previewType: _WelcomePreviewType.settings,
          ),
        ]
      : const <_WelcomeSlideData>[
          _WelcomeSlideData(
            title: 'Create New Tune',
            text:
                'The car list stays on the left, performance inputs on the right, and Tune Config is condensed along the lower center.',
            previewType: _WelcomePreviewType.create,
          ),
          _WelcomeSlideData(
            title: 'Calculate Tune',
            text:
                'Calculate and Save now appear in the lower-right corner once enough information is available to act on.',
            previewType: _WelcomePreviewType.calculate,
          ),
          _WelcomeSlideData(
            title: 'My Garage',
            text:
                'Manage saved tunes in table view, sort quickly, and export or import tune files.',
            previewType: _WelcomePreviewType.garage,
          ),
          _WelcomeSlideData(
            title: 'Settings',
            text:
                'Adjust theme, language, accent color, and background behavior with the updated app styling.',
            previewType: _WelcomePreviewType.settings,
          ),
        ];
}

class _NeoPalette {
  const _NeoPalette({
    required this.isDark,
    required this.panel,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.shadow,
    required this.backdrop,
  });

  factory _NeoPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _NeoPalette(
        isDark: true,
        panel: Color(0xFF151A22),
        surface: Color(0xFF1E2430),
        surfaceAlt: Color(0xFF252C38),
        text: Color(0xFFF5F7FA),
        muted: Color(0xFFB4C2D8),
        border: Color(0x33F7FBFF),
        accent: FTunePalette.accent,
        shadow: Color(0x66000000),
        backdrop: Color(0x99060B12),
      );
    }

    return const _NeoPalette(
      isDark: false,
      panel: Color(0xFFFFFFFF),
      surface: Color(0xFFF5F7FA),
      surfaceAlt: Color(0xFFECEFF4),
      text: Color(0xFF1D1F22),
      muted: Color(0xFF5E636B),
      border: Color(0x26000000),
      accent: FTunePalette.electronAccent,
      shadow: Color(0x1A000000),
      backdrop: Color(0x55000000),
    );
  }

  final bool isDark;
  final Color panel;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color shadow;
  final Color backdrop;
}

class _OverlayHeaderButton extends StatefulWidget {
  const _OverlayHeaderButton({
    required this.palette,
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final _NeoPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_OverlayHeaderButton> createState() => _OverlayHeaderButtonState();
}

class _OverlayHeaderButtonState extends State<_OverlayHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final background = _hovered && enabled
        ? widget.palette.surfaceAlt
        : widget.palette.surface;
    final borderColor = _hovered && enabled
        ? _withAlpha(widget.palette.accent, 0.36)
        : widget.palette.border;
    final foreground = enabled
        ? (_hovered ? widget.palette.text : widget.palette.muted)
        : _withAlpha(widget.palette.muted, 0.52);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: _hovered && enabled ? 1.02 : 1,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: borderColor),
                  color: background,
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: 17, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeChoiceButton extends StatefulWidget {
  const _WelcomeChoiceButton({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _NeoPalette palette;
  final VoidCallback onTap;

  @override
  State<_WelcomeChoiceButton> createState() => _WelcomeChoiceButtonState();
}

class _WelcomeChoiceButtonState extends State<_WelcomeChoiceButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? _withAlpha(const Color(0xFF2D84FF), 0.24)
        : (_hovered
            ? _withAlpha(Colors.white, 0.10)
      : _withAlpha(Colors.white, 0.03));
    final borderColor = widget.selected
        ? _withAlpha(const Color(0xFF6FB5FF), 0.50)
    : _withAlpha(Colors.white, _hovered ? 0.16 : 0.08);
    final foreground = widget.selected
        ? Colors.white
        : (_hovered ? Colors.white : _withAlpha(Colors.white, 0.74));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: background,
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.selected
                        ? const Color(0xFF2D84FF)
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.selected
                          ? _withAlpha(Colors.white, 0.24)
                          : _withAlpha(Colors.white, 0.22),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: widget.selected ? 1 : 0,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeGlassPanel extends StatelessWidget {
  const _WelcomeGlassPanel({
    required this.palette,
    required this.child,
  });

  final _NeoPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: _withAlpha(Colors.white, 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _withAlpha(const Color(0xFF11131A), palette.isDark ? 0.42 : 0.18),
                _withAlpha(palette.surface, palette.isDark ? 0.26 : 0.16),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _withAlpha(Colors.black, palette.isDark ? 0.38 : 0.16),
                blurRadius: 48,
                offset: const Offset(0, 26),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WelcomeTopBarButton extends StatefulWidget {
  const _WelcomeTopBarButton({
    required this.palette,
    required this.icon,
    this.onTap,
  });

  final _NeoPalette palette;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_WelcomeTopBarButton> createState() => _WelcomeTopBarButtonState();
}

class _WelcomeTopBarButtonState extends State<_WelcomeTopBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final background = _hovered && enabled
        ? _withAlpha(Colors.white, 0.18)
        : _withAlpha(Colors.white, 0.12);
    final borderColor = _withAlpha(Colors.white, _hovered && enabled ? 0.28 : 0.16);
    final foreground = enabled ? Colors.white : _withAlpha(Colors.white, 0.36);

    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: enabled && _hovered ? 1.02 : 1,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: borderColor),
                  color: background,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _withAlpha(Colors.black, widget.palette.isDark ? 0.16 : 0.08),
                      blurRadius: enabled && _hovered ? 20 : 16,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, size: 20, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeActionButton extends StatefulWidget {
  const _WelcomeActionButton({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final _NeoPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  State<_WelcomeActionButton> createState() => _WelcomeActionButtonState();
}

class _WelcomeActionButtonState extends State<_WelcomeActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final start = _hovered ? const Color(0xFF2D8EFF) : const Color(0xFF3A98FF);
    final end = _hovered ? const Color(0xFF1668FF) : const Color(0xFF1D72FF);
    const foreground = Colors.white;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.982 : (_hovered ? 1.01 : 1),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[start, end],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: _withAlpha(const Color(0xFF1C6FFF), 0.26),
                    blurRadius: _pressed ? 14 : (_hovered ? 28 : 22),
                    offset: Offset(0, _pressed ? 6 : 12),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePreviewScene extends StatelessWidget {
  const _WelcomePreviewScene({
    required this.palette,
    required this.type,
    required this.isVietnamese,
  });

  final _NeoPalette palette;
  final _WelcomePreviewType type;
  final bool isVietnamese;

  String _t(String english, String vietnamese) =>
      isVietnamese ? vietnamese : english;

  @override
  Widget build(BuildContext context) {
    final assetPath = _welcomePreviewAsset(type);
    final image = Image.asset(
      assetPath,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => _buildFallbackPreview(),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.surfaceAlt,
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  Widget _buildFallbackPreview() {
    final label = _t(
      'Using built-in fallback preview',
      'Đang dùng bản xem trước tích hợp',
    );

    return Container(
      color: palette.surfaceAlt,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFallbackScene(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackScene() {
    return switch (type) {
      _WelcomePreviewType.create => _buildCreateScene(),
      _WelcomePreviewType.calculate => _buildCalculateScene(),
      _WelcomePreviewType.garage => _buildGarageScene(),
      _WelcomePreviewType.settings => _buildOverlayScene(),
    };
  }

  Widget _buildCreateScene() {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          bottom: 56,
          child: SizedBox(
            width: 116,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 82,
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Session', 'Phiên tune')),
                        const SizedBox(height: 8),
                        _miniChip('PI A 842'),
                        const SizedBox(height: 6),
                        _miniChip(_t('Ready', 'Sẵn sàng')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _miniPanel(
                    child: Column(
                      children: <Widget>[
                        _miniSearchBar(),
                        const SizedBox(height: 10),
                        _miniListItem(active: true),
                        const SizedBox(height: 8),
                        _miniListItem(),
                        const SizedBox(height: 8),
                        _miniListItem(),
                        const SizedBox(height: 8),
                        _miniListItem(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 56,
          child: SizedBox(
            width: 136,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 82,
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Garage Snapshot', 'Garage gần đây')),
                        const SizedBox(height: 8),
                        _miniResultLine('GT3 RS', _t('Saved', 'Đã lưu')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Performance', 'Hiệu năng')),
                        const SizedBox(height: 10),
                        _miniMetric('A 842', '#A6051A'),
                        const SizedBox(height: 8),
                        _miniMetric('RWD', '#475569'),
                        const SizedBox(height: 8),
                        _miniField(),
                        const SizedBox(height: 8),
                        _miniField(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Result Delta', 'So sánh')),
                        const SizedBox(height: 8),
                        _miniResultLine(_t('Ride', 'Độ cao'), '-0.2'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(128, 10, 144, 76),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: _miniHeaderBar(widthFactor: 0.44)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniHeaderBar(widthFactor: 0.24)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: _miniHeroCard()),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 238,
            child: _miniPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: _miniChip(_t('Drive', 'Dẫn động'))),
                      const SizedBox(width: 8),
                      Expanded(child: _miniChip(_t('Surface', 'Mặt đường'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(child: _miniChip(_t('Tune', 'Kiểu tune'))),
                      const SizedBox(width: 8),
                      Expanded(child: _miniChip(_t('Gears', 'Số / đơn vị'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            width: 138,
            child: Row(
              children: <Widget>[
                Expanded(child: _accentMiniButton(_t('CALC', 'TÍNH'))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: _miniPanel(
                    child: Icon(
                      Icons.save_rounded,
                      size: 16,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculateScene() {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          bottom: 56,
          child: SizedBox(
            width: 108,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 72,
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Session', 'Phiên tune')),
                        const SizedBox(height: 8),
                        _miniChip(_t('Result ready', 'Đã có kết quả')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _miniPanel(
                    child: Column(
                      children: <Widget>[
                        _miniSearchBar(),
                        const SizedBox(height: 10),
                        _miniListItem(active: true),
                        const SizedBox(height: 8),
                        _miniListItem(),
                        const SizedBox(height: 8),
                        _miniListItem(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 56,
          child: SizedBox(
            width: 142,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 118,
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Performance', 'Hiệu năng')),
                        const SizedBox(height: 10),
                        _miniField(),
                        const SizedBox(height: 8),
                        _miniField(),
                        const SizedBox(height: 8),
                        _miniField(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _miniPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _miniPanelTitle(_t('Result Delta', 'So sánh kết quả')),
                        const SizedBox(height: 10),
                        _miniResultLine(_t('Pressure', 'Áp suất'), 'F 1.95 · R 2.02'),
                        const SizedBox(height: 8),
                        _miniResultLine(_t('Gearing', 'Tỷ số truyền'), 'FD 3.62'),
                        const SizedBox(height: 8),
                        _miniResultLine(_t('Braking', 'Phanh'), _t('Balance 51%', 'Cân bằng 51%')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(120, 0, 152, 84),
          child: Column(
            children: <Widget>[
              Expanded(child: _miniHeroCard()),
              const SizedBox(height: 10),
              SizedBox(
                height: 108,
                child: _miniPanel(
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: _miniMetric(_t('Handling', 'Vào cua'), '#FF764B')),
                          const SizedBox(width: 8),
                          Expanded(child: _miniMetric(_t('Grip', 'Bám đường'), '#5EA1FF')),
                          const SizedBox(width: 8),
                          Expanded(child: _miniMetric(_t('Launch', 'Đề-pa'), '#50C878')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _miniResultLine(
                              _t('Pressure', 'Áp suất'),
                              'F 1.95 · R 2.02',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _miniResultLine(
                              _t('Braking', 'Phanh'),
                              _t('Balance 51%', 'Cân bằng 51%'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 238,
            child: _miniPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: _miniChip(_t('Drive', 'Dẫn động'))),
                      const SizedBox(width: 8),
                      Expanded(child: _miniChip(_t('Surface', 'Mặt đường'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(child: _miniChip(_t('Tune', 'Kiểu tune'))),
                      const SizedBox(width: 8),
                      Expanded(child: _miniChip(_t('Units', 'Đơn vị'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            width: 138,
            child: Row(
              children: <Widget>[
                Expanded(child: _accentMiniButton(_t('SAVE', 'LƯU'))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: _miniPanel(
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: palette.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGarageScene() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _miniPanel(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _miniHeaderBar(widthFactor: 0.38)),
                    const SizedBox(width: 8),
                    Expanded(child: _miniHeaderBar(widthFactor: 0.22)),
                    const SizedBox(width: 8),
                    Expanded(child: _miniHeaderBar(widthFactor: 0.3)),
                  ],
                ),
                const SizedBox(height: 10),
                _miniGarageRow(highlight: true),
                const SizedBox(height: 8),
                _miniGarageRow(),
                const SizedBox(height: 8),
                _miniGarageRow(),
                const SizedBox(height: 8),
                _miniGarageRow(),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 174,
          child: Column(
            children: <Widget>[
              Expanded(
                child: _miniPanel(
                  child: Column(
                    children: <Widget>[
                      Expanded(child: _miniHeroCard()),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(child: _miniChip(_t('Overlay', 'Overlay'))),
                          const SizedBox(width: 8),
                          Expanded(child: _miniChip(_t('Edit', 'Sửa'))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: _accentMiniButton(_t('EXPORT', 'XUẤT')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayScene() {
    return Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.bottomLeft,
          child: Opacity(
            opacity: 0.62,
            child: SizedBox(
              width: 208,
              height: 110,
              child: _miniPanel(
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(child: _miniHeaderBar(widthFactor: 0.42)),
                        const SizedBox(width: 8),
                        Expanded(child: _miniHeaderBar(widthFactor: 0.18)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _miniHeroCard()),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 168,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0x44FF4F9A),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: palette.surface,
              border: Border.all(color: palette.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _withAlpha(Colors.black, palette.isDark ? 0.40 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: _miniHeaderBar(widthFactor: 0.42)),
                    const SizedBox(width: 8),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFD166),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CD964),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _miniSummaryPill(),
                const SizedBox(height: 8),
                _miniResultLine(_t('Pressure', 'Áp suất'), 'F 1.95 · R 2.02'),
                const SizedBox(height: 6),
                _miniResultLine(
                  _t('Gearing', 'Tỷ số truyền'),
                  _t('FD 3.62 · 7 gears', 'FD 3.62 · 7 cấp'),
                ),
                const SizedBox(height: 6),
                _miniResultLine(
                  _t('Braking', 'Phanh'),
                  _t('Balance 51% · Force 114%', 'Cân bằng 51% · Lực 114%'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }

  Widget _miniSearchBar() {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.surfaceAlt,
      ),
    );
  }

  Widget _miniListItem({bool active = false}) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: active ? _withAlpha(palette.accent, 0.12) : palette.surfaceAlt,
        border: Border.all(
          color: active ? _withAlpha(palette.accent, 0.45) : palette.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: palette.surface,
              border: Border.all(color: palette.border),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _miniHeaderBar(widthFactor: active ? 0.72 : 0.58)),
        ],
      ),
    );
  }

  Widget _miniHeroCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            top: 24,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    _withAlpha(palette.accent, 0.7),
                    _withAlpha(palette.accent, 0.35),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 12,
            child: _miniHeaderBar(widthFactor: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _miniField() {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
    );
  }

  Widget _accentMiniButton(String label) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: palette.accent,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _withAlpha(palette.accent, 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String colorHex) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _miniHeaderBar(widthFactor: 0.56),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(int.parse('0xFF${colorHex.substring(1)}')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPanelTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: palette.text,
      ),
    );
  }

  Widget _miniSummaryPill() {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: palette.accent,
      ),
    );
  }

  Widget _miniResultLine(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniHeaderBar({double widthFactor = 0.68}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _withAlpha(palette.muted, 0.35),
        ),
      ),
    );
  }

  Widget _miniGarageRow({bool highlight = false}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            highlight ? _withAlpha(palette.accent, 0.12) : palette.surfaceAlt,
        border: Border.all(
          color: highlight ? _withAlpha(palette.accent, 0.45) : palette.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _miniHeaderBar(widthFactor: 0.58)),
          const SizedBox(width: 8),
          Expanded(child: _miniHeaderBar(widthFactor: 0.32)),
          const SizedBox(width: 8),
          Expanded(child: _miniHeaderBar(widthFactor: 0.42)),
        ],
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: palette.muted,
        ),
      ),
    );
  }
}

Color _withAlpha(Color color, double opacity) {
  final alpha = (opacity * 255).round().clamp(0, 255).toInt();
  return color.withAlpha(alpha);
}
