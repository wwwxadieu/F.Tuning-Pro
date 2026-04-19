import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../features/create/domain/tune_models.dart';
import 'ftune_models.dart';

enum FTuneWindowKind {
  main,
  overlay,
}

class FTuneOverlayWindowPayload {
  const FTuneOverlayWindowPayload({
    required this.record,
    required this.preferences,
  });

  final SavedTuneRecord record;
  final AppPreferences preferences;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'record': record.toJson(),
        'preferences': preferences.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());

  FTuneOverlayWindowPayload copyWith({
    SavedTuneRecord? record,
    AppPreferences? preferences,
  }) {
    return FTuneOverlayWindowPayload(
      record: record ?? this.record,
      preferences: preferences ?? this.preferences,
    );
  }

  factory FTuneOverlayWindowPayload.fromJsonString(String raw) {
    final source = raw.trim();
    if (source.isEmpty) {
      throw const FormatException('Overlay payload is empty.');
    }
    final json = jsonDecode(source) as Map<String, dynamic>;
    return FTuneOverlayWindowPayload(
      record: SavedTuneRecord.fromJson(
        Map<String, dynamic>.from(
            json['record'] as Map? ?? <String, dynamic>{}),
      ),
      preferences: AppPreferences.fromJson(
        Map<String, dynamic>.from(
          json['preferences'] as Map? ?? <String, dynamic>{},
        ),
      ),
    );
  }
}

class FTuneWindowLaunchData {
  const FTuneWindowLaunchData._({
    required this.kind,
    this.overlayPayload,
  });

  const FTuneWindowLaunchData.main() : this._(kind: FTuneWindowKind.main);

  const FTuneWindowLaunchData.overlay(FTuneOverlayWindowPayload payload)
      : this._(kind: FTuneWindowKind.overlay, overlayPayload: payload);

  final FTuneWindowKind kind;
  final FTuneOverlayWindowPayload? overlayPayload;

  bool get isOverlay => kind == FTuneWindowKind.overlay;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.name,
        if (overlayPayload != null) 'overlayPayload': overlayPayload!.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory FTuneWindowLaunchData.fromJsonString(String? raw) {
    final source = raw?.trim() ?? '';
    if (source.isEmpty) {
      return const FTuneWindowLaunchData.main();
    }

    try {
      final json = jsonDecode(source);
      if (json is! Map) {
        return const FTuneWindowLaunchData.main();
      }
      final map = Map<String, dynamic>.from(json);
      final kindName = map['kind'] as String? ?? FTuneWindowKind.main.name;
      if (kindName == FTuneWindowKind.overlay.name) {
        final payloadJson = Map<String, dynamic>.from(
            map['overlayPayload'] as Map? ?? <String, dynamic>{});
        return FTuneWindowLaunchData.overlay(
          FTuneOverlayWindowPayload(
            record: SavedTuneRecord.fromJson(
              Map<String, dynamic>.from(
                payloadJson['record'] as Map? ?? <String, dynamic>{},
              ),
            ),
            preferences: AppPreferences.fromJson(
              Map<String, dynamic>.from(
                payloadJson['preferences'] as Map? ?? <String, dynamic>{},
              ),
            ),
          ),
        );
      }
    } catch (_) {
      return const FTuneWindowLaunchData.main();
    }

    return const FTuneWindowLaunchData.main();
  }
}

class FTuneOverlayWindowService {
  FTuneOverlayWindowService._();

  static final FTuneOverlayWindowService instance =
      FTuneOverlayWindowService._();
  static const WindowMethodChannel _bridgeChannel = WindowMethodChannel(
    'ftune_overlay_bridge',
    mode: ChannelMode.unidirectional,
  );

  WindowController? _overlayController;
  String? _lastPayloadKey;
  bool _bridgeBound = false;
  bool _creating = false;
  Future<void> _syncQueue = Future<void>.value();
  Future<void> Function()? _onOverlayClosed;
  Function(bool)? _onOverlayLockedChanged;

  bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> bind({
    required Future<void> Function() onOverlayClosed,
    Function(bool)? onOverlayLockedChanged,
  }) async {
    if (!isSupported) return;
    _onOverlayClosed = onOverlayClosed;
    _onOverlayLockedChanged = onOverlayLockedChanged;
    if (_bridgeBound) return;
    _bridgeBound = true;
    await _bridgeChannel.setMethodCallHandler((call) async {
      if (call.method == 'overlay_closed') {
        _overlayController = null;
        _lastPayloadKey = null;
        await _onOverlayClosed?.call();
        return true;
      }
      if (call.method == 'overlay_lock_changed') {
        final locked = call.arguments as bool? ?? false;
        _onOverlayLockedChanged?.call(locked);
        return true;
      }
      throw MissingPluginException('Not implemented: ${call.method}');
    });
  }

  Future<void> sync({
    required SavedTuneRecord? record,
    required AppPreferences preferences,
  }) async {
    _syncQueue = _syncQueue
        .catchError((_) {})
        .then((_) => _syncInternal(record: record, preferences: preferences));
    await _syncQueue;
  }

  Future<void> _syncInternal({
    required SavedTuneRecord? record,
    required AppPreferences preferences,
  }) async {
    if (!isSupported) return;

    if (record == null || !preferences.overlayPreviewEnabled) {
      await close();
      return;
    }

    await _ensureSingleOverlayWindow();

    final payload = FTuneOverlayWindowPayload(
      record: record,
      preferences: preferences,
    );
    final payloadKey = payload.toJsonString();

    if (_overlayController == null) {
      if (_creating) return;
      _creating = true;
      try {
        await _create(payload, payloadKey);
      } finally {
        _creating = false;
      }
      return;
    }

    if (_lastPayloadKey == payloadKey) {
      try {
        await _overlayController!.invokeMethod('overlay_focus');
        return;
      } catch (_) {
        _overlayController = null;
        _lastPayloadKey = null;
        await _create(payload, payloadKey);
        return;
      }
    }

    try {
      await _overlayController!.invokeMethod('overlay_update', payloadKey);
      await _overlayController!.invokeMethod('overlay_focus');
      _lastPayloadKey = payloadKey;
    } catch (_) {
      _overlayController = null;
      _lastPayloadKey = null;
      await _create(payload, payloadKey);
    }
  }

  Future<void> _create(
    FTuneOverlayWindowPayload payload,
    String payloadKey,
  ) async {
    // Recheck before creating to avoid duplicate overlay windows.
    await _ensureSingleOverlayWindow();
    if (_overlayController != null) {
      await _overlayController!.invokeMethod('overlay_update', payloadKey);
      await _overlayController!.invokeMethod('overlay_focus');
      _lastPayloadKey = payloadKey;
      return;
    }

    final controller = await WindowController.create(
      WindowConfiguration(
        arguments: FTuneWindowLaunchData.overlay(payload).toJsonString(),
        hiddenAtLaunch: true,
      ),
    );
    _overlayController = controller;
    _lastPayloadKey = payloadKey;
    await controller.show();
  }

  Future<void> close() async {
    final controllers = await _collectOverlayWindows();
    final controller = _overlayController;
    _overlayController = null;
    _lastPayloadKey = null;
    if (controllers.isEmpty && controller == null) return;

    final all = <WindowController>{...controllers, if (controller != null) controller};
    for (final item in all) {
      try {
        await item.invokeMethod('overlay_close');
      } catch (_) {
        try {
          await item.hide();
        } catch (_) {}
      }
    }
  }

  Future<void> _ensureSingleOverlayWindow() async {
    final overlays = await _collectOverlayWindows();
    if (overlays.isEmpty) {
      _overlayController = null;
      _lastPayloadKey = null;
      return;
    }

    WindowController keeper;
    if (_overlayController != null) {
      keeper = overlays.firstWhere(
        (candidate) => candidate.windowId == _overlayController!.windowId,
        orElse: () => overlays.first,
      );
    } else {
      keeper = overlays.first;
    }

    _overlayController = keeper;
    if (overlays.length <= 1) return;

    for (final candidate in overlays) {
      if (candidate.windowId == keeper.windowId) continue;
      try {
        await candidate.invokeMethod('overlay_close');
      } catch (_) {
        try {
          await candidate.hide();
        } catch (_) {}
      }
    }
  }

  Future<List<WindowController>> _collectOverlayWindows() async {
    final windows = await WindowController.getAll();
    return windows.where((window) {
      final launchData = FTuneWindowLaunchData.fromJsonString(window.arguments);
      return launchData.isOverlay;
    }).toList(growable: false);
  }
}

class FTuneOverlayWindowApp extends StatefulWidget {
  const FTuneOverlayWindowApp({
    super.key,
    required this.payload,
  });

  final FTuneOverlayWindowPayload payload;

  @override
  State<FTuneOverlayWindowApp> createState() => _FTuneOverlayWindowAppState();
}

class _FTuneOverlayWindowAppState extends State<FTuneOverlayWindowApp>
    with WindowListener {
  static const WindowMethodChannel _bridgeChannel = WindowMethodChannel(
    'ftune_overlay_bridge',
    mode: ChannelMode.unidirectional,
  );

  late FTuneOverlayWindowPayload _payload;
  WindowController? _windowController;
  late double _windowOpacity;
  late bool _alwaysOnTop;
  late Size _windowSize;
  DateTime? _lastResizeTime;
  static const _resizeDebounceMs = 100;

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
    _windowOpacity = widget.payload.preferences.overlayOpacity;
    _alwaysOnTop = widget.payload.preferences.overlayOnTop;
    _windowSize = _windowSizeFor(widget.payload.preferences.overlayLayout);
    _bootstrapWindow();
  }

  Future<void> _bootstrapWindow() async {
    final controller = await WindowController.fromCurrentEngine();
    _windowController = controller;
    await controller.setWindowMethodHandler(_handleWindowMethod);
    windowManager.addListener(this);
    await _applyWindowConfig(center: true);
  }

  Future<dynamic> _handleWindowMethod(MethodCall call) async {
    switch (call.method) {
      case 'overlay_update':
        final raw = call.arguments?.toString() ?? '';
        final nextPayload = FTuneOverlayWindowPayload.fromJsonString(raw);
        if (mounted) {
          setState(() => _payload = nextPayload);
        } else {
          _payload = nextPayload;
        }
        await _applyWindowConfig();
        return true;
      case 'overlay_focus':
        await windowManager.show();
        await windowManager.focus();
        return true;
      case 'overlay_close':
        await windowManager.close();
        return true;
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  Size _windowSizeFor(String layout) {
    switch (layout) {
      case 'horizontal':
        return const Size(720, 380);
      case 'compact':
        return const Size(360, 540);
      default:
        return const Size(460, 680);
    }
  }

  Future<void> _applyWindowConfig({bool center = false}) async {
    final options = WindowOptions(
      size: _windowSize,
      center: center,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      alwaysOnTop: _alwaysOnTop,
      title: 'F.Tune Overlay',
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setAlwaysOnTop(_alwaysOnTop);
    await windowManager.setOpacity(_windowOpacity.clamp(0.45, 1.0));
    await windowManager.setResizable(true);
    await windowManager.setMaximizable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setClosable(true);
    await windowManager.setPreventClose(false);
    await windowManager.setHasShadow(true);
    await windowManager.setTitle('F.Tune Overlay');
    await windowManager.setMinimumSize(const Size(340, 420));
    await windowManager.setMaximumSize(const Size(680, 1200));
    await windowManager.setSize(_windowSize);
  }

  Future<void> _setWindowOpacity(double value) async {
    final next = value.clamp(0.45, 1.0).toDouble();
    if (mounted) {
      setState(() => _windowOpacity = next);
    } else {
      _windowOpacity = next;
    }
    await windowManager.setOpacity(next);
  }

  Future<void> _setAlwaysOnTop(bool value) async {
    if (mounted) {
      setState(() => _alwaysOnTop = value);
    } else {
      _alwaysOnTop = value;
    }
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> _setWindowSize(Size size) async {
    // Clamp size to min/max bounds before applying
    final clampedSize = Size(
      size.width.clamp(340.0, 680.0),
      size.height.clamp(420.0, 1200.0),
    );
    if (mounted) {
      setState(() => _windowSize = clampedSize);
    } else {
      _windowSize = clampedSize;
    }
    await windowManager.setSize(clampedSize);
  }

  Future<void> _syncWindowSizeFromManager() async {
    final size = await windowManager.getSize();
    if (mounted) {
      setState(() => _windowSize = size);
    } else {
      _windowSize = size;
    }
  }

  @override
  void onWindowResize() {
    // Debounce resize events to prevent excessive rebuilds
    final now = DateTime.now();
    if (_lastResizeTime != null &&
        now.difference(_lastResizeTime!).inMilliseconds < _resizeDebounceMs) {
      return;
    }
    _lastResizeTime = now;
    _syncWindowSizeFromManager();
  }

  @override
  void onWindowResized() {
    // Final sync when resize ends
    _syncWindowSizeFromManager();
  }

  @override
  void dispose() {
    _windowController?.setWindowMethodHandler(null);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = _payload.preferences.themeMode == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    final userAccent = Color(_payload.preferences.accentColorValue);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'F.Tune Overlay',
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: userAccent,
          brightness: Brightness.light,
          primary: userAccent,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: userAccent,
          brightness: Brightness.dark,
          primary: userAccent,
        ),
      ),
      home: _FTuneOverlayWindowPage(
        payload: _payload,
        windowSize: _windowSize,
        windowOpacity: _windowOpacity,
        alwaysOnTop: _alwaysOnTop,
        onOpacityChanged: _setWindowOpacity,
        onAlwaysOnTopChanged: _setAlwaysOnTop,
        onSizeSelected: _setWindowSize,
        onClose: () async {
          await _bridgeChannel.invokeMethod('overlay_closed');
          await windowManager.close();
        },
        onOverlayLockedChanged: (locked) async {
          if (mounted) {
            setState(() {
              _payload = _payload.copyWith(
                preferences:
                    _payload.preferences.copyWith(overlayLocked: locked),
              );
            });
          } else {
            _payload = _payload.copyWith(
              preferences: _payload.preferences.copyWith(overlayLocked: locked),
            );
          }
          // Notify main window to update preferences
          await _bridgeChannel.invokeMethod('overlay_lock_changed', locked);
        },
      ),
    );
  }
}

class _FTuneOverlayWindowPage extends StatelessWidget {
  const _FTuneOverlayWindowPage({
    required this.payload,
    required this.windowSize,
    required this.windowOpacity,
    required this.alwaysOnTop,
    required this.onOpacityChanged,
    required this.onAlwaysOnTopChanged,
    required this.onSizeSelected,
    required this.onClose,
    this.onOverlayLockedChanged,
  });

  final FTuneOverlayWindowPayload payload;
  final Size windowSize;
  final double windowOpacity;
  final bool alwaysOnTop;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<bool> onAlwaysOnTopChanged;
  final ValueChanged<Size> onSizeSelected;
  final VoidCallback onClose;
  final ValueChanged<bool>? onOverlayLockedChanged;

  @override
  Widget build(BuildContext context) {
    final palette = _OverlayPalette.of(context);
    final isHorizontal = payload.preferences.overlayLayout == 'horizontal';
    final useMetric = payload.record.session?.metric ??
        !payload.record.topSpeedDisplay.toLowerCase().contains('mph');
    final lines = _buildOverlayLines(payload.record, useMetric: useMetric);
    final subtitle = <String>[
      '${payload.record.brand} ${payload.record.model}'.trim(),
      if (payload.record.shareCode.trim().isNotEmpty)
        'SC ${payload.record.shareCode.trim()}',
    ].join(' · ');

    final sizePresets = <_OverlaySizePreset>[
      const _OverlaySizePreset('S', Size(420, 560)),
      const _OverlaySizePreset('M', Size(500, 700)),
      const _OverlaySizePreset('L', Size(620, 860)),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: <Widget>[
              // ── Glassmorphic panel ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette.isDark
                        ? <Color>[
                            const Color(0xE01F242B),
                            const Color(0xD7262B33),
                            const Color(0xCB1E232A),
                          ]
                        : <Color>[
                            const Color(0xFCFFFFFF),
                            const Color(0xF8F7F9FC),
                            const Color(0xF1EFF3F8),
                          ],
                  ),
                  border: Border.all(
                    color: palette.isDark
                        ? palette.border
                        : Colors.white.withAlpha(214),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _withAlpha(
                        palette.accent,
                        palette.isDark ? 0.12 : 0.06,
                      ),
                      blurRadius: 24,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: palette.shadow,
                      blurRadius: 24,
                      spreadRadius: -10,
                      offset: const Offset(0, 12),
                    ),
                    if (!palette.isDark)
                      BoxShadow(
                        color: Colors.white.withAlpha(186),
                        blurRadius: 16,
                        spreadRadius: -12,
                        offset: const Offset(-3, -3),
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: <Widget>[
                    // Glass shimmer top-left
                    Positioned(
                      top: -40,
                      left: -40,
                      width: 180,
                      height: 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              _withAlpha(
                                palette.accent,
                                palette.isDark ? 0.08 : 0.05,
                              ),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          // ignore: deprecated_member_use
                          textScaleFactor: payload.preferences.overlayTextScale,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // ── Header: title + controls ──
                            Builder(
                              builder: (context) {
                                final headerRow = Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            payload.record.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: palette.text,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: palette.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _OverlayHeaderButton(
                                      palette: palette,
                                      icon: payload.preferences.overlayLocked
                                          ? Icons.lock_rounded
                                          : Icons.lock_open_rounded,
                                      tooltip: payload.preferences.overlayLocked
                                          ? 'Unlock position'
                                          : 'Lock position',
                                      onTap: () {
                                        onOverlayLockedChanged?.call(
                                          !payload.preferences.overlayLocked,
                                        );
                                      },
                                      active: payload.preferences.overlayLocked,
                                    ),
                                    const SizedBox(width: 6),
                                    _OverlayHeaderButton(
                                      palette: palette,
                                      icon: alwaysOnTop
                                          ? Icons.push_pin_rounded
                                          : Icons.push_pin_outlined,
                                      tooltip: alwaysOnTop
                                          ? 'Always on top'
                                          : 'Pin overlay',
                                      onTap: () =>
                                          onAlwaysOnTopChanged(!alwaysOnTop),
                                      active: alwaysOnTop,
                                    ),
                                    const SizedBox(width: 6),
                                    _OverlayHeaderButton(
                                      palette: palette,
                                      icon: Icons.close_rounded,
                                      tooltip: 'Close overlay',
                                      onTap: onClose,
                                    ),
                                  ],
                                );
                                return payload.preferences.overlayLocked
                                    ? headerRow
                                    : DragToMoveArea(child: headerRow);
                              },
                            ),
                            // ── Inline controls bar: size + opacity ──
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: _OverlayInlineControls(
                                palette: palette,
                                windowSize: windowSize,
                                opacity: windowOpacity,
                                presets: sizePresets,
                                onOpacityChanged: onOpacityChanged,
                                onSizeSelected: onSizeSelected,
                              ),
                            ),
                            // ── Thin divider ──
                            Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.transparent,
                                    palette.border,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            // ── Summary pills ──
                            _OverlaySummaryCard(
                              palette: palette,
                              record: payload.record,
                            ),
                            const SizedBox(height: 8),
                            // ── Tune data ──
                            Expanded(
                              child: isHorizontal
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(
                                          flex: 2,
                                          child: _OverlayLinesList(
                                            palette: palette,
                                            lines: lines,
                                            useMetric: useMetric,
                                          ),
                                        ),
                                      ],
                                    )
                                  : _OverlayLinesList(
                                      palette: palette,
                                      lines: lines,
                                      useMetric: useMetric,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Positioned(
                right: 4,
                bottom: 4,
                child: _OverlayResizeGrip(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlaySummaryCard extends StatelessWidget {
  const _OverlaySummaryCard({
    required this.palette,
    required this.record,
  });

  final _OverlayPalette palette;
  final SavedTuneRecord record;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _summaryPill(record.piClass, palette),
        _summaryPill(record.driveType, palette),
        _summaryPill(record.surface, palette),
        _summaryPill(record.tuneType, palette),
        _summaryPill(record.topSpeedDisplay, palette, emphasized: true),
      ],
    );
  }

  Widget _summaryPill(
    String label,
    _OverlayPalette palette, {
    bool emphasized = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: emphasized
            ? _withAlpha(palette.accent, palette.isDark ? 0.20 : 0.12)
            : palette.surfaceAlt,
        border: Border.all(
          color: emphasized ? _withAlpha(palette.accent, 0.44) : palette.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: emphasized ? palette.accent : palette.text,
        ),
      ),
    );
  }
}

class _OverlayInlineControls extends StatelessWidget {
  const _OverlayInlineControls({
    required this.palette,
    required this.windowSize,
    required this.opacity,
    required this.presets,
    required this.onOpacityChanged,
    required this.onSizeSelected,
  });

  final _OverlayPalette palette;
  final Size windowSize;
  final double opacity;
  final List<_OverlaySizePreset> presets;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<Size> onSizeSelected;

  @override
  Widget build(BuildContext context) {
    bool matchesPreset(Size presetSize) {
      return (windowSize.width - presetSize.width).abs() < 2 &&
          (windowSize.height - presetSize.height).abs() < 2;
    }

    return Row(
      children: <Widget>[
        // Size presets
        ...presets.map(
          (preset) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _OverlayToggleChip(
              label: preset.label,
              selected: matchesPreset(preset.size),
              palette: palette,
              onTap: () => onSizeSelected(preset.size),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Opacity icon
        Icon(
          Icons.opacity_rounded,
          size: 13,
          color: palette.muted,
        ),
        const SizedBox(width: 2),
        // Compact opacity slider
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: palette.accent,
              inactiveTrackColor: palette.border,
              thumbColor: palette.accent,
              overlayColor: _withAlpha(palette.accent, 0.12),
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
            ),
            child: Slider(
              value: opacity.clamp(0.45, 1.0),
              min: 0.45,
              max: 1.0,
              divisions: 11,
              onChanged: onOpacityChanged,
            ),
          ),
        ),
        // Opacity percentage
        SizedBox(
          width: 32,
          child: Text(
            '${(opacity * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayToggleChip extends StatelessWidget {
  const _OverlayToggleChip({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _OverlayPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? _withAlpha(palette.accent, palette.isDark ? 0.24 : 0.14)
              : palette.surfaceAlt,
          border: Border.all(
            color: selected ? _withAlpha(palette.accent, 0.44) : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: selected ? palette.accent : palette.text,
          ),
        ),
      ),
    );
  }
}

class _OverlaySizePreset {
  const _OverlaySizePreset(this.label, this.size);

  final String label;
  final Size size;
}

class _OverlayResizeGrip extends StatefulWidget {
  const _OverlayResizeGrip();

  @override
  State<_OverlayResizeGrip> createState() => _OverlayResizeGripState();
}

class _OverlayResizeGripState extends State<_OverlayResizeGrip> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final effectiveAlpha = _isDragging ? 200 : (_isHovered ? 160 : 100);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _isDragging = true);
          windowManager.startResizing(ResizeEdge.bottomRight);
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanCancel: () => setState(() => _isDragging = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _isDragging || _isHovered
                ? color.withAlpha(20)
                : Colors.transparent,
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: _isDragging ? 1.15 : (_isHovered ? 1.08 : 1.0),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 16,
                  color: color.withAlpha(effectiveAlpha),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayLinesList extends StatefulWidget {
  const _OverlayLinesList({
    required this.palette,
    required this.lines,
    this.useMetric = true,
  });

  final _OverlayPalette palette;
  final List<_OverlayLineData> lines;
  final bool useMetric;

  @override
  State<_OverlayLinesList> createState() => _OverlayLinesListState();
}

class _OverlayLinesListState extends State<_OverlayLinesList> {
  final Set<String> _expandedTitles = <String>{};

  @override
  void initState() {
    super.initState();
    _ensureDefaultExpansion(widget.lines);
  }

  @override
  void didUpdateWidget(covariant _OverlayLinesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validTitles = widget.lines.map((line) => line.title).toSet();
    _expandedTitles.removeWhere((title) => !validTitles.contains(title));
    _ensureDefaultExpansion(widget.lines);
  }

  void _ensureDefaultExpansion(List<_OverlayLineData> lines) {
    for (final line in lines) {
      if (line.detailRows.isNotEmpty &&
          line.title.toLowerCase().contains('gearing')) {
        _expandedTitles.add(line.title);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: widget.lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isGearing = line.gearingData != null;
        final expandable = line.detailRows.isNotEmpty || isGearing;
        final isExpanded = _expandedTitles.contains(line.title);
        final hasSliders = line.sliders.isNotEmpty && !isGearing;

        return InkWell(
          onTap: !expandable
              ? null
              : () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTitles.remove(line.title);
                    } else {
                      _expandedTitles.add(line.title);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpanded
                    ? _withAlpha(widget.palette.accent, 0.40)
                    : widget.palette.border,
              ),
              color: widget.palette.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        line.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: widget.palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        line.value,
                        maxLines: isExpanded ? 6 : 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.palette.text,
                        ),
                      ),
                    ),
                    if (expandable) ...<Widget>[
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 14,
                        color: widget.palette.muted,
                      ),
                    ],
                  ],
                ),
                // ── Slider bars for non-gearing cards ──
                if (hasSliders && !isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _OverlaySliderBars(
                      palette: widget.palette,
                      sliders: line.sliders,
                      compact: true,
                    ),
                  ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: (expandable && isExpanded)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: 8),
                            // ── Visual gearing panel ──
                            if (isGearing)
                              _OverlayGearingPanel(
                                palette: widget.palette,
                                gearing: line.gearingData!,
                                useMetric: widget.useMetric,
                              )
                            // ── Slider bars for expanded non-gearing cards ──
                            else if (hasSliders)
                              _OverlaySliderBars(
                                palette: widget.palette,
                                sliders: line.sliders,
                                compact: false,
                              )
                            else
                              for (final detail in line.detailRows) ...<Widget>[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: widget.palette.surfaceAlt,
                                    border: Border.all(
                                        color: widget.palette.border),
                                  ),
                                  child: Text(
                                    detail,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: widget.palette.text,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _OverlayGearingPanel — Visual gear ratio bars with speed labels
// ══════════════════════════════════════════════════════════════════

class _OverlayGearingPanel extends StatelessWidget {
  const _OverlayGearingPanel({
    required this.palette,
    required this.gearing,
    required this.useMetric,
  });

  final _OverlayPalette palette;
  final TuneCalcGearingData gearing;
  final bool useMetric;

  @override
  Widget build(BuildContext context) {
    final maxSpeed = gearing.ratios.isEmpty
        ? 1.0
        : gearing.ratios
            .map((r) => r.topSpeedKmh)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // ── FD + Redline header ──
        Row(
          children: <Widget>[
            _gearInfoChip(
              'FD ${gearing.finalDrive.toStringAsFixed(2)}',
              emphasized: true,
            ),
            const SizedBox(width: 6),
            _gearInfoChip('${gearing.redlineRpm.round()} rpm'),
            const SizedBox(width: 6),
            _gearInfoChip(_formatOverlaySpeed(gearing.scaleMaxKmh, useMetric)),
          ],
        ),
        const SizedBox(height: 10),
        // ── Gear bars ──
        ...gearing.ratios.map((ratio) {
          final fraction = (ratio.topSpeedKmh / maxSpeed).clamp(0.0, 1.0);
          final speed = _formatOverlaySpeed(ratio.topSpeedKmh, useMetric);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: Text(
                    'G${ratio.gear}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: palette.muted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: <Widget>[
                          // Track
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: palette.surfaceAlt,
                            ),
                          ),
                          // Fill bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: 16,
                            width: constraints.maxWidth * fraction,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: <Color>[
                                  _withAlpha(palette.accent, 0.6),
                                  _withAlpha(palette.accent, 0.3),
                                ],
                              ),
                            ),
                          ),
                          // Ratio label inside bar
                          Positioned.fill(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    ratio.ratio.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                    ),
                                  ),
                                  Text(
                                    speed,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _gearInfoChip(String label, {bool emphasized = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: emphasized
            ? _withAlpha(palette.accent, palette.isDark ? 0.20 : 0.12)
            : palette.surfaceAlt,
        border: Border.all(
          color: emphasized ? _withAlpha(palette.accent, 0.40) : palette.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: emphasized ? palette.accent : palette.text,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _OverlaySliderBars — Mini slider-style bars for tune parameters
// ══════════════════════════════════════════════════════════════════

class _OverlaySliderBars extends StatelessWidget {
  const _OverlaySliderBars({
    required this.palette,
    required this.sliders,
    this.compact = false,
  });

  final _OverlayPalette palette;
  final List<TuneCalcSlider> sliders;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final display = compact ? sliders.take(3).toList() : sliders;
    return Column(
      children: <Widget>[
        for (final slider in display) ...<Widget>[
          _buildSliderRow(slider),
          if (!compact) const SizedBox(height: 4),
        ],
        if (compact && sliders.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+${sliders.length - 3} more',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: palette.muted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSliderRow(TuneCalcSlider slider) {
    final range = slider.max - slider.min;
    final fraction =
        range > 0 ? ((slider.value - slider.min) / range).clamp(0.0, 1.0) : 0.5;
    final label = slider.side.trim();
    final formattedValue = _formatSlider(slider);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          children: <Widget>[
            if (label.isNotEmpty)
              SizedBox(
                width: 28,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
              ),
            Expanded(
              child: _miniBar(fraction),
            ),
            const SizedBox(width: 4),
            Text(
              formattedValue,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: <Widget>[
        SizedBox(
          width: 50,
          child: Text(
            label.isNotEmpty ? label : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: palette.muted,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Stack(
            children: <Widget>[
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: palette.surfaceAlt,
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 14,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: <Color>[
                          _withAlpha(palette.accent, 0.50),
                          _withAlpha(palette.accent, 0.25),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Thumb indicator
              LayoutBuilder(
                builder: (context, constraints) {
                  final pos = constraints.maxWidth * fraction;
                  final left = (pos - 2).clamp(0.0, constraints.maxWidth - 4);
                  return SizedBox(
                    height: 14,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          left: left,
                          top: 1,
                          child: Container(
                            width: 4,
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: palette.accent,
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: _withAlpha(palette.accent, 0.40),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 44,
          child: Text(
            formattedValue,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniBar(double fraction) {
    return Container(
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: palette.surfaceAlt,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: _withAlpha(palette.accent, 0.50),
          ),
        ),
      ),
    );
  }
}

class _OverlayHeaderButton extends StatefulWidget {
  const _OverlayHeaderButton({
    required this.palette,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
  });

  final _OverlayPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  State<_OverlayHeaderButton> createState() => _OverlayHeaderButtonState();
}

class _OverlayHeaderButtonState extends State<_OverlayHeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.active
        ? _withAlpha(
            widget.palette.accent,
            widget.palette.isDark ? 0.22 : 0.14,
          )
        : (_hovered ? widget.palette.surfaceAlt : widget.palette.surface);
    final borderColor = widget.active
        ? _withAlpha(widget.palette.accent, 0.42)
        : (_hovered
            ? _withAlpha(widget.palette.accent, 0.36)
            : widget.palette.border);
    final foreground = widget.active
        ? widget.palette.accent
        : (_hovered ? widget.palette.text : widget.palette.muted);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
                color: background,
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 15, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayPalette {
  const _OverlayPalette({
    required this.isDark,
    required this.panel,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.shadow,
  });

  factory _OverlayPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    if (isDark) {
      return _OverlayPalette(
        isDark: true,
        panel: const Color(0xE01F242B),
        surface: const Color(0xCC1F2228),
        surfaceAlt: const Color(0xDB252A31),
        text: const Color(0xFFF5F7FA),
        muted: const Color(0xFFC2C8D0),
        border: const Color(0x4DF2F4F7),
        accent: accent,
        shadow: const Color(0x66000000),
      );
    }

    return _OverlayPalette(
      isDark: false,
      panel: const Color(0xFCFFFFFF),
      surface: const Color(0xECFDFDFD),
      surfaceAlt: const Color(0xF7F5F7FA),
      text: const Color(0xFF1D1F22),
      muted: const Color(0xFF5E636B),
      border: const Color(0xA6D3D8E2),
      accent: accent,
      shadow: const Color(0x16000000),
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
}

class _OverlayLineData {
  const _OverlayLineData({
    required this.title,
    required this.value,
    this.detailRows = const <String>[],
    this.gearingData,
    this.sliders = const <TuneCalcSlider>[],
  });

  final String title;
  final String value;
  final List<String> detailRows;
  final TuneCalcGearingData? gearingData;
  final List<TuneCalcSlider> sliders;
}

List<_OverlayLineData> _buildOverlayLines(
  SavedTuneRecord record, {
  required bool useMetric,
}) {
  return record.result.cards
      .map(
        (card) => _OverlayLineData(
          title: card.title,
          value: _summarizeOverlayCard(card, record.result.gearing),
          detailRows: _buildOverlayDetailRows(
            card,
            record.result.gearing,
            useMetric: useMetric,
          ),
          gearingData: card.title.toLowerCase().contains('gearing')
              ? record.result.gearing
              : null,
          sliders: card.sliders,
        ),
      )
      .toList();
}

List<String> _buildOverlayDetailRows(
  TuneCalcCard card,
  TuneCalcGearingData gearing, {
  required bool useMetric,
}) {
  if (!card.title.toLowerCase().contains('gearing')) {
    return const <String>[];
  }

  return <String>[
    'Final drive  ${gearing.finalDrive.toStringAsFixed(2)}',
    'Redline  ${gearing.redlineRpm.round()} rpm',
    'Scale max  ${_formatOverlaySpeed(gearing.scaleMaxKmh, useMetric)}',
    ...gearing.ratios.map(
      (ratio) =>
          'G${ratio.gear}  ${ratio.ratio.toStringAsFixed(2)}  •  ${_formatOverlaySpeed(ratio.topSpeedKmh, useMetric)}',
    ),
  ];
}

String _summarizeOverlayCard(TuneCalcCard card, TuneCalcGearingData gearing) {
  if (card.title.toLowerCase().contains('gearing')) {
    return 'FD ${gearing.finalDrive.toStringAsFixed(2)} · ${gearing.ratios.length} gears';
  }

  final parts = card.sliders
      .map(_sliderSummary)
      .where((value) => value.trim().isNotEmpty)
      .take(4)
      .toList();
  return parts.isEmpty ? '--' : parts.join(' · ');
}

String _sliderSummary(TuneCalcSlider slider) {
  final label = slider.side.trim();
  final value = _formatSlider(slider);
  if (label.isEmpty) return value;
  return '$label $value';
}

String _formatSlider(TuneCalcSlider slider) {
  if (slider.labels != null && slider.labels!.isNotEmpty) {
    final index =
        slider.value.round().clamp(0, slider.labels!.length - 1).toInt();
    return slider.labels![index];
  }

  final fixed = slider.value.toStringAsFixed(slider.decimals);
  final cleaned = fixed
      .replaceFirst(RegExp(r'\.0+$'), '')
      .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
  return '$cleaned${slider.suffix ?? ''}';
}

String _formatOverlaySpeed(double speedKmh, bool useMetric) {
  if (useMetric) {
    return '${speedKmh.round()} km/h';
  }
  return '${(speedKmh * 0.6213711922).round()} mph';
}

Color _withAlpha(Color color, double opacity) {
  final alpha = (opacity * 255).round().clamp(0, 255);
  return color.withAlpha(alpha);
}
