import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/ftune_models.dart';
import '../../app/ftune_ui.dart';
import 'data/brand_logo_repository.dart';
import 'domain/car_spec.dart';
import 'domain/tune_calculation_service.dart';
import 'domain/tune_models.dart';

class CreateTunePage extends StatefulWidget {
  const CreateTunePage({
    super.key,
    this.initialMetric = true,
    this.initialSession,
    this.onBack,
    this.onMetricChanged,
    this.onSaveTune,
    this.onOpenOverlayTune,
    this.onGarageRequested,
    this.languageCode = 'en',
    this.themeMode = 'dark',
    this.overlayOnTop = true,
    this.onLanguageChanged,
    this.onThemeModeChanged,
    this.onOverlayOnTopChanged,
    this.backgroundImagePath,
    this.isPro = false,
  });

  final bool initialMetric;
  final CreateTuneSession? initialSession;
  final VoidCallback? onBack;
  final ValueChanged<bool>? onMetricChanged;
  final ValueChanged<SavedTuneDraft>? onSaveTune;
  final Future<void> Function(SavedTuneRecord? record)? onOpenOverlayTune;
  final VoidCallback? onGarageRequested;
  final String languageCode;
  final String themeMode;
  final bool overlayOnTop;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<String>? onThemeModeChanged;
  final ValueChanged<bool>? onOverlayOnTopChanged;
  final String? backgroundImagePath;
  final bool isPro;

  @override
  State<CreateTunePage> createState() => _CreateTunePageState();
}

class _CreateTunePageState extends State<CreateTunePage> {
  static final List<TextInputFormatter> _decimalInputFormatters =
      <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  ];
  static final List<TextInputFormatter> _integerInputFormatters =
      <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];
  static final List<TextInputFormatter> _tireInputFormatters =
      <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9Rr /]')),
  ];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _frontDistributionController =
      TextEditingController();
  final ScrollController _rightPaneScrollController = ScrollController();
  final TextEditingController _currentPiController = TextEditingController();
  final TextEditingController _powerBandController = TextEditingController();
  final TextEditingController _maxTorqueController = TextEditingController();
  final TextEditingController _topSpeedController = TextEditingController();
  final TextEditingController _frontTireSizeController =
      TextEditingController();
  final TextEditingController _rearTireSizeController = TextEditingController();

  List<CarSpec> _cars = const <CarSpec>[];
  Map<String, String> _thumbnailCatalog = const <String, String>{};
  bool _isLoading = true;
  String _query = '';
  String? _selectedBrand;
  CarSpec? _selectedModel;
  bool _metric = true;
  bool _sortAscending = true;
  String _driveType = 'RWD';
  String _gameVersion = 'FH5';
  String _surface = 'Street';
  String _tuneType = 'Race';
  int _gearCount = 6;
  _ResultStage _resultStage = _ResultStage.info;
  _SetupStep _setupStep = _SetupStep.info;
  String? _appliedSessionKey;

  _CreateCopy get _copy => _CreateCopy(widget.languageCode);

  @override
  void initState() {
    super.initState();
    _metric = widget.initialMetric;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _bindReactiveControllers();
    _loadCars();
  }

  @override
  void didUpdateWidget(covariant CreateTunePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMetric != widget.initialMetric &&
        _metric != widget.initialMetric) {
      setState(() => _metric = widget.initialMetric);
    }
    if (oldWidget.initialSession != widget.initialSession) {
      if (widget.initialSession == null) {
        _resetForNewTune();
      } else {
        _applyInitialSessionIfNeeded();
      }
    }
  }

  @override
  void dispose() {
    _unbindReactiveControllers();
    _searchController.dispose();
    _weightController.dispose();
    _frontDistributionController.dispose();
    _currentPiController.dispose();
    _powerBandController.dispose();
    _maxTorqueController.dispose();
    _topSpeedController.dispose();
    _frontTireSizeController.dispose();
    _rearTireSizeController.dispose();
    _rightPaneScrollController.dispose();
    super.dispose();
  }

  List<TextEditingController> get _reactiveControllers =>
      <TextEditingController>[
        _weightController,
        _frontDistributionController,
        _currentPiController,
        _powerBandController,
        _maxTorqueController,
        _topSpeedController,
        _frontTireSizeController,
        _rearTireSizeController,
      ];

  void _bindReactiveControllers() {
    for (final controller in _reactiveControllers) {
      controller.addListener(_handleReactiveFieldChange);
    }
  }

  void _unbindReactiveControllers() {
    for (final controller in _reactiveControllers) {
      controller.removeListener(_handleReactiveFieldChange);
    }
  }

  void _handleReactiveFieldChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadCars() async {
    final raw = await rootBundle.loadString('assets/data/FH5_cars.json');
    Map<String, String> thumbnails = const <String, String>{};
    try {
      final rawThumbnails =
          await rootBundle.loadString('assets/data/wiki_car_thumbnails.json');
      final decodedThumbnails =
          jsonDecode(rawThumbnails) as Map<String, dynamic>;
      thumbnails = decodedThumbnails.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    } catch (_) {
      thumbnails = const <String, String>{};
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    final cars = decoded
        .map((entry) => CarSpec.fromJson(entry as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        final brandCompare = a.brand.compareTo(b.brand);
        if (brandCompare != 0) return brandCompare;
        return a.model.compareTo(b.model);
      });

    if (!mounted) return;
    setState(() {
      _cars = cars;
      _thumbnailCatalog = thumbnails;
      _isLoading = false;
    });
    _applyInitialSessionIfNeeded();
  }

  List<BrandBucket> get _brandBuckets {
    final map = <String, List<CarSpec>>{};
    for (final car in _cars) {
      map.putIfAbsent(car.brand, () => <CarSpec>[]).add(car);
    }
    final buckets = map.entries
        .map((entry) => BrandBucket(entry.key, entry.value))
        .toList();
    buckets.sort((a, b) => _compareAlpha(a.brand, b.brand));
    return _sortAscending ? buckets : buckets.reversed.toList();
  }

  List<BrandBucket> get _visibleBrands {
    if (_query.isEmpty) return _brandBuckets;
    return _brandBuckets.where((bucket) {
      if (bucket.brand.toLowerCase().contains(_query)) return true;
      return bucket.models
          .any((car) => car.model.toLowerCase().contains(_query));
    }).toList();
  }

  List<CarSpec> get _visibleModels {
    final brand = _selectedBrand;
    if (brand == null) return const <CarSpec>[];
    final bucket = _brandBuckets.firstWhere(
      (entry) => entry.brand == brand,
      orElse: () => BrandBucket(brand, const <CarSpec>[]),
    );
    final models = _query.isEmpty
        ? bucket.models
        : bucket.models
            .where((car) => car.model.toLowerCase().contains(_query))
            .toList();
    return _sortCars(models);
  }

  void _selectBrand(String brand) {
    final selected = _sortCars(
      _cars.where((car) => car.brand == brand).toList(),
    ).firstOrNull;
    setState(() {
      _selectedBrand = brand;
      _selectedModel = selected;
      if (selected != null) {
        _driveType = selected.driveType;
        _seedFields(selected);
      }
      _resultStage = _ResultStage.info;
    });
  }

  void _backToBrands() {
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
      _resultStage = _ResultStage.info;
    });
  }

  void _toggleSortOrder() {
    setState(() => _sortAscending = !_sortAscending);
  }

  void _setDriveType(String value) {
    final front = _frontTireSizeController.text.trim();
    final rear = _rearTireSizeController.text.trim();

    setState(() {
      _driveType = value;
      if (value == 'FWD') {
        if (front.isEmpty && rear.isNotEmpty) {
          _frontTireSizeController.text = rear;
        }
        if (_rearTireSizeController.text.trim().isEmpty &&
            _frontTireSizeController.text.trim().isNotEmpty) {
          _rearTireSizeController.text = _frontTireSizeController.text.trim();
        }
      } else if (rear.isEmpty && front.isNotEmpty) {
        _rearTireSizeController.text = front;
      }
    });
  }

  void _adjustGearCount(int delta) {
    setState(() {
      _gearCount = (_gearCount + delta).clamp(2, 10);
    });
  }

  void _setResultStage(_ResultStage stage) {
    if (stage == _ResultStage.tune && _tuneResult == null) {
      return;
    }
    setState(() => _resultStage = stage);
  }

  void _selectModel(CarSpec car) {
    setState(() {
      _selectedBrand = car.brand;
      _selectedModel = car;
      _driveType = car.driveType;
      _seedFields(car);
      _resultStage = _ResultStage.info;
    });
  }

  String? _sessionKey(CreateTuneSession? session) {
    if (session == null) return null;
    return <String>[
      session.brand,
      session.model,
      session.tuneTitle,
      session.shareCode,
      session.currentPi,
      session.topSpeed,
      session.driveType,
      session.surface,
      session.tuneType,
      '${session.metric}',
      '${session.gearCount}',
    ].join('|');
  }

  void _resetForNewTune() {
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
      _query = '';
      _searchController.clear();
      _metric = widget.initialMetric;
      _driveType = 'RWD';
      _gameVersion = 'FH5';
      _surface = 'Street';
      _tuneType = 'Race';
      _gearCount = 6;
      _resultStage = _ResultStage.info;
      _weightController.clear();
      _frontDistributionController.clear();
      _currentPiController.clear();
      _powerBandController.clear();
      _maxTorqueController.clear();
      _topSpeedController.clear();
      _frontTireSizeController.clear();
      _rearTireSizeController.clear();
      _appliedSessionKey = null;
    });
  }

  void _applyInitialSessionIfNeeded() {
    final session = widget.initialSession;
    final sessionKey = _sessionKey(session);
    if (session == null || _cars.isEmpty || sessionKey == _appliedSessionKey) {
      return;
    }

    final matchedCar = _cars.cast<CarSpec?>().firstWhere(
          (car) => car?.brand == session.brand && car?.model == session.model,
          orElse: () => null,
        );

    setState(() {
      _selectedBrand = session.brand;
      _selectedModel = matchedCar;
      if (matchedCar != null) {
        _seedFields(matchedCar);
      }
      _metric = session.metric;
      _driveType = session.driveType;
      _gameVersion = session.gameVersion;
      _surface = session.surface;
      _tuneType = session.tuneType;
      _gearCount = session.gearCount.clamp(2, 10);
      if (session.weightKg.trim().isNotEmpty) {
        _weightController.text = session.weightKg.trim();
      }
      if (session.frontDistributionPercent.trim().isNotEmpty) {
        _frontDistributionController.text =
            session.frontDistributionPercent.trim();
      }
      if (session.currentPi.trim().isNotEmpty) {
        _currentPiController.text = session.currentPi.trim();
      }
      if (session.maxTorqueNm.trim().isNotEmpty) {
        _maxTorqueController.text = session.maxTorqueNm.trim();
      }
      if (session.topSpeed.trim().isNotEmpty) {
        _topSpeedController.text = session.topSpeed.trim();
      }
      _frontTireSizeController.text = session.frontTireSize.trim();
      _rearTireSizeController.text = session.rearTireSize.trim().isNotEmpty
          ? session.rearTireSize.trim()
          : session.frontTireSize.trim();
      _powerBandController.text = _powerBandText(session.powerBand);
      _appliedSessionKey = sessionKey;
    });
  }

  void _seedFields(CarSpec car) {
    var frontDistribution = 47;
    if (car.driveType == 'FWD') {
      frontDistribution = 61;
    } else if (car.driveType == 'AWD') {
      frontDistribution = 54;
    }
    final weight = (car.pi * 2.85 + 610).round();
    final torque = math.max(260, ((car.pi - 300) * 1.75).round());
    final topSpeed = car.topSpeedKmh.toStringAsFixed(0);
    final lowerSpeed = math.max(240, car.topSpeedKmh - 95).round();
    final upperSpeed = math.max(lowerSpeed + 120, car.topSpeedKmh + 18).round();
    var frontTireSizeText = '255 / 35 / R19';
    var rearTireSizeText = '275 / 30 / R19';
    if (car.driveType == 'AWD') {
      frontTireSizeText = '255 / 35 / R19';
      rearTireSizeText = '265 / 35 / R19';
    } else if (car.driveType == 'FWD') {
      frontTireSizeText = '245 / 40 / R18';
      rearTireSizeText = '245 / 40 / R18';
    }

    _weightController.text = '$weight';
    _frontDistributionController.text = '$frontDistribution';
    _currentPiController.text = '${car.pi}';
    _powerBandController.text = _powerBandText(
      TuneCalcPowerBand(
        scaleMax: math.max(10000, ((upperSpeed / 1000).ceil() * 1000)).toInt(),
        redlineRpm: upperSpeed,
        maxTorqueRpm: lowerSpeed,
      ),
    );
    _maxTorqueController.text = '$torque';
    _topSpeedController.text = topSpeed;
    _frontTireSizeController.text = frontTireSizeText;
    _rearTireSizeController.text = rearTireSizeText;
    _gearCount = car.driveType == 'AWD' ? 7 : 6;
  }

  TuneCalcResult? get _tuneResult {
    final car = _selectedModel;
    if (car == null) return null;

    final tireSize = _parseTireSize(_effectiveDriveTireSizeText);
    final powerBand = _parsePowerBand(_powerBandController.text);
    final input = TuneCalcInput(
      brand: car.brand,
      model: car.model,
      driveType: _driveType,
      surface: _surface,
      tuneType: _tuneType,
      pi: _readInt(_currentPiController.text, car.pi),
      topSpeedKmh: _readDouble(_topSpeedController.text, car.topSpeedKmh),
      weightKg: _readDouble(_weightController.text, car.pi * 2.85 + 610),
      frontDistributionPercent: _readDouble(
          _frontDistributionController.text,
          car.driveType == 'FWD'
              ? 61
              : car.driveType == 'AWD'
                  ? 54
                  : 47),
      maxTorqueNm: _readDouble(_maxTorqueController.text,
          math.max(260, ((car.pi - 300) * 1.75).round()).toDouble()),
      gears: _gearCount,
      tireWidth: tireSize.width,
      tireAspect: tireSize.aspect,
      tireRim: tireSize.rim,
      tireType: car.tireType,
      differentialType: car.differential,
      powerBand: powerBand,
    );
    return TuneCalculationService.calculate(input, metric: _metric);
  }

  int? get _currentPiValue {
    final car = _selectedModel;
    if (car == null) return null;
    return _readInt(_currentPiController.text, car.pi);
  }

  bool get _upgradeInfoReady {
    return _selectedModel != null &&
        _weightController.text.trim().isNotEmpty &&
        _currentPiController.text.trim().isNotEmpty &&
        _topSpeedController.text.trim().isNotEmpty &&
        _maxTorqueController.text.trim().isNotEmpty &&
        _frontTireSizeController.text.trim().isNotEmpty &&
        _rearTireSizeController.text.trim().isNotEmpty &&
        _powerBandController.text.trim().isNotEmpty;
  }

  bool get _resultReady => _tuneResult != null;

  String? _thumbnailFor(CarSpec car) {
    final url = _thumbnailCatalog['${car.brand} ${car.model}']?.trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  int _compareAlpha(String left, String right) {
    return left.toLowerCase().compareTo(right.toLowerCase());
  }

  List<CarSpec> _sortCars(List<CarSpec> models) {
    final sorted = models.toList()
      ..sort((a, b) => _compareAlpha(a.model, b.model));
    return _sortAscending ? sorted : sorted.reversed.toList();
  }

  String _piClassDisplay(int? pi) {
    return ftunePiClassDisplay(pi);
  }

  String get _effectiveDriveTireSizeText {
    final front = _frontTireSizeController.text.trim();
    final rear = _rearTireSizeController.text.trim();
    switch (_driveType) {
      case 'FWD':
        return front.isNotEmpty
            ? front
            : (rear.isNotEmpty ? rear : '245 / 40 / R18');
      case 'RWD':
        return rear.isNotEmpty
            ? rear
            : (front.isNotEmpty ? front : '275 / 30 / R19');
      case 'AWD':
        return rear.isNotEmpty
            ? rear
            : (front.isNotEmpty ? front : '255 / 35 / R19');
      default:
        return rear.isNotEmpty
            ? rear
            : (front.isNotEmpty ? front : '275 / 30 / R19');
    }
  }

  String _powerBandText(TuneCalcPowerBand powerBand) {
    return '${powerBand.maxTorqueRpm} - ${powerBand.redlineRpm} RPM';
  }

  CreateTuneSession? _captureSession({
    required String tuneTitle,
    required String shareCode,
  }) {
    final car = _selectedModel;
    if (car == null) return null;
    return CreateTuneSession(
      metric: _metric,
      brand: car.brand,
      model: car.model,
      driveType: _driveType,
      gameVersion: _gameVersion,
      surface: _surface,
      tuneType: _tuneType,
      gearCount: _gearCount,
      weightKg: _weightController.text.trim(),
      frontDistributionPercent: _frontDistributionController.text.trim(),
      currentPi: _currentPiController.text.trim(),
      maxTorqueNm: _maxTorqueController.text.trim(),
      topSpeed: _topSpeedController.text.trim(),
      frontTireSize: _frontTireSizeController.text.trim(),
      rearTireSize: _rearTireSizeController.text.trim(),
      powerBand: _parsePowerBand(_powerBandController.text),
      tuneTitle: tuneTitle,
      shareCode: shareCode,
    );
  }

  ModelInsight? get _insight {
    final car = _selectedModel;
    final result = _tuneResult;
    if (car == null || result == null) return null;

    final overview = result.overview;
    final pressureCard = _findCalcCard(result.cards, 'pressure');
    final brakeCard = _findCalcCard(result.cards, 'braking');
    final gearingCard = _findCalcCard(result.cards, 'gearing');

    final pressureFront = _findCalcSlider(pressureCard, 'f');
    final pressureRear = _findCalcSlider(pressureCard, 'r');
    final brakeBalance = _findCalcSlider(brakeCard, 'balance');
    final finalDrive = _findCalcSlider(gearingCard, 'final');

    return ModelInsight(
      title: '${car.brand} ${car.model}',
      subtitle: result.subtitle,
      metrics: overview.metrics
          .map((metric) =>
              InsightMetric(metric.label, metric.score, metric.color))
          .toList(),
      details: <InsightDetail>[
        InsightDetail('Differential', overview.differentialType),
        InsightDetail('Tire compound', overview.tireType),
        InsightDetail('Top speed', overview.topSpeedDisplay),
        InsightDetail(
          'Pressure F/R',
          '${pressureFront == null ? '--' : _formatCalcSlider(pressureFront)} / ${pressureRear == null ? '--' : _formatCalcSlider(pressureRear)}',
        ),
        InsightDetail(
          'Brake balance',
          brakeBalance == null ? '--' : _formatCalcSlider(brakeBalance),
        ),
        InsightDetail(
          'Final drive',
          finalDrive == null ? '--' : _formatCalcSlider(finalDrive),
        ),
      ],
      sections: overview.detailSections,
    );
  }

  _TireSizeSpec _parseTireSize(String value) {
    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(value).toList();
    if (matches.length >= 3) {
      return _TireSizeSpec(
        width: double.tryParse(matches[0].group(0) ?? '') ?? 275,
        aspect: double.tryParse(matches[1].group(0) ?? '') ?? 30,
        rim: double.tryParse(matches[2].group(0) ?? '') ?? 19,
      );
    }
    return const _TireSizeSpec(width: 275, aspect: 30, rim: 19);
  }

  TuneCalcPowerBand _parsePowerBand(String value) {
    final matches = RegExp(r'(\d+)').allMatches(value).toList();
    final torquePeak = matches.isNotEmpty
        ? int.tryParse(matches.first.group(0) ?? '') ?? 6800
        : 6800;
    final redline = matches.length > 1
        ? int.tryParse(matches[1].group(0) ?? '') ?? 10000
        : 10000;
    final scaleMax = math.max(10000, ((redline / 1000).ceil() * 1000)).toInt();
    return TuneCalcPowerBand(
      scaleMax: scaleMax,
      redlineRpm: redline,
      maxTorqueRpm: math.min(torquePeak, redline).toInt(),
    );
  }

  Future<void> _openPowerBandEditor() async {
    final initialBand = _parsePowerBand(_powerBandController.text);
    final result = await showDialog<TuneCalcPowerBand>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PowerBandModal(
        initialBand: initialBand,
        languageCode: widget.languageCode,
      ),
    );
    if (result != null && mounted) {
      _powerBandController.text = _powerBandText(result);
    }
  }

  double _readDouble(String raw, double fallback) {
    final numeric = double.tryParse(raw.trim());
    return numeric ?? fallback;
  }

  int _readInt(String raw, int fallback) {
    final numeric = int.tryParse(raw.trim());
    return numeric ?? fallback;
  }

  TuneCalcCard? _findCalcCard(List<TuneCalcCard> cards, String token) {
    final normalized =
        token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    for (final card in cards) {
      final title =
          card.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (title.contains(normalized)) return card;
    }
    return null;
  }

  TuneCalcSlider? _findCalcSlider(TuneCalcCard? card, String sideToken) {
    if (card == null) return null;
    final normalized =
        sideToken.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    for (final slider in card.sliders) {
      final side =
          slider.side.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (side == normalized || side.contains(normalized)) return slider;
    }
    return null;
  }

  String _formatCalcSlider(TuneCalcSlider slider) {
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

  String _buildTuneSummaryText({
    required CarSpec car,
    required TuneCalcResult result,
    required String tuneTitle,
    required String shareCode,
  }) {
    final lines = <String>[
      tuneTitle.isEmpty ? '${car.brand} ${car.model}' : tuneTitle,
      'PI: ${_piClassDisplay(_currentPiValue)}',
      'Drive: $_driveType',
      'Surface: $_surface',
      'Tune: $_tuneType',
      if (shareCode.isNotEmpty) 'Share Code: $shareCode',
      '',
      'Top Speed: ${result.overview.topSpeedDisplay}',
      'Tire: ${result.overview.tireType}',
      'Differential: ${result.overview.differentialType}',
      'Power Band: ${_powerBandController.text.trim()}',
      'Front Tire: ${_frontTireSizeController.text.trim()}',
      'Rear Tire: ${_rearTireSizeController.text.trim()}',
      '',
    ];

    for (final card in result.cards) {
      lines.add(card.title);
      for (final slider in card.sliders) {
        lines.add('- ${slider.side}: ${_formatCalcSlider(slider)}');
      }
      lines.add('');
    }

    lines.add('Gearing');
    lines.add('- Final Drive: ${result.gearing.finalDrive.toStringAsFixed(2)}');
    for (final ratio in result.gearing.ratios) {
      lines.add('- G${ratio.gear}: ${ratio.ratio.toStringAsFixed(2)}');
    }

    return lines.join('\n').trim();
  }

  Future<void> _copyTuneSummary({
    required BuildContext context,
    required String text,
    required String message,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<_ComparisonMetricData> _buildComparisonMetrics(
    CarSpec car,
    TuneCalcResult result,
  ) {
    final topSpeed = _readDouble(_topSpeedController.text, car.topSpeedKmh);
    final weight = _readDouble(_weightController.text, car.pi * 2.85 + 610);
    final torque = _readDouble(
      _maxTorqueController.text,
      math.max(260, ((car.pi - 300) * 1.75).round()).toDouble(),
    );
    final frontDistribution = _readDouble(
      _frontDistributionController.text,
      car.driveType == 'FWD'
          ? 61
          : car.driveType == 'AWD'
              ? 54
              : 47,
    );

    final tunedScores = <String, int>{
      for (final metric in result.overview.metrics)
        metric.label.toLowerCase(): metric.score,
    };

    int fallback(String label, int value) {
      return tunedScores[label.toLowerCase()] ?? value;
    }

    return <_ComparisonMetricData>[
      _ComparisonMetricData(
        label: 'Speed',
        stockValue: ((topSpeed / 420) * 100).round().clamp(10, 99).toInt(),
        tunedValue: fallback('speed', 70),
        accent: const Color(0xFFFF8C42),
      ),
      _ComparisonMetricData(
        label: 'Handling',
        stockValue: (100 - (frontDistribution - 50).abs() * 1.8)
            .round()
            .clamp(10, 99)
            .toInt(),
        tunedValue: fallback('handling', 72),
        accent: const Color(0xFF00E5FF),
      ),
      _ComparisonMetricData(
        label: 'Accel',
        stockValue: ((torque / 14) + ((_currentPiValue ?? car.pi) - 500) * 0.08)
            .round()
            .clamp(10, 99)
            .toInt(),
        tunedValue: fallback('accel', 74),
        accent: const Color(0xFFFFB547),
      ),
      _ComparisonMetricData(
        label: 'Launch',
        stockValue: ((52 +
                (_driveType == 'AWD'
                    ? 16
                    : _driveType == 'RWD'
                        ? 10
                        : 6) +
                _gearCount * 2.5))
            .round()
            .clamp(10, 99)
            .toInt(),
        tunedValue: fallback('launch', 76),
        accent: const Color(0xFFB07CFF),
      ),
      _ComparisonMetricData(
        label: 'Braking',
        stockValue: ((118 - (weight / 55) - (frontDistribution - 50).abs()))
            .round()
            .clamp(10, 99)
            .toInt(),
        tunedValue: fallback('braking', 71),
        accent: const Color(0xFF5B95FF),
      ),
    ];
  }

  Future<void> _showTuneResultPreview(BuildContext context) async {
    final result = _tuneResult;
    final car = _selectedModel;
    if (result == null || car == null) return;

    final initialTitle = widget.initialSession?.tuneTitle.trim();
    final nameController = TextEditingController(
      text: initialTitle == null || initialTitle.isEmpty
          ? '${car.brand} ${car.model}'
          : initialTitle,
    );
    final shareController = TextEditingController(
      text: widget.initialSession?.shareCode ?? '',
    );
    final previewStage = ValueNotifier<_ResultStage>(_resultStage);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 760),
            child: LayoutBuilder(
              builder: (context, dialogConstraints) {
                final stackedForm = dialogConstraints.maxWidth < 720;
                final comparisonMetrics = _buildComparisonMetrics(car, result);

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Tune Results Preview',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  result.subtitle,
                                  style: TextStyle(
                                    color: FTuneElectronPaletteData.of(context)
                                        .muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _roundIconButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (stackedForm)
                        Column(
                          children: <Widget>[
                            TextField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                hintText: 'Tune name',
                                prefixIcon: Icon(
                                    Icons.drive_file_rename_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: shareController,
                              decoration: const InputDecoration(
                                hintText: 'Share code (optional)',
                                prefixIcon: Icon(Icons.tag_rounded),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  hintText: 'Tune name',
                                  prefixIcon: Icon(
                                      Icons.drive_file_rename_outline_rounded),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: shareController,
                                decoration: const InputDecoration(
                                  hintText: 'Share code (optional)',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: <Widget>[
                                  _summaryChip('${car.brand} ${car.model}',
                                      filled: true),
                                  _summaryChip(
                                      _metric ? _copy.metric : _copy.imperial),
                                  _summaryChip(result.overview.topSpeedDisplay),
                                  _summaryChip(result.overview.tireType),
                                  _summaryChip(
                                      result.overview.differentialType),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<_ResultStage>(
                                valueListenable: previewStage,
                                builder: (context, stage, _) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      _buildResultStepSwitcher(
                                        compact:
                                            dialogConstraints.maxWidth < 760,
                                        currentStage: stage,
                                        onStageChanged: (_ResultStage value) {
                                          previewStage.value = value;
                                          if (mounted) {
                                            setState(
                                                () => _resultStage = value);
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      if (stage == _ResultStage.info)
                                        _buildPreviewInfoPanel(
                                          car: car,
                                          result: result,
                                          comparisonMetrics: comparisonMetrics,
                                        )
                                      else
                                        _buildPreviewTunePanel(
                                          result: result,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () {
                              _copyTuneSummary(
                                context: context,
                                text: _buildTuneSummaryText(
                                  car: car,
                                  result: result,
                                  tuneTitle: nameController.text.trim(),
                                  shareCode: shareController.text.trim(),
                                ),
                                message: 'Tune summary copied.',
                              );
                            },
                            icon: const Icon(Icons.copy_all_rounded),
                            label: const Text('COPY ALL'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _copyTuneSummary(
                                context: context,
                                text: _buildTuneSummaryText(
                                  car: car,
                                  result: result,
                                  tuneTitle: nameController.text.trim(),
                                  shareCode: shareController.text.trim(),
                                ),
                                message: 'Share-ready summary copied.',
                              );
                            },
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('SHARE'),
                          ),
                          if (widget.onGarageRequested != null)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                widget.onGarageRequested?.call();
                              },
                              icon: const Icon(Icons.garage_rounded),
                              label: const Text('OPEN GARAGE'),
                            ),
                          FilledButton.icon(
                            onPressed: () {
                              final tuneTitle = nameController.text.trim();
                              final shareCode = shareController.text.trim();
                              widget.onSaveTune?.call(
                                SavedTuneDraft(
                                  title: tuneTitle,
                                  shareCode: shareCode,
                                  brand: car.brand,
                                  model: car.model,
                                  driveType: _driveType,
                                  surface: _surface,
                                  tuneType: _tuneType,
                                  piClass: _piClassDisplay(_currentPiValue),
                                  topSpeedDisplay:
                                      result.overview.topSpeedDisplay,
                                  result: result,
                                  session: _captureSession(
                                    tuneTitle: tuneTitle,
                                    shareCode: shareCode,
                                  ),
                                ),
                              );
                              Navigator.of(dialogContext).pop();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Tune saved to Garage.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('SAVE TO GARAGE'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    previewStage.dispose();
  }

  Widget _buildPreviewInfoPanel({
    required CarSpec car,
    required TuneCalcResult result,
    required List<_ComparisonMetricData> comparisonMetrics,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Info',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${car.brand} ${car.model} · ${_piClassDisplay(_currentPiValue)}',
            style: const TextStyle(color: FTunePalette.textMuted),
          ),
          const SizedBox(height: 14),
          _ComparisonSplitPreview(
            metrics: comparisonMetrics,
            leftTitle: 'Stock',
            rightTitle: 'Tuned',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: result.overview.metrics
                .map(
                  (metric) => _metricRing(
                    InsightMetric(metric.label, metric.score, metric.color),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTunePanel({
    required TuneCalcResult result,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tune',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Separated outputs keep the lower area stable and easier to scan.',
            style: TextStyle(color: FTunePalette.textMuted),
          ),
          const SizedBox(height: 14),
          _buildGearingPreview(result.gearing, embedded: true),
          const SizedBox(height: 14),
          _buildTuneCardsPreview(result.cards, embedded: true),
        ],
      ),
    );
  }

  Widget _buildTuneCardsPreview(List<TuneCalcCard> cards,
      {bool embedded = false}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Calculated Setup',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map(_buildTuneCardPreview).toList(),
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return _glassCard(
      child: content,
    );
  }

  Widget _buildTuneCardPreview(TuneCalcCard card) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final slider in card.sliders) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    slider.side.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _formatCalcSlider(slider),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: slider.max <= slider.min
                    ? 0
                    : ((slider.value - slider.min) / (slider.max - slider.min))
                        .clamp(0, 1)
                        .toDouble(),
                minHeight: 5,
                backgroundColor: palette.surfaceSoft,
                valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildGearingPreview(TuneCalcGearingData gearing,
      {bool embedded = false}) {
    final palette = FTuneElectronPaletteData.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Gearing Preview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _summaryChip('FD ${gearing.finalDrive.toStringAsFixed(2)}',
                filled: true),
            _summaryChip('${gearing.ratios.length} gears'),
            _summaryChip('${gearing.redlineRpm.round()} rpm'),
          ],
        ),
        const SizedBox(height: 14),
        for (final ratio in gearing.ratios) ...<Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 34,
                child: Text(
                  'G${ratio.gear}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (ratio.topSpeedKmh / gearing.scaleMaxKmh)
                        .clamp(0, 1)
                        .toDouble(),
                    minHeight: 8,
                    backgroundColor: palette.surfaceSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 54,
                child: Text(
                  ratio.ratio.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 74,
                child: Text(
                  _metric
                      ? '${ratio.topSpeedKmh.toStringAsFixed(0)} km/h'
                      : '${(ratio.topSpeedKmh * 0.6213711922).toStringAsFixed(0)} mph',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );

    if (embedded) {
      return InkWell(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) => _GearingChartModal(
              gearing: gearing,
              powerBand: _parsePowerBand(_powerBandController.text),
              palette: FTuneElectronPaletteData.of(context),
              copy: _CreateCopy(widget.languageCode),
            ),
          );
        },
        child: content,
      );
    }

    return _glassCard(
      child: InkWell(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) => _GearingChartModal(
              gearing: gearing,
              powerBand: _parsePowerBand(_powerBandController.text),
              palette: FTuneElectronPaletteData.of(context),
              copy: _CreateCopy(widget.languageCode),
            ),
          );
        },
        child: content,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked =
            constraints.maxWidth < 1140 || constraints.maxHeight < 760;
        // SizedBox.expand() enforces tight bounds so that
        // FractionallySizedBox inside the glass frame gets finite constraints.
        return SizedBox.expand(
          child: _buildShell(context, isStacked),
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, bool isStacked) {
    final palette = FTuneElectronPaletteData.of(context);
    return FTuneElectronSurface(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: palette.surface,
          dividerColor: palette.border,
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: palette.text,
                displayColor: palette.text,
              ),
        ),
        child: Column(
          children: <Widget>[
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, bodyConstraints) {
                    if (isStacked) {
                      return SingleChildScrollView(
                        child: Column(
                          children: <Widget>[
                            _buildVehiclePanel(isStacked: true),
                            const SizedBox(height: 14),
                            _buildRightPane(compact: true),
                          ],
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 344,
                          height: bodyConstraints.maxHeight,
                          child: _buildVehiclePanel(isStacked: false),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: _buildRightPane(compact: false)),
                      ],
                    );
                  },
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final palette = FTuneElectronPaletteData.of(context);
        final copy = _copy;
        final stacked = constraints.maxWidth < 760;
        final toggles = Container(
          height: 38,
          decoration: BoxDecoration(
            color: palette.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    setState(() => _metric = true);
                    widget.onMetricChanged?.call(true);
                  },
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  child: Container(
                    width: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _metric ? palette.accent : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                    ),
                    child: Text(
                      copy.metric,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _metric ? Colors.white : palette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: palette.border),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    setState(() => _metric = false);
                    widget.onMetricChanged?.call(false);
                  },
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                  child: Container(
                    width: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_metric ? palette.accent : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                    ),
                    child: Text(
                      copy.imperial,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: !_metric ? Colors.white : palette.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final title = Text(
          copy.headerTitle,
          style: TextStyle(
            fontSize: stacked ? 28 : 34,
            fontWeight: FontWeight.w800,
            color: palette.text,
            letterSpacing: -0.7,
          ),
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(
              bottom: BorderSide(color: palette.headerDivider),
            ),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        _roundIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: widget.onBack,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: title),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: toggles,
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    _roundIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: widget.onBack,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: title),
                    toggles,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFooter() {
    final palette = FTuneElectronPaletteData.of(context);
    final copy = _copy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;
          final button = _tuneNowButton(
            onPressed: !_upgradeInfoReady
                ? null
                : () => _showTuneResultPreview(context),
          );

          if (stacked) {
            return Padding(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    copy.footerNote,
                    style: TextStyle(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: button),
                ],
              ),
            );
          }

          return Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  copy.footerNote,
                  style: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _tuneNowButton({required VoidCallback? onPressed}) {
    final palette = FTuneElectronPaletteData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final copy = _copy;
    final enabled = onPressed != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: enabled ? scheme.primary : palette.surfaceSoft,
            border: Border.all(
              color: enabled ? scheme.primary : palette.border,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: enabled ? palette.glow : Colors.transparent,
                blurRadius: 20,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                copy.calculate,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: enabled ? scheme.onPrimary : palette.muted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: enabled ? scheme.onPrimary : palette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehiclePanel({required bool isStacked}) {
    final copy = _copy;
    final browser = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FTuneElectronPaletteData.of(context).border),
        color: FTuneElectronPaletteData.of(context).surfaceHover,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _selectedBrand == null
                  ? _buildBrandList(_visibleBrands)
                  : _buildModelList(_visibleModels),
            ),
    );

    final panel = _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.72,
                color: FTuneElectronPaletteData.of(context).text,
              ),
              children: <InlineSpan>[
                TextSpan(text: copy.selectCarStep),
                if (_selectedBrand != null)
                  TextSpan(
                    text: '  ${_selectedBrand!}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0,
                      color: FTunePalette.electronAccent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              if (_selectedBrand != null) ...<Widget>[
                _roundIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: _backToBrands),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: copy.filterHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sortToggleButton(),
            ],
          ),
          const SizedBox(height: 14),
          if (isStacked)
            SizedBox(height: 420, child: browser)
          else
            Expanded(child: browser),
        ],
      ),
    );

    if (isStacked) {
      return panel;
    }

    return SizedBox.expand(child: panel);
  }

  Widget _buildBrandList(List<BrandBucket> buckets) {
    return ListView.separated(
      key: const ValueKey<String>('brands'),
      padding: const EdgeInsets.all(12),
      itemCount: buckets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bucket = buckets[index];
        return _selectableTile(
          title: bucket.brand,
          subtitle: _copy.modelCount(bucket.models.length),
          leading: _brandBadge(bucket.brand),
          onTap: () => _selectBrand(bucket.brand),
        );
      },
    );
  }

  Widget _buildModelList(List<CarSpec> models) {
    final featured = _selectedModel ?? models.firstOrNull;
    return Column(
      key: const ValueKey<String>('models'),
      children: <Widget>[
        if (featured != null) _buildPreviewCard(featured),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: models.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final car = models[index];
              return _selectableTile(
                title: car.model,
                subtitle: identical(car, _selectedModel)
                    ? '$_driveType • ${car.tireType}'
                    : car.driveType,
                leading: _brandBadge(car.brand, size: 40),
                trailing: FTunePiBadge.fromPi(
                  identical(car, _selectedModel) ? _currentPiValue : car.pi,
                  compact: true,
                ),
                selected: identical(car, _selectedModel),
                onTap: () => _selectModel(car),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRightPane({required bool compact}) {
    final insight = _insight;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isUnbounded = constraints.maxHeight == double.infinity;
        
        final content = _setupStep == _SetupStep.info
            ? _buildModelInfoCard(insight, compact: compact)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildPerformanceCard(compact: compact),
                  SizedBox(height: compact ? 14 : 12),
                  _buildAdvancedCard(compact: compact),
                  SizedBox(height: compact ? 14 : 12),
                  _buildConfigurationCard(compact: compact),
                  SizedBox(height: compact ? 14 : 12),
                  _buildEnvironmentCard(compact: compact),
                ],
              );
              
        final scrollingArea = isUnbounded
            ? content
            : Scrollbar(
                controller: _rightPaneScrollController,
                child: SingleChildScrollView(
                  controller: _rightPaneScrollController,
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: content,
                  ),
                ),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _resultStepChip(
                    label: _copy.stepInfo,
                    selected: _setupStep == _SetupStep.info,
                    onTap: () => setState(() => _setupStep = _SetupStep.info),
                    compact: compact,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _resultStepChip(
                    label: 'Step 2: Settings',
                    selected: _setupStep == _SetupStep.tune,
                    onTap: insight != null
                        ? () => setState(() => _setupStep = _SetupStep.tune)
                        : null,
                    compact: compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isUnbounded) scrollingArea else Expanded(child: scrollingArea),
          ],
        );
      },
    );
  }

  Widget _buildModelInfoCard(ModelInsight? insight, {required bool compact}) {
    final car = _selectedModel;
    final copy = _copy;
    return _glassCard(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    copy.modelInfoTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    copy.infoSnapshotTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: FTuneElectronPaletteData.of(context).muted,
                    ),
                  ),
                ],
              ),
              if (car != null) ...<Widget>[
                const Spacer(),
                _brandBadge(car.brand, size: 32),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (insight == null)
            Container(
              height: compact ? 96 : 112,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: FTuneElectronPaletteData.of(context).surfaceAlt,
                border: Border.all(
                    color: FTuneElectronPaletteData.of(context).border),
              ),
              child: Text(
                copy.modelInfoEmpty,
                style: TextStyle(
                    color: FTuneElectronPaletteData.of(context).muted),
              ),
            )
          else ...<Widget>[
            _buildInsightHero(insight, car, compact: compact),
            const SizedBox(height: 12),
            _buildInfoSnapshotPanel(insight, compact: compact),
            const SizedBox(height: 10),
            _buildTuneSnapshotPanel(insight, compact: compact),
          ],
        ],
      ),
    );
  }

  Widget _buildResultStepSwitcher({
    required bool compact,
    _ResultStage? currentStage,
    ValueChanged<_ResultStage>? onStageChanged,
  }) {
    final stage = currentStage ?? _resultStage;
    final handleStageChanged = onStageChanged ?? _setResultStage;

    return Row(
      children: <Widget>[
        Expanded(
          child: _resultStepChip(
            label: _copy.stepInfo,
            selected: stage == _ResultStage.info,
            onTap: () => handleStageChanged(_ResultStage.info),
            compact: compact,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _resultStepChip(
            label: _copy.stepTune,
            selected: stage == _ResultStage.tune,
            onTap: _resultReady
                ? () => handleStageChanged(_ResultStage.tune)
                : null,
            compact: compact,
          ),
        ),
      ],
    );
  }

  Widget _resultStepChip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    required bool compact,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    final enabled = onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? palette.accentSoft : palette.surfaceAlt,
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: enabled ? palette.text : palette.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSnapshotPanel(ModelInsight insight,
      {required bool compact}) {
    return _insightSection(
      title: _copy.vehicleSnapshotTitle,
      child: _adaptiveGrid(
        children: insight.details.map(_detailCard).toList(),
        minChildWidth: compact ? 145 : 170,
        maxColumns: compact ? 2 : 3,
      ),
    );
  }

  Widget _buildTuneSnapshotPanel(ModelInsight insight,
      {required bool compact}) {
    return _insightSection(
      title: _copy.performanceMetricsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _adaptiveGrid(
            children: insight.metrics.map(_metricRing).toList(),
            minChildWidth: compact ? 126 : 140,
            maxColumns: compact ? 2 : 5,
          ),
          if (insight.sections.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final double minWidth = compact ? 220 : 260;
                final bool singleColumn = constraints.maxWidth < (minWidth * 2 + 10);
                
                if (singleColumn) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: insight.sections.map((sec) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _detailSectionCard(sec),
                    )).toList(),
                  );
                }

                final List<Widget> col1 = [];
                final List<Widget> col2 = [];
                final sections = insight.sections.toList();
                
                for (var i = 0; i < sections.length; i++) {
                  final card = Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _detailSectionCard(sections[i]),
                  );
                  if (i % 2 == 0) {
                    col1.add(card);
                  } else {
                    col2.add(card);
                  }
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: col1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: col2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceCard({required bool compact}) {
    final copy = _copy;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.performanceCardTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _adaptiveGrid(
            children: <Widget>[
              _fieldBlock(copy.weightLabel, _weightController,
                  hint: 'Enter weight',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters),
              _fieldBlock(
                  copy.frontDistributionLabel, _frontDistributionController,
                  hint: 'Enter front distribution',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters),
              _currentPiField(),
            ],
            minChildWidth: compact ? 180 : 200,
            maxColumns: compact ? 1 : 2,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard({required bool compact}) {
    final copy = _copy;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.advancedTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _adaptiveGrid(
            children: <Widget>[
              _powerBandTrigger(compact: compact),
              _fieldBlock(copy.maxTorqueLabel, _maxTorqueController,
                  hint: 'Enter torque',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters),
              _gearTile(compact: compact),
              _fieldBlock(copy.topSpeedLabel, _topSpeedController,
                  hint: 'Enter top speed',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalInputFormatters),
              _fieldBlock(copy.frontTireLabel, _frontTireSizeController,
                  hint: '255 / 35 / R19',
                  inputFormatters: _tireInputFormatters),
              _fieldBlock(copy.rearTireLabel, _rearTireSizeController,
                  hint: '275 / 30 / R19',
                  inputFormatters: _tireInputFormatters),
            ],
            minChildWidth: compact ? 180 : 200,
            maxColumns: compact ? 1 : 2,
          ),
          const SizedBox(height: 10),
          _contextNote(
            icon: Icons.info_outline_rounded,
            label: copy.tireNote(_driveType),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard({required bool compact}) {
    final copy = _copy;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.configurationTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _selectionGroup(copy.driveTypeLabel, <String>['FWD', 'AWD', 'RWD'],
              _driveType, _setDriveType,
              columns: compact ? 3 : 3),
          const SizedBox(height: 14),
          _selectionGroup(copy.gameVersionLabel, <String>['FH5', 'FH6'],
              _gameVersion, (value) {
            if (value == 'FH6' && !widget.isPro) {
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
            setState(() => _gameVersion = value);
          }, columns: 2),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard({required bool compact}) {
    final copy = _copy;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.environmentTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _selectionGroup(
              copy.surfaceLabel,
              <String>['Street', 'Dirt', 'Cross', 'Off-road'],
              _surface,
              (value) => setState(() => _surface = value),
              columns: compact ? 2 : 2),
          const SizedBox(height: 14),
          _selectionGroup(copy.tuneTypeLabel, <String>['Race', 'Drag'],
              _tuneType, (value) => setState(() => _tuneType = value),
              columns: compact ? 2 : 2),
        ],
      ),
    );
  }

  Widget _currentPiField() {
    final palette = FTuneElectronPaletteData.of(context);
    final copy = _copy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.currentPiLabel.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.muted)),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _currentPiController,
                keyboardType: TextInputType.number,
                inputFormatters: _integerInputFormatters,
                decoration: InputDecoration(
                  hintText: copy.currentPiHint,
                  filled: true,
                  fillColor: palette.surfaceAlt,
                  hintStyle: TextStyle(color: palette.muted),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.borderStrong),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: palette.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FTunePiBadge.fromPi(_currentPiValue, compact: true),
          ],
        ),
      ],
    );
  }

  Widget _powerBandTrigger({required bool compact}) {
    final palette = FTuneElectronPaletteData.of(context);
    final copy = _copy;
    final band = _parsePowerBand(_powerBandController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(copy.powerBandLabel.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.muted)),
        const SizedBox(height: 8),
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _openPowerBandEditor,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              padding: EdgeInsets.all(compact ? 12 : 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    palette.surfaceHover,
                    palette.surface,
                  ],
                ),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _powerBandText(band),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 16 : 17,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.powerBandHint,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: palette.surfaceAlt,
                      border: Border.all(color: palette.border),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: palette.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gearTile({required bool compact}) {
    final palette = FTuneElectronPaletteData.of(context);
    final copy = _copy;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.surfaceHover,
            palette.surface,
          ],
        ),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(copy.gearsLabel.toUpperCase(),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.muted)),
              const Spacer(),
              Text(
                '2-10',
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _stepperButton(
                icon: Icons.remove_rounded,
                onTap: _gearCount > 2 ? () => _adjustGearCount(-1) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_gearCount',
                    style: TextStyle(
                      fontSize: compact ? 24 : 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              _stepperButton(
                icon: Icons.add_rounded,
                onTap: _gearCount < 10 ? () => _adjustGearCount(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    final enabled = onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: enabled ? palette.surfaceAlt : palette.surfaceSoft,
            border: Border.all(
              color: enabled ? palette.border : palette.border,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? palette.text : palette.muted,
          ),
        ),
      ),
    );
  }

  Widget _contextNote({
    required IconData icon,
    required String label,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: palette.surfaceHover,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: palette.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightHero(ModelInsight insight, CarSpec? car,
      {required bool compact}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final palette = FTuneElectronPaletteData.of(context);
        final stacked = compact || constraints.maxWidth < 580;
        final headline = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              insight.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 18 : 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        );

        final tags = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FTunePill(_driveType, compact: true),
            if (car != null)
              FTunePill(car.tireType, filled: true, compact: true),
            FTunePill(_surface, compact: true),
            FTunePill(_tuneType, compact: true),
          ],
        );

        return Container(
          padding: EdgeInsets.all(compact ? 14 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: palette.surfaceHover,
            border: Border.all(color: palette.border),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: headline),
                        const SizedBox(width: 12),
                        FTunePiBadge.fromPi(_currentPiValue, compact: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    tags,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: headline),
                        const SizedBox(width: 12),
                        FTunePiBadge.fromPi(_currentPiValue),
                      ],
                    ),
                    const SizedBox(height: 12),
                    tags,
                  ],
                ),
        );
      },
    );
  }

  Widget _insightSection({
    required String title,
    required Widget child,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: palette.surfaceHover,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _adaptiveGrid({
    required List<Widget> children,
    required double minChildWidth,
    int? maxColumns,
    double spacing = 10,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : minChildWidth;
        var columns = math.max(1,
            ((availableWidth + spacing) / (minChildWidth + spacing)).floor());
        if (maxColumns != null) {
          columns = math.min(columns, maxColumns);
        }
        columns = math.min(columns, children.length);
        final itemWidth =
            ((availableWidth - ((columns - 1) * spacing)) / columns)
                .clamp(0, double.infinity);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) =>
                  SizedBox(width: itemWidth.toDouble(), child: child))
              .toList(),
        );
      },
    );
  }

  Widget _glassCard(
      {required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.surface,
        border: Border.all(color: palette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.glow,
            blurRadius: 18,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }

  Widget _fieldBlock(String label, TextEditingController controller,
      {required String hint,
      TextInputType? keyboardType,
      List<TextInputFormatter>? inputFormatters}) {
    final palette = FTuneElectronPaletteData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: palette.surfaceAlt,
            hintStyle: TextStyle(color: palette.muted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.borderStrong),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: palette.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectionGroup(String label, List<String> values, String selected,
      ValueChanged<String> onChanged,
      {required int columns}) {
    final palette = FTuneElectronPaletteData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.muted)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: palette.surfaceAlt,
            border: Border.all(color: palette.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final count = math.max(1, math.min(columns, values.length));
              final availableWidth = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : (count * 120).toDouble();
              final itemWidth =
                  ((availableWidth - ((count - 1) * spacing)) / count)
                      .clamp(0, double.infinity)
                      .toDouble();

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: values
                    .map(
                      (value) => SizedBox(
                        width: itemWidth,
                        child: _segmentButton(
                          label: value,
                          selected: value == selected,
                          onTap: () => onChanged(value),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _metricRing(InsightMetric metric) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(metric.label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.muted)),
          const SizedBox(height: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(
                    value: metric.value / 100,
                    strokeWidth: 6,
                    color: metric.color,
                    backgroundColor: palette.border),
                Center(
                    child: Text('${metric.value}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: palette.text,
                        ))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(InsightDetail detail) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(detail.label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.muted)),
          const SizedBox(height: 4),
          Text(
            detail.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: palette.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSectionCard(TuneCalcDetailSection section) {
    final palette = FTuneElectronPaletteData.of(context);
    final rows = section.rows.take(4).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: section.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(fontWeight: FontWeight.w800, color: palette.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < rows.length; index++) ...<Widget>[
            Text(
              rows[index].label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: palette.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rows[index].value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: rows[index].progress / 100,
                minHeight: 5,
                backgroundColor: palette.border,
                valueColor: AlwaysStoppedAnimation<Color>(section.color),
              ),
            ),
            if (index != rows.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard(CarSpec car) {
    final palette = FTuneElectronPaletteData.of(context);
    final thumbnailUrl = _thumbnailFor(car);
    return Container(
      height: 140,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.accent.withAlpha(palette.isDark ? 30 : 15),
            palette.surfaceAlt,
          ],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _buildPreviewVisual(car, thumbnailUrl),
      ),
    );
  }

  Widget _buildPreviewVisual(CarSpec car, String? thumbnailUrl) {
    if (thumbnailUrl == null) {
      return _buildPreviewFallback(car);
    }

    return Image.network(
      thumbnailUrl,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      cacheWidth: 400,
      errorBuilder: (_, __, ___) => _buildPreviewFallback(car),
    );
  }

  Widget _buildPreviewFallback(CarSpec car) {
    final palette = FTuneElectronPaletteData.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: palette.surfaceAlt,
            border: Border.all(color: palette.border),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.directions_car_filled_rounded,
            size: 28,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${car.brand} ${car.model}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: palette.muted, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, {bool filled = false}) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: filled ? palette.accent : palette.border,
        ),
        color: filled ? palette.accent : palette.surfaceAlt,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color:
              filled ? Theme.of(context).colorScheme.onPrimary : palette.text,
        ),
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, VoidCallback? onTap}) {
    final palette = FTuneElectronPaletteData.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.border),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                palette.chromeTop,
                palette.surface,
                palette.chromeBottom,
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.chromeHighlight,
                blurRadius: 8,
                offset: const Offset(-3, -3),
              ),
              BoxShadow(
                color: palette.shadow.withAlpha(palette.isDark ? 140 : 69),
                blurRadius: 14,
                offset: const Offset(5, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: palette.muted),
        ),
      ),
    );
  }

  Widget _sortToggleButton() {
    final palette = FTuneElectronPaletteData.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _toggleSortOrder,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: 56,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: palette.surfaceAlt,
            border: Border.all(
              color: _sortAscending ? palette.border : palette.accent,
            ),
          ),
          child: Center(
            child: Text(
              _sortAscending ? 'A-Z' : 'Z-A',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _sortAscending ? palette.text : palette.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _brandBadge(String brand, {double size = 34}) {
    return _BrandLogoBadge(brand: brand, size: size);
  }

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = FTuneElectronPaletteData.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
            color: selected ? palette.accent : palette.surface,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : palette.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectableTile(
      {required String title,
      required VoidCallback onTap,
      String? subtitle,
      Widget? leading,
      Widget? trailing,
      bool selected = false}) {
    final palette = FTuneElectronPaletteData.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
          ),
          color: selected ? palette.accentSoft : palette.surface,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading,
              const SizedBox(width: 12)
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 12),
              trailing
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandLogoBadge extends StatefulWidget {
  const _BrandLogoBadge({
    required this.brand,
    required this.size,
  });

  final String brand;
  final double size;

  @override
  State<_BrandLogoBadge> createState() => _BrandLogoBadgeState();
}

class _BrandLogoBadgeState extends State<_BrandLogoBadge> {
  List<String> _candidates = const <String>[];
  int _candidateIndex = 0;

  @override
  void initState() {
    super.initState();
    _resetCandidates();
  }

  @override
  void didUpdateWidget(covariant _BrandLogoBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brand != widget.brand) {
      _resetCandidates();
    }
  }

  void _resetCandidates() {
    _candidates = BrandLogoRepository.getBrandLogoUrlCandidates(widget.brand);
    _candidateIndex = 0;
  }

  void _showNextCandidate() {
    if (!mounted || _candidateIndex >= _candidates.length - 1) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _candidateIndex += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallbackText =
        BrandLogoRepository.getBrandLogoFallbackText(widget.brand);
    final url = _candidateIndex < _candidates.length
        ? _candidates[_candidateIndex]
        : null;
    final palette = FTuneElectronPaletteData.of(context);

    return Container(
      width: widget.size,
      height: widget.size,
      padding: EdgeInsets.all(widget.size * 0.18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.size * 0.34),
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              fallbackText,
              style: TextStyle(
                fontSize: widget.size * 0.33,
                fontWeight: FontWeight.w900,
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                _showNextCandidate();
                return Text(
                  fallbackText,
                  style: TextStyle(
                    fontSize: widget.size * 0.33,
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
    );
  }
}

// CarSpec and BrandBucket are now defined in domain/car_spec.dart

class ModelInsight {
  const ModelInsight({
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.details,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final List<InsightMetric> metrics;
  final List<InsightDetail> details;
  final List<TuneCalcDetailSection> sections;
}

class InsightMetric {
  const InsightMetric(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class InsightDetail {
  const InsightDetail(this.label, this.value);

  final String label;
  final String value;
}

class _TireSizeSpec {
  const _TireSizeSpec({
    required this.width,
    required this.aspect,
    required this.rim,
  });

  final double width;
  final double aspect;
  final double rim;
}

enum _ResultStage {
  info,
  tune,
}

enum _SetupStep {
  info,
  tune,
}

class _ComparisonMetricData {
  const _ComparisonMetricData({
    required this.label,
    required this.stockValue,
    required this.tunedValue,
    required this.accent,
  });

  final String label;
  final int stockValue;
  final int tunedValue;
  final Color accent;
}

class _ComparisonSplitPreview extends StatefulWidget {
  const _ComparisonSplitPreview({
    required this.metrics,
    required this.leftTitle,
    required this.rightTitle,
  });

  final List<_ComparisonMetricData> metrics;
  final String leftTitle;
  final String rightTitle;

  @override
  State<_ComparisonSplitPreview> createState() =>
      _ComparisonSplitPreviewState();
}

class _ComparisonSplitPreviewState extends State<_ComparisonSplitPreview> {
  double _split = 0.5;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final leftFlex = (_split * 100).round().clamp(28, 72).toInt();
    final rightFlex = (100 - leftFlex).clamp(28, 72).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: palette.surfaceAlt,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Split-View Tuner',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Compare your base input snapshot against the tuned result.',
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: leftFlex,
                child: _ComparisonPane(
                  title: widget.leftTitle,
                  highlight: false,
                  metrics: widget.metrics,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 1,
                  height: 188,
                  color: palette.border,
                ),
              ),
              Expanded(
                flex: rightFlex,
                child: _ComparisonPane(
                  title: widget.rightTitle,
                  highlight: true,
                  metrics: widget.metrics,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.accent,
              inactiveTrackColor: palette.surfaceSoft,
              thumbColor: palette.text,
              overlayColor: _withAlpha(palette.accent, 0.18),
            ),
            child: Slider(
              value: _split,
              onChanged: (value) => setState(() => _split = value),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonPane extends StatelessWidget {
  const _ComparisonPane({
    required this.title,
    required this.highlight,
    required this.metrics,
  });

  final String title;
  final bool highlight;
  final List<_ComparisonMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: highlight ? palette.accentSoft : palette.surface,
        border: Border.all(
          color: highlight ? palette.accent : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: highlight ? palette.accent : palette.muted,
            ),
          ),
          const SizedBox(height: 12),
          for (final metric in metrics) ...<Widget>[
            _ComparisonMetricLine(
              label: metric.label,
              value: highlight ? metric.tunedValue : metric.stockValue,
              accent: metric.accent,
              highlight: highlight,
            ),
            if (metric != metrics.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ComparisonMetricLine extends StatelessWidget {
  const _ComparisonMetricLine({
    required this.label,
    required this.value,
    required this.accent,
    required this.highlight,
  });

  final String label;
  final int value;
  final Color accent;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: highlight ? palette.text : palette.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ComparisonSparkline(
          value: value,
          accent: accent,
          highlight: highlight,
        ),
      ],
    );
  }
}

class _ComparisonSparkline extends StatelessWidget {
  const _ComparisonSparkline({
    required this.value,
    required this.accent,
    required this.highlight,
  });

  final int value;
  final Color accent;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final normalized = (value / 100).clamp(0.0, 1.0);

    return Row(
      children: List<Widget>.generate(7, (index) {
        final threshold = (index + 1) / 7;
        final active = normalized >= threshold;
        final height = 5.0 + (index * 3.0);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 4),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active
                      ? (highlight ? accent : accent.withAlpha(170))
                      : palette.surfaceSoft,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Power Band Modal
// ─────────────────────────────────────────────────────────────────

class _PowerBandModal extends StatefulWidget {
  const _PowerBandModal({
    required this.initialBand,
    this.languageCode = 'en',
  });

  final TuneCalcPowerBand initialBand;
  final String languageCode;

  @override
  State<_PowerBandModal> createState() => _PowerBandModalState();
}

class _PowerBandModalState extends State<_PowerBandModal> {
  static const List<int> _presets = <int>[8000, 10000, 12000];
  static const int _customDefault = 14000;
  static const int _scaleStep = 50;
  static const int _customMin = 6000;
  static const int _customMax = 20000;

  late int _scaleMax;
  late int _redlineRpm;
  late int _maxTorqueRpm;
  bool _isCustomScale = false;
  late int _customScaleMax;
  late TextEditingController _customController;

  bool get _isVi => widget.languageCode.trim().toLowerCase() == 'vi';

  @override
  void initState() {
    super.initState();
    final b = widget.initialBand;
    _redlineRpm = b.redlineRpm.clamp(0, b.scaleMax);
    _maxTorqueRpm = b.maxTorqueRpm.clamp(0, _redlineRpm);

    final inPreset = _presets.contains(b.scaleMax);
    if (inPreset) {
      _scaleMax = b.scaleMax;
      _customScaleMax = _customDefault;
      _isCustomScale = false;
    } else {
      _isCustomScale = true;
      _customScaleMax = _roundToStep(b.scaleMax).clamp(_customMin, _customMax);
      _scaleMax = _customScaleMax;
    }
    _customController =
        TextEditingController(text: '$_customScaleMax');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  int _roundToStep(int v) => ((v / _scaleStep).round() * _scaleStep);

  void _applyPreset(int preset) {
    final redlineRatio = _scaleMax > 0 ? _redlineRpm / _scaleMax : 0.8;
    final torqueRatio = _scaleMax > 0 ? _maxTorqueRpm / _scaleMax : 0.5;
    setState(() {
      _isCustomScale = false;
      _scaleMax = preset;
      _redlineRpm = _roundToStep((preset * redlineRatio).round()).clamp(0, preset);
      _maxTorqueRpm = _roundToStep((preset * torqueRatio).round()).clamp(0, _redlineRpm);
    });
  }

  void _applyCustomScale() {
    final v = int.tryParse(_customController.text.trim()) ?? _customDefault;
    final clamped = _roundToStep(v).clamp(_customMin, _customMax);
    final redlineRatio = _scaleMax > 0 ? _redlineRpm / _scaleMax : 0.8;
    final torqueRatio = _scaleMax > 0 ? _maxTorqueRpm / _scaleMax : 0.5;
    setState(() {
      _isCustomScale = true;
      _customScaleMax = clamped;
      _scaleMax = clamped;
      _customController.text = '$clamped';
      _redlineRpm = _roundToStep((clamped * redlineRatio).round()).clamp(0, clamped);
      _maxTorqueRpm = _roundToStep((clamped * torqueRatio).round()).clamp(0, _redlineRpm);
    });
  }

  void _selectCustomMode() {
    final redlineRatio = _scaleMax > 0 ? _redlineRpm / _scaleMax : 0.8;
    final torqueRatio = _scaleMax > 0 ? _maxTorqueRpm / _scaleMax : 0.5;
    setState(() {
      _isCustomScale = true;
      _scaleMax = _customScaleMax;
      _redlineRpm = _roundToStep((_customScaleMax * redlineRatio).round()).clamp(0, _customScaleMax);
      _maxTorqueRpm = _roundToStep((_customScaleMax * torqueRatio).round()).clamp(0, _redlineRpm);
    });
  }

  String _formatK(int rpm) {
    final k = rpm / 1000;
    return k == k.roundToDouble() ? '${k.round()}K' : '${k.toStringAsFixed(1)}K';
  }

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final isDark = palette.isDark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? const Color(0xFF161C26) : Colors.white,
            border: Border.all(color: palette.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _withAlpha(Colors.black, isDark ? 0.4 : 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildHeader(palette),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    children: <Widget>[
                      _buildRedlineSection(palette),
                      const SizedBox(height: 14),
                      _buildTorqueSection(palette),
                      const SizedBox(height: 14),
                      _buildScaleSection(palette),
                      const SizedBox(height: 14),
                      _buildChart(palette),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildFooter(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FTuneElectronPaletteData palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isVi ? 'Dải Công Suất' : 'Power Band',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isVi
                      ? 'Cấu hình dải RPM redline và peak torque'
                      : 'Configure redline and peak torque RPM range',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ],
            ),
          ),
          _IconBtn(
            icon: Icons.close_rounded,
            palette: palette,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildRedlineSection(FTuneElectronPaletteData palette) {
    return _SliderSection(
      palette: palette,
      title: _isVi ? 'Redline RPM' : 'Redline RPM',
      value: _redlineRpm,
      min: 0,
      max: _scaleMax,
      step: _scaleStep,
      midLabel: '${(_scaleMax / 2).round()}',
      maxLabel: '$_scaleMax',
      accentColor: FTunePalette.accent,
      onChanged: (v) {
        setState(() {
          _redlineRpm = v;
          if (_maxTorqueRpm > _redlineRpm) {
            _maxTorqueRpm = _redlineRpm;
          }
        });
      },
    );
  }

  Widget _buildTorqueSection(FTuneElectronPaletteData palette) {
    return _SliderSection(
      palette: palette,
      title: _isVi ? 'Peak Torque RPM' : 'Peak Torque RPM',
      value: _maxTorqueRpm,
      min: 0,
      max: _scaleMax,
      step: _scaleStep,
      midLabel: '${(_scaleMax / 2).round()}',
      maxLabel: '$_scaleMax',
      accentColor: const Color(0xFFFF2B8B),
      onChanged: (v) {
        setState(() {
          _maxTorqueRpm = v.clamp(0, _redlineRpm);
        });
      },
    );
  }

  Widget _buildScaleSection(FTuneElectronPaletteData palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _isVi ? 'Thang RPM' : 'RPM Scale',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            ..._presets.map((p) {
              final active = !_isCustomScale && _scaleMax == p;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ScaleChip(
                    label: _formatK(p),
                    active: active,
                    palette: palette,
                    onTap: () => _applyPreset(p),
                  ),
                ),
              );
            }),
            Expanded(
              child: _ScaleChip(
                label: _isVi ? 'Tuỳ chỉnh' : 'Custom',
                active: _isCustomScale,
                palette: palette,
                onTap: _selectCustomMode,
              ),
            ),
          ],
        ),
        if (_isCustomScale) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: TextStyle(color: palette.text),
                  decoration: InputDecoration(
                    hintText: _isVi ? 'RPM tối đa (6000–20000)' : 'Max RPM (6000–20000)',
                    hintStyle: TextStyle(color: palette.muted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _applyCustomScale(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyCustomScale,
                style: FilledButton.styleFrom(
                  backgroundColor: FTunePalette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: Text(_isVi ? 'Áp dụng' : 'Apply'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildChart(FTuneElectronPaletteData palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _isVi ? 'Biểu Đồ Công Suất' : 'Performance Chart',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x8EFF2B8B)),
                color: const Color(0x22FF2B8B),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(width: 10, height: 2, color: const Color(0xFFFF2B8B)),
                  const SizedBox(width: 5),
                  Text('Torque', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.text)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _withAlpha(FTunePalette.highlight, 0.6)),
                color: _withAlpha(FTunePalette.highlight, 0.18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(width: 10, height: 2, color: FTunePalette.highlight),
                  const SizedBox(width: 5),
                  Text('Power', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.text)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
            color: palette.isDark ? const Color(0xFF1B2436) : const Color(0xFFF8FAFB),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _PowerBandChartPainter(
              scaleMax: _scaleMax,
              redlineRpm: _redlineRpm,
              maxTorqueRpm: _maxTorqueRpm,
              isDark: palette.isDark,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(FTuneElectronPaletteData palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_isVi ? 'Hủy' : 'Cancel'),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(
                TuneCalcPowerBand(
                  scaleMax: _scaleMax,
                  redlineRpm: _redlineRpm,
                  maxTorqueRpm: _maxTorqueRpm,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: FTunePalette.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(_isVi ? 'Áp dụng' : 'Apply'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Slider section widget
// ─────────────────────────────────────────────────────────────────
class _SliderSection extends StatelessWidget {
  const _SliderSection({
    required this.palette,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.midLabel,
    required this.maxLabel,
    required this.accentColor,
    required this.onChanged,
  });

  final FTuneElectronPaletteData palette;
  final String title;
  final int value;
  final int min;
  final int max;
  final int step;
  final String midLabel;
  final String maxLabel;
  final Color accentColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final progress = max > min ? (value - min) / (max - min) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
                color: palette.surfaceAlt,
              ),
              child: Text(
                '$value RPM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accentColor,
            inactiveTrackColor: _withAlpha(accentColor, 0.2),
            thumbColor: accentColor,
            overlayColor: _withAlpha(accentColor, 0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max > min ? max.toDouble() : (min + step).toDouble(),
            divisions: max > min ? ((max - min) ~/ step).clamp(1, 400) : 1,
            onChanged: (v) => onChanged(((v / step).round() * step).clamp(min, max)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              Text('0', style: TextStyle(fontSize: 10, color: palette.muted)),
              const Spacer(),
              Text(midLabel, style: TextStyle(fontSize: 10, color: palette.muted)),
              const Spacer(),
              Text(maxLabel, style: TextStyle(fontSize: 10, color: palette.muted)),
            ],
          ),
        ),
        // ignore: unused_local_variable
        SizedBox(height: 0, child: Opacity(opacity: 0, child: Text('$progress'))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Scale chip button
// ─────────────────────────────────────────────────────────────────
class _ScaleChip extends StatelessWidget {
  const _ScaleChip({
    required this.label,
    required this.active,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool active;
  final FTuneElectronPaletteData palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? FTunePalette.accent : palette.border,
          ),
          color: active
              ? FTunePalette.accent
              : palette.surfaceAlt,
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: _withAlpha(FTunePalette.accent, 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : palette.muted,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Icon button used in power band modal header
// ─────────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final FTuneElectronPaletteData palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: palette.border),
            color: palette.surfaceAlt,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: palette.muted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Power Band Chart Painter
// ─────────────────────────────────────────────────────────────────
class _PowerBandChartPainter extends CustomPainter {
  const _PowerBandChartPainter({
    required this.scaleMax,
    required this.redlineRpm,
    required this.maxTorqueRpm,
    required this.isDark,
  });

  final int scaleMax;
  final int redlineRpm;
  final int maxTorqueRpm;
  final bool isDark;

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  static double _easeOutCubic(double t) {
    final tc = _clamp(t, 0, 1);
    return 1 - math.pow(1 - tc, 3).toDouble();
  }

  static double _easeInOutSine(double t) {
    final tc = _clamp(t, 0, 1);
    return -(math.cos(math.pi * tc) - 1) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (scaleMax <= 0 || size.width <= 0 || size.height <= 0) return;

    final effRedline = redlineRpm.clamp(0, scaleMax);
    final effTorquePeak = maxTorqueRpm.clamp(0, effRedline);
    const sampleCount = 120;

    final scaleFactor = _clamp((scaleMax - 8000) / 12000, 0, 1);
    final peakTorqueNm = 520 + 120 * scaleFactor;
    final baseTorqueNm = peakTorqueNm * 0.56;
    final endTorqueNm = peakTorqueNm * 0.75;

    final torquePoints = <Offset>[];
    final powerPoints = <Offset>[];

    for (var i = 0; i <= sampleCount; i++) {
      final rpm = effRedline <= 0 ? 0.0 : (effRedline * i / sampleCount);
      double torqueNm;

      if (rpm <= effTorquePeak) {
        final rise = effTorquePeak <= 0 ? 1.0 : _clamp(rpm / effTorquePeak, 0, 1);
        torqueNm = baseTorqueNm + (peakTorqueNm - baseTorqueNm) * _easeOutCubic(rise);
      } else {
        final fall = _clamp((rpm - effTorquePeak) / math.max(effRedline - effTorquePeak, 1), 0, 1);
        torqueNm = peakTorqueNm - (peakTorqueNm - endTorqueNm) * _easeInOutSine(fall);
      }

      final idleRamp = _clamp(rpm / 900, 0, 1);
      torqueNm = math.max(0, torqueNm * (0.38 + 0.62 * idleRamp));

      final powerHp = (torqueNm * rpm) / 7127;
      torquePoints.add(Offset(rpm.toDouble(), torqueNm));
      powerPoints.add(Offset(rpm.toDouble(), powerHp));
    }

    final allVals = <double>[
      ...torquePoints.map((p) => p.dy),
      ...powerPoints.map((p) => p.dy),
      100,
    ];
    final yMax = math.max(100.0, (allVals.reduce(math.max) / 100).ceil() * 100.0);

    // Grid
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(18)
      ..strokeWidth = 1;
    for (var gi = 1; gi < 8; gi++) {
      final y = size.height - (gi / 8) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var gj = 1; gj <= 10; gj++) {
      final x = (gj / 10) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    Offset toCanvas(Offset p) => Offset(
          (p.dx / scaleMax) * size.width,
          size.height - _clamp(p.dy / yMax, 0, 1) * size.height,
        );

    // Torque line
    final torquePaint = Paint()
      ..color = const Color(0xFFFF2B8B)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final torquePath = Path();
    for (var i = 0; i < torquePoints.length; i++) {
      final pt = toCanvas(torquePoints[i]);
      if (i == 0) { torquePath.moveTo(pt.dx, pt.dy); }
      else { torquePath.lineTo(pt.dx, pt.dy); }
    }
    canvas.drawPath(torquePath, torquePaint);

    // Power line
    final powerPaint = Paint()
      ..color = FTunePalette.highlight
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final powerPath = Path();
    for (var i = 0; i < powerPoints.length; i++) {
      final pt = toCanvas(powerPoints[i]);
      if (i == 0) { powerPath.moveTo(pt.dx, pt.dy); }
      else { powerPath.lineTo(pt.dx, pt.dy); }
    }
    canvas.drawPath(powerPath, powerPaint);

    // Redline marker
    if (effRedline > 0) {
      final rx = (effRedline / scaleMax) * size.width;
      final markerPaint = Paint()
        ..color = FTunePalette.accent.withAlpha(160)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(rx, 0), Offset(rx, size.height), markerPaint);
    }
  }

  @override
  bool shouldRepaint(_PowerBandChartPainter old) =>
      old.scaleMax != scaleMax ||
      old.redlineRpm != redlineRpm ||
      old.maxTorqueRpm != maxTorqueRpm ||
      old.isDark != isDark;
}

class _GearingChartModal extends StatelessWidget {
  const _GearingChartModal({
    required this.gearing,
    required this.powerBand,
    required this.palette,
    required this.copy,
  });

  final TuneCalcGearingData gearing;
  final TuneCalcPowerBand powerBand;
  final FTuneElectronPaletteData palette;
  final _CreateCopy copy;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 800,
        height: 520,
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
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  Icon(Icons.query_stats_rounded, color: palette.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      copy.gearingChartTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  FTuneRoundIconButton(
                    icon: Icons.close_rounded,
                    tooltip: copy.closeLabel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CustomPaint(
                  painter: _GearingChartPainter(
                    gearing: gearing,
                    powerBand: powerBand,
                    palette: palette,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GearingChartPainter extends CustomPainter {
  const _GearingChartPainter({
    required this.gearing,
    required this.powerBand,
    required this.palette,
  });

  final TuneCalcGearingData gearing;
  final TuneCalcPowerBand powerBand;
  final FTuneElectronPaletteData palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (gearing.ratios.isEmpty || gearing.scaleMaxKmh == 0) return;

    final isDark = palette.isDark;
    
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(15)
      ..strokeWidth = 1;
    
    for (var gi = 1; gi <= 10; gi++) {
      final x = (gi / 10) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    
    for (var gj = 1; gj < 8; gj++) {
      final y = size.height - (gj / 8) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final redlineDisplay = gearing.redlineRpm;
    final scaleMaxRpm = powerBand.scaleMax > 0 ? powerBand.scaleMax.toDouble() : (redlineDisplay * 1.1);

    Offset toCanvas(double rpm, double speedKmh) {
      final x = (speedKmh / gearing.scaleMaxKmh) * size.width;
      final y = size.height - (rpm / scaleMaxRpm).clamp(0, 1) * size.height;
      return Offset(x, y);
    }

    if (powerBand.scaleMax > 0) {
      final pbPath = Path();
      bool started = false;
      for (double rpm = 1000; rpm <= redlineDisplay; rpm += 500) {
        final torque = 300 + math.sin(rpm / 3000) * 100;
        final hp = (torque * rpm) / 7120.8;
        
        final x = (rpm / redlineDisplay) * size.width;
        final y = size.height - ((hp * 1.5) / scaleMaxRpm).clamp(0, 1) * size.height;
        if (!started) {
          pbPath.moveTo(x, y);
          started = true;
        } else {
          pbPath.lineTo(x, y);
        }
      }
      final pbPaint = Paint()
        ..color = FTunePalette.highlight.withAlpha(isDark ? 25 : 15)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(pbPath, pbPaint);
    }

    final gearPaint = Paint()
      ..color = palette.accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dropPaint = Paint()
      ..color = palette.accent.withAlpha(isDark ? 100 : 70)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Offset? lastPoint;

    for (int i = 0; i < gearing.ratios.length; i++) {
      final ratio = gearing.ratios[i];
      final currentTopSpeed = ratio.topSpeedKmh;
      final prevTopSpeed = i == 0 ? 0.0 : gearing.ratios[i - 1].topSpeedKmh;
      final startRpm = prevTopSpeed == 0 ? 0.0 : redlineDisplay * (prevTopSpeed / currentTopSpeed);

      final pStart = toCanvas(startRpm, prevTopSpeed);
      final pEnd = toCanvas(redlineDisplay.toDouble(), currentTopSpeed);

      canvas.drawLine(pStart, pEnd, gearPaint);

      if (lastPoint != null) {
        canvas.drawLine(lastPoint, pStart, dropPaint);
      }

      final tp = TextPainter(
        text: TextSpan(
          text: 'G${ratio.gear}',
          style: TextStyle(
            color: palette.text,
            fontWeight: FontWeight.w800,
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pEnd.dx - tp.width - 4, pEnd.dy - tp.height - 4));

      lastPoint = pEnd;
    }

    final rx = toCanvas(redlineDisplay.toDouble(), gearing.scaleMaxKmh);
    final markerPaint = Paint()
      ..color = const Color(0xFFFF2B8B).withAlpha(120)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, rx.dy), Offset(size.width, rx.dy), markerPaint);
  }

  @override
  bool shouldRepaint(_GearingChartPainter old) =>
      old.gearing != gearing ||
      old.powerBand != powerBand ||
      old.palette.isDark != palette.isDark;
}

class _CreateCopy {
  _CreateCopy(String languageCode)
      : isVietnamese = languageCode.trim().toLowerCase() == 'vi';

  final bool isVietnamese;

  String get metric => 'Metric';
  String get imperial => 'Imperial';
  String modelCount(int count) =>
      isVietnamese ? '$count mẫu xe' : '$count models';
  String get headerTitle => isVietnamese ? 'Tạo Tune Mới' : 'Create New Tune';
  String get closeLabel => isVietnamese ? 'Đóng' : 'Close';
  String get gearingChartTitle => isVietnamese ? 'Biểu Đồ Cấp Số' : 'Gearing Chart';
  String get footerNote => isVietnamese
      ? 'Kiểm tra lại toàn bộ tham số trước khi tiếp tục'
      : 'Verify all parameters before continuing';
  String get calculate => isVietnamese ? 'TÍNH TOÁN' : 'CALCULATION';
  String get selectCarStep => isVietnamese ? '1. CHỌN XE' : '1. SELECT CAR';
  String get filterHint => isVietnamese
      ? 'Lọc theo hãng xe hoặc mẫu xe...'
      : 'Filter brand or model...';
  String get modelInfoTitle => isVietnamese ? 'Thông Tin Xe' : 'Model Info';
  String get infoSnapshotTitle =>
      isVietnamese ? '4. Tổng Quan' : '4. Info Snapshot';
  String get modelInfoEmpty => isVietnamese
      ? 'Chọn một mẫu xe để xem nhanh thông số và insight tune.'
      : 'Select a model to preview vehicle specs and tune insights.';
  String get vehicleSnapshotTitle =>
      isVietnamese ? 'Tóm Tắt Xe' : 'Vehicle Snapshot';
  String get performanceMetricsTitle =>
      isVietnamese ? 'Chỉ Số Hiệu Năng' : 'Performance Metrics';
  String get performanceCardTitle =>
      isVietnamese ? '2. Dữ Liệu Hiệu Năng' : '2. Performance Data';
  String get weightLabel => isVietnamese ? 'Khối Lượng (kg)' : 'Weight (kg)';
  String get frontDistributionLabel =>
      isVietnamese ? 'Phân Bố Trước (%)' : 'F. Distribution (%)';
  String get advancedTitle =>
      isVietnamese ? '3. Thông Số Nâng Cao' : '3. Advanced Specs';
  String get maxTorqueLabel =>
      isVietnamese ? 'Mô-men cực đại (N-m)' : 'Max Torque (N-m)';
  String get gearsLabel => isVietnamese ? 'Số cấp số' : 'Gears';
  String get topSpeedLabel =>
      isVietnamese ? 'Tốc độ tối đa (km/h)' : 'Top Speed (km/h)';
  String get frontTireLabel => isVietnamese ? 'Lốp trước' : 'Front Tire Size';
  String get rearTireLabel => isVietnamese ? 'Lốp sau' : 'Rear Tire Size';
  String tireNote(String driveType) => isVietnamese
      ? 'Hệ thống tune đang dùng kích thước lốp ${driveType == 'FWD' ? 'trước' : 'sau'} cho $driveType.'
      : 'Tuning uses the ${driveType == 'FWD' ? 'front' : 'rear'} tire size for $driveType.';
  String get configurationTitle =>
      isVietnamese ? '4. Cấu Hình' : '4. Configuration';
  String get driveTypeLabel => isVietnamese ? 'Kiểu dẫn động' : 'Drive Type';
  String get gameVersionLabel =>
      isVietnamese ? 'Phiên bản game' : 'Game Version';
  String get environmentTitle =>
      isVietnamese ? '5. Môi Trường & Mục Tiêu' : '5. Environment & Purpose';
  String get surfaceLabel => isVietnamese ? 'Bề mặt' : 'Surface';
  String get tuneTypeLabel => isVietnamese ? 'Kiểu tune' : 'Tune Type';
  String get currentPiLabel => 'Current PI';
  String get currentPiHint =>
      isVietnamese ? 'Nhập PI hiện tại' : 'Enter current PI';
  String get powerBandLabel => isVietnamese ? 'Dải công suất' : 'Power Band';
  String get powerBandHint => isVietnamese
      ? 'Chạm để sửa peak torque và redline'
      : 'Tap to edit peak torque and redline';
  String get stepInfo => isVietnamese ? 'Bước 1: Thông tin' : 'Step 1: Info';
  String get stepTune => isVietnamese ? 'Bước 2: Cài đặt' : 'Step 2: Settings';
  String get powerBandApply => isVietnamese ? 'Áp dụng' : 'Apply';
  String get powerBandCancel => isVietnamese ? 'Hủy' : 'Cancel';
  String get tuneSaved => isVietnamese ? 'Tune đã lưu vào Garage.' : 'Tune saved to Garage.';
  String get tuneCopyAll => isVietnamese ? 'SAO CHÉP TẤT CẢ' : 'COPY ALL';
  String get tuneShare => isVietnamese ? 'CHIA SẺ' : 'SHARE';
  String get tuneOpenGarage => isVietnamese ? 'MỞ GARAGE' : 'OPEN GARAGE';
  String get tuneSaveToGarage => isVietnamese ? 'LƯU VÀO GARAGE' : 'SAVE TO GARAGE';
  String get tuneResultsTitle => isVietnamese ? 'Kết Quả Tune' : 'Tune Results Preview';
  String get tuneName => isVietnamese ? 'Tên tune' : 'Tune name';
  String get tuneShareCode => isVietnamese ? 'Share code (tùy chọn)' : 'Share code (optional)';
  String get tuneCopied => isVietnamese ? 'Đã sao chép tóm tắt tune.' : 'Tune summary copied.';
  String get shareReadyCopied => isVietnamese ? 'Đã sao chép để chia sẻ.' : 'Share-ready summary copied.';
}

Color _withAlpha(Color color, double opacity) {
  final alpha = (opacity * 255).round().clamp(0, 255).toInt();
  return color.withAlpha(alpha);
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
