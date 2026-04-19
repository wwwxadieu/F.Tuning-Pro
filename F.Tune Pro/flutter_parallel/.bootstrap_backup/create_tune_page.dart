import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/ftune_models.dart';
import 'domain/tune_calculation_service.dart';
import 'domain/tune_models.dart';

class CreateTunePage extends StatefulWidget {
  const CreateTunePage({
    super.key,
    this.initialMetric = true,
    this.onBack,
    this.onMetricChanged,
    this.onSaveTune,
    this.onGarageRequested,
  });

  final bool initialMetric;
  final VoidCallback? onBack;
  final ValueChanged<bool>? onMetricChanged;
  final ValueChanged<SavedTuneDraft>? onSaveTune;
  final VoidCallback? onGarageRequested;

  @override
  State<CreateTunePage> createState() => _CreateTunePageState();
}

class _CreateTunePageState extends State<CreateTunePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _frontDistributionController = TextEditingController();
  final TextEditingController _currentPiController = TextEditingController();
  final TextEditingController _powerBandController = TextEditingController();
  final TextEditingController _maxTorqueController = TextEditingController();
  final TextEditingController _topSpeedController = TextEditingController();
  final TextEditingController _tireSizeController = TextEditingController();

  List<CarSpec> _cars = const <CarSpec>[];
  bool _isLoading = true;
  String _query = '';
  String? _selectedBrand;
  CarSpec? _selectedModel;
  bool _metric = true;
  String _driveType = 'RWD';
  String _gameVersion = 'FH5';
  String _surface = 'Street';
  String _tuneType = 'Race';
  int _gearCount = 6;

  @override
  void initState() {
    super.initState();
    _metric = widget.initialMetric;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _loadCars();
  }

  @override
  void didUpdateWidget(covariant CreateTunePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMetric != widget.initialMetric && _metric != widget.initialMetric) {
      setState(() => _metric = widget.initialMetric);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _weightController.dispose();
    _frontDistributionController.dispose();
    _currentPiController.dispose();
    _powerBandController.dispose();
    _maxTorqueController.dispose();
    _topSpeedController.dispose();
    _tireSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadCars() async {
    final raw = await rootBundle.loadString('assets/data/FH5_cars.json');
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
      _isLoading = false;
    });
  }

  List<BrandBucket> get _brandBuckets {
    final map = <String, List<CarSpec>>{};
    for (final car in _cars) {
      map.putIfAbsent(car.brand, () => <CarSpec>[]).add(car);
    }
    return map.entries
        .map((entry) => BrandBucket(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.brand.compareTo(b.brand));
  }

  List<BrandBucket> get _visibleBrands {
    if (_query.isEmpty) return _brandBuckets;
    return _brandBuckets.where((bucket) {
      if (bucket.brand.toLowerCase().contains(_query)) return true;
      return bucket.models.any((car) => car.model.toLowerCase().contains(_query));
    }).toList();
  }

  List<CarSpec> get _visibleModels {
    final brand = _selectedBrand;
    if (brand == null) return const <CarSpec>[];
    final bucket = _brandBuckets.firstWhere(
      (entry) => entry.brand == brand,
      orElse: () => BrandBucket(brand, const <CarSpec>[]),
    );
    if (_query.isEmpty) return bucket.models;
    return bucket.models.where((car) => car.model.toLowerCase().contains(_query)).toList();
  }

  void _selectBrand(String brand) {
    setState(() {
      _selectedBrand = brand;
      _selectedModel = null;
    });
  }

  void _backToBrands() {
    setState(() {
      _selectedBrand = null;
      _selectedModel = null;
    });
  }

  void _selectModel(CarSpec car) {
    setState(() {
      _selectedBrand = car.brand;
      _selectedModel = car;
      _driveType = car.driveType;
      _seedFields(car);
    });
  }

  void _seedFields(CarSpec car) {
    final frontDistribution = switch (car.driveType) {
      'FWD' => 61,
      'AWD' => 54,
      _ => 47,
    };
    final weight = (car.pi * 2.85 + 610).round();
    final torque = math.max(260, ((car.pi - 300) * 1.75).round());
    final topSpeed = car.topSpeedKmh.toStringAsFixed(0);
    final lowerSpeed = math.max(240, car.topSpeedKmh - 95).round();
    final upperSpeed = math.max(lowerSpeed + 120, car.topSpeedKmh + 18).round();
    final tireWidth = switch (car.driveType) {
      'AWD' => '255 / 35 / R19',
      'FWD' => '245 / 40 / R18',
      _ => '275 / 30 / R19',
    };

    _weightController.text = '$weight';
    _frontDistributionController.text = '$frontDistribution';
    _currentPiController.text = '${car.pi}';
    _powerBandController.text = '$lowerSpeed - $upperSpeed RPM';
    _maxTorqueController.text = '$torque';
    _topSpeedController.text = topSpeed;
    _tireSizeController.text = tireWidth;
    _gearCount = car.driveType == 'AWD' ? 7 : 6;
  }

  TuneCalcResult? get _tuneResult {
    final car = _selectedModel;
    if (car == null) return null;

    final tireSize = _parseTireSize(_tireSizeController.text);
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
      frontDistributionPercent: _readDouble(_frontDistributionController.text, car.driveType == 'FWD' ? 61 : car.driveType == 'AWD' ? 54 : 47),
      maxTorqueNm: _readDouble(_maxTorqueController.text, math.max(260, ((car.pi - 300) * 1.75).round()).toDouble()),
      gears: _gearCount,
      tireWidth: tireSize.$1,
      tireAspect: tireSize.$2,
      tireRim: tireSize.$3,
      tireType: car.tireType,
      differentialType: car.differential,
      powerBand: powerBand,
    );
    return TuneCalculationService.calculate(input, metric: _metric);
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
          .map((metric) => InsightMetric(metric.label, metric.score, metric.color))
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

  (double, double, double) _parseTireSize(String value) {
    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(value).toList();
    if (matches.length >= 3) {
      return (
        double.tryParse(matches[0].group(0) ?? '') ?? 275,
        double.tryParse(matches[1].group(0) ?? '') ?? 30,
        double.tryParse(matches[2].group(0) ?? '') ?? 19,
      );
    }
    return (275, 30, 19);
  }

  TuneCalcPowerBand _parsePowerBand(String value) {
    final matches = RegExp(r'(\d+)').allMatches(value).toList();
    final torquePeak = matches.isNotEmpty ? int.tryParse(matches.first.group(0) ?? '') ?? 6800 : 6800;
    final redline = matches.length > 1 ? int.tryParse(matches[1].group(0) ?? '') ?? 10000 : 10000;
    final scaleMax = math.max(10000, ((redline / 1000).ceil() * 1000)).toInt();
    return TuneCalcPowerBand(
      scaleMax: scaleMax,
      redlineRpm: redline,
      maxTorqueRpm: math.min(torquePeak, redline).toInt(),
    );
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
    final normalized = token.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    for (final card in cards) {
      final title = card.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (title.contains(normalized)) return card;
    }
    return null;
  }

  TuneCalcSlider? _findCalcSlider(TuneCalcCard? card, String sideToken) {
    if (card == null) return null;
    final normalized = sideToken.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    for (final slider in card.sliders) {
      final side = slider.side.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (side == normalized || side.contains(normalized)) return slider;
    }
    return null;
  }

  String _formatCalcSlider(TuneCalcSlider slider) {
    if (slider.labels != null && slider.labels!.isNotEmpty) {
      final index = slider.value.round().clamp(0, slider.labels!.length - 1).toInt();
      return slider.labels![index];
    }
    final fixed = slider.value.toStringAsFixed(slider.decimals);
    final cleaned = fixed
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
    return '${cleaned}${slider.suffix ?? ''}';
  }

  Future<void> _showTuneResultPreview(BuildContext context) async {
    final result = _tuneResult;
    final car = _selectedModel;
    if (result == null || car == null) return;

    final wide = MediaQuery.of(context).size.width > 1180;
    final nameController = TextEditingController(text: '${car.brand} ${car.model}');
    final shareController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1320),
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x3AFFFFFF)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 760),
            child: Padding(
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
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              result.subtitle,
                              style: const TextStyle(color: Color(0xB7FFFFFF)),
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
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            hintText: 'Tune name',
                            prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
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
                              _summaryChip('${car.brand} ${car.model}', filled: true),
                              _summaryChip(_metric ? 'Metric' : 'Imperial'),
                              _summaryChip(result.overview.topSpeedDisplay),
                              _summaryChip(result.overview.tireType),
                              _summaryChip(result.overview.differentialType),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _glassCard(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: result.overview.metrics
                                  .map((metric) => _metricRing(
                                        InsightMetric(metric.label, metric.score, metric.color),
                                      ))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 3,
                                  child: _buildTuneCardsPreview(result.cards),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildGearingPreview(result.gearing),
                                ),
                              ],
                            )
                          else ...<Widget>[
                            _buildGearingPreview(result.gearing),
                            const SizedBox(height: 16),
                            _buildTuneCardsPreview(result.cards),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      if (widget.onGarageRequested != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            widget.onGarageRequested?.call();
                          },
                          icon: const Icon(Icons.garage_rounded),
                          label: const Text('OPEN GARAGE'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {
                          widget.onSaveTune?.call(
                            SavedTuneDraft(
                              title: nameController.text.trim(),
                              shareCode: shareController.text.trim(),
                              brand: car.brand,
                              model: car.model,
                              result: result,
                            ),
                          );
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tune saved to Garage.')),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildTuneCardsPreview(List<TuneCalcCard> cards) {
    return _glassCard(
      child: Column(
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
      ),
    );
  }

  Widget _buildTuneCardPreview(TuneCalcCard card) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x3F251B31),
        border: Border.all(color: const Color(0x24FFFFFF)),
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
                      color: Color(0xA6FFFFFF),
                    ),
                  ),
                ),
                Text(
                  _formatCalcSlider(slider),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: slider.max <= slider.min
                    ? 0
                    : ((slider.value - slider.min) / (slider.max - slider.min))
                        .clamp(0, 1)
                        .toDouble(),
                minHeight: 5,
                backgroundColor: const Color(0x1FFFFFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B83)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildGearingPreview(TuneCalcGearingData gearing) {
    return _glassCard(
      child: Column(
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
              _summaryChip('FD ${gearing.finalDrive.toStringAsFixed(2)}', filled: true),
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
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (ratio.topSpeedKmh / gearing.scaleMaxKmh).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: const Color(0x1FFFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF9448)),
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
                    style: const TextStyle(color: Color(0xB7FFFFFF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < 1140 || constraints.maxHeight < 760;
        final panelWidth = math.min(constraints.maxWidth - 32, 1320.0);
        final panelHeight = math.min(constraints.maxHeight - 32, 820.0);

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.asset('assets/images/fh6-main-bg.jpg', fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0xFF160F1C).withOpacity(0.78),
                      const Color(0xFF0E0A13).withOpacity(0.92),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SizedBox(
                    width: panelWidth,
                    height: panelHeight,
                    child: _buildShell(context, isStacked),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShell(BuildContext context, bool isStacked) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x4DFF5B87)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF311B2A), Color(0xFF1A1222)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x6620102A), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, isStacked ? 20 : 18),
        child: Column(
          children: <Widget>[
            _buildHeader(),
            const SizedBox(height: 14),
            Expanded(
              child: isStacked
                  ? SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          _buildVehiclePanel(isStacked: true),
                          const SizedBox(height: 16),
                          _buildRightPane(compact: true),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(width: 340, child: _buildVehiclePanel(isStacked: false)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildRightPane(compact: false)),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        _roundIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: widget.onBack,
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Create New Tune',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        _unitChip('Metric', _metric, () {
          setState(() => _metric = true);
          widget.onMetricChanged?.call(true);
        }),
        const SizedBox(width: 8),
        _unitChip('Imperial', !_metric, () {
          setState(() => _metric = false);
          widget.onMetricChanged?.call(false);
        }),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xCC1B1320),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: <Widget>[
          const Spacer(),
          const Text(
            'VERIFY ALL PARAMETERS BEFORE CONTINUING',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xB7FFFFFF)),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: _selectedModel == null ? null : () => _showTuneResultPreview(context),
            style: FilledButton.styleFrom(
              minimumSize: const Size(186, 48),
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF26182A),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('CALCULATION', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePanel({required bool isStacked}) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _selectedBrand == null ? '1. Select Vehicle' : '1. Select Vehicle - ${_selectedBrand!}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _selectedBrand == null ? Colors.white : const Color(0xFFFFD95B),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              if (_selectedBrand != null) ...<Widget>[
                _roundIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: _backToBrands),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Filter brand or model...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _roundIconButton(icon: Icons.sort_by_alpha_rounded),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: isStacked ? 420 : 540,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xE0FF3A53)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF32212B), Color(0xFF1B151A)],
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _selectedBrand == null
                          ? _buildBrandList(_visibleBrands)
                          : _buildModelList(_visibleModels),
                    ),
            ),
          ),
        ],
      ),
    );
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
          subtitle: '${bucket.models.length} models',
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
                subtitle: '${car.driveType}   PI ${car.pi}',
                trailing: _summaryChip(car.tireType),
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
    final leftCards = <Widget>[
      _buildPerformanceCard(),
      _buildAdvancedCard(),
    ];
    final rightCards = <Widget>[
      _buildConfigurationCard(compact: compact),
      _buildEnvironmentCard(compact: compact),
    ];

    return Column(
      children: <Widget>[
        _buildModelInfoCard(insight, compact: compact),
        const SizedBox(height: 16),
        if (compact) ...<Widget>[
          for (final card in leftCards.followedBy(rightCards)) ...<Widget>[card, const SizedBox(height: 16)],
        ] else
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: Row(children: <Widget>[Expanded(child: leftCards[0]), const SizedBox(width: 16), Expanded(child: rightCards[0])])),
                const SizedBox(height: 16),
                Expanded(child: Row(children: <Widget>[Expanded(child: leftCards[1]), const SizedBox(width: 16), Expanded(child: rightCards[1])])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelInfoCard(ModelInsight? insight, {required bool compact}) {
    return _glassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Model Info', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _buildPresetBar(),
          const SizedBox(height: 14),
          if (insight == null)
            Container(
              height: compact ? 96 : 132,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0x66291F37),
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: const Text(
                'Choose a car to reveal its tune profile, baseline metrics, and launch behavior.',
                style: TextStyle(color: Color(0xB7FFFFFF)),
              ),
            )
          else ...<Widget>[
            Text(insight.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(insight.subtitle, style: const TextStyle(color: Color(0xB7FFFFFF))),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: insight.metrics.map(_metricRing).toList(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: insight.details.map(_detailCard).toList(),
            ),
            if (insight.sections.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: insight.sections.map(_detailSectionCard).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('2. Performance Data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(child: _fieldBlock('Weight (kg)', _weightController, hint: 'Enter weight')),
              const SizedBox(width: 12),
              Expanded(child: _fieldBlock('F. Distribution (%)', _frontDistributionController, hint: 'Enter front distribution')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _fieldBlock('Current PI', _currentPiController, hint: 'Enter PI')),
              const SizedBox(width: 12),
              SizedBox(width: 72, child: _summaryChip(_selectedModel?.tireType ?? '--', filled: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('3. Advanced Specs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(child: _fieldBlock('Power Band', _powerBandController, hint: '6800 - 10000 RPM')),
              const SizedBox(width: 12),
              Expanded(child: _fieldBlock('Max Torque (N-m)', _maxTorqueController, hint: 'Enter torque')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _infoTile('Gears', '$_gearCount')),
              const SizedBox(width: 12),
              Expanded(child: _fieldBlock('Top Speed (km/h)', _topSpeedController, hint: 'Enter top speed')),
            ],
          ),
          const SizedBox(height: 14),
          _fieldBlock('Drive tire size (Width / Aspect / Rim)', _tireSizeController, hint: '275 / 30 / R19'),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard({required bool compact}) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('4. Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _selectionGroup('Drive Type', <String>['FWD', 'AWD', 'RWD'], _driveType, (value) => setState(() => _driveType = value), columns: compact ? 3 : 3),
          const SizedBox(height: 14),
          _selectionGroup('Game Version', <String>['FH5', 'FH6'], _gameVersion, (value) => setState(() => _gameVersion = value), columns: 2),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard({required bool compact}) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('5. Environment & Purpose', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _selectionGroup('Surface', <String>['Street', 'Dirt', 'Cross', 'Off-road'], _surface, (value) => setState(() => _surface = value), columns: compact ? 2 : 2),
          const SizedBox(height: 14),
          _selectionGroup('Tune Type', <String>['Race', 'Drift', 'Rain', 'Drag'], _tuneType, (value) => setState(() => _tuneType = value), columns: compact ? 2 : 2),
        ],
      ),
    );
  }

  Widget _buildPresetBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const <Widget>[
        _PresetChip('MAX GRIP'),
        _PresetChip('OVERSTEER'),
        _PresetChip('UNDERSTEER'),
        _PresetChip('COMFORT'),
      ],
    );
  }

  Widget _glassCard({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x3AFFFFFF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xE126192E), Color(0xD6181221)],
        ),
      ),
      child: child,
    );
  }

  Widget _fieldBlock(String label, TextEditingController controller, {required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xCCFFFFFF))),
        const SizedBox(height: 8),
        TextField(controller: controller, decoration: InputDecoration(hintText: hint)),
      ],
    );
  }

  Widget _selectionGroup(String label, List<String> values, String selected, ValueChanged<String> onChanged, {required int columns}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xCCFFFFFF))),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.7,
          ),
          itemBuilder: (context, index) {
            final value = values[index];
            final active = value == selected;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(value),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: active ? Colors.transparent : const Color(0x33FFFFFF)),
                  gradient: active
                      ? const LinearGradient(colors: <Color>[Color(0xFFFF4C8A), Color(0xFFFF9448)])
                      : const LinearGradient(colors: <Color>[Color(0x331F1B2A), Color(0x221B1521)]),
                ),
                child: Center(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _metricRing(InsightMetric metric) {
    return Container(
      width: 126,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x8036284A),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        children: <Widget>[
          Text(metric.label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xCCFFFFFF))),
          const SizedBox(height: 10),
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CircularProgressIndicator(value: metric.value / 100, strokeWidth: 6, color: metric.color, backgroundColor: const Color(0x33FFFFFF)),
                Center(child: Text('${metric.value}', style: const TextStyle(fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailCard(InsightDetail detail) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x471E1930),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(detail.label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xA6FFFFFF))),
          const SizedBox(height: 6),
          Text(detail.value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _detailSectionCard(TuneCalcDetailSection section) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x471E1930),
        border: Border.all(color: const Color(0x24FFFFFF)),
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
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in section.rows.take(4)) ...<Widget>[
            Text(
              row.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xA6FFFFFF),
              ),
            ),
            const SizedBox(height: 4),
            Text(row.value, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: row.progress / 100,
                minHeight: 5,
                backgroundColor: const Color(0x22FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(section.color),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0x3A251D34),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xCCFFFFFF))),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(CarSpec car) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x55FF587D)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xBB3B2330), Color(0xAA22161D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('${car.brand} ${car.model}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            height: 86,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const RadialGradient(colors: <Color>[Color(0x55FFFFFF), Color(0x00FFFFFF)]),
            ),
            alignment: Alignment.center,
            child: const Text('CAR PREVIEW', style: TextStyle(letterSpacing: 2, color: Color(0x88FFFFFF))),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _summaryChip(car.driveType),
              _summaryChip('PI ${car.pi}'),
              _summaryChip(car.tireType, filled: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: filled ? Colors.transparent : const Color(0x33FFFFFF)),
        gradient: filled
            ? const LinearGradient(colors: <Color>[Color(0xFFFF5B87), Color(0xFFFF9553)])
            : const LinearGradient(colors: <Color>[Color(0x4F2E2338), Color(0x2A1B1521)]),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: filled ? const Color(0xFF1E1222) : Colors.white)),
    );
  }

  Widget _roundIconButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0x5E2A1E39),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _unitChip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 102,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33FFFFFF)),
          gradient: active
              ? const LinearGradient(colors: <Color>[Color(0xFFFF4B8C), Color(0xFFFF9651)])
              : const LinearGradient(colors: <Color>[Color(0x2D201828), Color(0x2616111E)]),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
      ),
    );
  }

  Widget _brandBadge(String brand) {
    final initials = brand.trim().isEmpty
        ? '--'
        : brand.trim().split(RegExp(r'\s+')).take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0x6B322342),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      alignment: Alignment.center,
      child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _selectableTile({required String title, required VoidCallback onTap, String? subtitle, Widget? leading, Widget? trailing, bool selected = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xAAFF5C7E) : const Color(0x26FFFFFF)),
          gradient: selected
              ? const LinearGradient(colors: <Color>[Color(0x6B4D2234), Color(0x5D2A1823)])
              : const LinearGradient(colors: <Color>[Color(0x50261C2E), Color(0x3D18131E)]),
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[leading, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Color(0xA9FFFFFF), fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing],
          ],
        ),
      ),
    );
  }
}

class CarSpec {
  const CarSpec({required this.brand, required this.model, required this.pi, required this.topSpeedKmh, required this.differential, required this.tireType, required this.driveType});

  final String brand;
  final String model;
  final int pi;
  final double topSpeedKmh;
  final String differential;
  final String tireType;
  final String driveType;

  factory CarSpec.fromJson(Map<String, dynamic> json) {
    return CarSpec(
      brand: json['brand'] as String? ?? 'Unknown',
      model: json['model'] as String? ?? 'Unknown',
      pi: (json['pi'] as num? ?? 0).round(),
      topSpeedKmh: (json['topSpeedKmh'] as num? ?? 0).toDouble(),
      differential: json['differential'] as String? ?? 'Unknown Differential',
      tireType: json['tireType'] as String? ?? 'Street',
      driveType: json['driveType'] as String? ?? 'RWD',
    );
  }
}

class BrandBucket {
  const BrandBucket(this.brand, this.models);

  final String brand;
  final List<CarSpec> models;
}

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

class _PresetChip extends StatelessWidget {
  const _PresetChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0x54261E2F),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

extension FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

