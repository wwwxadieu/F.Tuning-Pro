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
}

class TuneCalcCard {
  const TuneCalcCard({
    required this.title,
    required this.sliders,
  });

  final String title;
  final List<TuneCalcSlider> sliders;
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
}
