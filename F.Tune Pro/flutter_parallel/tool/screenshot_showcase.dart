import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:ftune_flutter/app/ftune_models.dart';
import 'package:ftune_flutter/app/ftune_shell.dart';
import 'package:ftune_flutter/app/ftune_ui.dart';
import 'package:ftune_flutter/features/create/domain/tune_models.dart';
import 'package:ftune_flutter/features/dashboard/dashboard_page.dart';

const bool _captureEnabled = bool.fromEnvironment(
  'FTUNE_CAPTURE',
  defaultValue: true,
);
const String _screenArg = String.fromEnvironment(
  'FTUNE_SCREEN',
  defaultValue: 'all',
);
const String _outputDirArg = String.fromEnvironment(
  'FTUNE_OUTPUT_DIR',
  defaultValue: '',
);
const int _canvasWidth = int.fromEnvironment(
  'FTUNE_CANVAS_WIDTH',
  defaultValue: 1600,
);
const int _canvasHeight = int.fromEnvironment(
  'FTUNE_CANVAS_HEIGHT',
  defaultValue: 900,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ScreenshotShowcaseApp());
}

class _ScreenshotShowcaseApp extends StatefulWidget {
  const _ScreenshotShowcaseApp();

  @override
  State<_ScreenshotShowcaseApp> createState() => _ScreenshotShowcaseAppState();
}

class _ScreenshotShowcaseAppState extends State<_ScreenshotShowcaseApp> {
  final GlobalKey _captureKey = GlobalKey();
  late final AppPreferences _preferences = _samplePreferences();
  late final List<_ShowcaseScenario> _scenarios = _resolveScenarios();
  late final Size _canvasSize =
      Size(_canvasWidth.toDouble(), _canvasHeight.toDouble());

  int _scenarioIndex = 0;
  bool _captureScheduled = false;
  String _status = _captureEnabled ? 'Preparing capture...' : 'Preview mode';
  String? _lastSavedPath;
  Object? _captureError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleCaptureIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenarios[_scenarioIndex];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'F.Tune Pro Screenshot Showcase',
      themeMode: ThemeMode.dark,
      theme: _buildShowcaseTheme(Brightness.light),
      darkTheme: _buildShowcaseTheme(Brightness.dark),
      home: ColoredBox(
        color: const Color(0xFF080B10),
        child: Stack(
          children: <Widget>[
            Center(
              child: RepaintBoundary(
                key: _captureKey,
                child: SizedBox(
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: ClipRect(child: scenario.builder(_preferences)),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 18,
              child: _StatusPanel(
                scenario: scenario,
                index: _scenarioIndex,
                total: _scenarios.length,
                status: _status,
                outputDir: _outputDirectory,
                lastSavedPath: _lastSavedPath,
                error: _captureError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleCaptureIfNeeded() {
    if (!_captureEnabled || _captureScheduled || !mounted) {
      return;
    }

    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_captureScenario());
    });
  }

  Future<void> _captureScenario() async {
    final scenario = _scenarios[_scenarioIndex];

    try {
      if (mounted) {
        setState(() {
          _status = 'Rendering ${scenario.id}...';
          _captureError = null;
        });
      }

      await _prepareScenario(scenario);
      final bytes = await _captureBytes();
      final file = await _writeCapture(scenario.fileStem, bytes);

      if (!mounted) return;
      setState(() {
        _lastSavedPath = file.path;
        _status = 'Saved ${file.path}';
      });

      _captureScheduled = false;
      if (_scenarioIndex < _scenarios.length - 1) {
        setState(() {
          _scenarioIndex += 1;
          _status = 'Preparing ${_scenarios[_scenarioIndex].id}...';
        });
        _scheduleCaptureIfNeeded();
        return;
      }

      setState(() => _status = 'Capture complete');
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 220),
          () => exit(0),
        ),
      );
    } catch (error) {
      _captureScheduled = false;
      if (mounted) {
        setState(() {
          _captureError = error;
          _status = 'Capture failed';
        });
      }
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 220),
          () => exit(1),
        ),
      );
    }
  }

  Future<void> _prepareScenario(_ShowcaseScenario scenario) async {
    for (final source in scenario.previewSources) {
      final provider = source.startsWith('http')
          ? NetworkImage(source)
          : AssetImage(source) as ImageProvider<Object>;
      await precacheImage(provider, context);
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(scenario.settleDuration);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Uint8List> _captureBytes() async {
    final boundary =
        _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Capture boundary is unavailable.');
    }

    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Unable to encode PNG bytes.');
    }

    return byteData.buffer.asUint8List();
  }

  Future<File> _writeCapture(String fileStem, Uint8List bytes) async {
    final directory = Directory(_outputDirectory);
    await directory.create(recursive: true);
    final outputPath = _joinPath(directory.path, '$fileStem.png');
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String get _outputDirectory {
    if (_outputDirArg.trim().isNotEmpty) {
      return _outputDirArg.trim();
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return _joinPath(userProfile, 'Pictures${Platform.pathSeparator}F.Tuning Pro Screenshot');
    }

    return _joinPath(Directory.current.path, 'screenshots');
  }

  List<_ShowcaseScenario> _resolveScenarios() {
    final all = <_ShowcaseScenario>[
      _ShowcaseScenario(
        id: 'welcome-setup',
        fileStem: 'welcome-setup',
        previewSources: const <String>[
          _fh5BoxArtUrl,
          'assets/images/fh6-main-bg.jpg',
        ],
        settleDuration: const Duration(milliseconds: 980),
        builder: (preferences) => FTuneWelcomeTourPreview(
          preferences: preferences,
          initialPage: 0,
        ),
      ),
      _ShowcaseScenario(
        id: 'welcome-create',
        fileStem: 'welcome-create',
        previewSources: const <String>['assets/images/welcome/home_create.png'],
        settleDuration: const Duration(milliseconds: 980),
        builder: (preferences) => FTuneWelcomeTourPreview(
          preferences: preferences,
          initialPage: 1,
        ),
      ),
      _ShowcaseScenario(
        id: 'welcome-calculate',
        fileStem: 'welcome-calculate',
        previewSources: const <String>['assets/images/welcome/home_calculate.png'],
        settleDuration: const Duration(milliseconds: 980),
        builder: (preferences) => FTuneWelcomeTourPreview(
          preferences: preferences,
          initialPage: 2,
        ),
      ),
      _ShowcaseScenario(
        id: 'welcome-garage',
        fileStem: 'welcome-garage',
        previewSources: const <String>['assets/images/welcome/garage_overview.png'],
        settleDuration: const Duration(milliseconds: 980),
        builder: (preferences) => FTuneWelcomeTourPreview(
          preferences: preferences,
          initialPage: 3,
        ),
      ),
      _ShowcaseScenario(
        id: 'welcome-start',
        fileStem: 'welcome-start',
        previewSources: const <String>['assets/images/welcome/settings_overview.png'],
        settleDuration: const Duration(milliseconds: 980),
        builder: (preferences) => FTuneWelcomeTourPreview(
          preferences: preferences,
          initialPage: 4,
        ),
      ),
      _ShowcaseScenario(
        id: 'dashboard-home',
        fileStem: 'dashboard-home',
        previewSources: const <String>[_porscheHeroUrl],
        settleDuration: const Duration(milliseconds: 1800),
        builder: (preferences) => _buildDashboardScenario(
          preferences: preferences,
          initialTab: 0,
          pendingCreateSession: _samplePorscheSession(),
        ),
      ),
      _ShowcaseScenario(
        id: 'dashboard-calculate',
        fileStem: 'dashboard-calculate',
        previewSources: const <String>[_porscheHeroUrl],
        settleDuration: const Duration(milliseconds: 2400),
        builder: (preferences) => _buildDashboardScenario(
          preferences: preferences,
          initialTab: 0,
          pendingCreateSession: _samplePorscheSession(),
          autoCalculateOnLoad: true,
          autoOpenResultPopupOnLoad: true,
          inlineResultPopupPreview: true,
        ),
      ),
      _ShowcaseScenario(
        id: 'garage-overview',
        fileStem: 'garage-overview',
        builder: (preferences) => _buildDashboardScenario(
          preferences: preferences,
          initialTab: 1,
        ),
      ),
      _ShowcaseScenario(
        id: 'settings-overview',
        fileStem: 'settings-overview',
        builder: (preferences) => _buildDashboardScenario(
          preferences: preferences,
          initialTab: 2,
        ),
      ),
    ];

    final requested = _screenArg
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();

    if (requested.isEmpty || requested.contains('all')) {
      return all;
    }

    final selected = all.where((scenario) => requested.contains(scenario.id)).toList();
    return selected.isEmpty ? all : selected;
  }
}

class _ShowcaseScenario {
  const _ShowcaseScenario({
    required this.id,
    required this.fileStem,
    required this.builder,
    this.previewSources = const <String>[],
    this.settleDuration = const Duration(milliseconds: 550),
  });

  final String id;
  final String fileStem;
  final Widget Function(AppPreferences preferences) builder;
  final List<String> previewSources;
  final Duration settleDuration;
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.scenario,
    required this.index,
    required this.total,
    required this.status,
    required this.outputDir,
    this.lastSavedPath,
    this.error,
  });

  final _ShowcaseScenario scenario;
  final int index;
  final int total;
  final String status;
  final String outputDir;
  final String? lastSavedPath;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xCC0E131A),
        border: Border.all(color: const Color(0x33FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.45,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${index + 1} / $total  •  ${scenario.id}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(status),
              const SizedBox(height: 6),
              Text(outputDir),
              if (lastSavedPath != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(lastSavedPath!),
              ],
              if (error != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  '$error',
                  style: const TextStyle(color: Color(0xFFFFA1A1)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

ThemeData _buildShowcaseTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  const primary = FTunePalette.accent;
  final bodyColor = isDark
      ? const Color(0xFFF6FAFF)
      : const Color(0xFF1D1F22);
  final textTheme = buildFTuneTextTheme(
    ThemeData(brightness: brightness).textTheme,
    bodyColor: bodyColor,
    displayColor: bodyColor,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
    ),
    textTheme: textTheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF171A1F) : const Color(0xFFF3F4F7),
  );
}

Widget _buildDashboardScenario({
  required AppPreferences preferences,
  required int initialTab,
  CreateTuneSession? pendingCreateSession,
  bool autoCalculateOnLoad = false,
  bool autoOpenResultPopupOnLoad = false,
  bool inlineResultPopupPreview = false,
}) {
  return _DashboardScenarioHost(
    preferences: preferences,
    initialTab: initialTab,
    pendingCreateSession: pendingCreateSession,
    autoCalculateOnLoad: autoCalculateOnLoad,
    autoOpenResultPopupOnLoad: autoOpenResultPopupOnLoad,
    inlineResultPopupPreview: inlineResultPopupPreview,
  );
}

class _DashboardScenarioHost extends StatefulWidget {
  const _DashboardScenarioHost({
    required this.preferences,
    required this.initialTab,
    this.pendingCreateSession,
    this.autoCalculateOnLoad = false,
    this.autoOpenResultPopupOnLoad = false,
    this.inlineResultPopupPreview = false,
  });

  final AppPreferences preferences;
  final int initialTab;
  final CreateTuneSession? pendingCreateSession;
  final bool autoCalculateOnLoad;
  final bool autoOpenResultPopupOnLoad;
  final bool inlineResultPopupPreview;

  @override
  State<_DashboardScenarioHost> createState() => _DashboardScenarioHostState();
}

class _DashboardScenarioHostState extends State<_DashboardScenarioHost> {
  late int _accentColorValue;

  @override
  void initState() {
    super.initState();
    _accentColorValue = widget.preferences.accentColorValue;
  }

  @override
  void didUpdateWidget(covariant _DashboardScenarioHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences.accentColorValue !=
        widget.preferences.accentColorValue) {
      _accentColorValue = widget.preferences.accentColorValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      key: ValueKey<String>(
        'dashboard-${widget.initialTab}-${widget.pendingCreateSession?.model ?? 'empty'}-${widget.autoCalculateOnLoad}-${widget.autoOpenResultPopupOnLoad}',
      ),
      languageCode: widget.preferences.languageCode,
      accentColorValue: _accentColorValue,
      isDarkMode: true,
      initialTab: widget.initialTab,
      autoCalculateOnLoad: widget.autoCalculateOnLoad,
      autoOpenResultPopupOnLoad: widget.autoOpenResultPopupOnLoad,
      inlineResultPopupPreview: widget.inlineResultPopupPreview,
      onAccentChange: (value) {
        if (_accentColorValue == value) return;
        setState(() => _accentColorValue = value);
      },
      onCreateTune: () {},
      onOpenGarage: () {},
      onOpenSettings: () {},
      pendingCreateSession: widget.pendingCreateSession,
      garageTunes: _sampleGarageRecords(),
      preferences: widget.preferences.copyWith(
        accentColorValue: _accentColorValue,
      ),
      onSaveTune: (_) {},
      onOpenOverlayTune: (_) async {},
      onDeleteTune: (_) {},
      onTogglePinnedTune: (_) {},
      onImportTune: () async {},
      onExportTune: (_) async {},
      onSetOverlayTune: (_) async {},
      onPreferencesChanged: (_) {},
      onPickBackground: () async {},
      onClearBackground: () async {},
      onDropBackground: (_) async => true,
      onOpenWelcomeTour: () {},
    );
  }
}

AppPreferences _samplePreferences() {
  return const AppPreferences.defaults().copyWith(
    languageCode: 'en',
    themeMode: 'dark',
    accentColorValue: FTunePalette.accent.toARGB32(),
    overlayPreviewEnabled: true,
    overlayOnTop: false,
  );
}

String _joinPath(String left, String right) {
  if (left.endsWith('\\') || left.endsWith('/')) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}

const String _fh5BoxArtUrl =
  'https://cdn.forza.net/strapi-uploads/assets/FH_5_Series40_POR_911_GT_3_RS_23_POR_911_Dakar_23_01_16x9_3840x2160_b767ece705.jpg';
const String _porscheHeroUrl =
  'https://static.wikia.nocookie.net/forzamotorsport/images/e/e3/FH5_Porsche_911_GT3_RS_2023.png/revision/latest/scale-to-width-down/800?cb=20241107031805';

CreateTuneSession _samplePorscheSession() {
  return const CreateTuneSession(
    metric: true,
    brand: 'Porsche',
    model: '911 GT3 RS',
    driveType: 'RWD',
    gameVersion: 'FH5',
    surface: 'Street',
    tuneType: 'Race',
    gearCount: 7,
    weightKg: '1450',
    frontDistributionPercent: '39',
    currentPi: '900',
    maxTorqueNm: '465',
    topSpeed: '304',
    frontTireSize: '275/35R20',
    rearTireSize: '335/30R21',
    powerBand: TuneCalcPowerBand(
      scaleMax: 9500,
      redlineRpm: 9000,
      maxTorqueRpm: 6300,
    ),
    tuneTitle: '911 GT3 RS Sprint',
    shareCode: '911 304 900',
  );
}

CreateTuneSession _sampleSession() {
  return const CreateTuneSession(
    metric: true,
    brand: 'Ariel',
    model: 'Nomad',
    driveType: 'RWD',
    gameVersion: 'FH5',
    surface: 'Street',
    tuneType: 'Race',
    gearCount: 6,
    weightKg: '670',
    frontDistributionPercent: '47',
    currentPi: '711',
    maxTorqueNm: '410',
    topSpeed: '232',
    frontTireSize: '255/35R19',
    rearTireSize: '275/30R19',
    powerBand: TuneCalcPowerBand(
      scaleMax: 10000,
      redlineRpm: 8800,
      maxTorqueRpm: 6100,
    ),
    tuneTitle: 'Ariel Nomad Grip',
    shareCode: '123 456 789',
  );
}

List<SavedTuneRecord> _sampleGarageRecords() {
  return <SavedTuneRecord>[
    _sampleRecord(
      id: 'sample-1',
      title: 'Ariel Nomad Grip',
      topSpeed: '232 km/h',
      createdAt: DateTime(2026, 4, 4),
      pinned: true,
    ),
    _sampleRecord(
      id: 'sample-2',
      title: '911 GT3 RS Sprint',
      brand: 'Porsche',
      model: '911 GT3 RS',
      driveType: 'RWD',
      surface: 'Street',
      tuneType: 'Race',
      piClass: 'S1 900',
      topSpeed: '304 km/h',
      createdAt: DateTime(2026, 4, 7),
    ),
    _sampleRecord(
      id: 'sample-3',
      title: 'GR Supra Rally',
      brand: 'Toyota',
      model: 'GR Supra',
      driveType: 'AWD',
      surface: 'Dirt',
      tuneType: 'Rally',
      piClass: 'A 792',
      topSpeed: '265 km/h',
      createdAt: DateTime(2026, 4, 9),
    ),
  ];
}

SavedTuneRecord _sampleRecord({
  required String id,
  required String title,
  required String topSpeed,
  required DateTime createdAt,
  String brand = 'Ariel',
  String model = 'Nomad',
  String driveType = 'RWD',
  String surface = 'Street',
  String tuneType = 'Race',
  String piClass = 'A 711',
  bool pinned = false,
}) {
  return SavedTuneRecord(
    id: id,
    title: title,
    shareCode: '123 456 789',
    brand: brand,
    model: model,
    driveType: driveType,
    surface: surface,
    tuneType: tuneType,
    piClass: piClass,
    topSpeedDisplay: topSpeed,
    result: _sampleResult(),
    createdAt: createdAt,
    session: _sampleSession(),
    isPinned: pinned,
  );
}

TuneCalcResult _sampleResult() {
  return const TuneCalcResult(
    cards: <TuneCalcCard>[
      TuneCalcCard(
        title: 'Pressure',
        sliders: <TuneCalcSlider>[
          TuneCalcSlider(
            side: 'Front',
            value: 2.1,
            min: 1.0,
            max: 3.5,
            decimals: 1,
            suffix: ' bar',
          ),
          TuneCalcSlider(
            side: 'Rear',
            value: 2.1,
            min: 1.0,
            max: 3.5,
            decimals: 1,
            suffix: ' bar',
          ),
        ],
      ),
      TuneCalcCard(
        title: 'Braking',
        sliders: <TuneCalcSlider>[
          TuneCalcSlider(
            side: 'Balance',
            value: 52.9,
            min: 30,
            max: 70,
            decimals: 1,
            suffix: '%',
          ),
        ],
      ),
    ],
    overview: TuneCalcOverview(
      topSpeedDisplay: '232 km/h',
      tireType: 'Sport',
      differentialType: 'Race',
      metrics: <TuneCalcMetric>[
        TuneCalcMetric(
          key: 'speed',
          label: 'Speed',
          color: Color(0xFFFF7A2F),
          score: 55,
          value: '55',
        ),
        TuneCalcMetric(
          key: 'handling',
          label: 'Handling',
          color: Color(0xFF26D4CF),
          score: 90,
          value: '90',
        ),
      ],
      detailSections: <TuneCalcDetailSection>[
        TuneCalcDetailSection(
          key: 'balance',
          title: 'Balance',
          color: Color(0xFF26D4CF),
          rows: <TuneCalcDetailRow>[
            TuneCalcDetailRow(label: 'Front', value: '52%', progress: 52),
            TuneCalcDetailRow(label: 'Rear', value: '48%', progress: 48),
          ],
        ),
      ],
    ),
    subtitle: 'Ariel Nomad • RWD • Street • Race • PI 711',
    gearing: TuneCalcGearingData(
      finalDrive: 2.51,
      redlineRpm: 10000,
      scaleMaxKmh: 260,
      ratios: <TuneCalcGearRatio>[
        TuneCalcGearRatio(gear: 1, ratio: 3.1, topSpeedKmh: 72),
        TuneCalcGearRatio(gear: 2, ratio: 2.1, topSpeedKmh: 108),
      ],
    ),
  );
}