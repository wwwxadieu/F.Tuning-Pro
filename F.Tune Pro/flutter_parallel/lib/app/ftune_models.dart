import '../features/create/domain/tune_models.dart';

enum AppSection {
  dashboard,
  create,
  garage,
  settings,
}

class AppPreferences {
  const AppPreferences({
    required this.useMetric,
    required this.languageCode,
    required this.themeMode,
    required this.autoSaveGarage,
    required this.overlayPreviewEnabled,
    required this.overlayOnTop,
    required this.overlayOpacity,
    required this.overlayTextScale,
    required this.overlayLayout,
    required this.overlayLocked,
    this.autoBackgroundFromCarColor = true,
    this.accentColorValue = 0xFFCAFF03,
  });

  const AppPreferences.defaults()
      : useMetric = true,
        languageCode = 'en',
        themeMode = 'dark',
        autoSaveGarage = true,
        overlayPreviewEnabled = true,
        overlayOnTop = true,
        overlayOpacity = 0.88,
        overlayTextScale = 1.0,
        overlayLayout = 'vertical',
        overlayLocked = false,
        autoBackgroundFromCarColor = true,
        accentColorValue = 0xFFCAFF03;

  final bool useMetric;
  final String languageCode;
  final String themeMode;
  final bool autoSaveGarage;
  final bool overlayPreviewEnabled;
  final bool overlayOnTop;
  final double overlayOpacity;
  final double overlayTextScale;
  final String overlayLayout;
  final bool overlayLocked;
  final bool autoBackgroundFromCarColor;
  final int accentColorValue;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'useMetric': useMetric,
        'languageCode': languageCode,
        'themeMode': themeMode,
        'autoSaveGarage': autoSaveGarage,
        'overlayPreviewEnabled': overlayPreviewEnabled,
        'overlayOnTop': overlayOnTop,
        'overlayOpacity': overlayOpacity,
        'overlayTextScale': overlayTextScale,
        'overlayLayout': overlayLayout,
        'overlayLocked': overlayLocked,
        'autoBackgroundFromCarColor': autoBackgroundFromCarColor,
        'accentColorValue': accentColorValue,
      };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
        useMetric: json['useMetric'] as bool? ?? true,
        languageCode: json['languageCode'] as String? ?? 'en',
        themeMode: json['themeMode'] as String? ?? 'dark',
        autoSaveGarage: json['autoSaveGarage'] as bool? ?? true,
        overlayPreviewEnabled: json['overlayPreviewEnabled'] as bool? ?? true,
        overlayOnTop: json['overlayOnTop'] as bool? ?? true,
        overlayOpacity: ((json['overlayOpacity'] as num?) ?? 0.88)
            .toDouble()
            .clamp(0.35, 1.0),
        overlayTextScale: ((json['overlayTextScale'] as num?) ?? 1.0)
            .toDouble()
            .clamp(0.85, 1.35),
        overlayLayout: _normalizeOverlayLayout(
          json['overlayLayout'] as String? ?? 'vertical',
        ),
        overlayLocked: json['overlayLocked'] as bool? ?? false,
        autoBackgroundFromCarColor:
            json['autoBackgroundFromCarColor'] as bool? ?? true,
        accentColorValue:
            json['accentColorValue'] as int? ?? 0xFFCAFF03,
      );

  AppPreferences copyWith({
    bool? useMetric,
    String? languageCode,
    String? themeMode,
    bool? autoSaveGarage,
    bool? overlayPreviewEnabled,
    bool? overlayOnTop,
    double? overlayOpacity,
    double? overlayTextScale,
    String? overlayLayout,
    bool? overlayLocked,
    bool? autoBackgroundFromCarColor,
    int? accentColorValue,
  }) {
    return AppPreferences(
      useMetric: useMetric ?? this.useMetric,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      autoSaveGarage: autoSaveGarage ?? this.autoSaveGarage,
      overlayPreviewEnabled:
          overlayPreviewEnabled ?? this.overlayPreviewEnabled,
      overlayOnTop: overlayOnTop ?? this.overlayOnTop,
      overlayOpacity:
          (overlayOpacity ?? this.overlayOpacity).clamp(0.35, 1.0).toDouble(),
      overlayTextScale: (overlayTextScale ?? this.overlayTextScale)
          .clamp(0.85, 1.35)
          .toDouble(),
      overlayLayout:
          _normalizeOverlayLayout(overlayLayout ?? this.overlayLayout),
      overlayLocked: overlayLocked ?? this.overlayLocked,
      autoBackgroundFromCarColor:
          autoBackgroundFromCarColor ?? this.autoBackgroundFromCarColor,
      accentColorValue: accentColorValue ?? this.accentColorValue,
    );
  }
}

String _normalizeOverlayLayout(String value) {
  switch (value) {
    case 'horizontal':
    case 'compact':
      return value;
    default:
      return 'vertical';
  }
}

class SavedTuneDraft {
  const SavedTuneDraft({
    required this.title,
    required this.shareCode,
    required this.brand,
    required this.model,
    required this.driveType,
    required this.surface,
    required this.tuneType,
    required this.piClass,
    required this.topSpeedDisplay,
    required this.result,
    this.session,
  });

  final String title;
  final String shareCode;
  final String brand;
  final String model;
  final String driveType;
  final String surface;
  final String tuneType;
  final String piClass;
  final String topSpeedDisplay;
  final TuneCalcResult result;
  final CreateTuneSession? session;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'shareCode': shareCode,
        'brand': brand,
        'model': model,
        'driveType': driveType,
        'surface': surface,
        'tuneType': tuneType,
        'piClass': piClass,
        'topSpeedDisplay': topSpeedDisplay,
        'result': result.toJson(),
        'session': session?.toJson(),
      };
}

class SavedTuneRecord {
  const SavedTuneRecord({
    required this.id,
    required this.title,
    required this.shareCode,
    required this.brand,
    required this.model,
    required this.driveType,
    required this.surface,
    required this.tuneType,
    required this.piClass,
    required this.topSpeedDisplay,
    required this.result,
    required this.createdAt,
    this.session,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String shareCode;
  final String brand;
  final String model;
  final String driveType;
  final String surface;
  final String tuneType;
  final String piClass;
  final String topSpeedDisplay;
  final TuneCalcResult result;
  final DateTime createdAt;
  final CreateTuneSession? session;
  final bool isPinned;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'shareCode': shareCode,
        'brand': brand,
        'model': model,
        'driveType': driveType,
        'surface': surface,
        'tuneType': tuneType,
        'piClass': piClass,
        'topSpeedDisplay': topSpeedDisplay,
        'result': result.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'session': session?.toJson(),
        'isPinned': isPinned,
      };

  factory SavedTuneRecord.fromJson(Map<String, dynamic> json) =>
      SavedTuneRecord(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        shareCode: json['shareCode'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        driveType: json['driveType'] as String? ?? 'RWD',
        surface: json['surface'] as String? ?? 'Street',
        tuneType: json['tuneType'] as String? ?? 'Race',
        piClass: json['piClass'] as String? ?? '--',
        topSpeedDisplay: json['topSpeedDisplay'] as String? ?? '--',
        result: TuneCalcResult.fromJson(
          Map<String, dynamic>.from(
            json['result'] as Map? ?? const <String, dynamic>{},
          ),
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        session: json['session'] is Map
            ? CreateTuneSession.fromJson(
                Map<String, dynamic>.from(json['session'] as Map),
              )
            : null,
        isPinned: json['isPinned'] as bool? ?? false,
      );

  SavedTuneRecord copyWith({
    String? id,
    String? title,
    String? shareCode,
    String? brand,
    String? model,
    String? driveType,
    String? surface,
    String? tuneType,
    String? piClass,
    String? topSpeedDisplay,
    TuneCalcResult? result,
    DateTime? createdAt,
    CreateTuneSession? session,
    bool? isPinned,
  }) {
    return SavedTuneRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      shareCode: shareCode ?? this.shareCode,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      driveType: driveType ?? this.driveType,
      surface: surface ?? this.surface,
      tuneType: tuneType ?? this.tuneType,
      piClass: piClass ?? this.piClass,
      topSpeedDisplay: topSpeedDisplay ?? this.topSpeedDisplay,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      session: session ?? this.session,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

class CreateTuneSession {
  const CreateTuneSession({
    required this.metric,
    required this.brand,
    required this.model,
    required this.driveType,
    required this.gameVersion,
    required this.surface,
    required this.tuneType,
    required this.gearCount,
    required this.weightKg,
    required this.frontDistributionPercent,
    required this.currentPi,
    required this.maxTorqueNm,
    required this.topSpeed,
    required this.frontTireSize,
    required this.rearTireSize,
    required this.powerBand,
    this.tuneTitle = '',
    this.shareCode = '',
  });

  final bool metric;
  final String brand;
  final String model;
  final String driveType;
  final String gameVersion;
  final String surface;
  final String tuneType;
  final int gearCount;
  final String weightKg;
  final String frontDistributionPercent;
  final String currentPi;
  final String maxTorqueNm;
  final String topSpeed;
  final String frontTireSize;
  final String rearTireSize;
  final TuneCalcPowerBand powerBand;
  final String tuneTitle;
  final String shareCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'metric': metric,
        'brand': brand,
        'model': model,
        'driveType': driveType,
        'gameVersion': gameVersion,
        'surface': surface,
        'tuneType': tuneType,
        'gearCount': gearCount,
        'weightKg': weightKg,
        'frontDistributionPercent': frontDistributionPercent,
        'currentPi': currentPi,
        'maxTorqueNm': maxTorqueNm,
        'topSpeed': topSpeed,
        'frontTireSize': frontTireSize,
        'rearTireSize': rearTireSize,
        'tireSize': _legacyTireSizePayload(frontTireSize, rearTireSize),
        'powerBand': powerBand.toJson(),
        'tuneTitle': tuneTitle,
        'shareCode': shareCode,
      };

  factory CreateTuneSession.fromJson(Map<String, dynamic> json) {
    final legacyTireSize = json['tireSize'] as String? ?? '';
    final parsedLegacyTireSizes = _parseLegacyTireSizePayload(legacyTireSize);
    return CreateTuneSession(
      metric: json['metric'] as bool? ?? true,
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      driveType: json['driveType'] as String? ?? 'RWD',
      gameVersion: json['gameVersion'] as String? ?? 'FH5',
      surface: json['surface'] as String? ?? 'Street',
      tuneType: json['tuneType'] as String? ?? 'Race',
      gearCount: json['gearCount'] as int? ?? 6,
      weightKg: json['weightKg'] as String? ?? '',
      frontDistributionPercent:
          json['frontDistributionPercent'] as String? ?? '',
      currentPi: json['currentPi'] as String? ?? '',
      maxTorqueNm: json['maxTorqueNm'] as String? ?? '',
      topSpeed: json['topSpeed'] as String? ?? '',
      frontTireSize: json['frontTireSize'] as String? ?? parsedLegacyTireSizes.front,
      rearTireSize: json['rearTireSize'] as String? ?? parsedLegacyTireSizes.rear,
      powerBand: TuneCalcPowerBand.fromJson(
        Map<String, dynamic>.from(
          json['powerBand'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      tuneTitle: json['tuneTitle'] as String? ?? '',
      shareCode: json['shareCode'] as String? ?? '',
    );
  }
}

String _legacyTireSizePayload(String front, String rear) {
  if (front.isEmpty && rear.isEmpty) return '';
  if (front == rear || rear.isEmpty) return front;
  if (front.isEmpty) return rear;
  return '$front | $rear';
}

_LegacyTireSizePair _parseLegacyTireSizePayload(String value) {
  if (value.contains('|')) {
    final parts = value.split('|');
    final front = parts.isNotEmpty ? parts.first.trim() : '';
    final rear = parts.length > 1 ? parts[1].trim() : front;
    return _LegacyTireSizePair(front: front, rear: rear);
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return const _LegacyTireSizePair(front: '', rear: '');
  }
  return _LegacyTireSizePair(front: normalized, rear: normalized);
}

class _LegacyTireSizePair {
  const _LegacyTireSizePair({
    required this.front,
    required this.rear,
  });

  final String front;
  final String rear;
}
