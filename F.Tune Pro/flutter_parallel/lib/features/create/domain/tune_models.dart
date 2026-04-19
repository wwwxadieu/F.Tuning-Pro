import 'package:flutter/material.dart';

class TuneCalcPowerBand {
  const TuneCalcPowerBand({
    required this.scaleMax,
    required this.redlineRpm,
    required this.maxTorqueRpm,
  });

  final int scaleMax;
  final int redlineRpm;
  final int maxTorqueRpm;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scaleMax': scaleMax,
        'redlineRpm': redlineRpm,
        'maxTorqueRpm': maxTorqueRpm,
      };

  factory TuneCalcPowerBand.fromJson(Map<String, dynamic> json) =>
      TuneCalcPowerBand(
        scaleMax: (json['scaleMax'] as num?)?.toInt() ?? 10000,
        redlineRpm: (json['redlineRpm'] as num?)?.toInt() ?? 10000,
        maxTorqueRpm: (json['maxTorqueRpm'] as num?)?.toInt() ?? 6800,
      );
}

class TuneCalcInput {
  const TuneCalcInput({
    required this.brand,
    required this.model,
    required this.driveType,
    required this.surface,
    required this.tuneType,
    required this.pi,
    required this.topSpeedKmh,
    required this.weightKg,
    required this.frontDistributionPercent,
    required this.maxTorqueNm,
    required this.gears,
    required this.tireWidth,
    required this.tireAspect,
    required this.tireRim,
    required this.tireType,
    required this.differentialType,
    required this.powerBand,
  });

  final String brand;
  final String model;
  final String driveType;
  final String surface;
  final String tuneType;
  final int pi;
  final double topSpeedKmh;
  final double weightKg;
  final double frontDistributionPercent;
  final double maxTorqueNm;
  final int gears;
  final double tireWidth;
  final double tireAspect;
  final double tireRim;
  final String tireType;
  final String differentialType;
  final TuneCalcPowerBand powerBand;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'brand': brand,
        'model': model,
        'driveType': driveType,
        'surface': surface,
        'tuneType': tuneType,
        'pi': pi,
        'topSpeedKmh': topSpeedKmh,
        'weightKg': weightKg,
        'frontDistributionPercent': frontDistributionPercent,
        'maxTorqueNm': maxTorqueNm,
        'gears': gears,
        'tireWidth': tireWidth,
        'tireAspect': tireAspect,
        'tireRim': tireRim,
        'tireType': tireType,
        'differentialType': differentialType,
        'powerBand': powerBand.toJson(),
      };

  factory TuneCalcInput.fromJson(Map<String, dynamic> json) => TuneCalcInput(
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        driveType: json['driveType'] as String? ?? 'RWD',
        surface: json['surface'] as String? ?? 'Street',
        tuneType: json['tuneType'] as String? ?? 'Race',
        pi: (json['pi'] as num?)?.toInt() ?? 700,
        topSpeedKmh: (json['topSpeedKmh'] as num?)?.toDouble() ?? 300,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 1400,
        frontDistributionPercent:
            (json['frontDistributionPercent'] as num?)?.toDouble() ?? 50,
        maxTorqueNm: (json['maxTorqueNm'] as num?)?.toDouble() ?? 500,
        gears: (json['gears'] as num?)?.toInt() ?? 6,
        tireWidth: (json['tireWidth'] as num?)?.toDouble() ?? 275,
        tireAspect: (json['tireAspect'] as num?)?.toDouble() ?? 30,
        tireRim: (json['tireRim'] as num?)?.toDouble() ?? 19,
        tireType: json['tireType'] as String? ?? 'Sport',
        differentialType: json['differentialType'] as String? ?? 'Race',
        powerBand: TuneCalcPowerBand.fromJson(
          Map<String, dynamic>.from(
              json['powerBand'] as Map? ?? const <String, dynamic>{}),
        ),
      );
}

class TuneCalcSlider {
  const TuneCalcSlider({
    required this.side,
    required this.value,
    required this.min,
    required this.max,
    this.step = 0.1,
    this.decimals = 1,
    this.suffix,
    this.labels,
  });

  final String side;
  final double value;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final String? suffix;
  final List<String>? labels;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'side': side,
        'value': value,
        'min': min,
        'max': max,
        'step': step,
        'decimals': decimals,
        'suffix': suffix,
        'labels': labels,
      };

  factory TuneCalcSlider.fromJson(Map<String, dynamic> json) => TuneCalcSlider(
        side: json['side'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        min: (json['min'] as num?)?.toDouble() ?? 0,
        max: (json['max'] as num?)?.toDouble() ?? 0,
        step: (json['step'] as num?)?.toDouble() ?? 0.1,
        decimals: (json['decimals'] as num?)?.toInt() ?? 1,
        suffix: json['suffix'] as String?,
        labels:
            (json['labels'] as List<dynamic>?)?.map((item) => '$item').toList(),
      );
}

class TuneCalcCard {
  const TuneCalcCard({
    required this.title,
    required this.sliders,
  });

  final String title;
  final List<TuneCalcSlider> sliders;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'sliders': sliders.map((item) => item.toJson()).toList(),
      };

  factory TuneCalcCard.fromJson(Map<String, dynamic> json) => TuneCalcCard(
        title: json['title'] as String? ?? '',
        sliders: (json['sliders'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) =>
                TuneCalcSlider.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

class TuneCalcMetric {
  const TuneCalcMetric({
    required this.key,
    required this.label,
    required this.color,
    required this.score,
    required this.value,
  });

  final String key;
  final String label;
  final Color color;
  final int score;
  final String value;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'label': label,
        'color': color.toARGB32(),
        'score': score,
        'value': value,
      };

  factory TuneCalcMetric.fromJson(Map<String, dynamic> json) => TuneCalcMetric(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        color:
            Color((json['color'] as num?)?.toInt() ?? Colors.white.toARGB32()),
        score: (json['score'] as num?)?.toInt() ?? 0,
        value: json['value'] as String? ?? '',
      );
}

class TuneCalcDetailRow {
  const TuneCalcDetailRow({
    required this.label,
    required this.value,
    required this.progress,
  });

  final String label;
  final String value;
  final double progress;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'value': value,
        'progress': progress,
      };

  factory TuneCalcDetailRow.fromJson(Map<String, dynamic> json) =>
      TuneCalcDetailRow(
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
      );
}

class TuneCalcDetailSection {
  const TuneCalcDetailSection({
    required this.key,
    required this.title,
    required this.color,
    required this.rows,
  });

  final String key;
  final String title;
  final Color color;
  final List<TuneCalcDetailRow> rows;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'title': title,
        'color': color.toARGB32(),
        'rows': rows.map((item) => item.toJson()).toList(),
      };

  factory TuneCalcDetailSection.fromJson(Map<String, dynamic> json) =>
      TuneCalcDetailSection(
        key: json['key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        color:
            Color((json['color'] as num?)?.toInt() ?? Colors.white.toARGB32()),
        rows: (json['rows'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => TuneCalcDetailRow.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

class TuneCalcOverview {
  const TuneCalcOverview({
    required this.topSpeedDisplay,
    required this.tireType,
    required this.differentialType,
    required this.metrics,
    required this.detailSections,
  });

  final String topSpeedDisplay;
  final String tireType;
  final String differentialType;
  final List<TuneCalcMetric> metrics;
  final List<TuneCalcDetailSection> detailSections;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'topSpeedDisplay': topSpeedDisplay,
        'tireType': tireType,
        'differentialType': differentialType,
        'metrics': metrics.map((item) => item.toJson()).toList(),
        'detailSections': detailSections.map((item) => item.toJson()).toList(),
      };

  factory TuneCalcOverview.fromJson(Map<String, dynamic> json) =>
      TuneCalcOverview(
        topSpeedDisplay: json['topSpeedDisplay'] as String? ?? '--',
        tireType: json['tireType'] as String? ?? '--',
        differentialType: json['differentialType'] as String? ?? '--',
        metrics: (json['metrics'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) =>
                TuneCalcMetric.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        detailSections:
            (json['detailSections'] as List<dynamic>? ?? const <dynamic>[])
                .map(
                  (item) => TuneCalcDetailSection.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
      );
}

class TuneCalcGearRatio {
  const TuneCalcGearRatio({
    required this.gear,
    required this.ratio,
    required this.topSpeedKmh,
  });

  final int gear;
  final double ratio;
  final double topSpeedKmh;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'gear': gear,
        'ratio': ratio,
        'topSpeedKmh': topSpeedKmh,
      };

  factory TuneCalcGearRatio.fromJson(Map<String, dynamic> json) =>
      TuneCalcGearRatio(
        gear: (json['gear'] as num?)?.toInt() ?? 1,
        ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
        topSpeedKmh: (json['topSpeedKmh'] as num?)?.toDouble() ?? 0,
      );
}

class TuneCalcGearingData {
  const TuneCalcGearingData({
    required this.finalDrive,
    required this.redlineRpm,
    required this.scaleMaxKmh,
    required this.ratios,
  });

  final double finalDrive;
  final double redlineRpm;
  final double scaleMaxKmh;
  final List<TuneCalcGearRatio> ratios;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'finalDrive': finalDrive,
        'redlineRpm': redlineRpm,
        'scaleMaxKmh': scaleMaxKmh,
        'ratios': ratios.map((item) => item.toJson()).toList(),
      };

  factory TuneCalcGearingData.fromJson(Map<String, dynamic> json) =>
      TuneCalcGearingData(
        finalDrive: (json['finalDrive'] as num?)?.toDouble() ?? 0,
        redlineRpm: (json['redlineRpm'] as num?)?.toDouble() ?? 10000,
        scaleMaxKmh: (json['scaleMaxKmh'] as num?)?.toDouble() ?? 300,
        ratios: (json['ratios'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => TuneCalcGearRatio.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

class TuneCalcResult {
  const TuneCalcResult({
    required this.cards,
    required this.overview,
    required this.subtitle,
    required this.gearing,
  });

  final List<TuneCalcCard> cards;
  final TuneCalcOverview overview;
  final String subtitle;
  final TuneCalcGearingData gearing;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'cards': cards.map((item) => item.toJson()).toList(),
        'overview': overview.toJson(),
        'subtitle': subtitle,
        'gearing': gearing.toJson(),
      };

  factory TuneCalcResult.fromJson(Map<String, dynamic> json) => TuneCalcResult(
        cards: (json['cards'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) =>
                TuneCalcCard.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        overview: TuneCalcOverview.fromJson(
          Map<String, dynamic>.from(
              json['overview'] as Map? ?? const <String, dynamic>{}),
        ),
        subtitle: json['subtitle'] as String? ?? '',
        gearing: TuneCalcGearingData.fromJson(
          Map<String, dynamic>.from(
              json['gearing'] as Map? ?? const <String, dynamic>{}),
        ),
      );
}
