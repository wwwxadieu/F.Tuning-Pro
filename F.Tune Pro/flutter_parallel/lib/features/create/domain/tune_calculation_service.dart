import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tune_models.dart';

class TuneCalculationService {
  const TuneCalculationService._();

  static TuneCalcResult calculate(TuneCalcInput input, {bool metric = true}) {
    final driveType = _normalizeDriveType(input.driveType) ?? 'FWD';
    final surfaceKey = _normalizeSurfaceKey(input.surface);
    final tuneKey = _normalizeTuneTypeKey(input.tuneType);
    final surfaceProfile = _surfaceProfile(_surfaceTuneBucket(surfaceKey));

    final weightKg = _clamp(input.weightKg, 600, 2600);
    final frontDistributionPercent = _clamp(input.frontDistributionPercent, 35, 65);
    final currentPi = _clamp(input.pi.toDouble(), 100, 999);
    final topSpeedKmh = _clamp(input.topSpeedKmh, 80, 500);
    final maxTorqueNm = _clamp(input.maxTorqueNm, 100, 2000);
    final gears = _clamp(input.gears.toDouble(), 2, 10).round();
    final tireWidth = _clamp(input.tireWidth, 120, 500);
    final tireAspect = _clamp(input.tireAspect, 20, 80);
    final tireRim = _clamp(input.tireRim, 13, 24);
    final powerBand = _normalizePowerBand(input.powerBand);
    final redlineRpm = powerBand.redlineRpm.toDouble();
    final torquePeakRpm = powerBand.maxTorqueRpm.toDouble();

    final weightN = _clamp((weightKg - 900) / 1200, 0, 1);
    final piN = _clamp((currentPi - 100) / 899, 0, 1);
    final speedN = _clamp((topSpeedKmh - 120) / 300, 0, 1);
    final torqueN = _clamp((maxTorqueNm - 150) / 1150, 0, 1);
    final frontBias = _clamp(frontDistributionPercent / 100, 0.35, 0.65);
    final rearBias = 1 - frontBias;
    final tireGripMultiplier = _tireGripMultiplier(input.tireType);
    final differentialTier = _differentialTier(input.differentialType);
    final totalGrip = _clamp(surfaceProfile.gripMultiplier * tireGripMultiplier, 0.55, 1.35);
    final isLooseSurface = surfaceKey != 'street';
    final isDriftTune = tuneKey == 'drift';
    final isDragTune = tuneKey == 'drag';
    final isRaceTune = tuneKey == 'race' || tuneKey == 'rain';
    final isRallyLikeTune = tuneKey == 'rally' || tuneKey == 'buggy' || tuneKey == 'truck';

    final topSpeedMps = topSpeedKmh / 3.6;
    final tireCircumferenceM = _tireCircumferenceMeters(tireWidth, tireAspect, tireRim);
    final wheelRpmAtTopSpeed = _clamp((topSpeedMps / math.max(tireCircumferenceM, 0.1)) * 60, 100, 8000);
    final topGearRatio = _topGearRatio(gears);
    final tractionSlipAllowance = isDragTune ? 0.98 : (surfaceKey == 'street' ? 0.96 : 0.92);
    var gearingFinal = redlineRpm / math.max(wheelRpmAtTopSpeed * topGearRatio * tractionSlipAllowance, 1);
    final powerBandShape = _clamp(torquePeakRpm / math.max(redlineRpm, 1), 0.35, 0.95);
    if (isDriftTune) gearingFinal *= 1.05;
    if (isLooseSurface || isRallyLikeTune) gearingFinal *= 1.07;
    if (isDragTune) gearingFinal *= 0.93;
    gearingFinal *= 1 + ((1 - powerBandShape) * 0.08);
    gearingFinal = _clamp(gearingFinal, 2.2, 5.8);

    final peakPowerHp = (maxTorqueNm * math.max(torquePeakRpm, 1000)) / 7127;
    final powerToWeightHpPerTon = peakPowerHp / math.max(weightKg / 1000, 0.7);
    final powerToWeightN = _clamp((powerToWeightHpPerTon - 90) / 820, 0, 1.2);
    final targetLatG = _clamp(
      (totalGrip * (0.82 + (0.3 * piN) + (0.08 * speedN) + (0.06 * powerToWeightN))) +
          (isRaceTune ? 0.05 : 0) -
          (isLooseSurface ? 0.04 : 0),
      0.65,
      1.85,
    );

    final vehicleWeightN = weightKg * 9.81;
    final frontLoadPerTireN = (vehicleWeightN * frontBias) / 2;
    final rearLoadPerTireN = (vehicleWeightN * rearBias) / 2;
    final contactPatchFactor = _clamp(1 + ((tireWidth - 245) / 520), 0.72, 1.35);

    var pressureFront = surfaceProfile.basePressure +
        ((frontLoadPerTireN / (2750 * contactPatchFactor)) - 1) +
        (0.16 * speedN) +
        (isRaceTune && tireGripMultiplier >= 1.1 ? 0.05 : 0) +
        (isDragTune ? -0.04 : 0) +
        (isLooseSurface ? -0.09 : 0);
    var pressureRear = surfaceProfile.basePressure +
        ((rearLoadPerTireN / (2750 * contactPatchFactor)) - 1) +
        (0.18 * speedN) +
        (isRaceTune && tireGripMultiplier >= 1.1 ? 0.04 : 0) +
        (isDragTune ? 0.11 : 0) +
        (isLooseSurface ? -0.12 : 0);
    pressureFront = _clamp(pressureFront, 1.2, 2.8);
    pressureRear = _clamp(pressureRear, 1.2, 2.8);

    final camberLoadFactor = _clamp((targetLatG - 0.7) / 1.05, 0, 1.2);
    var camberFront = -(0.5 + (1.9 * camberLoadFactor) + (0.2 * speedN) + (isDriftTune ? 0.45 : 0));
    var camberRear = -(0.28 + (1.45 * camberLoadFactor) + (driveType == 'RWD' ? 0.12 : 0) + (isDriftTune ? 0.3 : 0) - (isDragTune ? 0.25 : 0));
    if (isLooseSurface) {
      camberFront += 0.18;
      camberRear += 0.2;
    }
    if (isDriftTune) {
      camberFront -= 0.12;
      camberRear -= 0.08;
    }
    camberFront = _clamp(camberFront, -5, 5);
    camberRear = _clamp(camberRear, -5, 5);

    var toeFront = isDriftTune ? 0.22 : (isLooseSurface ? 0.08 : 0.03);
    var toeRear = isDriftTune ? 0.34 : (isLooseSurface ? 0.1 : -0.03);
    if (driveType == 'FWD') toeFront += 0.02;
    if (driveType == 'RWD') toeRear += 0.04;
    if (isDragTune) {
      toeFront = -0.02;
      toeRear = 0.18;
    }
    toeFront = _clamp(toeFront, -1, 1);
    toeRear = _clamp(toeRear, -1, 1);
    var casterFront = 4.7 + (2.1 * speedN) + (1.1 * piN) + (isDriftTune ? 0.9 : 0) - (isLooseSurface ? 0.45 : 0);
    var casterRear = 3.6 + (1.6 * speedN) + (0.75 * piN) + (isDriftTune ? 0.7 : 0) - (isLooseSurface ? 0.55 : 0);
    casterFront = _clamp(casterFront, 0, 10);
    casterRear = _clamp(casterRear, 0, 10);

    final frontAxleMass = weightKg * frontBias;
    final rearAxleMass = weightKg * rearBias;
    final frontCornerMass = math.max((frontAxleMass * 0.9) / 2, 100);
    final rearCornerMass = math.max((rearAxleMass * 0.9) / 2, 100);

    final baseRideFrequency = surfaceProfile.rideFrequency + (0.26 * piN) + (0.16 * speedN);
    var rideFrequencyFront = baseRideFrequency + ((frontBias - 0.5) * 0.45) + (driveType == 'FWD' ? 0.06 : 0) + (isDriftTune ? 0.1 : 0) + (isDragTune ? -0.2 : 0);
    var rideFrequencyRear = baseRideFrequency - ((frontBias - 0.5) * 0.45) + (driveType == 'RWD' ? 0.08 : 0) + (isDriftTune ? 0.12 : 0) + (isDragTune ? 0.24 : 0);
    rideFrequencyFront = _clamp(rideFrequencyFront, 1.2, 3.2);
    rideFrequencyRear = _clamp(rideFrequencyRear, 1.2, 3.2);

    final springFrontNPerM = math.pow((2 * math.pi * rideFrequencyFront), 2) * frontCornerMass;
    final springRearNPerM = math.pow((2 * math.pi * rideFrequencyRear), 2) * rearCornerMass;
    final springFront = _clamp(springFrontNPerM / 1000, 20, 260);
    final springRear = _clamp(springRearNPerM / 1000, 20, 260);

    final totalArbTarget = _clamp((springFront + springRear) * (0.24 + (0.14 * targetLatG)), 10, 120);
    var arbFrontShare = frontBias +
        (driveType == 'FWD' ? -0.05 : driveType == 'RWD' ? 0.04 : 0) +
        (isDriftTune ? -0.05 : 0) +
        (isLooseSurface ? -0.02 : 0);
    arbFrontShare = _clamp(arbFrontShare, 0.35, 0.65);
    final antiRollFront = _clamp(totalArbTarget * arbFrontShare, 1, 65);
    final antiRollRear = _clamp(totalArbTarget * (1 - arbFrontShare), 1, 65);

    var rideHeightFront = surfaceProfile.rideHeightFront + (2.3 * weightN) + (isDriftTune ? 1.4 : 0) + (isLooseSurface ? 1.6 : 0) - (isRaceTune ? 2.2 * speedN : 0);
    var rideHeightRear = surfaceProfile.rideHeightRear + (2 * weightN) + (isDriftTune ? 1.1 : 0) + (isLooseSurface ? 1.9 : 0) - (isRaceTune ? 1.5 * speedN : 0);
    if (isDragTune) {
      rideHeightFront = 5.5;
      rideHeightRear = 8.5;
    }
    rideHeightFront = _clamp(rideHeightFront, 0, 100);
    rideHeightRear = _clamp(rideHeightRear, 0, 100);

    final frontCriticalDamping = 2 * math.sqrt(springFrontNPerM * frontCornerMass);
    final rearCriticalDamping = 2 * math.sqrt(springRearNPerM * rearCornerMass);
    final frontReboundRatio = surfaceProfile.reboundRatio + (0.06 * piN) + (0.05 * speedN) + (isDriftTune ? 0.05 : 0);
    final rearReboundRatio = surfaceProfile.reboundRatio + (0.06 * piN) + (0.04 * speedN) + (driveType == 'RWD' ? 0.03 : 0) + (isDriftTune ? 0.06 : 0);
    final reboundFront = _clamp((frontCriticalDamping * frontReboundRatio) / 520, 1, 20);
    final reboundRear = _clamp((rearCriticalDamping * rearReboundRatio) / 520, 1, 20);
    final bumpFront = _clamp(reboundFront * surfaceProfile.bumpToReboundRatio, 1, 20);
    final bumpRear = _clamp(reboundRear * surfaceProfile.bumpToReboundRatio, 1, 20);

    var aeroDemand = speedN + ((targetLatG - 1) * 0.55) + (isRaceTune ? 0.24 : 0) + (isDriftTune ? 0.05 : 0) - (isLooseSurface ? 0.24 : 0) - (isDragTune ? 0.6 : 0);
    aeroDemand = _clamp(aeroDemand, 0, 1.3);
    final aeroFront = _clamp((isDragTune ? 0 : (aeroDemand >= 1 ? 2 : (aeroDemand >= 0.55 ? 1 : 0))).toDouble(), 0, 2).roundToDouble();
    final aeroRear = _clamp((isDragTune ? 0 : (aeroDemand >= 0.72 ? 1 : 0)).toDouble(), 0, 1).roundToDouble();

    final dynamicFrontBrakeShare = _clamp(
      frontBias + 0.06 + (0.05 * speedN) - (driveType == 'RWD' ? 0.02 : 0) - (isLooseSurface ? 0.02 : 0),
      0.35,
      0.65,
    );
    final brakeBalance = _clamp(dynamicFrontBrakeShare * 100, 35, 65);
    final brakeForce = _clamp(
      58 + (55 * totalGrip) + (18 * speedN) + (12 * piN) + (isDragTune ? 8 : 0) - (isLooseSurface ? 14 : 0),
      50,
      150,
    );

    final diffAggression = _clamp(
      0.35 + (0.45 * differentialTier) + (0.25 * torqueN) + (isDriftTune ? 0.2 : 0) + (isDragTune ? 0.15 : 0),
      0,
      1.4,
    );

    var frontDifferential = 0.0;
    var rearDifferential = 0.0;
    var centerDifferential = 0.0;
    if (driveType == 'FWD') {
      frontDifferential = _clamp(22 + (48 * diffAggression) + (isDragTune ? 6 : 0) - (isLooseSurface ? 8 : 0), 0, 100);
    } else if (driveType == 'RWD') {
      rearDifferential = _clamp(28 + (52 * diffAggression) + (isDriftTune ? 10 : 0) + (isDragTune ? 8 : 0) - (isLooseSurface ? 6 : 0), 0, 100);
    } else {
      frontDifferential = _clamp(14 + (32 * diffAggression) + (isDriftTune ? 8 : 0) - (isLooseSurface ? 6 : 0), 0, 100);
      rearDifferential = _clamp(26 + (42 * diffAggression) + (isDriftTune ? 12 : 0) + (isDragTune ? 6 : 0) - (isLooseSurface ? 5 : 0), 0, 100);
      centerDifferential = _clamp(40 + (36 * diffAggression) + (isDriftTune ? 16 : 0) + (isDragTune ? 10 : 0) - (isLooseSurface ? 10 : 0), 0, 100);
    }

    final cards = <TuneCalcCard>[
      TuneCalcCard(title: 'Pressure (bar)', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: pressureFront, min: 1, max: 3, step: 0.01, decimals: 2, suffix: ' bar'),
        TuneCalcSlider(side: 'R', value: pressureRear, min: 1, max: 3, step: 0.01, decimals: 2, suffix: ' bar'),
      ]),
      TuneCalcCard(title: 'Camber', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: camberFront, min: -5, max: 5, step: 0.01, decimals: 2, suffix: ' deg'),
        TuneCalcSlider(side: 'R', value: camberRear, min: -5, max: 5, step: 0.01, decimals: 2, suffix: ' deg'),
      ]),
      TuneCalcCard(title: 'Gearing', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'Final', value: gearingFinal, min: 2.2, max: 5.8, step: 0.01, decimals: 2),
      ]),
      TuneCalcCard(title: 'Toe', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: toeFront, min: -1, max: 1, step: 0.01, decimals: 2, suffix: ' deg'),
        TuneCalcSlider(side: 'R', value: toeRear, min: -1, max: 1, step: 0.01, decimals: 2, suffix: ' deg'),
      ]),
      TuneCalcCard(title: 'Caster', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: casterFront, min: 0, max: 10, step: 0.01, decimals: 2, suffix: ' deg'),
        TuneCalcSlider(side: 'R', value: casterRear, min: 0, max: 10, step: 0.01, decimals: 2, suffix: ' deg'),
      ]),
      TuneCalcCard(title: 'Anti-roll Bars', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: antiRollFront, min: 1, max: 65, step: 0.1, decimals: 1),
        TuneCalcSlider(side: 'R', value: antiRollRear, min: 1, max: 65, step: 0.1, decimals: 1),
      ]),
      TuneCalcCard(title: 'Springs (N/mm)', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: springFront, min: 20, max: 260, step: 0.1, decimals: 1, suffix: ' N/mm'),
        TuneCalcSlider(side: 'R', value: springRear, min: 20, max: 260, step: 0.1, decimals: 1, suffix: ' N/mm'),
      ]),
      TuneCalcCard(title: 'Ride Height (Min)', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: rideHeightFront, min: 0, max: 100, step: 1, decimals: 0, suffix: ' min'),
        TuneCalcSlider(side: 'R', value: rideHeightRear, min: 0, max: 100, step: 1, decimals: 0, suffix: ' min'),
      ]),
      TuneCalcCard(title: 'Rebound', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: reboundFront, min: 1, max: 20, step: 0.1, decimals: 1),
        TuneCalcSlider(side: 'R', value: reboundRear, min: 1, max: 20, step: 0.1, decimals: 1),
      ]),
      TuneCalcCard(title: 'Bump', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: bumpFront, min: 1, max: 20, step: 0.1, decimals: 1),
        TuneCalcSlider(side: 'R', value: bumpRear, min: 1, max: 20, step: 0.1, decimals: 1),
      ]),
      TuneCalcCard(title: 'Aero Downforce', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'F', value: aeroFront, min: 0, max: 2, step: 1, labels: const <String>['Low', 'Med', 'High']),
        TuneCalcSlider(side: 'R', value: aeroRear, min: 0, max: 1, step: 1, labels: const <String>['Low', 'Med']),
      ]),
      TuneCalcCard(title: 'Braking', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'Balance', value: brakeBalance, min: 35, max: 65, step: 0.1, decimals: 1, suffix: '%'),
        TuneCalcSlider(side: 'Force', value: brakeForce, min: 50, max: 150, step: 0.1, decimals: 1, suffix: '%'),
      ]),
      TuneCalcCard(title: 'Front Differential', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'Front', value: frontDifferential, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%'),
      ]),
      TuneCalcCard(title: 'Rear Differential', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'Rear', value: rearDifferential, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%'),
      ]),
      TuneCalcCard(title: 'Center (%)', sliders: <TuneCalcSlider>[
        TuneCalcSlider(side: 'Center', value: centerDifferential, min: 0, max: 100, step: 0.1, decimals: 1, suffix: '%'),
      ]),
    ];

    final gearing = _buildGearingData(
      finalDrive: gearingFinal,
      gearCount: gears,
      redlineRpm: redlineRpm,
      topSpeedKmh: topSpeedKmh,
      tireWidth: tireWidth,
      tireAspect: tireAspect,
      tireRim: tireRim,
    );
    final subtitle = '${input.brand} ${input.model} • $driveType • ${_titleCase(surfaceKey)} • ${_titleCase(tuneKey)} • PI ${currentPi.round()}';

    return TuneCalcResult(
      cards: cards,
      overview: _buildOverview(
        input: input,
        cards: cards,
        metric: metric,
        driveType: driveType,
        surfaceKey: surfaceKey,
        tuneKey: tuneKey,
        topSpeedKmh: topSpeedKmh,
        currentPi: currentPi,
        frontDistributionPercent: frontDistributionPercent,
      ),
      subtitle: subtitle,
      gearing: gearing,
    );
  }

  static TuneCalcOverview _buildOverview({
    required TuneCalcInput input,
    required List<TuneCalcCard> cards,
    required bool metric,
    required String driveType,
    required String surfaceKey,
    required String tuneKey,
    required double topSpeedKmh,
    required double currentPi,
    required double frontDistributionPercent,
  }) {
    final piNormalized = _clamp((currentPi - 100) / 899, 0, 1);
    final speedNormalized = _clamp((topSpeedKmh - 120) / 320, 0, 1);
    final frontBiasNormalized = _clamp((frontDistributionPercent - 50) / 20, -1, 1);
    final tireScore = _vehicleModelTireScore(input.tireType);
    final differentialScore = _vehicleModelDifferentialScore(input.differentialType);
    final driveLaunchBonus = driveType == 'AWD' ? 14 : driveType == 'RWD' ? 9 : driveType == 'FWD' ? 6 : 8;
    final driveHandlingBonus = driveType == 'AWD' ? 8 : driveType == 'RWD' ? 6 : driveType == 'FWD' ? 4 : 5;

    final normalizedTireKey = _normalizeSegmentKey(input.tireType);
    final isDragTire = normalizedTireKey.contains('drag');
    final isOffroadTire = normalizedTireKey.contains('offroad') || normalizedTireKey.contains('rally');
    final isSlickTire = normalizedTireKey.contains('slick') && !normalizedTireKey.contains('semi');
    final isSemiSlickTire = normalizedTireKey.contains('semi');

    final gripBiasByTire = isSlickTire ? 1.08 : isSemiSlickTire ? 1.05 : isDragTire ? 0.9 : isOffroadTire ? 0.95 : 1.0;
    final launchBiasByTire = isDragTire ? 1.16 : isSlickTire ? 1.04 : isOffroadTire ? 0.92 : 1.0;
    final speedBiasByTire = isOffroadTire ? 0.9 : isDragTire ? 0.97 : 1.0;

    final driveLaunchBias = driveType == 'AWD' ? 1.12 : driveType == 'RWD' ? 1.04 : driveType == 'FWD' ? 0.95 : 1.0;
    final driveGripBias = driveType == 'AWD' ? 1.08 : driveType == 'RWD' ? 1.01 : driveType == 'FWD' ? 0.96 : 1.0;
    final driveSpeedBonus = driveType == 'RWD' ? 3.5 : driveType == 'AWD' ? 1.6 : driveType == 'FWD' ? -1.0 : 0.0;

    final surfaceGripBias = surfaceKey == 'street' ? 1.04 : surfaceKey == 'dirt' ? 1.1 : surfaceKey == 'cross' ? 1.06 : surfaceKey == 'offroad' ? 1.12 : 1.0;
    final surfaceSpeedBias = surfaceKey == 'street' ? 1.04 : surfaceKey == 'cross' ? 0.97 : surfaceKey == 'dirt' ? 0.94 : surfaceKey == 'offroad' ? 0.9 : 1.0;
    final surfaceLaunchBias = surfaceKey == 'street' ? 1.03 : surfaceKey == 'cross' ? 1.05 : surfaceKey == 'dirt' ? 1.08 : surfaceKey == 'offroad' ? 1.1 : 1.0;

    final tuneGripBias = tuneKey == 'race' ? 1.06 : tuneKey == 'rain' ? 1.09 : tuneKey == 'rally' || tuneKey == 'truck' || tuneKey == 'buggy' ? 1.07 : tuneKey == 'drift' ? 1.02 : 1.0;
    final tuneSpeedBias = tuneKey == 'drag' ? 1.1 : tuneKey == 'race' ? 1.04 : tuneKey == 'rain' ? 0.96 : tuneKey == 'rally' || tuneKey == 'truck' || tuneKey == 'buggy' ? 0.95 : 1.0;
    final tuneLaunchBias = tuneKey == 'drag' ? 1.17 : tuneKey == 'drift' ? 1.07 : tuneKey == 'rally' || tuneKey == 'truck' || tuneKey == 'buggy' ? 1.11 : tuneKey == 'race' ? 1.05 : 1.0;
    final brakingContextBias = tuneKey == 'rain' ? 1.08 : tuneKey == 'drag' ? 0.94 : surfaceKey == 'offroad' ? 0.9 : surfaceKey == 'dirt' ? 0.93 : 1.0;

    final balanceHandlingModifier = _clamp((-frontBiasNormalized) * 7, -6, 6);
    final balanceLaunchModifier = driveType == 'FWD' ? _clamp(frontBiasNormalized * 8, -6, 6) : driveType == 'RWD' ? _clamp((-frontBiasNormalized) * 4, -4, 4) : _clamp(frontBiasNormalized * 2, -2, 2);
    final balanceBrakingModifier = _clamp(frontBiasNormalized * 6, -6, 6);
    final rawGripScore = (tireScore * 0.58) + (differentialScore * 0.16) + (piNormalized * 20) + (speedNormalized * 6) + (driveHandlingBonus * 1.2) + balanceHandlingModifier;
    final handlingScore = _clamp(rawGripScore * gripBiasByTire * driveGripBias * surfaceGripBias * tuneGripBias, 16, 99).round();

    final rawLaunchScore = (tireScore * 0.34) + (differentialScore * 0.24) + (piNormalized * 26) + (speedNormalized * 8) + (driveLaunchBonus * 2.2) + balanceLaunchModifier;
    final launchScore = _clamp(rawLaunchScore * launchBiasByTire * driveLaunchBias * surfaceLaunchBias * tuneLaunchBias, 12, 99).round();

    final rawSpeedScore = (speedNormalized * 82) + (piNormalized * 20) + (differentialScore * 0.06) + driveSpeedBonus;
    final speedScore = _clamp(rawSpeedScore * speedBiasByTire * surfaceSpeedBias * tuneSpeedBias, 12, 99).round();
    final accelScore = _clamp((launchScore * 0.48) + (speedScore * 0.36) + (handlingScore * 0.16), 14, 99).round();

    final rawBrakingScore = (tireScore * 0.62) + (differentialScore * 0.1) + (piNormalized * 18) + (driveHandlingBonus * 1.1) + (isSlickTire ? 2 : 0) + balanceBrakingModifier;
    final brakingScore = _clamp(rawBrakingScore * brakingContextBias, 16, 99).round();

    return TuneCalcOverview(
      topSpeedDisplay: _formatSpeed(topSpeedKmh, metric: metric),
      tireType: _compactTireType(input.tireType),
      differentialType: _compactDifferentialType(input.differentialType),
      metrics: <TuneCalcMetric>[
        TuneCalcMetric(key: 'speed', label: 'Speed', color: const Color(0xFFFF6A1F), score: speedScore, value: metric ? '${topSpeedKmh.round()}' : '${_kmhToMph(topSpeedKmh).round()}'),
        TuneCalcMetric(key: 'handling', label: 'Handling', color: const Color(0xFF13D9C6), score: handlingScore, value: '$handlingScore'),
        TuneCalcMetric(key: 'accel', label: 'Accel', color: const Color(0xFFFFB020), score: accelScore, value: '$accelScore'),
        TuneCalcMetric(key: 'launch', label: 'Launch', color: const Color(0xFFA66BFF), score: launchScore, value: '$launchScore'),
        TuneCalcMetric(key: 'braking', label: 'Braking', color: const Color(0xFF2D86FF), score: brakingScore, value: '$brakingScore'),
      ],
      detailSections: _buildDetailSections(cards),
    );
  }

  static List<TuneCalcDetailSection> _buildDetailSections(List<TuneCalcCard> cards) {
    final pressureCard = _findCard(cards, 'pressure');
    final camberCard = _findCard(cards, 'camber');
    final toeCard = _findCard(cards, 'toe');
    final springsCard = _findCard(cards, 'springs');
    final rideHeightCard = _findCard(cards, 'rideheight');
    final reboundCard = _findCard(cards, 'rebound');
    final bumpCard = _findCard(cards, 'bump');
    final aeroCard = _findCard(cards, 'aero');
    final frontDiffCard = _findCard(cards, 'frontdifferential');
    final rearDiffCard = _findCard(cards, 'reardifferential');
    final brakingCard = _findCard(cards, 'braking');

    final frontDiffAccel = _findSlider(frontDiffCard, 'front');
    final rearDiffAccel = _findSlider(rearDiffCard, 'rear');
    final frontDiffDecel = TuneCalcSlider(side: 'Front', value: _clamp((frontDiffAccel?.value ?? 0) * 0.36, 0, 100), min: 0, max: 100, decimals: 1, suffix: '%');
    final rearDiffDecel = TuneCalcSlider(side: 'Rear', value: _clamp((rearDiffAccel?.value ?? 0) * 0.42, 0, 100), min: 0, max: 100, decimals: 1, suffix: '%');
    final brakeBalance = _findSlider(brakingCard, 'balance');
    final brakeForce = _findSlider(brakingCard, 'force');
    final rearBalanceValue = brakeBalance == null ? null : _clamp(100 - brakeBalance.value, 35, 65);

    return <TuneCalcDetailSection>[
      TuneCalcDetailSection(key: 'tires', title: 'Tires & Alignment', color: const Color(0xFF3B82F6), rows: <TuneCalcDetailRow>[
        _row('Front Pressure', _findSlider(pressureCard, 'f')),
        _row('Rear Pressure', _findSlider(pressureCard, 'r')),
        _row('Front Camber', _findSlider(camberCard, 'f')),
        _row('Rear Camber', _findSlider(camberCard, 'r')),
        _row('Front Toe', _findSlider(toeCard, 'f')),
        _row('Rear Toe', _findSlider(toeCard, 'r')),
      ]),
      TuneCalcDetailSection(key: 'springs', title: 'Springs & Dampers', color: const Color(0xFFF59E0B), rows: <TuneCalcDetailRow>[
        _row('Front Stiffness', _findSlider(springsCard, 'f')),
        _row('Rear Stiffness', _findSlider(springsCard, 'r')),
        _row('Front Height', _findSlider(rideHeightCard, 'f')),
        _row('Rear Height', _findSlider(rideHeightCard, 'r')),
        _row('Front Rebound', _findSlider(reboundCard, 'f')),
        _row('Rear Rebound', _findSlider(reboundCard, 'r')),
        _row('Front Bump', _findSlider(bumpCard, 'f')),
        _row('Rear Bump', _findSlider(bumpCard, 'r')),
      ]),
      TuneCalcDetailSection(key: 'aero', title: 'Aerodynamics', color: const Color(0xFF8B5CF6), rows: <TuneCalcDetailRow>[
        _row('Front Downforce', _findSlider(aeroCard, 'f')),
        _row('Rear Downforce', _findSlider(aeroCard, 'r')),
      ]),
      TuneCalcDetailSection(key: 'drivetrain', title: 'Drivetrain & Diff', color: const Color(0xFF22C55E), rows: <TuneCalcDetailRow>[
        _row('Differential Front Accel', frontDiffAccel),
        _row('Differential Front Decel', frontDiffDecel),
        _row('Differential Rear Accel', rearDiffAccel),
        _row('Differential Rear Decel', rearDiffDecel),
      ]),
      TuneCalcDetailSection(key: 'brakes', title: 'Brakes', color: const Color(0xFFF43F5E), rows: <TuneCalcDetailRow>[
        _row('Front Balance', brakeBalance),
        _row('Rear Balance', rearBalanceValue == null ? null : TuneCalcSlider(side: 'Rear', value: rearBalanceValue, min: 35, max: 65, decimals: 1, suffix: '%')),
        _row('Pressure', brakeForce),
      ]),
    ];
  }

  static TuneCalcDetailRow _row(String label, TuneCalcSlider? slider) {
    if (slider == null) {
      return TuneCalcDetailRow(label: label, value: '--', progress: 0);
    }
    return TuneCalcDetailRow(label: label, value: _formatSliderValue(slider), progress: _sliderProgress(slider));
  }

  static TuneCalcCard? _findCard(List<TuneCalcCard> cards, String token) {
    final normalized = _normalizeSegmentKey(token);
    for (final card in cards) {
      if (_normalizeSegmentKey(card.title).contains(normalized)) {
        return card;
      }
    }
    return null;
  }

  static TuneCalcSlider? _findSlider(TuneCalcCard? card, String sideToken) {
    if (card == null) return null;
    final normalized = _normalizeSegmentKey(sideToken);
    for (final slider in card.sliders) {
      final side = _normalizeSegmentKey(slider.side);
      if (side == normalized || side.contains(normalized)) {
        return slider;
      }
    }
    return null;
  }

  static String _formatSliderValue(TuneCalcSlider slider) {
    if (slider.labels != null && slider.labels!.isNotEmpty) {
      final index = _clamp(slider.value.roundToDouble(), 0, (slider.labels!.length - 1).toDouble()).round();
      return slider.labels![index];
    }
    final fixed = slider.value.toStringAsFixed(slider.decimals);
    final cleaned = fixed.replaceFirst(RegExp(r'\.0+$'), '').replaceFirst(RegExp(r'(\.\d*[1-9])0+$'), r'$1');
    return '$cleaned${slider.suffix ?? ''}';
  }

  static double _sliderProgress(TuneCalcSlider slider) {
    if (slider.max <= slider.min) return 0;
    return _clamp(((slider.value - slider.min) / (slider.max - slider.min)) * 100, 0, 100);
  }

  static TuneCalcGearingData _buildGearingData({
    required double finalDrive,
    required int gearCount,
    required double redlineRpm,
    required double topSpeedKmh,
    required double tireWidth,
    required double tireAspect,
    required double tireRim,
  }) {
    final estimated = _buildEstimatedGearRatios(gearCount);
    final tireCircumferenceM = _tireCircumferenceMeters(tireWidth, tireAspect, tireRim);
    final safeRatios = estimated.map((ratio) => _clamp(ratio, 0.1, 8)).toList();
    final topSpeeds = safeRatios.map((gearRatio) {
      final wheelRpm = redlineRpm / math.max(gearRatio * finalDrive, 0.12);
      final speedMps = (wheelRpm / 60) * tireCircumferenceM;
      return _clamp(speedMps * 3.6, 6, 640);
    }).toList();
    final scaleMaxKmh = _clamp(
      ((math.max(topSpeedKmh, topSpeeds.fold<double>(0, math.max)) + 5) / 10).ceil() * 10,
      120,
      680,
    );

    return TuneCalcGearingData(
      finalDrive: double.parse(finalDrive.toStringAsFixed(2)),
      redlineRpm: redlineRpm,
      scaleMaxKmh: scaleMaxKmh,
      ratios: List<TuneCalcGearRatio>.generate(safeRatios.length, (index) {
        return TuneCalcGearRatio(
          gear: index + 1,
          ratio: double.parse(safeRatios[index].toStringAsFixed(2)),
          topSpeedKmh: double.parse(topSpeeds[index].toStringAsFixed(1)),
        );
      }),
    );
  }

  static List<double> _buildEstimatedGearRatios(int gearCount) {
    final clampedGearCount = _clamp(gearCount.toDouble(), 2, 10).round();
    final topGearRatio = _topGearRatio(clampedGearCount);
    const firstGearRatioByCount = <int, double>{
      2: 2.2,
      3: 2.65,
      4: 2.95,
      5: 3.1,
      6: 3.25,
      7: 3.35,
      8: 3.45,
      9: 3.52,
      10: 3.58,
    };
    final firstGearRatio = math.max(
      firstGearRatioByCount[clampedGearCount] ?? 3.2,
      topGearRatio + 0.35,
    );

    return List<double>.generate(clampedGearCount, (index) {
      final progress = clampedGearCount <= 1 ? 0 : (index / (clampedGearCount - 1));
      final ratio = firstGearRatio * math.pow(topGearRatio / firstGearRatio, progress);
      return double.parse(ratio.toStringAsFixed(2));
    });
  }

  static TuneCalcPowerBand _normalizePowerBand(TuneCalcPowerBand powerBand) {
    final scaleMax = _roundToStep(_clamp(powerBand.scaleMax.toDouble(), 6000, 20000), 100).round();
    final redline = _roundToStep(_clamp(powerBand.redlineRpm.toDouble(), 0, scaleMax.toDouble()), 100).round();
    final torquePeak = _roundToStep(_clamp(powerBand.maxTorqueRpm.toDouble(), 0, redline.toDouble()), 100).round();
    return TuneCalcPowerBand(scaleMax: scaleMax, redlineRpm: redline, maxTorqueRpm: torquePeak);
  }

  static _SurfaceProfile _surfaceProfile(String surfaceKey) {
    if (surfaceKey == 'dirt') {
      return const _SurfaceProfile(gripMultiplier: 0.78, basePressure: 1.8, rideFrequency: 1.58, rideHeightFront: 28, rideHeightRear: 31, reboundRatio: 0.68, bumpToReboundRatio: 0.54);
    }
    if (surfaceKey == 'offroad') {
      return const _SurfaceProfile(gripMultiplier: 0.7, basePressure: 1.72, rideFrequency: 1.46, rideHeightFront: 34, rideHeightRear: 38, reboundRatio: 0.64, bumpToReboundRatio: 0.52);
    }
    return const _SurfaceProfile(gripMultiplier: 1, basePressure: 2.12, rideFrequency: 2.16, rideHeightFront: 7, rideHeightRear: 10, reboundRatio: 0.78, bumpToReboundRatio: 0.58);
  }

  static String _surfaceTuneBucket(String surfaceKey) {
    if (surfaceKey == 'dirt') return 'dirt';
    if (surfaceKey == 'cross' || surfaceKey == 'offroad') return 'offroad';
    return 'race';
  }

  static double _tireGripMultiplier(String tireType) {
    final key = _normalizeSegmentKey(tireType);
    if (key.contains('slick') && !key.contains('semi')) return 1.2;
    if (key.contains('semislick')) return 1.12;
    if (key.contains('sport')) return 1.03;
    if (key.contains('offroad') || key.contains('rally')) return 0.88;
    if (key.contains('drag')) return 0.92;
    if (key.contains('drift')) return 0.96;
    return 0.95;
  }

  static double _differentialTier(String differentialType) {
    final key = _normalizeSegmentKey(differentialType);
    if (key.contains('race')) return 1;
    if (key.contains('sport')) return 0.68;
    return 0.42;
  }

  static double _topGearRatio(int gearCount) {
    const ratios = <int, double>{2: 1, 3: 0.86, 4: 0.77, 5: 0.7, 6: 0.64, 7: 0.58, 8: 0.53, 9: 0.49, 10: 0.45};
    return ratios[gearCount] ?? 0.64;
  }

  static double _tireCircumferenceMeters(double tireWidthMm, double tireAspectPercent, double tireRimInches) {
    final sidewallHeightMeters = (tireWidthMm * (tireAspectPercent / 100)) / 1000;
    final rimDiameterMeters = tireRimInches * 0.0254;
    final tireDiameterMeters = rimDiameterMeters + (2 * sidewallHeightMeters);
    if (!tireDiameterMeters.isFinite || tireDiameterMeters <= 0) return 2.05;
    return math.pi * tireDiameterMeters;
  }

  static int _vehicleModelTireScore(String tireType) {
    final normalized = _normalizeSegmentKey(tireType);
    if (normalized.contains('slick') && !normalized.contains('semi')) return 93;
    if (normalized.contains('semi')) return 86;
    if (normalized.contains('sport')) return 77;
    if (normalized.contains('offroad') || normalized.contains('rally')) return 64;
    if (normalized.contains('drag')) return 70;
    return 68;
  }

  static int _vehicleModelDifferentialScore(String differentialType) {
    final normalized = _normalizeSegmentKey(differentialType);
    if (normalized.contains('race')) return 92;
    if (normalized.contains('sport')) return 78;
    if (normalized.contains('drift')) return 84;
    if (normalized.contains('drag')) return 82;
    return 66;
  }

  static String? _normalizeDriveType(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized == 'FWD' || normalized == 'RWD' || normalized == 'AWD') return normalized;
    return null;
  }

  static String _normalizeSurfaceKey(String value) {
    final normalized = _normalizeSegmentKey(value);
    if (normalized == 'street' || normalized.isEmpty) return 'street';
    if (normalized == 'dirt') return 'dirt';
    if (normalized == 'cross') return 'cross';
    if (normalized == 'offroad') return 'offroad';
    return normalized;
  }

  static String _normalizeTuneTypeKey(String value) {
    final normalized = _normalizeSegmentKey(value);
    if (normalized == 'dua') return 'race';
    if (normalized == 'mua') return 'rain';
    return normalized.isEmpty ? 'race' : normalized;
  }

  static String _normalizeSegmentKey(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

  static String _compactTireType(String value) {
    final compact = value.replaceAll(RegExp(r'\s*tire$', caseSensitive: false), '').trim();
    return compact.isEmpty ? value : compact;
  }

  static String _compactDifferentialType(String value) {
    final compact = value.replaceAll(RegExp(r'\s*differential$', caseSensitive: false), '').trim();
    return compact.isEmpty ? value : compact;
  }

  static String _formatSpeed(double speedKmh, {required bool metric}) => metric ? '${speedKmh.toStringAsFixed(1)} km/h' : '${_kmhToMph(speedKmh).toStringAsFixed(1)} mph';

  static double _kmhToMph(double value) => value * 0.6213711922;

  static String _titleCase(String value) => value.isEmpty ? '--' : value[0].toUpperCase() + value.substring(1);

  static double _clamp(double value, double min, double max) {
    if (!value.isFinite) return min;
    return math.min(max, math.max(min, value));
  }

  static double _roundToStep(double value, double step) => (value / step).round() * step;
}

class _SurfaceProfile {
  const _SurfaceProfile({
    required this.gripMultiplier,
    required this.basePressure,
    required this.rideFrequency,
    required this.rideHeightFront,
    required this.rideHeightRear,
    required this.reboundRatio,
    required this.bumpToReboundRatio,
  });

  final double gripMultiplier;
  final double basePressure;
  final double rideFrequency;
  final double rideHeightFront;
  final double rideHeightRear;
  final double reboundRatio;
  final double bumpToReboundRatio;
}
