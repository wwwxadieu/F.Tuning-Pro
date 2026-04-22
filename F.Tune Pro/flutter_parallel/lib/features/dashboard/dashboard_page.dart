import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../app/ftune_models.dart';
import '../create/data/brand_logo_repository.dart';
import '../create/data/wiki_car_thumbnail_repository.dart';
import '../create/domain/car_spec.dart';
import '../create/domain/tune_calculation_service.dart';
import '../create/domain/tune_models.dart';
import '../garage/garage_page.dart';
import '../settings/settings_page.dart';
import 'widgets/bento_segmented_bar.dart';
import '../../app/ftune_ui.dart';
import 'widgets/bento_glass_container.dart';

/// Returns black or white text depending on the accent background luminance.
Color _onAccent(Color accent) =>
    accent.computeLuminance() > 0.5 ? const Color(0xFF111111) : Colors.white;

String _normalizeDashboardToken(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

enum _DashboardCarCatalog {
  fh5('FH5', 'assets/data/FH5_cars.json'),
  fh6('FH6', 'assets/data/FH6_cars.json');

  const _DashboardCarCatalog(this.label, this.assetPath);

  final String label;
  final String assetPath;

  static _DashboardCarCatalog fromGameVersion(String? value) {
    return value?.trim().toUpperCase() == 'FH6'
        ? _DashboardCarCatalog.fh6
        : _DashboardCarCatalog.fh5;
  }
}

// ══════════════════════════════════════════════════════════════════
// DashboardPage — Unified App Shell
// Tab 0 = Home Dashboard (car preview + tune form)
// Tab 1 = Garage
// Tab 2 = Settings
// ══════════════════════════════════════════════════════════════════

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.languageCode = 'en',
    this.accentColorValue = 0xFFCAFF03,
    this.isDarkMode = true,
    this.initialTab = 0,
    this.autoCalculateOnLoad = false,
    this.autoOpenResultPopupOnLoad = false,
    this.inlineResultPopupPreview = false,
    this.onAccentChange,
    this.onThemeToggle,
    required this.onCreateTune,
    required this.onOpenGarage,
    required this.onOpenSettings,
    this.initialMetric = true,
    this.pendingCreateSession,
    this.overlayOnTop = true,
    this.themeMode = 'dark',
    this.backgroundImagePath,
    this.onMetricChanged,
    this.onSaveTune,
    this.onOpenOverlayTune,
    this.onLanguageChanged,
    this.onThemeModeChanged,
    this.onOverlayOnTopChanged,
    this.garageTunes = const <SavedTuneRecord>[],
    this.overlayPreviewEnabled = true,
    this.onDeleteTune,
    this.onTogglePinnedTune,
    this.onImportTune,
    this.onExportTune,
    this.onSetOverlayTune,
    this.preferences,
    this.hasCustomBackground = false,
    this.onPreferencesChanged,
    this.onPickBackground,
    this.onClearBackground,
    this.onDropBackground,
    this.onOpenWelcomeTour,
    this.isPro = false,
    this.licenseStatus,
    this.licenseKey,
    this.onActivateLicense,
    this.onDeactivateLicense,
    this.garageLimit = 15,
  });

  final String languageCode;
  final int accentColorValue;
  final bool isDarkMode;
  final int initialTab;
  final bool autoCalculateOnLoad;
  final bool autoOpenResultPopupOnLoad;
  final bool inlineResultPopupPreview;
  final ValueChanged<int>? onAccentChange;
  final VoidCallback? onThemeToggle;
  final VoidCallback onCreateTune;
  final VoidCallback onOpenGarage;
  final VoidCallback onOpenSettings;
  final bool initialMetric;
  final CreateTuneSession? pendingCreateSession;
  final bool overlayOnTop;
  final String themeMode;
  final String? backgroundImagePath;
  final ValueChanged<bool>? onMetricChanged;
  final ValueChanged<SavedTuneDraft>? onSaveTune;
  final Future<void> Function(SavedTuneRecord? record)? onOpenOverlayTune;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<String>? onThemeModeChanged;
  final ValueChanged<bool>? onOverlayOnTopChanged;
  final List<SavedTuneRecord> garageTunes;
  final bool overlayPreviewEnabled;
  final ValueChanged<String>? onDeleteTune;
  final ValueChanged<String>? onTogglePinnedTune;
  final Future<void> Function()? onImportTune;
  final Future<void> Function(List<SavedTuneRecord> records)? onExportTune;
  final Future<void> Function(SavedTuneRecord? record)? onSetOverlayTune;
  final AppPreferences? preferences;
  final bool hasCustomBackground;
  final ValueChanged<AppPreferences>? onPreferencesChanged;
  final Future<void> Function()? onPickBackground;
  final Future<void> Function()? onClearBackground;
  final Future<bool> Function(String path)? onDropBackground;
  final VoidCallback? onOpenWelcomeTour;
  final bool isPro;
  final Object? licenseStatus;
  final String? licenseKey;
  final Future<String?> Function(String key)? onActivateLicense;
  final Future<void> Function()? onDeactivateLicense;
  final int garageLimit;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late int _tab;
  SavedTuneRecord? _pendingEdit;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  Color get _accent => Color(widget.accentColorValue);

  void _switchTab(int index) => setState(() => _tab = index);

  void _editInCreate(SavedTuneRecord record) {
    setState(() {
      _pendingEdit = null; // reset first to ensure didUpdateWidget fires
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _pendingEdit = record;
        _tab = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final isDark = palette.isDark;
    final prefs = widget.preferences ?? const AppPreferences.defaults();
    final adaptiveCarTheme = prefs.autoBackgroundFromCarColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFDEDEDE),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _ShellBackground(
            isDarkMode: isDark,
            accent: _accent,
            backgroundImagePath: widget.backgroundImagePath,
            applyAccentTint: false,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Column(
                children: <Widget>[
                  // ── Top: Segmented tab bar ──
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: BentoSegmentedBar(
                        activeIndex: _tab,
                        onTabChanged: _switchTab,
                        accent: _accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Content area ──
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // ── 0: Dashboard Home (Bento layout) ──
                        _TabPane(
                          active: _tab == 0,
                          slideDirection: _tab > 0 ? -1 : 0,
                          child: _DashboardHome(
                            isDarkMode: isDark,
                            accent: _accent,
                            languageCode: widget.languageCode,
                            initialMetric: prefs.useMetric,
                            autoCalculateOnLoad: widget.autoCalculateOnLoad,
                            autoOpenResultPopupOnLoad:
                                widget.autoOpenResultPopupOnLoad,
                            inlineResultPopupPreview:
                                widget.inlineResultPopupPreview,
                            pendingSession: _pendingEdit?.session ??
                                widget.pendingCreateSession,
                            garageTunes: widget.garageTunes,
                            onSaveTune: widget.onSaveTune,
                            onExportTune: widget.onExportTune,
                            onOpenGarage: () => _switchTab(1),
                            onMetricChanged: widget.onMetricChanged,
                            onOpenOverlayTune: widget.onOpenOverlayTune,
                            onAccentChange: widget.onAccentChange,
                            autoCarThemeEnabled: adaptiveCarTheme,
                            isPro: widget.isPro,
                            garageLimit: widget.garageLimit,
                          ),
                        ),

                        // ── 1: Garage ──
                        _TabPane(
                          active: _tab == 1,
                          slideDirection: _tab < 1 ? 1 : (_tab > 1 ? -1 : 0),
                          child: GaragePage(
                            languageCode: widget.languageCode,
                            records: widget.garageTunes,
                            overlayPreviewEnabled: prefs.overlayPreviewEnabled,
                            onBack: () => _switchTab(0),
                            onCreateNew: () => _switchTab(0),
                            onDelete: (id) => widget.onDeleteTune?.call(id),
                            onTogglePinned: (id) =>
                                widget.onTogglePinnedTune?.call(id),
                            onImport: () async {
                              await widget.onImportTune?.call();
                            },
                            onExport: (records) async {
                              await widget.onExportTune?.call(records);
                            },
                            onSetOverlayTune: (record) async {
                              await widget.onSetOverlayTune?.call(record);
                            },
                            onEditInCreate: _editInCreate,
                            isPro: widget.isPro,
                            garageLimit: widget.garageLimit,
                          ),
                        ),

                        // ── 2: Settings ──
                        _TabPane(
                          active: _tab == 2,
                          slideDirection: _tab < 2 ? 1 : 0,
                          child: SettingsPage(
                            languageCode: widget.languageCode,
                            preferences: prefs,
                            hasCustomBackground: widget.hasCustomBackground,
                            onBack: () => _switchTab(0),
                            onChanged: (p) =>
                                widget.onPreferencesChanged?.call(p),
                            onPickBackground: () async {
                              await widget.onPickBackground?.call();
                            },
                            onClearBackground: () async {
                              await widget.onClearBackground?.call();
                            },
                            onDropBackground: (path) async {
                              if (widget.onDropBackground != null) {
                                return await widget.onDropBackground!(path);
                              }
                              return false;
                            },
                            onOpenWelcomeTour:
                                widget.onOpenWelcomeTour ?? () {},
                            isPro: widget.isPro,
                            licenseStatus: widget.licenseStatus,
                            licenseKey: widget.licenseKey,
                            onActivateLicense: widget.onActivateLicense,
                            onDeactivateLicense: widget.onDeactivateLicense,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _TabPane — wraps each tab with slide + fade transition
// ══════════════════════════════════════════════════════════════════

class _TabPane extends StatelessWidget {
  const _TabPane({
    required this.active,
    required this.slideDirection,
    required this.child,
  });

  /// Whether this tab is currently visible.
  final bool active;

  /// -1 = slide out left, 0 = centered, 1 = slide out right.
  final int slideDirection;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedSlide(
        offset: active ? Offset.zero : Offset(slideDirection * 0.04, 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: active ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}

class _ShellBackground extends StatefulWidget {
  const _ShellBackground({
    required this.isDarkMode,
    required this.accent,
    required this.backgroundImagePath,
    required this.applyAccentTint,
  });

  final bool isDarkMode;
  final Color accent;
  final String? backgroundImagePath;
  final bool applyAccentTint;

  @override
  State<_ShellBackground> createState() => _ShellBackgroundState();
}

class _ShellBackgroundState extends State<_ShellBackground> {
  static const Set<String> _videoExtensions = <String>{
    '.mp4',
    '.webm',
    '.mov',
    '.avi',
  };

  VideoPlayerController? _vpController;
  String? _currentVideoPath;

  bool get _supportsVideoBackground =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  bool _isVideo(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0) return false;
    return _videoExtensions.contains(path.substring(dot).toLowerCase());
  }

  void _syncVideo() {
    final path = widget.backgroundImagePath?.trim();
    final hasPath = path != null && path.isNotEmpty;
    final videoPath =
        hasPath && _isVideo(path) && _supportsVideoBackground ? path : null;

    if (videoPath == _currentVideoPath) return;
    _currentVideoPath = videoPath;

    if (videoPath == null) {
      _disposeVideo();
      return;
    }

    _disposeVideo();
    final controller = VideoPlayerController.file(File(videoPath));
    controller
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          controller.play();
        }
      }).catchError((_) {
        if (!mounted) {
          controller.dispose();
          return;
        }
        if (identical(_vpController, controller)) {
          setState(() {
            _vpController = null;
          });
        }
        controller.dispose();
      });
    setState(() {
      _vpController = controller;
    });
  }

  void _disposeVideo() {
    _vpController?.dispose();
    _vpController = null;
  }

  @override
  void initState() {
    super.initState();
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant _ShellBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundImagePath != widget.backgroundImagePath) {
      _syncVideo();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.backgroundImagePath?.trim();
    final hasBackground = path != null && path.isNotEmpty;
    final showTintLayer = widget.applyAccentTint;
    final isVideoPath = hasBackground && _isVideo(path);
    final showVideoBackground = isVideoPath && _supportsVideoBackground;

    if (!hasBackground && !showTintLayer) {
      return const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (hasBackground &&
            showVideoBackground &&
            _vpController != null &&
            _vpController!.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _vpController!.value.size.width,
                height: _vpController!.value.size.height,
                child: VideoPlayer(_vpController!),
              ),
            ),
          )
        else if (hasBackground && !isVideoPath)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) => const SizedBox.shrink(),
          ),
        if (showTintLayer)
          AnimatedContainer(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isDarkMode
                    ? <Color>[
                        Color.alphaBlend(
                          widget.accent.withAlpha(92),
                          const Color(0xFF130913),
                        ),
                        Color.alphaBlend(
                          widget.accent.withAlpha(48),
                          const Color(0xFF0B0E14),
                        ),
                        const Color(0xFF090B11),
                      ]
                    : <Color>[
                        Color.alphaBlend(
                          widget.accent.withAlpha(62),
                          const Color(0xFFFFFFFF),
                        ),
                        Color.alphaBlend(
                          widget.accent.withAlpha(28),
                          const Color(0xFFF3F5F8),
                        ),
                        const Color(0xFFF3F5F8),
                      ],
                stops: const <double>[0, 0.42, 1],
              ),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _DashboardHome — Layout theo concept: car preview to + info + tune
// ══════════════════════════════════════════════════════════════════

class _DashboardHome extends StatefulWidget {
  const _DashboardHome({
    required this.isDarkMode,
    required this.accent,
    required this.languageCode,
    required this.initialMetric,
    required this.garageTunes,
    required this.onOpenGarage,
    this.autoCalculateOnLoad = false,
    this.autoOpenResultPopupOnLoad = false,
    this.inlineResultPopupPreview = false,
    this.pendingSession,
    this.onSaveTune,
    this.onExportTune,
    this.onMetricChanged,
    this.onOpenOverlayTune,
    this.onAccentChange,
    this.autoCarThemeEnabled = false,
    this.isPro = false,
    this.garageLimit = 15,
  });

  final bool isDarkMode;
  final Color accent;
  final String languageCode;
  final bool initialMetric;
  final bool autoCalculateOnLoad;
  final bool autoOpenResultPopupOnLoad;
  final bool inlineResultPopupPreview;
  final CreateTuneSession? pendingSession;
  final List<SavedTuneRecord> garageTunes;
  final VoidCallback onOpenGarage;
  final ValueChanged<SavedTuneDraft>? onSaveTune;
  final Future<void> Function(List<SavedTuneRecord> records)? onExportTune;
  final ValueChanged<bool>? onMetricChanged;
  final Future<void> Function(SavedTuneRecord? record)? onOpenOverlayTune;
  final ValueChanged<int>? onAccentChange;
  final bool autoCarThemeEnabled;
  final bool isPro;
  final int garageLimit;

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

// ── PI class system ────────────────────────────────────────────────
String _piClassLabel(int pi) {
  if (pi >= 999) return 'X';
  if (pi >= 901) return 'S2';
  if (pi >= 801) return 'S1';
  if (pi >= 701) return 'A';
  if (pi >= 601) return 'B';
  if (pi >= 501) return 'C';
  return 'D';
}

Color _piClassColor(String cls) {
  switch (cls) {
    case 'X':
      return const Color(0xFFE040FB);
    case 'S2':
      return const Color(0xFFE53935);
    case 'S1':
      return const Color(0xFFFF7043);
    case 'A':
      return const Color(0xFFFFB300);
    case 'B':
      return const Color(0xFF00BCD4);
    case 'C':
      return const Color(0xFF4CAF50);
    default:
      return const Color(0xFF9E9E9E);
  }
}

class _DashboardHomeState extends State<_DashboardHome> {
  // ── Car catalog state ──────────────────────────────────────────
  final Map<_DashboardCarCatalog, List<CarSpec>> _carsByCatalog =
      <_DashboardCarCatalog, List<CarSpec>>{};
  _DashboardCarCatalog _selectedCatalog = _DashboardCarCatalog.fh5;
  List<CarSpec> _cars = <CarSpec>[];
  Map<String, String> _thumbnails = <String, String>{};
  Map<String, String> _normalizedThumbnails = <String, String>{};
  Map<String, int> _modelThemeColors = <String, int>{};
  Map<String, int> _brandThemeColors = <String, int>{};
  final Map<String, String?> _resolvedThumbnailUrls = <String, String?>{};
  final Set<String> _pendingThumbnailKeys = <String>{};
  bool _isLoading = true;

  // ── Form state ─────────────────────────────────────────────────
  CarSpec? _selectedCar;
  bool _metric = true;
  String _driveType = 'RWD';
  String _surface = 'Street';
  String _tuneType = 'Race';
  int _gearCount = 6;

  // ── Power band state ───────────────────────────────────────────
  int _redlineRpm = 8000;
  int _maxTorqueRpm = 5500;
  int _scaleMax = 10000;
  int _defaultRedlineRpm = 8000;
  int _defaultMaxTorqueRpm = 5500;
  int _defaultScaleMax = 10000;

  // ── Text controllers ───────────────────────────────────────────
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _frontDistCtrl = TextEditingController();
  final TextEditingController _piCtrl = TextEditingController();
  final TextEditingController _torqueCtrl = TextEditingController();
  final TextEditingController _topSpeedCtrl = TextEditingController();
  // Front tire: width / aspect / rim
  final TextEditingController _fTireWCtrl = TextEditingController(text: '255');
  final TextEditingController _fTireACtrl = TextEditingController(text: '35');
  final TextEditingController _fTireRCtrl = TextEditingController(text: '19');
  // Rear tire: width / aspect / rim
  final TextEditingController _rTireWCtrl = TextEditingController(text: '275');
  final TextEditingController _rTireACtrl = TextEditingController(text: '30');
  final TextEditingController _rTireRCtrl = TextEditingController(text: '19');

  // keep legacy controllers for session compat
  final TextEditingController _frontTireCtrl = TextEditingController();
  final TextEditingController _rearTireCtrl = TextEditingController();

  // ── Result ─────────────────────────────────────────────────────
  TuneCalcResult? _result;
  TuneCalcResult? _inlineResultPopupResult;
  bool _showResult = false;
  bool _isResultPopupOpen = false;

  // ── Brand search ───────────────────────────────────────────────
  String _brandQuery = '';
  String? _selectedBrand;

  Iterable<TextEditingController> get _formControllers =>
      <TextEditingController>[
        _weightCtrl,
        _frontDistCtrl,
        _piCtrl,
        _torqueCtrl,
        _topSpeedCtrl,
        _fTireWCtrl,
        _fTireACtrl,
        _fTireRCtrl,
        _rTireWCtrl,
        _rTireACtrl,
        _rTireRCtrl,
        _frontTireCtrl,
        _rearTireCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _metric = widget.initialMetric;
    for (final controller in _formControllers) {
      controller.addListener(_handleFormControllersChanged);
    }
    _loadCars();
  }

  void _handleFormControllersChanged() {
    if (!mounted) return;
    if (_result != null || _showResult) {
      setState(() {
        _result = null;
        _inlineResultPopupResult = null;
        _showResult = false;
        _isResultPopupOpen = false;
      });
      return;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant _DashboardHome old) {
    super.didUpdateWidget(old);
    if (old.pendingSession != widget.pendingSession &&
        widget.pendingSession != null) {
      _applySession(widget.pendingSession!);
    }
    if (!old.autoCarThemeEnabled &&
        widget.autoCarThemeEnabled &&
        _selectedCar != null) {
      _applyCarThemeFor(_selectedCar!);
    }
  }

  @override
  void dispose() {
    for (final controller in _formControllers) {
      controller.removeListener(_handleFormControllersChanged);
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasMinimumTuneInputs {
    if (_selectedCar == null) return false;

    bool hasDouble(TextEditingController controller) =>
        double.tryParse(controller.text.trim()) != null;
    bool hasInt(TextEditingController controller) =>
        int.tryParse(controller.text.trim()) != null;

    return hasDouble(_weightCtrl) &&
        hasDouble(_frontDistCtrl) &&
        hasInt(_piCtrl) &&
        hasDouble(_torqueCtrl) &&
        hasDouble(_topSpeedCtrl) &&
        hasInt(_fTireWCtrl) &&
        hasInt(_fTireACtrl) &&
        hasInt(_fTireRCtrl) &&
        hasInt(_rTireWCtrl) &&
        hasInt(_rTireACtrl) &&
        hasInt(_rTireRCtrl);
  }

  bool get _canSaveCurrentTune =>
      _hasMinimumTuneInputs && _showResult && _result != null;

  int _currentPiFor(CarSpec car) {
    return int.tryParse(_piCtrl.text.trim()) ?? car.pi;
  }

  String _currentPiClassDisplay(CarSpec car) {
    return ftunePiClassDisplay(_currentPiFor(car));
  }

  String _currentTopSpeedDisplay(TuneCalcResult result) {
    final rawSpeed = double.tryParse(_topSpeedCtrl.text.trim());
    if (rawSpeed == null) return result.overview.topSpeedDisplay;
    return '${rawSpeed.toStringAsFixed(0)} ${_metric ? 'km/h' : 'mph'}';
  }

  String _tireSizeText(
    TextEditingController width,
    TextEditingController aspect,
    TextEditingController rim,
  ) {
    final widthText = width.text.trim();
    final aspectText = aspect.text.trim();
    final rimText = rim.text.trim();
    if (widthText.isEmpty || aspectText.isEmpty || rimText.isEmpty) {
      return '';
    }
    return '$widthText / $aspectText / R$rimText';
  }

  CreateTuneSession _captureCurrentSession({
    required CarSpec car,
    required String tuneTitle,
    required String shareCode,
  }) {
    return CreateTuneSession(
      metric: _metric,
      brand: car.brand,
      model: car.model,
      driveType: _driveType,
      gameVersion: _selectedCatalog.label,
      surface: _surface,
      tuneType: _tuneType,
      gearCount: _gearCount,
      weightKg: _weightCtrl.text.trim(),
      frontDistributionPercent: _frontDistCtrl.text.trim(),
      currentPi: _piCtrl.text.trim(),
      maxTorqueNm: _torqueCtrl.text.trim(),
      topSpeed: _topSpeedCtrl.text.trim(),
      frontTireSize: _tireSizeText(_fTireWCtrl, _fTireACtrl, _fTireRCtrl),
      rearTireSize: _tireSizeText(_rTireWCtrl, _rTireACtrl, _rTireRCtrl),
      powerBand: TuneCalcPowerBand(
        scaleMax: _scaleMax,
        redlineRpm: _redlineRpm,
        maxTorqueRpm: _maxTorqueRpm,
      ),
      tuneTitle: tuneTitle,
      shareCode: shareCode,
    );
  }

  SavedTuneDraft? _buildCurrentTuneDraft(
    TuneCalcResult result, {
    String? title,
    String shareCode = '',
  }) {
    final car = _selectedCar;
    if (car == null) return null;
    final normalizedTitle = (title ?? '').trim().isEmpty
        ? '${car.brand} ${car.model}'
        : title!.trim();
    final normalizedShareCode = shareCode.trim();
    return SavedTuneDraft(
      title: normalizedTitle,
      shareCode: normalizedShareCode,
      brand: car.brand,
      model: car.model,
      driveType: _driveType,
      surface: _surface,
      tuneType: _tuneType,
      piClass: _currentPiClassDisplay(car),
      topSpeedDisplay: _currentTopSpeedDisplay(result),
      result: result,
      session: _captureCurrentSession(
        car: car,
        tuneTitle: normalizedTitle,
        shareCode: normalizedShareCode,
      ),
    );
  }

  SavedTuneRecord? _buildCurrentTuneRecord(
    TuneCalcResult result, {
    String? title,
    String shareCode = '',
    String idPrefix = 'quick-export',
  }) {
    final draft = _buildCurrentTuneDraft(
      result,
      title: title,
      shareCode: shareCode,
    );
    if (draft == null) return null;
    final timestamp = DateTime.now();
    return SavedTuneRecord(
      id: '$idPrefix-${timestamp.microsecondsSinceEpoch}',
      title: draft.title,
      shareCode: draft.shareCode,
      brand: draft.brand,
      model: draft.model,
      driveType: draft.driveType,
      surface: draft.surface,
      tuneType: draft.tuneType,
      piClass: draft.piClass,
      topSpeedDisplay: draft.topSpeedDisplay,
      result: draft.result,
      createdAt: timestamp,
      session: draft.session,
    );
  }

  bool _ensureGarageHasRoom() {
    if (widget.isPro || widget.garageTunes.length < widget.garageLimit) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.languageCode == 'vi'
              ? 'Garage đầy (${widget.garageLimit}/${widget.garageLimit}). Nâng cấp Pro để lưu không giới hạn.'
              : 'Garage full (${widget.garageLimit}/${widget.garageLimit}). Upgrade to Pro for unlimited saves.',
        ),
      ),
    );
    return false;
  }

  void _saveCurrentTuneQuick(TuneCalcResult result) {
    if (widget.onSaveTune == null || !_ensureGarageHasRoom()) return;
    final draft = _buildCurrentTuneDraft(result);
    if (draft == null) return;
    widget.onSaveTune!(draft);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.languageCode == 'vi'
              ? 'Tune đã lưu vào Garage.'
              : 'Tune saved to Garage.',
        ),
      ),
    );
  }

  Future<void> _exportCurrentTuneQuick(TuneCalcResult result) async {
    final record = _buildCurrentTuneRecord(result);
    if (record == null || widget.onExportTune == null) return;
    await widget.onExportTune!(<SavedTuneRecord>[record]);
  }

  int get _readyFieldCount {
    final checks = <bool>[
      _selectedCar != null,
      double.tryParse(_weightCtrl.text.trim()) != null,
      double.tryParse(_frontDistCtrl.text.trim()) != null,
      int.tryParse(_piCtrl.text.trim()) != null,
      double.tryParse(_torqueCtrl.text.trim()) != null,
      double.tryParse(_topSpeedCtrl.text.trim()) != null,
      int.tryParse(_fTireWCtrl.text.trim()) != null,
      int.tryParse(_fTireACtrl.text.trim()) != null,
      int.tryParse(_fTireRCtrl.text.trim()) != null,
      int.tryParse(_rTireWCtrl.text.trim()) != null,
      int.tryParse(_rTireACtrl.text.trim()) != null,
      int.tryParse(_rTireRCtrl.text.trim()) != null,
    ];
    return checks.where((value) => value).length;
  }

  String get _sessionStatusLabel {
    if (_canSaveCurrentTune) return 'Result ready';
    if (_hasMinimumTuneInputs) return 'Ready to calculate';
    if (_selectedCar != null) return 'Input needed';
    return 'Select a car';
  }

  Color get _sessionStatusColor {
    if (_canSaveCurrentTune) return const Color(0xFF22C55E);
    if (_hasMinimumTuneInputs) return widget.accent;
    if (_selectedCar != null) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  List<SavedTuneRecord> get _sortedGarageTunes {
    final records = List<SavedTuneRecord>.from(widget.garageTunes);
    records.sort((left, right) {
      if (left.isPinned != right.isPinned) {
        return left.isPinned ? -1 : 1;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
    return records;
  }

  List<SavedTuneRecord> get _garageSnapshotTunes =>
      _sortedGarageTunes.take(3).toList();

  String _relativeTimeLabel(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    final weeks = (difference.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (difference.inDays / 30).floor();
    return '${months}mo ago';
  }

  String _thumbnailLookupKey(String brand, String model) => '$brand $model';

  String _normalizeThumbnailLookupKey(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r"['’]"), '');
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _matchLocalThumbnail(CarSpec car) {
    final exact =
        _thumbnails[_thumbnailLookupKey(car.brand, car.model)]?.trim();
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }

    final normalizedKey = _normalizeThumbnailLookupKey(
      _thumbnailLookupKey(car.brand, car.model),
    );
    final normalized = _normalizedThumbnails[normalizedKey]?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }

    return null;
  }

  void _queueThumbnailResolution(CarSpec? car) {
    if (car == null) return;
    final key = _thumbnailLookupKey(car.brand, car.model);
    if (_matchLocalThumbnail(car) != null ||
        _resolvedThumbnailUrls.containsKey(key) ||
        _pendingThumbnailKeys.contains(key)) {
      return;
    }

    _pendingThumbnailKeys.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveThumbnailFor(car, key);
    });
  }

  Future<void> _resolveThumbnailFor(CarSpec car, String key) async {
    final resolved = await WikiCarThumbnailRepository.resolveByName(
      car.brand,
      car.model,
    );
    _pendingThumbnailKeys.remove(key);
    if (!mounted) return;
    setState(() {
      _resolvedThumbnailUrls[key] = resolved?.trim() ?? '';
    });
  }

  List<CarSpec> _sortCars(List<CarSpec> cars) {
    final sorted = List<CarSpec>.from(cars);
    sorted.sort((left, right) {
      final brandCompare = left.brand.compareTo(right.brand);
      if (brandCompare != 0) return brandCompare;
      return left.model.compareTo(right.model);
    });
    return sorted;
  }

  Future<List<CarSpec>> _loadCarCatalog(_DashboardCarCatalog catalog) async {
    final raw = await rootBundle.loadString(catalog.assetPath).catchError(
          (_) => '[]',
        );
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <CarSpec>[];
    final cars = decoded
        .map(
          (item) => CarSpec.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return _sortCars(cars);
  }

  CarSpec? _findCarInCatalog(
    List<CarSpec> cars, {
    required String brand,
    required String model,
  }) {
    for (final car in cars) {
      if (car.brand == brand && car.model == model) {
        return car;
      }
    }
    return null;
  }

  void _setActiveCatalog(
    _DashboardCarCatalog catalog, {
    CarSpec? preferredCar,
    String? preferredBrand,
    bool clearSearch = false,
  }) {
    final nextCars = _carsByCatalog[catalog] ?? const <CarSpec>[];
    final candidateCar = preferredCar ?? _selectedCar;
    final nextSelectedCar = candidateCar == null
        ? null
        : _findCarInCatalog(
            nextCars,
            brand: candidateCar.brand,
            model: candidateCar.model,
          );
    final brandCandidate =
        preferredBrand ?? nextSelectedCar?.brand ?? _selectedBrand;
    final nextSelectedBrand = brandCandidate != null &&
            nextCars.any((car) => car.brand == brandCandidate)
        ? brandCandidate
        : null;

    setState(() {
      _selectedCatalog = catalog;
      _cars = nextCars;
      _selectedCar = nextSelectedCar;
      _selectedBrand = nextSelectedBrand;
      if (clearSearch) {
        _brandQuery = '';
      }
      _result = null;
      _inlineResultPopupResult = null;
      _showResult = false;
      _isResultPopupOpen = false;
    });

    if (nextSelectedCar != null) {
      _applyCarThemeFor(nextSelectedCar);
    }
  }

  void _switchCatalog(_DashboardCarCatalog catalog) {
    if (_selectedCatalog == catalog) return;
    if (catalog == _DashboardCarCatalog.fh6 && !widget.isPro) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            widget.languageCode == 'vi'
                ? 'FH6 chỉ dành cho bản Pro. Kích hoạt trong Cài đặt.'
                : 'FH6 is Pro only. Activate in Settings.',
          ),
        ),
      );
      return;
    }
    _setActiveCatalog(catalog, clearSearch: true);
  }

  Future<void> _loadCars() async {
    try {
      final fh5Cars = await _loadCarCatalog(_DashboardCarCatalog.fh5);
      final fh6Cars = await _loadCarCatalog(_DashboardCarCatalog.fh6);
      final rawThumbs = await rootBundle
          .loadString('assets/data/wiki_car_thumbnails.json')
          .catchError((_) => '{}');
      final rawColors = await rootBundle
          .loadString('assets/data/car_color_map.json')
          .catchError((_) => '{}');
      final thumbMap = (jsonDecode(rawThumbs) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      );
      final normalizedThumbMap = <String, String>{
        for (final entry in thumbMap.entries)
          _normalizeThumbnailLookupKey(entry.key): entry.value,
      };
      final decodedColors =
          Map<String, dynamic>.from(jsonDecode(rawColors) as Map);
      final modelColors = _parseColorMap(decodedColors['models']);
      final brandColors = _parseColorMap(decodedColors['brands']);
      if (!mounted) return;
      setState(() {
        _carsByCatalog
          ..clear()
          ..[_DashboardCarCatalog.fh5] = fh5Cars
          ..[_DashboardCarCatalog.fh6] = fh6Cars;
        _selectedCatalog = _DashboardCarCatalog.fh5;
        _cars = fh5Cars;
        _thumbnails = thumbMap;
        _normalizedThumbnails = normalizedThumbMap;
        _modelThemeColors = modelColors;
        _brandThemeColors = brandColors;
        _resolvedThumbnailUrls.clear();
        _pendingThumbnailKeys.clear();
        _isLoading = false;
      });
      if (widget.pendingSession != null) {
        _applySession(widget.pendingSession!);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySession(CreateTuneSession s) {
    final targetCatalog = _DashboardCarCatalog.fromGameVersion(s.gameVersion);
    final catalogCars = _carsByCatalog[targetCatalog] ??
        (targetCatalog == _selectedCatalog ? _cars : const <CarSpec>[]);
    final car = _findCarInCatalog(
      catalogCars,
      brand: s.brand,
      model: s.model,
    );
    final sessionBrand =
        catalogCars.any((entry) => entry.brand == s.brand) ? s.brand : null;
    // Parse front tire
    final fParts = RegExp(r'(\d+)').allMatches(s.frontTireSize).toList();
    // Parse rear tire
    final rParts = RegExp(r'(\d+)').allMatches(s.rearTireSize).toList();
    setState(() {
      _selectedCatalog = targetCatalog;
      _cars = catalogCars;
      _selectedCar = car;
      _selectedBrand = sessionBrand;
      _brandQuery = '';
      _metric = s.metric;
      _driveType = s.driveType;
      _surface = s.surface;
      _tuneType = s.tuneType;
      _gearCount = s.gearCount.clamp(2, 10);
      _weightCtrl.text = s.weightKg;
      _frontDistCtrl.text = s.frontDistributionPercent;
      _piCtrl.text = s.currentPi;
      _torqueCtrl.text = s.maxTorqueNm;
      _topSpeedCtrl.text = s.topSpeed;
      if (fParts.length >= 3) {
        _fTireWCtrl.text = fParts[0].group(0)!;
        _fTireACtrl.text = fParts[1].group(0)!;
        _fTireRCtrl.text = fParts[2].group(0)!;
      }
      if (rParts.length >= 3) {
        _rTireWCtrl.text = rParts[0].group(0)!;
        _rTireACtrl.text = rParts[1].group(0)!;
        _rTireRCtrl.text = rParts[2].group(0)!;
      }
      _redlineRpm = s.powerBand.redlineRpm.clamp(4000, 20000);
      _maxTorqueRpm = s.powerBand.maxTorqueRpm.clamp(1000, _redlineRpm);
      _scaleMax = s.powerBand.scaleMax.clamp(6000, 20000);
      _defaultRedlineRpm = _redlineRpm;
      _defaultMaxTorqueRpm = _maxTorqueRpm;
      _defaultScaleMax = _scaleMax;
      _result = null;
      _inlineResultPopupResult = null;
      _showResult = false;
      _isResultPopupOpen = false;
    });
    if (car != null) {
      _applyCarThemeFor(car);
      _queueThumbnailResolution(car);
    }
    if (widget.autoCalculateOnLoad) {
      final calculated = _calculate();
      if (calculated != null) {
        setState(() {
          _result = calculated;
          _showResult = true;
          if (widget.autoOpenResultPopupOnLoad &&
              widget.inlineResultPopupPreview) {
            _inlineResultPopupResult = calculated;
            _isResultPopupOpen = true;
          }
        });
        if (widget.autoOpenResultPopupOnLoad &&
            !widget.inlineResultPopupPreview) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showTuneResultPopup(calculated);
          });
        }
      }
    }
  }

  void _selectCar(CarSpec car) {
    final frontDist = car.driveType == 'FWD'
        ? 61
        : car.driveType == 'AWD'
            ? 54
            : 47;
    final weight = (car.pi * 2.85 + 610).round();
    final torque = math.max(260, ((car.pi - 300) * 1.75).round());
    // Estimate redline from PI
    final redline = (6000 + car.pi * 10).clamp(7000, 14000);
    final torqueRpm = (redline * 0.65).toInt().clamp(3000, redline - 500);
    // Snap scale max to nearest preset that fits the redline
    const scalePresets = <int>[8000, 10000, 12000];
    final neededMin = redline + 200;
    final scaleMax = scalePresets.firstWhere(
      (p) => p >= neededMin,
      orElse: () => (((neededMin) ~/ 1000) + 1) * 1000,
    );
    setState(() {
      _selectedCar = car;
      _selectedBrand = car.brand;
      _driveType = car.driveType;
      _gearCount = car.driveType == 'AWD' ? 7 : 6;
      _redlineRpm = redline;
      _maxTorqueRpm = torqueRpm;
      _scaleMax = scaleMax;
      _defaultRedlineRpm = redline;
      _defaultMaxTorqueRpm = torqueRpm;
      _defaultScaleMax = scaleMax;
      final speedStr = _metric
          ? car.topSpeedKmh.toStringAsFixed(0)
          : (car.topSpeedKmh * 0.621371).toStringAsFixed(0);
      final weightStr = _metric ? '$weight' : '${(weight * 2.20462).round()}';
      _weightCtrl.text = weightStr;
      _frontDistCtrl.text = '$frontDist';
      _piCtrl.text = '${car.pi}';
      _torqueCtrl.text = '$torque';
      _topSpeedCtrl.text = speedStr;
      // front tire
      final isFwd = car.driveType == 'FWD';
      _fTireWCtrl.text = isFwd ? '245' : '255';
      _fTireACtrl.text = '35';
      _fTireRCtrl.text = '19';
      _rTireWCtrl.text = isFwd ? '245' : '275';
      _rTireACtrl.text = isFwd ? '35' : '30';
      _rTireRCtrl.text = '19';
      _result = null;
      _showResult = false;
    });
    _applyCarThemeFor(car);
    _queueThumbnailResolution(car);
  }

  void _applyCarThemeFor(CarSpec car) {
    if (!widget.autoCarThemeEnabled) return;
    final resolved = _resolveCarThemeColor(car);
    if (resolved == null) return;
    widget.onAccentChange?.call(resolved);
  }

  int? _resolveCarThemeColor(CarSpec car) {
    final modelKey = _normalizeDashboardToken('${car.brand} ${car.model}');
    final modelColor = _modelThemeColors[modelKey];
    if (modelColor != null) return modelColor;
    return _brandThemeColors[_normalizeDashboardToken(car.brand)];
  }

  Map<String, int> _parseColorMap(dynamic source) {
    if (source is! Map) return <String, int>{};
    final output = <String, int>{};
    source.forEach((key, value) {
      final color = _parseColorValue(value);
      if (color != null) {
        output[_normalizeDashboardToken(key.toString())] = color;
      }
    });
    return output;
  }

  int? _parseColorValue(dynamic value) {
    if (value is int) return value;
    if (value is! String) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final sanitized = normalized.startsWith('#')
        ? normalized.substring(1)
        : normalized.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
    if (sanitized.length == 6) {
      return int.tryParse('FF$sanitized', radix: 16);
    }
    if (sanitized.length == 8) {
      return int.tryParse(sanitized, radix: 16);
    }
    return null;
  }

  /// Called when metric toggle is changed — auto-converts weight & speed.
  void _onMetricChanged(bool useMetric) {
    if (_metric == useMetric) return;
    setState(() {
      // Convert weight
      final w = double.tryParse(_weightCtrl.text);
      if (w != null) {
        _weightCtrl.text = useMetric
            ? (w / 2.20462).round().toString() // lb → kg
            : (w * 2.20462).round().toString(); // kg → lb
      }
      // Convert speed
      final s = double.tryParse(_topSpeedCtrl.text);
      if (s != null) {
        _topSpeedCtrl.text = useMetric
            ? (s / 0.621371).toStringAsFixed(0) // mph → km/h
            : (s * 0.621371).toStringAsFixed(0); // km/h → mph
      }
      _metric = useMetric;
    });
    widget.onMetricChanged?.call(useMetric);
  }

  void _showTuneResultPopup(TuneCalcResult result) {
    final palette = FTuneElectronPaletteData.of(context);
    final isDark = palette.isDark;
    final accent = palette.accent;
    final panelBg = isDark ? const Color(0xFF181C24) : const Color(0xFFFFFFFF);
    final border = palette.border;
    final text = palette.text;
    final muted = palette.muted;

    setState(() => _isResultPopupOpen = true);

    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, _, __) => _TuneResultPopup(
        result: result,
        accent: accent,
        isDarkMode: isDark,
        panelBg: panelBg,
        border: border,
        text: text,
        muted: muted,
        onActivateOverlay: () {
          Navigator.of(ctx).pop(true);
        },
        onSave: widget.onSaveTune == null
            ? null
            : () => _saveCurrentTuneQuick(result),
        onExport: widget.onExportTune == null
            ? null
            : () => _exportCurrentTuneQuick(result),
      ),
    ).then((activateOverlay) {
      if (mounted) setState(() => _isResultPopupOpen = false);
      if (activateOverlay == true && mounted) {
        widget.onOpenOverlayTune?.call(_buildOverlayRecord(result));
      }
    });
  }

  TuneCalcResult? _calculate() {
    final car = _selectedCar;
    if (car == null || !_hasMinimumTuneInputs) return null;
    final tw = double.tryParse(_rTireWCtrl.text) ?? 275.0;
    final ta = double.tryParse(_rTireACtrl.text) ?? 30.0;
    final tr = double.tryParse(_rTireRCtrl.text) ?? 19.0;
    // Speed always stored in user units → convert to km/h for calculation
    final rawSpeed = double.tryParse(_topSpeedCtrl.text) ?? car.topSpeedKmh;
    final speedKmh = _metric ? rawSpeed : rawSpeed / 0.621371;
    // Weight always stored in user units
    final rawWeight =
        double.tryParse(_weightCtrl.text) ?? (car.pi * 2.85 + 610);
    final weightKg = _metric ? rawWeight : rawWeight / 2.20462;
    return TuneCalculationService.calculate(
      TuneCalcInput(
        brand: car.brand,
        model: car.model,
        driveType: _driveType,
        surface: _surface,
        tuneType: _tuneType,
        pi: int.tryParse(_piCtrl.text) ?? car.pi,
        topSpeedKmh: speedKmh,
        weightKg: weightKg,
        frontDistributionPercent: double.tryParse(_frontDistCtrl.text) ?? 47.0,
        maxTorqueNm: double.tryParse(_torqueCtrl.text) ?? 300.0,
        gears: _gearCount,
        tireWidth: tw,
        tireAspect: ta,
        tireRim: tr,
        tireType: car.tireType,
        differentialType: car.differential,
        powerBand: TuneCalcPowerBand(
          scaleMax: _scaleMax,
          redlineRpm: _redlineRpm,
          maxTorqueRpm: _maxTorqueRpm,
        ),
      ),
      metric: _metric,
    );
  }

  String? _thumbFor(CarSpec? car) {
    if (car == null) return null;
    final key = _thumbnailLookupKey(car.brand, car.model);
    var url = _matchLocalThumbnail(car) ?? _resolvedThumbnailUrls[key]?.trim();
    if (url == null || url.isEmpty) {
      _queueThumbnailResolution(car);
      return null;
    }
    // Request original-resolution image — strip any wiki scale suffix
    url = url.replaceFirst(
      RegExp(r'/scale-to-width-down/\d+'),
      '',
    );
    return url;
  }

  SavedTuneRecord? _buildOverlayRecord(TuneCalcResult? result) {
    final car = _selectedCar;
    if (car == null || result == null) return null;
    final timestamp = DateTime.now();

    return SavedTuneRecord(
      id: 'overlay-${timestamp.microsecondsSinceEpoch}',
      title: '${car.brand} ${car.model}',
      shareCode: '',
      brand: car.brand,
      model: car.model,
      driveType: _driveType,
      surface: _surface,
      tuneType: _tuneType,
      piClass: _currentPiClassDisplay(car),
      topSpeedDisplay: _currentTopSpeedDisplay(result),
      result: result,
      createdAt: timestamp,
      session: _captureCurrentSession(
        car: car,
        tuneTitle: '${car.brand} ${car.model}',
        shareCode: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final isDark = palette.isDark;
    final accent = palette.accent;
    final panelBg = isDark ? const Color(0xFF181C24) : const Color(0xFFFFFFFF);
    final border = palette.border;
    final text = palette.text;
    final muted = palette.muted;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth >= 960;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 2),
      );
    }

    // ── Shared builders ──────────────────────────────────────

    Widget buildTuneConfig() => _TuneConfigBlock(
          isDarkMode: isDark,
          accent: accent,
          driveType: _driveType,
          surface: _surface,
          tuneType: _tuneType,
          gearCount: _gearCount,
          metric: _metric,
          panelBg: panelBg,
          border: border,
          text: text,
          muted: muted,
          onDriveType: (v) => setState(() => _driveType = v),
          onSurface: (v) => setState(() => _surface = v),
          onTuneType: (v) => setState(() => _tuneType = v),
          onGearCount: (v) => setState(() => _gearCount = v),
          onMetricChanged: _onMetricChanged,
        );

    Widget buildPerformance() => _PerformanceBlock(
          isDarkMode: isDark,
          accent: accent,
          metric: _metric,
          gearCount: _gearCount,
          weightCtrl: _weightCtrl,
          frontDistCtrl: _frontDistCtrl,
          piCtrl: _piCtrl,
          torqueCtrl: _torqueCtrl,
          topSpeedCtrl: _topSpeedCtrl,
          fTireW: _fTireWCtrl,
          fTireA: _fTireACtrl,
          fTireR: _fTireRCtrl,
          rTireW: _rTireWCtrl,
          rTireA: _rTireACtrl,
          rTireR: _rTireRCtrl,
          redlineRpm: _redlineRpm,
          maxTorqueRpm: _maxTorqueRpm,
          scaleMax: _scaleMax,
          defaultRedlineRpm: _defaultRedlineRpm,
          defaultMaxTorqueRpm: _defaultMaxTorqueRpm,
          defaultScaleMax: _defaultScaleMax,
          panelBg: panelBg,
          border: border,
          text: text,
          muted: muted,
          selectedCar: _selectedCar,
          result: _showResult ? _result : null,
          frozen: _isResultPopupOpen,
          onRedlineChanged: (v) => setState(() => _redlineRpm = v),
          onTorqueRpmChanged: (v) => setState(() => _maxTorqueRpm = v),
          onScaleMaxChanged: (v) => setState(() => _scaleMax = v),
          onGearCount: (v) => setState(() => _gearCount = v),
          showActions: _hasMinimumTuneInputs,
          canSaveAction: _canSaveCurrentTune,
          onCalculate: () {
            final r = _calculate();
            if (r == null) return;
            setState(() {
              _result = r;
              _showResult = true;
            });
            _showTuneResultPopup(r);
          },
          onSave: _canSaveCurrentTune ? () => _showSaveDialog() : null,
        );

    Widget buildCarBrowser({required double listMaxHeight}) => _CarInfoBlock(
          isDarkMode: isDark,
          accent: accent,
          cars: _cars,
          activeCatalog: _selectedCatalog,
          selectedCar: _selectedCar,
          selectedBrand: _selectedBrand,
          brandQuery: _brandQuery,
          panelBg: panelBg,
          border: border,
          text: text,
          muted: muted,
          listMaxHeight: listMaxHeight,
          onCatalogChanged: _switchCatalog,
          onBrandQueryChanged: (q) => setState(() => _brandQuery = q),
          onCarSelected: _selectCar,
        );

    Widget buildSessionSummaryCard({bool compact = false}) =>
        _SessionSummaryCard(
          accent: accent,
          border: border,
          text: text,
          muted: muted,
          isDarkMode: isDark,
          compact: compact,
          carLabel: _selectedCar == null
              ? 'No car selected'
              : '${_selectedCar!.brand} ${_selectedCar!.model}',
          statusLabel: _sessionStatusLabel,
          statusColor: _sessionStatusColor,
          readinessLabel: '$_readyFieldCount/12 ready',
          piLabel: _piCtrl.text.trim().isEmpty
              ? (_selectedCar == null ? '--' : 'PI ${_selectedCar!.pi}')
              : 'PI ${_piCtrl.text.trim()}',
          driveLabel: _driveType,
          surfaceLabel: _surface,
          tuneTypeLabel: _tuneType,
          unitsLabel: _metric ? 'Metric' : 'Imperial',
          gearsLabel: '${_gearCount.clamp(2, 10)} gears',
        );

    Widget buildGarageSnapshotCard({bool compact = false}) =>
        _GarageSnapshotCard(
          accent: accent,
          border: border,
          text: text,
          muted: muted,
          records: _garageSnapshotTunes,
          totalCount: widget.garageTunes.length,
          onOpenGarage: widget.onOpenGarage,
          relativeTimeLabel: _relativeTimeLabel,
          compact: compact,
          maxItems: compact ? 1 : 3,
        );

    Widget buildQuickTuneTips({bool compact = false}) => _QuickTuneTipsCard(
          accent: accent,
          border: border,
          text: text,
          muted: muted,
          tuneType: _tuneType,
          compact: compact,
        );

    Widget buildUtilityDeck(double maxWidth) {
      final stacked = maxWidth < 470;
      final itemWidth = stacked ? maxWidth : (maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          SizedBox(width: itemWidth, child: buildSessionSummaryCard()),
          SizedBox(width: itemWidth, child: buildGarageSnapshotCard()),
        ],
      );
    }

    // ══════════════════════════════════════════════════════════
    // BENTO GRID LAYOUT
    //
    // ┌────────────┬────────────────────┬──────────────┐
    // │  Car List   │   Car Preview      │  Basic Specs │
    // │  (left)     │   (center, large)  │  (right)     │
    // ├────────────┴────────────────────┴──────────────┤
    // │          Tune Features (bottom)                │
    // └────────────────────────────────────────────────┘
    // ══════════════════════════════════════════════════════════

    if (isWide) {
      return _wrapWithHeroCarBg(
        isDark: isDark,
        accent: accent,
        panelBg: panelBg,
        border: border,
        muted: muted,
        text: text,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final leftPanelWidth =
                (constraints.maxWidth * 0.24).clamp(280.0, 340.0);
            final rightPanelWidth =
                (constraints.maxWidth * 0.25).clamp(280.0, 360.0);
            final bottomPanelWidth =
                (constraints.maxWidth * 0.38).clamp(460.0, 620.0);
            final bottomPanelNeedsTwoRows = bottomPanelWidth < 580;
            final bottomPanelHeight = bottomPanelNeedsTwoRows
                ? (constraints.maxHeight * 0.30).clamp(246.0, 260.0)
                : (constraints.maxHeight * 0.19).clamp(156.0, 182.0);
            final sideBottomCardHeight = 118.0;
            final heroLabelWidth =
                (constraints.maxWidth * 0.30).clamp(260.0, 420.0);
            final sidePadding =
                math.max(12.0, constraints.maxWidth * 0.012).toDouble();
            final heroTopPadding =
                math.max(18.0, constraints.maxHeight * 0.03).toDouble();
            final sideColumnBottomInset = sideBottomCardHeight + 20;
            final browserListHeight =
                (constraints.maxHeight - sideBottomCardHeight - 160)
                    .clamp(220.0, 520.0);

            Widget glassPanel({
              required double width,
              required double height,
              required Widget child,
              bool scroll = true,
            }) {
              final panelChild = scroll
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: child,
                    )
                  : child;

              return SizedBox(
                width: width,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BentoGlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(12),
                    child: panelChild,
                  ),
                ),
              );
            }

            Widget expandedGlassPanel({
              required Widget child,
              bool scroll = true,
            }) {
              final panelChild = scroll
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: child,
                    )
                  : child;

              return Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BentoGlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(12),
                    child: panelChild,
                  ),
                ),
              );
            }

            return Stack(
              children: <Widget>[
                Positioned(
                  left: sidePadding,
                  top: heroTopPadding,
                  bottom: sideColumnBottomInset,
                  width: leftPanelWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      expandedGlassPanel(
                        scroll: false,
                        child: buildCarBrowser(
                          listMaxHeight: browserListHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: sidePadding,
                  top: heroTopPadding,
                  bottom: sideColumnBottomInset,
                  width: rightPanelWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      expandedGlassPanel(child: buildPerformance()),
                      const SizedBox(height: 10),
                      buildQuickTuneTips(compact: true),
                    ],
                  ),
                ),
                if (_selectedCar != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        leftPanelWidth + sidePadding + 18,
                        heroTopPadding,
                        rightPanelWidth + sidePadding + 18,
                        bottomPanelHeight + 24,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: heroLabelWidth,
                          child: _CarHeroLabel(
                            car: _selectedCar!,
                            pi: int.tryParse(_piCtrl.text) ?? _selectedCar?.pi,
                            accent: accent,
                            text: text,
                            muted: muted,
                            isDark: isDark,
                            showCompactSpecs: true,
                            weightText: _weightCtrl.text.isNotEmpty
                                ? _weightCtrl.text
                                : null,
                            frontDistText: _frontDistCtrl.text.isNotEmpty
                                ? _frontDistCtrl.text
                                : null,
                            torqueText: _torqueCtrl.text.isNotEmpty
                                ? _torqueCtrl.text
                                : null,
                            topSpeedText: _topSpeedCtrl.text.isNotEmpty
                                ? _topSpeedCtrl.text
                                : (_selectedCar?.topSpeedKmh != null
                                    ? '${_selectedCar!.topSpeedKmh.toInt()}'
                                    : null),
                            driveType: _driveType.isNotEmpty
                                ? _driveType
                                : _selectedCar?.driveType,
                            metric: _metric,
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: glassPanel(
                      width: bottomPanelWidth,
                      height: bottomPanelHeight,
                      scroll: false,
                      child: buildTuneConfig(),
                    ),
                  ),
                ),
                Positioned(
                  left: sidePadding,
                  bottom: 12,
                  width: leftPanelWidth,
                  child: SizedBox(
                    height: sideBottomCardHeight,
                    child: buildSessionSummaryCard(compact: true),
                  ),
                ),
                Positioned(
                  right: sidePadding,
                  bottom: 12,
                  width: rightPanelWidth,
                  child: SizedBox(
                    height: sideBottomCardHeight,
                    child: buildGarageSnapshotCard(compact: true),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    // ══════════════════════════════════════════════════════════
    // Narrow (mobile) layout
    // ══════════════════════════════════════════════════════════
    return _wrapWithHeroCarBg(
      isDark: isDark,
      accent: accent,
      panelBg: panelBg,
      border: border,
      muted: muted,
      text: text,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Car info header with compact specs
            if (_selectedCar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 160, 16, 16),
                child: _CarHeroLabel(
                  car: _selectedCar!,
                  pi: int.tryParse(_piCtrl.text) ?? _selectedCar?.pi,
                  accent: accent,
                  text: text,
                  muted: muted,
                  isDark: isDark,
                  showCompactSpecs: true,
                  weightText:
                      _weightCtrl.text.isNotEmpty ? _weightCtrl.text : null,
                  frontDistText: _frontDistCtrl.text.isNotEmpty
                      ? _frontDistCtrl.text
                      : null,
                  torqueText:
                      _torqueCtrl.text.isNotEmpty ? _torqueCtrl.text : null,
                  topSpeedText:
                      _topSpeedCtrl.text.isNotEmpty ? _topSpeedCtrl.text : null,
                  driveType: _driveType.isNotEmpty ? _driveType : null,
                  metric: _metric,
                ),
              )
            else
              const SizedBox(height: 200),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, utilityConstraints) {
                  return buildUtilityDeck(utilityConstraints.maxWidth);
                },
              ),
            ),

            const SizedBox(height: 10),

            // Car browser
            BentoGlassContainer(
              padding: const EdgeInsets.all(12),
              child: buildCarBrowser(
                listMaxHeight: (screenHeight * 0.35).clamp(220.0, 400.0),
              ),
            ),
            const SizedBox(height: 10),

            // Tune features
            BentoGlassContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  buildTuneConfig(),
                  const SizedBox(height: 10),
                  buildPerformance(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: buildQuickTuneTips(),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-screen car hero background with gradient veil.
  Widget _wrapWithHeroCarBg({
    required bool isDark,
    required Color accent,
    required Color panelBg,
    required Color border,
    required Color muted,
    required Color text,
    required Widget child,
  }) {
    final url = _thumbFor(_selectedCar);
    final hasCar = _selectedCar != null && url != null && url.isNotEmpty;
    final mediaSize = MediaQuery.of(context).size;
    final bgBase = isDark ? const Color(0xFF0A0C10) : Colors.white;

    final baseContent = hasCar
        ? Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: mediaSize.width * 0.22,
                right: mediaSize.width * 0.22,
                bottom: mediaSize.height * 0.16,
                height: 104,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.35,
                        colors: <Color>[
                          (isDark ? Colors.white : accent)
                              .withAlpha(isDark ? 20 : 18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        bottom: 72, left: 200, right: 140, top: 20),
                    child: _HeroCarImage(
                      key: ValueKey<String>('hero_$url'),
                      url: url,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.15),
                        radius: 0.95,
                        colors: <Color>[
                          bgBase.withAlpha(0),
                          bgBase.withAlpha(isDark ? 42 : 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          )
        : child;

    final inlineResult = _inlineResultPopupResult;
    if (inlineResult == null) {
      return baseContent;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        baseContent,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(isDark ? 120 : 36),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: _TuneResultPopup(
                result: inlineResult,
                accent: accent,
                isDarkMode: isDark,
                panelBg: panelBg,
                border: border,
                text: text,
                muted: muted,
                onClose: () {},
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSaveDialog() {
    final car = _selectedCar;
    final result = _result;
    if (car == null || result == null) return;

    if (!_ensureGarageHasRoom()) return;

    final nameCtrl = TextEditingController(text: '${car.brand} ${car.model}');
    final codeCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Tune'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Tune name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration:
                  const InputDecoration(labelText: 'Share code (optional)'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final draft = _buildCurrentTuneDraft(
                result,
                title: nameCtrl.text,
                shareCode: codeCtrl.text,
              );
              if (draft != null) {
                widget.onSaveTune?.call(draft);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.languageCode == 'vi'
                        ? 'Tune đã lưu vào Garage.'
                        : 'Tune saved to Garage.',
                  ),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _BrandLogoWidget extends StatefulWidget {
  const _BrandLogoWidget({
    required this.brand,
    required this.size,
    required this.isDarkMode,
  });

  final String brand;
  final double size;
  final bool isDarkMode;

  @override
  State<_BrandLogoWidget> createState() => _BrandLogoWidgetState();
}

class _BrandLogoWidgetState extends State<_BrandLogoWidget> {
  int _urlIndex = 0;
  bool _failed = false;

  List<String> get _urls =>
      BrandLogoRepository.getBrandLogoUrlCandidates(widget.brand);

  @override
  void didUpdateWidget(covariant _BrandLogoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brand != widget.brand) {
      _urlIndex = 0;
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (_failed || urls.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDarkMode
              ? const Color(0xFF252A34)
              : const Color(0xFFD8DAE0),
        ),
        child: Center(
          child: Text(
            BrandLogoRepository.getBrandLogoFallbackText(widget.brand),
            style: TextStyle(
              fontSize: widget.size * 0.35,
              fontWeight: FontWeight.w900,
              color: widget.isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
      );
    }
    return Image.network(
      urls[_urlIndex],
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            if (_urlIndex < urls.length - 1) {
              _urlIndex++;
            } else {
              _failed = true;
            }
          });
        });
        return const SizedBox.shrink();
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _PiClassBadge — Glowing PI class + number badge
// ══════════════════════════════════════════════════════════════════
class _PiClassBadge extends StatelessWidget {
  const _PiClassBadge({required this.pi, required this.isDarkMode});

  final int pi;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final cls = _piClassLabel(pi);
    final clsColor = _piClassColor(cls);
    const fClass = 13.0;
    const fNum = 11.0;
    const hPad = 8.0;
    const vPad = 4.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: clsColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                bottomLeft: Radius.circular(9),
              ),
            ),
            child: Text(
              cls,
              style: const TextStyle(
                fontSize: fClass,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                  clsColor.withAlpha(40),
                  isDarkMode
                      ? const Color(0xFF181C24)
                      : const Color(0xFFFFFFFF)),
              border: Border(
                top: BorderSide(color: clsColor),
                right: BorderSide(color: clsColor),
                bottom: BorderSide(color: clsColor),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(9),
                bottomRight: Radius.circular(9),
              ),
            ),
            child: Text(
              '$pi',
              style: TextStyle(
                fontSize: fNum,
                fontWeight: FontWeight.w900,
                color: clsColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _ZoomListView — scroll-aware zoom: center = 1.0, edges = 0.88
// ══════════════════════════════════════════════════════════════════

class _ZoomListView extends StatefulWidget {
  const _ZoomListView({
    required this.itemCount,
    required this.itemBuilder,
    required this.separatorBuilder,
    this.listKey,
  });

  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Widget Function(BuildContext, int) separatorBuilder;
  final Key? listKey;

  @override
  State<_ZoomListView> createState() => _ZoomListViewState();
}

class _ZoomListViewState extends State<_ZoomListView> {
  final ValueNotifier<double> _offset = ValueNotifier<double>(0.0);

  static const double _tileH = 52.0;
  static const double _slot = _tileH + 8.0;

  double _scaleFor(int i, double viewH, double scrollOffset) {
    final itemCenter = i * _slot + _tileH / 2 - scrollOffset;
    final dist = (itemCenter - viewH / 2).abs();
    final t = (dist / (viewH * 0.55)).clamp(0.0, 1.0);
    return 1.0 - 0.12 * t * t;
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 400.0;
        return ShaderMask(
          shaderCallback: (Rect rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: <double>[0.0, 0.05, 0.95, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _offset.value = notification.metrics.pixels;
              return false;
            },
            child: ValueListenableBuilder<double>(
              valueListenable: _offset,
              builder: (context, scrollOffset, _) {
                return ListView.separated(
                  key: widget.listKey,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  itemCount: widget.itemCount,
                  separatorBuilder: widget.separatorBuilder,
                  itemBuilder: (context, i) {
                    final scale = _scaleFor(i, viewH, scrollOffset);
                    return RepaintBoundary(
                      child: Transform.scale(
                        scale: scale,
                        child: widget.itemBuilder(context, i),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _AnimatedListItem — Staggered fade+slide entrance for list tiles
// ══════════════════════════════════════════════════════════════════

class _AnimatedListItem extends StatefulWidget {
  const _AnimatedListItem({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    final delay = (widget.index * 28).clamp(0, 200);
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ══════════════════════════════════════════════════════════════════
// _CarInfoBlock — Brand/model selector + unit toggle
// ══════════════════════════════════════════════════════════════════

class _CarInfoBlock extends StatefulWidget {
  const _CarInfoBlock({
    required this.isDarkMode,
    required this.accent,
    required this.cars,
    required this.activeCatalog,
    required this.selectedCar,
    required this.selectedBrand,
    required this.brandQuery,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
    required this.listMaxHeight,
    required this.onCatalogChanged,
    required this.onBrandQueryChanged,
    required this.onCarSelected,
  });

  final bool isDarkMode;
  final Color accent;
  final List<CarSpec> cars;
  final _DashboardCarCatalog activeCatalog;
  final CarSpec? selectedCar;
  final String? selectedBrand;
  final String brandQuery;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;
  final double listMaxHeight;
  final ValueChanged<_DashboardCarCatalog> onCatalogChanged;
  final ValueChanged<String> onBrandQueryChanged;
  final ValueChanged<CarSpec> onCarSelected;

  @override
  State<_CarInfoBlock> createState() => _CarInfoBlockState();
}

class _CarInfoBlockState extends State<_CarInfoBlock> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _sortAscending = true;
  int _sortVersion = 0;
  String? _activeBrand;
  bool _goingToModel = false;

  Key get _brandListStorageKey => PageStorageKey<String>(
        'dashboard-brand-list-${widget.activeCatalog.name}',
      );

  Key get _modelListStorageKey => PageStorageKey<String>(
        'dashboard-model-list-${widget.activeCatalog.name}-${_activeBrand ?? ''}',
      );

  @override
  void initState() {
    super.initState();
    _activeBrand = widget.selectedBrand;
    _searchCtrl.text = widget.brandQuery;
  }

  @override
  void didUpdateWidget(covariant _CarInfoBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brandQuery != widget.brandQuery &&
        widget.brandQuery != _searchCtrl.text) {
      _searchCtrl.value = TextEditingValue(
        text: widget.brandQuery,
        selection: TextSelection.collapsed(offset: widget.brandQuery.length),
      );
    }
    // Catalog changed → bump sort version to re-trigger list transition.
    if (oldWidget.activeCatalog != widget.activeCatalog) {
      _sortVersion++;
    }
    if (oldWidget.selectedBrand != widget.selectedBrand) {
      _activeBrand = widget.selectedBrand;
      _goingToModel = widget.selectedBrand != null;
    }
    if (_activeBrand != null &&
        !widget.cars.any((car) => car.brand == _activeBrand)) {
      _activeBrand = null;
      _goingToModel = false;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _query => widget.brandQuery.trim().toLowerCase();
  bool get _showModelPage => _activeBrand != null;

  int _compareAlpha(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  List<String> get _filteredBrands {
    final q = _query;
    final brands = widget.cars.map((c) => c.brand).toSet().toList()
      ..sort(_compareAlpha);
    final sorted = _sortAscending ? brands : brands.reversed.toList();
    if (q.isEmpty) return sorted;
    return sorted
        .where((b) =>
            b.toLowerCase().contains(q) ||
            widget.cars
                .any((c) => c.brand == b && c.model.toLowerCase().contains(q)))
        .toList();
  }

  List<CarSpec> get _filteredModels {
    final brand = _activeBrand;
    if (brand == null) return const <CarSpec>[];
    final models = widget.cars
        .where((car) =>
            car.brand == brand &&
            (_query.isEmpty || car.model.toLowerCase().contains(_query)))
        .toList()
      ..sort((a, b) => _compareAlpha(a.model, b.model));
    return _sortAscending ? models : models.reversed.toList();
  }

  void _openBrand(String brand) {
    setState(() {
      _goingToModel = true;
      _activeBrand = brand;
    });
  }

  void _backToBrands() {
    setState(() {
      _goingToModel = false;
      _activeBrand = null;
    });
  }

  int _brandModelCount(String brand) =>
      widget.cars.where((car) => car.brand == brand).length;

  Widget _toolbarButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool active = false,
    // When non-null, the icon rotates 180° each time this value changes
    int? sortVersion,
  }) {
    Widget iconWidget = Icon(
      icon,
      size: 17,
      color: active ? _onAccent(widget.accent) : widget.text,
    );

    if (sortVersion != null) {
      // Each sort flip alternates between 0 and 0.5 turns (180°)
      final targetTurns = (sortVersion % 2 == 0) ? 0.0 : 0.5;
      iconWidget = TweenAnimationBuilder<double>(
        tween: Tween<double>(end: targetTurns),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (_, turns, child) => RotationTransition(
            turns: AlwaysStoppedAnimation(turns), child: child!),
        child: Icon(
          icon,
          size: 17,
          color: active ? _onAccent(widget.accent) : widget.text,
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? widget.accent
                : (widget.isDarkMode
                    ? const Color(0xFF1C2028)
                    : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? widget.accent
                  : (widget.isDarkMode
                      ? const Color(0xFF2A2F3A).withAlpha(60)
                      : const Color(0xFFE8EAF0)),
            ),
          ),
          child: Center(child: iconWidget),
        ),
      ),
    );
  }

  Widget _browserTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted
              ? (widget.isDarkMode
                  ? const Color(0xFF1A2030)
                  : const Color(0xFFF0F8FF))
              : (widget.isDarkMode
                  ? const Color(0xFF181C24)
                  : const Color(0xFFFFFFFF)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? widget.accent
                : (widget.isDarkMode
                    ? const Color(0xFF2A2F3A).withAlpha(60)
                    : const Color(0xFFE8EAF0)),
          ),
          boxShadow: highlighted
              ? <BoxShadow>[
                  BoxShadow(
                    color: widget.accent.withAlpha(20),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : <BoxShadow>[],
        ),
        child: Row(
          children: <Widget>[
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: highlighted ? widget.accent : widget.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String label) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: widget.muted,
        ),
      ),
    );
  }

  Widget _buildBrandList() {
    if (_filteredBrands.isEmpty) {
      return _buildEmptyState('No brands matched your filter.');
    }

    // Key on outer widget is read by the outer AnimatedSwitcher for slide direction.
    // Inner AnimatedSwitcher keys on _sortVersion for vertical sort animation.
    return AnimatedSwitcher(
      key: const ValueKey<String>('brand-browser'),
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, _sortAscending ? -0.08 : 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey<String>('${widget.activeCatalog.name}-$_sortVersion'),
        child: _ZoomListView(
          listKey: _brandListStorageKey,
          itemCount: _filteredBrands.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final brand = _filteredBrands[index];
            final isCurrentBrand = widget.selectedBrand == brand;
            return _AnimatedListItem(
              index: index,
              child: _browserTile(
                leading: _BrandLogoWidget(
                  brand: brand,
                  size: 36,
                  isDarkMode: widget.isDarkMode,
                ),
                title: brand,
                subtitle: '${_brandModelCount(brand)} models',
                highlighted: isCurrentBrand,
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isCurrentBrand ? widget.accent : widget.muted,
                ),
                onTap: () => _openBrand(brand),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModelList() {
    final brand = _activeBrand;
    if (brand == null) return const SizedBox.shrink();
    final models = _filteredModels;
    if (models.isEmpty) {
      return _buildEmptyState('No models found for $brand.');
    }

    return AnimatedSwitcher(
      key: ValueKey<String>('model-browser-$brand'),
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, _sortAscending ? -0.08 : 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey<String>('${widget.activeCatalog.name}-$_sortVersion'),
        child: _ZoomListView(
          listKey: _modelListStorageKey,
          itemCount: models.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final car = models[index];
            final isSelected = widget.selectedCar == car;
            return _AnimatedListItem(
              index: index,
              child: _browserTile(
                leading: _BrandLogoWidget(
                  brand: car.brand,
                  size: 36,
                  isDarkMode: widget.isDarkMode,
                ),
                title: car.model,
                subtitle: '${car.driveType} • ${car.tireType}',
                highlighted: isSelected,
                trailing:
                    _PiClassBadge(pi: car.pi, isDarkMode: widget.isDarkMode),
                onTap: () => widget.onCarSelected(car),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Block(
      isDarkMode: widget.isDarkMode,
      panelBg: widget.panelBg,
      border: widget.border,
      title: 'Car Selection',
      icon: Icons.directions_car_rounded,
      accent: widget.accent,
      text: widget.text,
      expandChild: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BentoSegmentedBar(
            activeIndex:
                widget.activeCatalog == _DashboardCarCatalog.fh6 ? 1 : 0,
            accent: widget.accent,
            tabs: const <BentoTab>[
              BentoTab(
                icon: Icons.filter_5_rounded,
                label: 'Horizon 5',
                imageProvider: AssetImage('assets/images/fh5-hero.jpeg'),
              ),
              BentoTab(
                icon: Icons.filter_6_rounded,
                label: 'Horizon 6',
                imageProvider: AssetImage('assets/images/fh6-hero.jpg'),
              ),
            ],
            onTabChanged: (index) => widget.onCatalogChanged(
              index == 0 ? _DashboardCarCatalog.fh5 : _DashboardCarCatalog.fh6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              if (_showModelPage) ...<Widget>[
                _toolbarButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: _backToBrands,
                  tooltip: 'Back to brands',
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: widget.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search brand or model...',
                    hintStyle: TextStyle(color: widget.muted, fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: widget.muted, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: widget.accent),
                    ),
                  ),
                  onChanged: widget.onBrandQueryChanged,
                ),
              ),
              const SizedBox(width: 6),
              _toolbarButton(
                icon: _sortAscending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                onTap: () => setState(() {
                  _sortAscending = !_sortAscending;
                  _sortVersion++;
                }),
                tooltip: _sortAscending ? 'A → Z' : 'Z → A',
                active: true,
                sortVersion: _sortVersion,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_showModelPage) ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF181C24)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.border),
              ),
              child: Row(
                children: <Widget>[
                  _BrandLogoWidget(
                    brand: _activeBrand!,
                    size: 34,
                    isDarkMode: widget.isDarkMode,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _activeBrand!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: widget.text,
                      ),
                    ),
                  ),
                  Text(
                    '${_filteredModels.length} models',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final childKey = (child.key as ValueKey<String>?)?.value ?? '';
                final isIncoming = _goingToModel
                    ? childKey.startsWith('model-browser')
                    : childKey == 'brand-browser';
                final Offset begin = _goingToModel
                    ? (isIncoming
                        ? const Offset(1.0, 0.0)
                        : const Offset(-1.0, 0.0))
                    : (isIncoming
                        ? const Offset(-1.0, 0.0)
                        : const Offset(1.0, 0.0));
                return ClipRect(
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _showModelPage ? _buildModelList() : _buildBrandList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _TuneConfigBlock — Drive/Surface/Type/Gears
// ══════════════════════════════════════════════════════════════════

class _TuneConfigBlock extends StatelessWidget {
  const _TuneConfigBlock({
    required this.isDarkMode,
    required this.accent,
    required this.driveType,
    required this.surface,
    required this.tuneType,
    required this.gearCount,
    required this.metric,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
    required this.onDriveType,
    required this.onSurface,
    required this.onTuneType,
    required this.onGearCount,
    required this.onMetricChanged,
  });

  final bool isDarkMode;
  final Color accent;
  final String driveType;
  final String surface;
  final String tuneType;
  final int gearCount;
  final bool metric;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;
  final ValueChanged<String> onDriveType;
  final ValueChanged<String> onSurface;
  final ValueChanged<String> onTuneType;
  final ValueChanged<int> onGearCount;
  final ValueChanged<bool> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    return _Block(
      isDarkMode: isDarkMode,
      panelBg: panelBg,
      border: border,
      title: 'Tune Config',
      icon: Icons.settings_rounded,
      accent: accent,
      text: text,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      headerSpacing: 5,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const gap = 3.0;
          final useWideRow = constraints.maxWidth >= 580;
          final useTwoColumns = constraints.maxWidth >= 420;

          Widget section({required Widget child}) => Padding(
                padding: EdgeInsets.zero,
                child: child,
              );

          Widget gearsCell() {
            final dropdown = Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0x30FFFFFF)
                      : const Color(0x18000000),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: gearCount.clamp(2, 10),
                  isDense: true,
                  dropdownColor:
                      isDarkMode ? const Color(0xFF1E2232) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                  iconEnabledColor: accent,
                  iconSize: 16,
                  items: List.generate(9, (i) => i + 2)
                      .map(
                        (g) => DropdownMenuItem<int>(
                          value: g,
                          child: Text('$g'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onGearCount(v);
                  },
                ),
              ),
            );

            return LayoutBuilder(
              builder: (context, cellConstraints) {
                final compact = cellConstraints.maxWidth < 170;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.speed_rounded, size: 11, color: muted),
                          const SizedBox(width: 4),
                          Text(
                            'Gears',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: dropdown,
                      ),
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    Icon(Icons.speed_rounded, size: 11, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      'Gears',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    const Spacer(),
                    dropdown,
                  ],
                );
              },
            );
          }

          final driveSection = section(
            child: _ChipGroup(
              label: 'Drive',
              icon: Icons.settings_input_component_rounded,
              options: const <String>['RWD', 'AWD', 'FWD'],
              selected: driveType,
              accent: accent,
              border: border,
              text: text,
              muted: muted,
              onSelected: onDriveType,
              dense: true,
            ),
          );
          final surfaceSection = section(
            child: _ChipGroup(
              label: 'Surface',
              icon: Icons.terrain_rounded,
              options: const <String>[
                'Street',
                'Dirt',
                'Cross Country',
                'Snow'
              ],
              selected: surface,
              accent: accent,
              border: border,
              text: text,
              muted: muted,
              onSelected: onSurface,
              dense: true,
            ),
          );
          final tuneTypeSection = section(
            child: _ChipGroup(
              label: 'Tune Type',
              icon: Icons.tune_rounded,
              options: const <String>['Race', 'Rally', 'Drift'],
              selected: tuneType,
              accent: accent,
              border: border,
              text: text,
              muted: muted,
              onSelected: onTuneType,
              dense: true,
            ),
          );
          final setupSection = section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                gearsCell(),
                const SizedBox(height: 2),
                _UnitToggle(
                  metric: metric,
                  accent: accent,
                  border: border,
                  text: text,
                  muted: muted,
                  onChanged: onMetricChanged,
                  compact: true,
                ),
              ],
            ),
          );

          if (useWideRow) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: driveSection),
                const SizedBox(width: gap),
                Expanded(child: surfaceSection),
                const SizedBox(width: gap),
                Expanded(child: tuneTypeSection),
                const SizedBox(width: gap),
                SizedBox(width: 152, child: setupSection),
              ],
            );
          }

          final sectionWidth = useTwoColumns
              ? (constraints.maxWidth - gap) / 2
              : constraints.maxWidth;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              SizedBox(width: sectionWidth, child: driveSection),
              SizedBox(width: sectionWidth, child: surfaceSection),
              SizedBox(width: sectionWidth, child: tuneTypeSection),
              SizedBox(width: sectionWidth, child: setupSection),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _PerformanceBlock — Numeric inputs + Power Band + Calculate
// ══════════════════════════════════════════════════════════════════

class _PerformanceBlock extends StatefulWidget {
  const _PerformanceBlock({
    required this.isDarkMode,
    required this.accent,
    required this.metric,
    required this.gearCount,
    required this.weightCtrl,
    required this.frontDistCtrl,
    required this.piCtrl,
    required this.torqueCtrl,
    required this.topSpeedCtrl,
    required this.fTireW,
    required this.fTireA,
    required this.fTireR,
    required this.rTireW,
    required this.rTireA,
    required this.rTireR,
    required this.redlineRpm,
    required this.maxTorqueRpm,
    required this.scaleMax,
    required this.defaultRedlineRpm,
    required this.defaultMaxTorqueRpm,
    required this.defaultScaleMax,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
    required this.selectedCar,
    required this.result,
    required this.onRedlineChanged,
    required this.onTorqueRpmChanged,
    required this.onScaleMaxChanged,
    required this.onGearCount,
    required this.showActions,
    required this.canSaveAction,
    required this.onCalculate,
    this.onSave,
    this.frozen = false,
  });

  final bool isDarkMode;
  final Color accent;
  final bool metric;
  final int gearCount;
  final TextEditingController weightCtrl;
  final TextEditingController frontDistCtrl;
  final TextEditingController piCtrl;
  final TextEditingController torqueCtrl;
  final TextEditingController topSpeedCtrl;
  final TextEditingController fTireW, fTireA, fTireR;
  final TextEditingController rTireW, rTireA, rTireR;
  final int redlineRpm;
  final int maxTorqueRpm;
  final int scaleMax;
  final int defaultRedlineRpm;
  final int defaultMaxTorqueRpm;
  final int defaultScaleMax;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;
  final CarSpec? selectedCar;
  final TuneCalcResult? result;
  final ValueChanged<int> onRedlineChanged;
  final ValueChanged<int> onTorqueRpmChanged;
  final ValueChanged<int> onScaleMaxChanged;
  final ValueChanged<int> onGearCount;
  final bool showActions;
  final bool canSaveAction;
  final VoidCallback onCalculate;
  final VoidCallback? onSave;
  final bool frozen;

  @override
  State<_PerformanceBlock> createState() => _PerformanceBlockState();
}

class _PerformanceBlockState extends State<_PerformanceBlock> {
  // ── helpers ──────────────────────────────────────────────────────
  String _piClass(TextEditingController ctrl) {
    final v = int.tryParse(ctrl.text) ?? 0;
    return _piClassLabel(v);
  }

  Color _piColor(TextEditingController ctrl) {
    return _piClassColor(_piClass(ctrl));
  }

  @override
  Widget build(BuildContext context) {
    final speedLabel = widget.metric ? 'Top Speed (km/h)' : 'Top Speed (mph)';
    final weightLabel = widget.metric ? 'Weight (kg)' : 'Weight (lb)';
    final piClass = _piClass(widget.piCtrl);
    final piColor = _piColor(widget.piCtrl);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.frozen ? 0.5 : 1.0,
      child: AbsorbPointer(
        absorbing: widget.frozen,
        child: _Block(
          isDarkMode: widget.isDarkMode,
          panelBg: widget.panelBg,
          border: widget.border,
          title: 'Performance Data',
          icon: Icons.speed_rounded,
          accent: widget.accent,
          text: widget.text,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final cols = constraints.maxWidth >= 900
                  ? 3
                  : (constraints.maxWidth >= 500 ? 2 : 1);
              final gap = 8.0;
              final itemWidth = cols > 1
                  ? (constraints.maxWidth - gap * (cols - 1)) / cols
                  : constraints.maxWidth;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    spacing: gap,
                    runSpacing: 6,
                    children: <Widget>[
                      SizedBox(
                        width: itemWidth,
                        child: _InputField(
                          controller: widget.weightCtrl,
                          label: weightLabel,
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                          accent: widget.accent,
                          numOnly: true,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _InputField(
                          controller: widget.frontDistCtrl,
                          label: 'F. Distribution (%)',
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                          accent: widget.accent,
                          numOnly: true,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _PiInputField(
                          controller: widget.piCtrl,
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                          accent: widget.accent,
                          piClass: piClass,
                          piColor: piColor,
                          isDarkMode: widget.isDarkMode,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _InputField(
                          controller: widget.torqueCtrl,
                          label: 'Max Torque (N·m)',
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                          accent: widget.accent,
                          numOnly: true,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _InputField(
                          controller: widget.topSpeedCtrl,
                          label: speedLabel,
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                          accent: widget.accent,
                          numOnly: true,
                        ),
                      ),
                      // Power Band → compact button that opens popup dialog
                      SizedBox(
                        width: itemWidth,
                        child: _PowerBandButton(
                          redlineRpm: widget.redlineRpm,
                          maxTorqueRpm: widget.maxTorqueRpm,
                          scaleMax: widget.scaleMax,
                          defaultRedlineRpm: widget.defaultRedlineRpm,
                          defaultMaxTorqueRpm: widget.defaultMaxTorqueRpm,
                          defaultScaleMax: widget.defaultScaleMax,
                          accent: widget.accent,
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                          panelBg: widget.panelBg,
                          isDarkMode: widget.isDarkMode,
                          onRedlineChanged: widget.onRedlineChanged,
                          onTorqueRpmChanged: widget.onTorqueRpmChanged,
                          onScaleMaxChanged: widget.onScaleMaxChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Front tire (Width / Aspect / R Rim) ───────────────
                  _TireSizeRow(
                    label: 'FRONT TIRE (Width / Aspect / R Rim)',
                    wCtrl: widget.fTireW,
                    aCtrl: widget.fTireA,
                    rCtrl: widget.fTireR,
                    border: widget.border,
                    text: widget.text,
                    muted: widget.muted,
                    accent: widget.accent,
                  ),
                  const SizedBox(height: 6),

                  // ── Rear tire (Width / Aspect / R Rim) ────────────────
                  _TireSizeRow(
                    label: 'REAR TIRE (Width / Aspect / R Rim)',
                    wCtrl: widget.rTireW,
                    aCtrl: widget.rTireA,
                    rCtrl: widget.rTireR,
                    border: widget.border,
                    text: widget.text,
                    muted: widget.muted,
                    accent: widget.accent,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: !widget.showActions
                        ? const SizedBox.shrink(
                            key: ValueKey<String>('performance-actions-hidden'),
                          )
                        : Padding(
                            key: const ValueKey<String>(
                                'performance-actions-visible'),
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth >= 520
                                      ? 286
                                      : constraints.maxWidth,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.isDarkMode
                                        ? const Color(0xCC10151E)
                                        : Colors.white.withAlpha(220),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: widget.border),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.black.withAlpha(
                                          widget.isDarkMode ? 46 : 18,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: _CalculateButton(
                                          enabled: widget.showActions,
                                          accent: widget.accent,
                                          border: widget.border,
                                          muted: widget.muted,
                                          text: widget.text,
                                          onTap: widget.onCalculate,
                                        ),
                                      ),
                                      if (widget.canSaveAction) ...<Widget>[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _HoverButton(
                                            key: const ValueKey<String>(
                                                'action-save'),
                                            enabled: true,
                                            selected: true,
                                            accent: const Color(0xFF2E7D32),
                                            border: widget.border,
                                            muted: widget.muted,
                                            onTap: widget.onSave,
                                            padding: const EdgeInsets.all(0),
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                Icon(
                                                  Icons.save_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'SAVE',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.1,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _CalculateButton — State-based calculate button
// States: disabled (no car) → enabled (car selected) → hover → pressed
// ══════════════════════════════════════════════════════════════════

class _CalculateButton extends StatefulWidget {
  const _CalculateButton({
    required this.enabled,
    required this.accent,
    required this.border,
    required this.muted,
    required this.text,
    this.onTap,
  });

  final bool enabled;
  final Color accent;
  final Color border;
  final Color muted;
  final Color text;
  final VoidCallback? onTap;

  @override
  State<_CalculateButton> createState() => _CalculateButtonState();
}

class _CalculateButtonState extends State<_CalculateButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final accent = widget.accent;

    // State-based colors
    Color bg;
    Color textColor;
    Color borderColor;
    double scale;

    if (!enabled) {
      // Disabled — muted, no interaction
      bg = widget.muted.withAlpha(18);
      textColor = widget.muted.withAlpha(120);
      borderColor = widget.border.withAlpha(60);
      scale = 1.0;
    } else if (_pressed) {
      // Pressed — deeper accent, slight scale down
      bg = Color.lerp(accent, Colors.black, 0.15)!;
      textColor = _onAccent(accent);
      borderColor = accent;
      scale = 0.97;
    } else if (_hovered) {
      // Hover — accent fill
      bg = accent;
      textColor = _onAccent(accent);
      borderColor = accent;
      scale = 1.0;
    } else {
      // Enabled, idle — outlined accent
      bg = accent.withAlpha(12);
      textColor = accent;
      borderColor = accent.withAlpha(100);
      scale = 1.0;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) setState(() => _hovered = true);
      },
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          if (enabled) setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (enabled) {
            setState(() => _pressed = false);
            widget.onTap?.call();
          }
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 42,
          transform: Matrix4.diagonal3Values(scale, scale, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            enabled ? 'CALCULATE' : 'SELECT A CAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _HoverButton — glassmorphic button with hover glow
// ══════════════════════════════════════════════════════════════════

class _HoverButton extends StatefulWidget {
  const _HoverButton({
    super.key,
    required this.enabled,
    required this.accent,
    required this.border,
    required this.muted,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 0),
    this.selected = false,
  });

  final bool enabled;
  final Color accent;
  final Color border;
  final Color muted;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    final isSelected = widget.selected && active;
    final baseMatte = active ? widget.accent : widget.border.withAlpha(68);
    final hoverMatte = widget.accent;
    final bg = _hovered && active ? hoverMatte : baseMatte;
    final borderColor = isSelected
        ? widget.accent
        : (_hovered && active ? widget.accent : Colors.transparent);
    final shadow = !active ? <BoxShadow>[] : const <BoxShadow>[];

    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) {
          if (!active) return;
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          if (!active) return;
          setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (!active) return;
          setState(() => _pressed = false);
        },
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 42,
          padding: widget.padding,
          transform: _pressed
              ? (Matrix4.identity()..scaleByDouble(0.97, 0.97, 1.0, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: shadow,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _PiInputField — PI number field with live PI class badge
// ══════════════════════════════════════════════════════════════════

class _PiInputField extends StatelessWidget {
  const _PiInputField({
    required this.controller,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.piClass,
    required this.piColor,
    required this.isDarkMode,
    this.onChanged,
  });

  final TextEditingController controller;
  final Color border, text, muted, accent;
  final String piClass;
  final Color piColor;
  final bool isDarkMode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(color: text, fontSize: 12),
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: 'Current PI',
              labelStyle: TextStyle(fontSize: 11, color: muted),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: accent),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 41,
          decoration: BoxDecoration(
            color: Color.alphaBlend(piColor.withAlpha(40),
                isDarkMode ? const Color(0xFF181C24) : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: piColor),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                piClass,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: piColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _TireSizeRow — Width / Aspect / R Rim row
// ══════════════════════════════════════════════════════════════════

class _TireSizeRow extends StatelessWidget {
  const _TireSizeRow({
    required this.label,
    required this.wCtrl,
    required this.aCtrl,
    required this.rCtrl,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
  });

  final String label;
  final TextEditingController wCtrl, aCtrl, rCtrl;
  final Color border, text, muted, accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: _TireField(
                  ctrl: wCtrl,
                  hint: 'Width',
                  border: border,
                  text: text,
                  muted: muted,
                  accent: accent),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('/',
                  style: TextStyle(
                      color: muted, fontSize: 16, fontWeight: FontWeight.w300)),
            ),
            Expanded(
              flex: 4,
              child: _TireField(
                  ctrl: aCtrl,
                  hint: 'Aspect',
                  border: border,
                  text: text,
                  muted: muted,
                  accent: accent),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('R',
                  style: TextStyle(
                      color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: 4,
              child: _TireField(
                  ctrl: rCtrl,
                  hint: 'Rim',
                  border: border,
                  text: text,
                  muted: muted,
                  accent: accent),
            ),
          ],
        ),
      ],
    );
  }
}

class _TireField extends StatelessWidget {
  const _TireField({
    required this.ctrl,
    required this.hint,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
  });
  final TextEditingController ctrl;
  final String hint;
  final Color border, text, muted, accent;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: text, fontSize: 11),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly
      ],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: muted, fontSize: 10),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _PowerBandButton — compact button that opens a PowerBand popup
// ══════════════════════════════════════════════════════════════════

class _PowerBandButton extends StatelessWidget {
  const _PowerBandButton({
    required this.redlineRpm,
    required this.maxTorqueRpm,
    required this.scaleMax,
    required this.defaultRedlineRpm,
    required this.defaultMaxTorqueRpm,
    required this.defaultScaleMax,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.panelBg,
    required this.isDarkMode,
    required this.onRedlineChanged,
    required this.onTorqueRpmChanged,
    required this.onScaleMaxChanged,
  });

  final int redlineRpm, maxTorqueRpm, scaleMax;
  final int defaultRedlineRpm, defaultMaxTorqueRpm, defaultScaleMax;
  final Color accent, border, text, muted, panelBg;
  final bool isDarkMode;
  final ValueChanged<int> onRedlineChanged;
  final ValueChanged<int> onTorqueRpmChanged;
  final ValueChanged<int> onScaleMaxChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showPowerBandDialog(context),
        child: Container(
          height: 41,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0x18FFFFFF) : const Color(0x14000000),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.show_chart_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                'Power Band',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const Spacer(),
              Text(
                '${redlineRpm}rpm',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: text,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded, size: 12, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  void _showPowerBandDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _PowerBandDialog(
          redlineRpm: redlineRpm,
          maxTorqueRpm: maxTorqueRpm,
          scaleMax: scaleMax,
          defaultRedlineRpm: defaultRedlineRpm,
          defaultMaxTorqueRpm: defaultMaxTorqueRpm,
          defaultScaleMax: defaultScaleMax,
          accent: accent,
          border: border,
          text: text,
          muted: muted,
          panelBg: panelBg,
          isDarkMode: isDarkMode,
          onRedlineChanged: onRedlineChanged,
          onTorqueRpmChanged: onTorqueRpmChanged,
          onScaleMaxChanged: onScaleMaxChanged,
        );
      },
    );
  }
}

class _PowerBandDialog extends StatefulWidget {
  const _PowerBandDialog({
    required this.redlineRpm,
    required this.maxTorqueRpm,
    required this.scaleMax,
    required this.defaultRedlineRpm,
    required this.defaultMaxTorqueRpm,
    required this.defaultScaleMax,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.panelBg,
    required this.isDarkMode,
    required this.onRedlineChanged,
    required this.onTorqueRpmChanged,
    required this.onScaleMaxChanged,
  });

  final int redlineRpm, maxTorqueRpm, scaleMax;
  final int defaultRedlineRpm, defaultMaxTorqueRpm, defaultScaleMax;
  final Color accent, border, text, muted, panelBg;
  final bool isDarkMode;
  final ValueChanged<int> onRedlineChanged;
  final ValueChanged<int> onTorqueRpmChanged;
  final ValueChanged<int> onScaleMaxChanged;

  @override
  State<_PowerBandDialog> createState() => _PowerBandDialogState();
}

class _PowerBandDialogState extends State<_PowerBandDialog> {
  late int _redline;
  late int _torqueRpm;
  late int _scaleMax;

  @override
  void initState() {
    super.initState();
    _redline = widget.redlineRpm;
    _torqueRpm = widget.maxTorqueRpm;
    _scaleMax = widget.scaleMax;
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isDarkMode ? const Color(0xFF1A1E28) : const Color(0xFFF4F5F7);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 520),
            decoration: BoxDecoration(
              color: bg.withAlpha(widget.isDarkMode ? 180 : 190),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isDarkMode
                    ? Colors.white.withAlpha(30)
                    : Colors.black.withAlpha(15),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withAlpha(widget.isDarkMode ? 40 : 15),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.show_chart_rounded,
                          size: 18, color: widget.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Power Band Editor',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: widget.text,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: widget.muted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    color: widget.isDarkMode
                        ? Colors.white.withAlpha(12)
                        : Colors.black.withAlpha(8)),
                // ── Chart ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: SizedBox(
                    height: 200,
                    child: CustomPaint(
                      size: const Size(double.infinity, 200),
                      painter: _PowerBandPainter(
                        redlineRpm: _redline,
                        maxTorqueRpm: _torqueRpm,
                        scaleMax: _scaleMax,
                        accent: widget.accent,
                        isDark: widget.isDarkMode,
                      ),
                    ),
                  ),
                ),
                // ── Sliders ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PopupRpmSlider(
                    label: 'Redline RPM',
                    value: _redline.clamp(4000, _scaleMax),
                    min: 4000,
                    max: _scaleMax,
                    accent: widget.accent,
                    text: widget.text,
                    muted: widget.muted,
                    onChanged: (v) {
                      setState(() => _redline = v);
                      widget.onRedlineChanged(v);
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _PopupRpmSlider(
                    label: 'Peak Torque RPM',
                    value: _torqueRpm.clamp(2000, _scaleMax),
                    min: 2000,
                    max: _scaleMax,
                    accent: widget.accent,
                    text: widget.text,
                    muted: widget.muted,
                    onChanged: (v) {
                      setState(() => _torqueRpm = v);
                      widget.onTorqueRpmChanged(v);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // ── Scale Max presets ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: <Widget>[
                      Text('Scale Max:',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.muted)),
                      const SizedBox(width: 8),
                      for (final preset in <int>[8000, 9000, 10000, 12000])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _ScalePresetChip(
                            value: preset,
                            isActive: _scaleMax == preset,
                            accent: widget.accent,
                            muted: widget.muted,
                            isDark: widget.isDarkMode,
                            onTap: () {
                              setState(() {
                                _scaleMax = preset;
                                _redline = _redline.clamp(4000, preset);
                                _torqueRpm = _torqueRpm.clamp(2000, preset);
                              });
                              widget.onScaleMaxChanged(preset);
                              widget.onRedlineChanged(_redline);
                              widget.onTorqueRpmChanged(_torqueRpm);
                            },
                          ),
                        ),
                    ],
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

class _PopupRpmSlider extends StatelessWidget {
  const _PopupRpmSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.text,
    required this.muted,
    required this.onChanged,
  });

  final String label;
  final int value, min, max;
  final Color accent, text, muted;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: muted)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: accent,
              inactiveTrackColor: accent.withAlpha(30),
              thumbColor: accent,
              overlayColor: accent.withAlpha(20),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: ((max - min) / 100).round(),
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScalePresetChip extends StatelessWidget {
  const _ScalePresetChip({
    required this.value,
    required this.isActive,
    required this.accent,
    required this.muted,
    required this.isDark,
    required this.onTap,
  });

  final int value;
  final bool isActive;
  final Color accent, muted;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? accent.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isActive
                  ? accent
                  : (isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(10))),
        ),
        child: Text(
          '${(value / 1000).toStringAsFixed(0)}k',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isActive ? accent : muted,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _PowerBandWidget — collapsible power band editor with chart
// ══════════════════════════════════════════════════════════════════

class _PowerBandWidget extends StatefulWidget {
  const _PowerBandWidget({
    required this.redlineRpm,
    required this.maxTorqueRpm,
    required this.scaleMax,
    required this.defaultRedlineRpm,
    required this.defaultMaxTorqueRpm,
    required this.defaultScaleMax,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.panelBg,
    required this.isDarkMode,
    required this.expanded,
    required this.onToggle,
    required this.onRedlineChanged,
    required this.onTorqueRpmChanged,
    required this.onScaleMaxChanged,
  });

  final int redlineRpm, maxTorqueRpm, scaleMax;
  final int defaultRedlineRpm, defaultMaxTorqueRpm, defaultScaleMax;
  final Color accent, border, text, muted, panelBg;
  final bool isDarkMode, expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onRedlineChanged;
  final ValueChanged<int> onTorqueRpmChanged;
  final ValueChanged<int> onScaleMaxChanged;

  @override
  State<_PowerBandWidget> createState() => _PowerBandWidgetState();
}

class _PowerBandWidgetState extends State<_PowerBandWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.expanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _PowerBandWidget old) {
    super.didUpdateWidget(old);
    if (widget.expanded != old.expanded) {
      if (widget.expanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        '${(widget.maxTorqueRpm / 1000).toStringAsFixed(1)}k – ${(widget.redlineRpm / 1000).toStringAsFixed(1)}k RPM';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? const Color(0x18FFFFFF)
            : const Color(0x14000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.expanded ? widget.accent : widget.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header tap-to-expand
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: <Widget>[
                  Icon(Icons.graphic_eq_rounded,
                      size: 14, color: widget.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('POWER BAND',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: widget.muted,
                                letterSpacing: 0.6)),
                        Text(
                          summary,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.text),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: widget.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content with SizeTransition reveal
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: _expandAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Animated chart with smooth RPM transitions
                    SizedBox(
                      height: 110,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: widget.redlineRpm.toDouble(),
                          end: widget.redlineRpm.toDouble(),
                        ),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        builder: (context, animRedline, _) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: widget.maxTorqueRpm.toDouble(),
                              end: widget.maxTorqueRpm.toDouble(),
                            ),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, animTorque, _) {
                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: widget.scaleMax.toDouble(),
                                  end: widget.scaleMax.toDouble(),
                                ),
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                builder: (context, animScale, _) {
                                  return CustomPaint(
                                    painter: _PowerBandPainter(
                                      redlineRpm: animRedline.round(),
                                      maxTorqueRpm: animTorque.round(),
                                      scaleMax: animScale.round(),
                                      accent: widget.accent,
                                      isDark: widget.isDarkMode,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scale max preset buttons — larger & clearer
                    Row(
                      children: <Widget>[
                        Icon(Icons.straighten_rounded,
                            size: 12, color: widget.muted),
                        const SizedBox(width: 6),
                        Text(
                          'Scale Max',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.muted),
                        ),
                        const Spacer(),
                        ...<int>[8000, 10000, 12000].map(
                          (preset) => GestureDetector(
                            onTap: () {
                              widget.onScaleMaxChanged(preset);
                              if (widget.redlineRpm > preset) {
                                widget.onRedlineChanged((preset * 0.9).toInt());
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.scaleMax == preset
                                    ? widget.accent
                                    : widget.isDarkMode
                                        ? const Color(0xFF1C2028)
                                        : const Color(0xFFF4F4F6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: widget.scaleMax == preset
                                        ? widget.accent
                                        : widget.border),
                              ),
                              child: Text(
                                '${preset ~/ 1000}k',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: widget.scaleMax == preset
                                        ? _onAccent(widget.accent)
                                        : widget.muted),
                              ),
                            ),
                          ),
                        ),
                        // Custom scale max button
                        GestureDetector(
                          onTap: () {
                            final ctrl = TextEditingController(
                                text: '${(widget.scaleMax / 1000).round()}');
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Custom Scale Max'),
                                content: TextField(
                                  controller: ctrl,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'RPM (thousands)',
                                    suffixText: 'k',
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      final v = int.tryParse(ctrl.text);
                                      if (v != null && v >= 4) {
                                        final rpm =
                                            (v * 1000).clamp(6000, 30000);
                                        widget.onScaleMaxChanged(rpm);
                                        if (widget.redlineRpm > rpm) {
                                          widget.onRedlineChanged(
                                              (rpm * 0.9).toInt());
                                        }
                                      }
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Set'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: ![8000, 10000, 12000]
                                      .contains(widget.scaleMax)
                                  ? widget.accent
                                  : widget.isDarkMode
                                      ? const Color(0xFF1C2028)
                                      : const Color(0xFFF4F4F6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: ![8000, 10000, 12000]
                                          .contains(widget.scaleMax)
                                      ? widget.accent
                                      : widget.border),
                            ),
                            child: Text(
                              ![8000, 10000, 12000].contains(widget.scaleMax)
                                  ? '${(widget.scaleMax / 1000).round()}k'
                                  : 'Custom',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: ![8000, 10000, 12000]
                                          .contains(widget.scaleMax)
                                      ? _onAccent(widget.accent)
                                      : widget.muted),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Redline
                    _RpmSlider(
                      label: 'Redline RPM',
                      value: widget.redlineRpm,
                      min: 4000,
                      max: widget.scaleMax,
                      step: 100,
                      accent: const Color(0xFFFF2B8B),
                      text: widget.text,
                      muted: widget.muted,
                      border: widget.border,
                      onChanged: (v) {
                        widget.onRedlineChanged(v);
                        if (widget.maxTorqueRpm > v) {
                          widget.onTorqueRpmChanged((v * 0.75).toInt());
                        }
                      },
                    ),
                    const SizedBox(height: 6),

                    // Max Torque RPM
                    _RpmSlider(
                      label: 'Peak Torque RPM',
                      value: widget.maxTorqueRpm.clamp(1000, widget.redlineRpm),
                      min: 1000,
                      max: widget.redlineRpm,
                      step: 100,
                      accent: const Color(0xFFFFB020),
                      text: widget.text,
                      muted: widget.muted,
                      border: widget.border,
                      onChanged: widget.onTorqueRpmChanged,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RpmSlider extends StatelessWidget {
  const _RpmSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.accent,
    required this.text,
    required this.muted,
    required this.border,
    required this.onChanged,
  });

  final String label;
  final int value, min, max, step;
  final Color accent, text, muted, border;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = value >= 1000
        ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
        : '$value';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: muted)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent),
              ),
              child: Text(
                display,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accent,
            inactiveTrackColor: border.withAlpha(120),
            thumbColor: accent,
            overlayColor: accent.withAlpha(30),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max > min ? max.toDouble() : (min + step).toDouble(),
            divisions: max > min ? ((max - min) ~/ step).clamp(1, 400) : 1,
            onChanged: (v) =>
                onChanged(((v / step).round() * step).clamp(min, max)),
          ),
        ),
      ],
    );
  }
}

// ── Power band chart painter ────────────────────────────────────────
class _PowerBandPainter extends CustomPainter {
  const _PowerBandPainter({
    required this.redlineRpm,
    required this.maxTorqueRpm,
    required this.scaleMax,
    required this.accent,
    required this.isDark,
  });

  final int redlineRpm, maxTorqueRpm, scaleMax;
  final Color accent;
  final bool isDark;

  /// Builds a smooth Catmull-Rom spline through [pts].
  static Path _catmullRomPath(List<Offset> pts) {
    if (pts.isEmpty) return Path();
    if (pts.length < 2) return Path()..moveTo(pts.first.dx, pts.first.dy);
    final ext = [pts.first, ...pts, pts.last];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = ext[i];
      final p1 = ext[i + 1];
      final p2 = ext[i + 2];
      final p3 = ext[i + 3];
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final safe = math.max(10000, scaleMax);

    // Clip canvas so curves never render outside chart bounds
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h));

    // Draw background grid
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF222630) : const Color(0xFFE4E6EB)
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      canvas.drawLine(Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }
    for (var i = 1; i <= 8; i++) {
      canvas.drawLine(Offset(w * i / 8, 0), Offset(w * i / 8, h), gridPaint);
    }

    double xOf(int rpm) => (rpm / safe).clamp(0.0, 1.0) * w;
    final torX = xOf(maxTorqueRpm);
    final redX = xOf(redlineRpm);
    final safeX = xOf(safe);

    // Power curve: smooth rise from idle to redline, sharp limiter drop.
    // Points distributed to avoid Catmull-Rom overshoot near peak.
    final powerPts = <Offset>[
      Offset(0, h * 0.96),
      Offset(torX * 0.32, h * 0.76),
      Offset(torX * 0.66, h * 0.48),
      Offset(torX, h * 0.28),
      Offset(torX + (redX - torX) * 0.55, h * 0.13),
      Offset(redX, h * 0.10),
      Offset(redX + (safeX - redX) * 0.28, h * 0.34),
      Offset(redX + (safeX - redX) * 0.62, h * 0.64),
      Offset(safeX, h * 0.86),
    ];

    // Torque curve: peaks early, gentle plateau, gradual decay after redline.
    final torquePts = <Offset>[
      Offset(0, h * 0.76),
      Offset(torX * 0.22, h * 0.46),
      Offset(torX * 0.54, h * 0.20),
      Offset(torX, h * 0.12),
      Offset(torX + (redX - torX) * 0.48, h * 0.16),
      Offset(redX, h * 0.30),
      Offset(redX + (safeX - redX) * 0.46, h * 0.54),
      Offset(safeX, h * 0.68),
    ];

    // Fill under power curve
    final fillPath = _catmullRomPath(powerPts);
    fillPath.lineTo(safeX, h);
    fillPath.lineTo(0, h);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[accent.withAlpha(55), accent.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Torque curve (pink)
    canvas.drawPath(
      _catmullRomPath(torquePts),
      Paint()
        ..color = const Color(0xFFFF2B8B)
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Power curve (accent)
    canvas.drawPath(
      _catmullRomPath(powerPts),
      Paint()
        ..color = accent
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Redline vertical marker
    canvas.drawLine(
      Offset(redX, 0),
      Offset(redX, h),
      Paint()
        ..color = const Color(0xFFFF2B8B).withAlpha(140)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PowerBandPainter old) =>
      old.redlineRpm != redlineRpm ||
      old.maxTorqueRpm != maxTorqueRpm ||
      old.scaleMax != scaleMax ||
      old.accent != accent ||
      old.isDark != isDark;
}

// ══════════════════════════════════════════════════════════════════
// _ResultCardsRow — Tune result cards below the 3 blocks
// ══════════════════════════════════════════════════════════════════

BoxDecoration _resultCardDecoration({
  required bool isDarkMode,
  required Color border,
}) {
  return BoxDecoration(
    color: isDarkMode ? const Color(0xFF1A1E26) : const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(20),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: isDarkMode
            ? const Color(0xFF000000).withAlpha(30)
            : const Color(0xFF000000).withAlpha(8),
        blurRadius: 24,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════
// _TuneResultPopup — Glassmorphic popup showing calculated tune result
// ══════════════════════════════════════════════════════════════════

class _TuneResultPopup extends StatefulWidget {
  const _TuneResultPopup({
    required this.result,
    required this.accent,
    required this.isDarkMode,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
    this.onClose,
    this.onActivateOverlay,
    this.onSave,
    this.onExport,
  });

  final TuneCalcResult result;
  final Color accent;
  final bool isDarkMode;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;
  final VoidCallback? onClose;
  final VoidCallback? onActivateOverlay;
  final VoidCallback? onSave;
  final Future<void> Function()? onExport;

  @override
  State<_TuneResultPopup> createState() => _TuneResultPopupState();
}

class _TuneResultPopupState extends State<_TuneResultPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _closeWithAnimation() async {
    await _animCtrl.reverse();
    if (!mounted) return;
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final screenSize = MediaQuery.of(context).size;
    final maxW = math.min(960.0, screenSize.width * 0.9);
    final maxH = math.min(720.0, screenSize.height * 0.85);

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: child,
          ),
        );
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                width: maxW,
                constraints: BoxConstraints(maxHeight: maxH),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0D1117).withAlpha(220)
                      : Colors.white.withAlpha(220),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(20)
                        : Colors.black.withAlpha(10),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 80 : 30),
                      blurRadius: 48,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 18, 14),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.auto_awesome_rounded,
                              color: widget.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tune Result',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: widget.text,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (widget.result.subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                widget.result.subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.muted,
                                ),
                              ),
                            ),
                          if (widget.onActivateOverlay != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PopupIconButton(
                                icon: Icons.picture_in_picture_alt_rounded,
                                accent: widget.accent,
                                isDark: isDark,
                                onTap: widget.onActivateOverlay!,
                                tooltip: 'Overlay',
                              ),
                            ),
                          if (widget.onExport != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PopupIconButton(
                                icon: Icons.ios_share_rounded,
                                accent: widget.accent,
                                isDark: isDark,
                                onTap: () {
                                  widget.onExport!();
                                },
                                tooltip: 'Export tune',
                              ),
                            ),
                          if (widget.onSave != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _PopupIconButton(
                                icon: Icons.save_rounded,
                                accent: const Color(0xFF22C55E),
                                isDark: isDark,
                                onTap: widget.onSave!,
                                tooltip: 'Save to Garage',
                              ),
                            ),
                          _PopupCloseButton(
                            onTap: _closeWithAnimation,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(6),
                    ),
                    // Content — scrollable result cards
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _ResultCardsRow(
                          result: widget.result,
                          accent: widget.accent,
                          isDarkMode: widget.isDarkMode,
                          panelBg: widget.panelBg,
                          border: widget.border,
                          text: widget.text,
                          muted: widget.muted,
                        ),
                      ),
                    ),
                    if (widget.onSave != null || widget.onExport != null) ...[
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(6),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              if (widget.onExport != null)
                                OutlinedButton.icon(
                                  onPressed: () {
                                    widget.onExport!();
                                  },
                                  icon: const Icon(Icons.ios_share_rounded),
                                  label: const Text('EXPORT'),
                                ),
                              if (widget.onSave != null)
                                FilledButton.icon(
                                  onPressed: widget.onSave,
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text('SAVE TO GARAGE'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _CarHeroLabel — brand/model/PI overlay for hero background
// ══════════════════════════════════════════════════════════════════

// ── Hero car image with fade-in ──
class _HeroCarImage extends StatefulWidget {
  const _HeroCarImage({super.key, required this.url});
  final String url;

  @override
  State<_HeroCarImage> createState() => _HeroCarImageState();
}

class _HeroCarImageState extends State<_HeroCarImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _HeroCarImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _hasError = false;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || widget.url.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        child: Image.network(
          widget.url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: 1920,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            final totalBytes = loadingProgress.expectedTotalBytes;
            final progress = totalBytes == null
                ? null
                : loadingProgress.cumulativeBytesLoaded / totalBytes;
            return Center(
              child: Container(
                width: 196,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.black.withAlpha(120)
                      : Colors.white.withAlpha(210),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(70),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        value: progress,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Loading preview...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasError = true);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _CarHeroLabel extends StatelessWidget {
  const _CarHeroLabel({
    required this.car,
    required this.pi,
    required this.accent,
    required this.text,
    required this.muted,
    required this.isDark,
    this.weightText,
    this.frontDistText,
    this.torqueText,
    this.topSpeedText,
    this.driveType,
    this.metric = true,
    this.showCompactSpecs = false,
  });

  final CarSpec car;
  final int? pi;
  final Color accent, text, muted;
  final bool isDark;
  final String? weightText, frontDistText, torqueText, topSpeedText, driveType;
  final bool metric;
  final bool showCompactSpecs;

  @override
  Widget build(BuildContext context) {
    final piLabel = pi != null ? _piClassLabelFromValue(pi!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Brand row with logo
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _BrandLogoWidget(
              brand: car.brand,
              size: 36,
              isDarkMode: isDark,
            ),
            const SizedBox(width: 10),
            Text(
              car.brand.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: muted,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Model + PI badge
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                car.model,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: text,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ),
            if (piLabel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(isDark ? 40 : 30),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withAlpha(60)),
                ),
                child: Text(
                  '$piLabel  $pi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        // Compact specs row
        if (showCompactSpecs) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              if (driveType != null && driveType!.isNotEmpty)
                _CompactSpecChip(
                  icon: Icons.directions_car_rounded,
                  label: driveType!,
                  accent: accent,
                  text: text,
                  isDark: isDark,
                ),
              if (weightText != null && weightText!.isNotEmpty)
                _CompactSpecChip(
                  icon: Icons.fitness_center_rounded,
                  label: '$weightText ${metric ? 'kg' : 'lb'}',
                  accent: accent,
                  text: text,
                  isDark: isDark,
                ),
              if (torqueText != null && torqueText!.isNotEmpty)
                _CompactSpecChip(
                  icon: Icons.speed_rounded,
                  label: '$torqueText Nm',
                  accent: const Color(0xFFFF7043),
                  text: text,
                  isDark: isDark,
                ),
              if (topSpeedText != null && topSpeedText!.isNotEmpty)
                _CompactSpecChip(
                  icon: Icons.rocket_launch_rounded,
                  label: '$topSpeedText ${metric ? 'km/h' : 'mph'}',
                  accent: const Color(0xFF66BB6A),
                  text: text,
                  isDark: isDark,
                ),
              if (frontDistText != null && frontDistText!.isNotEmpty)
                _CompactSpecChip(
                  icon: Icons.balance_rounded,
                  label: '$frontDistText%',
                  accent: const Color(0xFF42A5F5),
                  text: text,
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _piClassLabelFromValue(int pi) {
    if (pi >= 999) return 'X';
    if (pi >= 901) return 'S2';
    if (pi >= 801) return 'S1';
    if (pi >= 701) return 'A';
    if (pi >= 601) return 'B';
    if (pi >= 501) return 'C';
    return 'D';
  }
}

class _CompactSpecChip extends StatefulWidget {
  const _CompactSpecChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.text,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color accent, text;
  final bool isDark;

  @override
  State<_CompactSpecChip> createState() => _CompactSpecChipState();
}

class _CompactSpecChipState extends State<_CompactSpecChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _CompactSpecChip old) {
    super.didUpdateWidget(old);
    if (old.label != widget.label || old.icon != widget.icon) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: AnimatedBuilder(
        animation: _progressAnim,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: _progressAnim.value,
                        strokeWidth: 3,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            (widget.isDark ? Colors.white : Colors.black)
                                .withAlpha(widget.isDark ? 20 : 14),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(widget.accent),
                      ),
                    ),
                    Icon(widget.icon, size: 16, color: widget.accent),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.text.withAlpha(200),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PopupCloseButton extends StatefulWidget {
  const _PopupCloseButton({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  State<_PopupCloseButton> createState() => _PopupCloseButtonState();
}

class _PopupCloseButtonState extends State<_PopupCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered
                ? (isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ),
      ),
    );
  }
}

class _PopupIconButton extends StatefulWidget {
  const _PopupIconButton({
    required this.icon,
    required this.accent,
    required this.isDark,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  final String tooltip;

  @override
  State<_PopupIconButton> createState() => _PopupIconButtonState();
}

class _PopupIconButtonState extends State<_PopupIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  _hovered ? widget.accent.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: widget.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCardsRow extends StatelessWidget {
  const _ResultCardsRow({
    required this.result,
    required this.accent,
    required this.isDarkMode,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
  });

  final TuneCalcResult result;
  final Color accent;
  final bool isDarkMode;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;

  TuneCalcCard? _findCard(String token) {
    final normalized = _normalizeCardKey(token);
    for (final card in result.cards) {
      final key = _normalizeCardKey(card.title);
      if (key.contains(normalized) || normalized.contains(key)) {
        return card;
      }
    }
    return null;
  }

  static String _normalizeCardKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final pressureCard = _findCard('pressure');
    final camberCard = _findCard('camber');
    final gridCards = <TuneCalcCard?>[
      _findCard('toe'),
      _findCard('caster'),
      _findCard('antirollbars'),
      _findCard('springs'),
      _findCard('rideheight'),
      _findCard('rebound'),
      _findCard('bump'),
      _findCard('aerodownforce'),
      _findCard('braking'),
      _findCard('frontdifferential'),
      _findCard('reardifferential'),
      _findCard('center'),
    ].whereType<TuneCalcCard>().toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 960;
        final leadCards = <TuneCalcCard>[
          if (pressureCard != null) pressureCard,
          if (camberCard != null) camberCard,
        ];

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final card in leadCards) ...<Widget>[
                _ResultCard(
                  card: card,
                  accent: accent,
                  isDarkMode: isDarkMode,
                  panelBg: panelBg,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                const SizedBox(height: 12),
              ],
              _GearingResultCard(
                gearing: result.gearing,
                accent: accent,
                isDarkMode: isDarkMode,
                panelBg: panelBg,
                border: border,
                text: text,
                muted: muted,
              ),
              if (gridCards.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _ResultCardGrid(
                  cards: gridCards,
                  accent: accent,
                  isDarkMode: isDarkMode,
                  panelBg: panelBg,
                  border: border,
                  text: text,
                  muted: muted,
                ),
              ],
            ],
          );
        }

        final leftColumnWidth =
            math.min(292.0, math.max(244.0, constraints.maxWidth * 0.27));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: leftColumnWidth,
                    child: Column(
                      children: <Widget>[
                        for (var index = 0;
                            index < leadCards.length;
                            index++) ...<Widget>[
                          _ResultCard(
                            card: leadCards[index],
                            accent: accent,
                            isDarkMode: isDarkMode,
                            panelBg: panelBg,
                            border: border,
                            text: text,
                            muted: muted,
                          ),
                          if (index != leadCards.length - 1)
                            const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GearingResultCard(
                      gearing: result.gearing,
                      accent: accent,
                      isDarkMode: isDarkMode,
                      panelBg: panelBg,
                      border: border,
                      text: text,
                      muted: muted,
                      stretchToFill: true,
                    ),
                  ),
                ],
              ),
            ),
            if (gridCards.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _ResultCardGrid(
                cards: gridCards,
                accent: accent,
                isDarkMode: isDarkMode,
                panelBg: panelBg,
                border: border,
                text: text,
                muted: muted,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ResultCardGrid extends StatelessWidget {
  const _ResultCardGrid({
    required this.cards,
    required this.accent,
    required this.isDarkMode,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
  });

  final List<TuneCalcCard> cards;
  final Color accent;
  final bool isDarkMode;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 680
                ? 2
                : 1;
        final itemWidth =
            ((constraints.maxWidth - ((columns - 1) * spacing)) / columns)
                .clamp(0, double.infinity)
                .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _ResultCard(
                    card: card,
                    accent: accent,
                    isDarkMode: isDarkMode,
                    panelBg: panelBg,
                    border: border,
                    text: text,
                    muted: muted,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _GearingResultCard extends StatelessWidget {
  const _GearingResultCard({
    required this.gearing,
    required this.accent,
    required this.isDarkMode,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
    this.stretchToFill = false,
  });

  final TuneCalcGearingData gearing;
  final Color accent;
  final bool isDarkMode;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;
  final bool stretchToFill;

  @override
  Widget build(BuildContext context) {
    final ratios = gearing.ratios;
    final ratioValues = ratios.map((ratio) => ratio.ratio).toList();
    final maxRatio =
        ratioValues.isEmpty ? gearing.finalDrive : ratioValues.reduce(math.max);
    final minRatio = ratioValues.isEmpty ? 0.0 : ratioValues.reduce(math.min);
    final ratioRows = <List<TuneCalcGearRatio>>[
      for (var index = 0; index < ratios.length; index += 2)
        ratios.sublist(index, math.min(index + 2, ratios.length)),
    ];

    return Container(
      height: stretchToFill ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: _resultCardDecoration(
        isDarkMode: isDarkMode,
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Gearing',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      accent.withAlpha(34),
                      isDarkMode
                          ? const Color(0xFF181C24)
                          : const Color(0xFFFFFFFF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.tune_rounded, size: 16, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GearingBarRow(
            label: 'Final',
            value: gearing.finalDrive,
            accent: accent,
            text: text,
            muted: muted,
            trackColor: border.withAlpha(120),
            progress: ((gearing.finalDrive - 2.2) / (5.8 - 2.2))
                .clamp(0.0, 1.0)
                .toDouble(),
          ),
          if (ratios.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            if (stretchToFill)
              Expanded(
                child: _buildRatioRows(ratioRows, maxRatio, minRatio),
              )
            else
              _buildRatioRows(ratioRows, maxRatio, minRatio),
          ],
        ],
      ),
    );
  }

  Widget _buildRatioRows(
    List<List<TuneCalcGearRatio>> ratioRows,
    double maxRatio,
    double minRatio,
  ) {
    return Column(
      mainAxisAlignment: stretchToFill
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      children: ratioRows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var index = 0; index < row.length; index++) ...<Widget>[
                    Expanded(
                      child: _GearingBarRow(
                        label: 'G${row[index].gear}',
                        value: row[index].ratio,
                        accent: accent,
                        text: text,
                        muted: muted,
                        trackColor: border.withAlpha(120),
                        progress: maxRatio <= minRatio
                            ? 0
                            : ((row[index].ratio - minRatio) /
                                    (maxRatio - minRatio))
                                .clamp(0.0, 1.0)
                                .toDouble(),
                      ),
                    ),
                    if (index != row.length - 1) const SizedBox(width: 12),
                  ],
                  if (row.length == 1) const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _GearingBarRow extends StatelessWidget {
  const _GearingBarRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.text,
    required this.muted,
    required this.trackColor,
    required this.progress,
  });

  final String label;
  final double value;
  final Color accent;
  final Color text;
  final Color muted;
  final Color trackColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.card,
    required this.accent,
    required this.isDarkMode,
    required this.panelBg,
    required this.border,
    required this.text,
    required this.muted,
  });

  final TuneCalcCard card;
  final Color accent;
  final bool isDarkMode;
  final Color panelBg;
  final Color border;
  final Color text;
  final Color muted;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  late List<double> _values;

  @override
  void initState() {
    super.initState();
    _values = widget.card.sliders.map((s) => s.value).toList();
  }

  @override
  void didUpdateWidget(_ResultCard old) {
    super.didUpdateWidget(old);
    if (old.card != widget.card) {
      _values = widget.card.sliders.map((s) => s.value).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sliders = widget.card.sliders;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _resultCardDecoration(
        isDarkMode: widget.isDarkMode,
        border: widget.border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.card.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.text,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _values = widget.card.sliders.map((s) => s.value).toList();
                }),
                child: Tooltip(
                  message: 'Reset to calculated',
                  child: Icon(Icons.refresh_rounded,
                      size: 13, color: widget.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(
              sliders.length,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SliderRow(
                      label: sliders[i].side.isEmpty
                          ? widget.card.title
                          : sliders[i].side,
                      value: _values.length > i ? _values[i] : sliders[i].value,
                      min: sliders[i].min,
                      max: sliders[i].max,
                      step: sliders[i].step,
                      accent: widget.accent,
                      border: widget.border,
                      text: widget.text,
                      muted: widget.muted,
                      decimals: sliders[i].decimals,
                      suffix: sliders[i].suffix ?? '',
                      labels: sliders[i].labels,
                      onChanged: (v) => setState(() => _values[i] = v),
                    ),
                  )),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.decimals,
    required this.suffix,
    this.step = 0.1,
    this.labels,
    this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final int decimals;
  final String suffix;
  final List<String>? labels;
  final ValueChanged<double>? onChanged;

  String get _displayValue {
    if (labels != null && labels!.isNotEmpty) {
      final idx = value.round().clamp(0, labels!.length - 1);
      return labels![idx];
    }
    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final safeMax = max > min ? max : min + (step > 0 ? step : 1);
    final divisions =
        step > 0 ? ((safeMax - min) / step).round().clamp(1, 500) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: muted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Text(
              _displayValue,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: text),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accent,
            inactiveTrackColor: border.withAlpha(80),
            thumbColor: accent,
            overlayColor: accent.withAlpha(30),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: value.clamp(min, safeMax),
            min: min,
            max: safeMax,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _DashboardGlassCard extends StatelessWidget {
  const _DashboardGlassCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.child,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final String? subtitle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BentoGlassContainer(
        borderRadius: 20,
        padding: EdgeInsets.all(compact ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: compact ? 14 : 15, color: accent),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
              SizedBox(height: compact ? 4 : 6),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  height: 1.35,
                  color: muted,
                ),
              ),
            ],
            SizedBox(height: compact ? 8 : 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DashboardInfoPill extends StatelessWidget {
  const _DashboardInfoPill({
    required this.label,
    required this.border,
    required this.text,
    required this.muted,
    this.tint,
  });

  final String label;
  final Color border;
  final Color text;
  final Color muted;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tint?.withAlpha(34) ?? Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint?.withAlpha(96) ?? border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: tint ?? text,
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.isDarkMode,
    this.compact = false,
    required this.carLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.readinessLabel,
    required this.piLabel,
    required this.driveLabel,
    required this.surfaceLabel,
    required this.tuneTypeLabel,
    required this.unitsLabel,
    required this.gearsLabel,
  });

  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final bool isDarkMode;
  final bool compact;
  final String carLabel;
  final String statusLabel;
  final Color statusColor;
  final String readinessLabel;
  final String piLabel;
  final String driveLabel;
  final String surfaceLabel;
  final String tuneTypeLabel;
  final String unitsLabel;
  final String gearsLabel;

  @override
  Widget build(BuildContext context) {
    final compactPills = <String>[
      statusLabel,
      piLabel,
      driveLabel,
    ];

    return _DashboardGlassCard(
      title: 'Session Summary',
      icon: Icons.dashboard_customize_rounded,
      accent: accent,
      border: border,
      text: text,
      muted: muted,
      compact: compact,
      subtitle:
          compact ? null : 'Current tune context and readiness at a glance.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            carLabel,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          if (compact) ...<Widget>[
            Text(
              '$readinessLabel • $surfaceLabel • $tuneTypeLabel • $gearsLabel • $unitsLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                height: 1.15,
                color: muted,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: compactPills
                  .map(
                    (label) => _DashboardInfoPill(
                      label: label,
                      border: border,
                      text: text,
                      muted: muted,
                      tint: label == statusLabel ? statusColor : null,
                    ),
                  )
                  .toList(),
            ),
          ] else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _DashboardInfoPill(
                  label: statusLabel,
                  border: border,
                  text: text,
                  muted: muted,
                  tint: statusColor,
                ),
                _DashboardInfoPill(
                  label: readinessLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                _DashboardInfoPill(
                  label: piLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                _DashboardInfoPill(
                  label: driveLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                _DashboardInfoPill(
                  label: surfaceLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                _DashboardInfoPill(
                  label: tuneTypeLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                _DashboardInfoPill(
                  label: unitsLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
                _DashboardInfoPill(
                  label: gearsLabel,
                  border: border,
                  text: text,
                  muted: muted,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GarageSnapshotCard extends StatelessWidget {
  const _GarageSnapshotCard({
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.records,
    required this.totalCount,
    required this.onOpenGarage,
    required this.relativeTimeLabel,
    this.compact = false,
    this.maxItems = 3,
  });

  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final List<SavedTuneRecord> records;
  final int totalCount;
  final VoidCallback onOpenGarage;
  final String Function(DateTime createdAt) relativeTimeLabel;
  final bool compact;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    return _DashboardGlassCard(
      title: 'Garage Snapshot',
      icon: Icons.garage_rounded,
      accent: accent,
      border: border,
      text: text,
      muted: muted,
      compact: compact,
      subtitle: compact
          ? null
          : '$totalCount saved tune${totalCount == 1 ? '' : 's'} ready for reuse.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (records.isEmpty)
            Text(
              'No tunes saved yet. Save one result and it will appear here.',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                height: 1.4,
                color: muted,
              ),
            )
          else
            ...records.take(maxItems).map(
                  (record) => Padding(
                    padding: EdgeInsets.only(bottom: compact ? 6 : 8),
                    child: _GarageSnapshotRow(
                      record: record,
                      border: border,
                      text: text,
                      muted: muted,
                      relativeTime: relativeTimeLabel(record.createdAt),
                      compact: compact,
                    ),
                  ),
                ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenGarage,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: Size(0, compact ? 26 : 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: Icon(Icons.arrow_forward_rounded, size: compact ? 14 : 16),
              label: Text(compact ? 'Garage' : 'Open Garage'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GarageSnapshotRow extends StatelessWidget {
  const _GarageSnapshotRow({
    required this.record,
    required this.border,
    required this.text,
    required this.muted,
    required this.relativeTime,
    this.compact = false,
  });

  final SavedTuneRecord record;
  final Color border;
  final Color text;
  final Color muted;
  final String relativeTime;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: compact ? 26 : 30,
            height: compact ? 26 : 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: record.isPinned
                  ? const Color(0x1AF59E0B)
                  : const Color(0x14000000),
              border: Border.all(
                color: record.isPinned ? const Color(0x80F59E0B) : border,
              ),
            ),
            child: Icon(
              record.isPinned ? Icons.push_pin_rounded : Icons.history_rounded,
              size: compact ? 12 : 14,
              color: record.isPinned ? const Color(0xFFF59E0B) : muted,
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                SizedBox(height: compact ? 1 : 2),
                Text(
                  '${record.piClass} • ${record.driveType} • ${record.tuneType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTuneTip {
  const _QuickTuneTip({required this.label, required this.value});
  final String label;
  final String value;
}

class _QuickTuneTipsCard extends StatelessWidget {
  const _QuickTuneTipsCard({
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.tuneType,
    this.compact = false,
  });

  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final String tuneType;
  final bool compact;

  static const Map<String, List<_QuickTuneTip>> _tipsByType =
      <String, List<_QuickTuneTip>>{
    'Race': <_QuickTuneTip>[
      _QuickTuneTip(label: 'Tire Pressure', value: '2.0–2.3 bar'),
      _QuickTuneTip(label: 'Anti-roll Bars', value: 'Stiffer front'),
      _QuickTuneTip(label: 'Springs', value: 'Firm both ends'),
      _QuickTuneTip(label: 'Diff Accel', value: '30–60%'),
    ],
    'Rally': <_QuickTuneTip>[
      _QuickTuneTip(label: 'Tire Pressure', value: '1.8–2.1 bar'),
      _QuickTuneTip(label: 'Suspension', value: 'Higher ride height'),
      _QuickTuneTip(label: 'Damping', value: 'Softer rebound'),
      _QuickTuneTip(label: 'Diff Decel', value: '20–40%'),
    ],
    'Drift': <_QuickTuneTip>[
      _QuickTuneTip(label: 'Tire Pressure', value: '2.3–2.6 bar rear'),
      _QuickTuneTip(label: 'Camber', value: '-2.0° rear'),
      _QuickTuneTip(label: 'Diff Accel', value: '70–100%'),
      _QuickTuneTip(label: 'Braking', value: 'Rear bias 55–65%'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final tips = _tipsByType[tuneType] ?? _tipsByType['Race']!;

    return _DashboardGlassCard(
      title: 'Quick Tune Tips',
      icon: Icons.tips_and_updates_rounded,
      accent: accent,
      border: border,
      text: text,
      muted: muted,
      compact: compact,
      subtitle: tuneType,
      child: compact
          ? Column(
              children: tips
                  .map((tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                tip.label,
                                style: TextStyle(fontSize: 10, color: muted),
                              ),
                            ),
                            Text(
                              tip.value,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: text,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tips
                  .map((tip) => Container(
                        constraints: const BoxConstraints(minWidth: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              tip.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Shared UI atoms
// ══════════════════════════════════════════════════════════════════

class _Block extends StatelessWidget {
  const _Block({
    required this.isDarkMode,
    required this.panelBg,
    required this.border,
    required this.title,
    required this.icon,
    required this.accent,
    required this.text,
    required this.child,
    this.expandChild = false,
    this.padding = const EdgeInsets.all(18),
    this.headerSpacing = 14,
  });

  final bool isDarkMode;
  final Color panelBg;
  final Color border;
  final String title;
  final IconData icon;
  final Color accent;
  final Color text;
  final Widget child;
  final bool expandChild;
  final EdgeInsetsGeometry padding;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ],
            ),
            SizedBox(height: headerSpacing),
            if (expandChild) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.onSelected,
    this.icon,
    this.dense = false,
  });

  final String label;
  final List<String> options;
  final String selected;
  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final ValueChanged<String> onSelected;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon!, size: dense ? 9 : 10, color: muted),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: dense ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    color: muted)),
          ],
        ),
        SizedBox(height: dense ? 3 : 4),
        Wrap(
          spacing: dense ? 3 : 4,
          runSpacing: dense ? 3 : 4,
          children: options
              .map(
                (opt) => _SelectableChip(
                  label: opt,
                  selected: selected == opt,
                  accent: accent,
                  border: border,
                  text: text,
                  dense: dense,
                  onTap: () => onSelected(opt),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SelectableChip extends StatefulWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.border,
    required this.text,
    this.dense = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color border;
  final Color text;
  final bool dense;
  final VoidCallback onTap;

  @override
  State<_SelectableChip> createState() => _SelectableChipState();
}

class _SelectableChipState extends State<_SelectableChip>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? widget.accent
        : (_hovered ? widget.accent.withAlpha(30) : Colors.transparent);
    final borderColor = widget.selected
        ? widget.accent
        : (_hovered ? widget.accent.withAlpha(120) : widget.border);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _scaleCtrl.forward(),
        onTapUp: (_) => _scaleCtrl.reverse(),
        onTapCancel: () => _scaleCtrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.dense ? 10 : 12,
              vertical: widget.dense ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: widget.selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: widget.accent.withAlpha(50),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.dense ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: widget.selected ? Colors.white : widget.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({
    required this.metric,
    required this.accent,
    required this.border,
    required this.text,
    required this.muted,
    required this.onChanged,
    this.compact = false,
  });

  final bool metric;
  final Color accent;
  final Color border;
  final Color text;
  final Color muted;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      children: <Widget>[
        _buildOption('Metric', true),
        _buildOption('Imperial', false),
      ],
    );
  }

  Widget _buildOption(String label, bool isMetric) {
    final isActive = metric == isMetric;
    return GestureDetector(
      onTap: () => onChanged(isMetric),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isActive ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? accent : border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : muted,
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    this.numOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final Color border;
  final Color text;
  final Color muted;
  final Color accent;
  final bool numOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: text, fontSize: 12),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: numOnly
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ]
          : <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[\d./\s R]')),
            ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11, color: muted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }
}
