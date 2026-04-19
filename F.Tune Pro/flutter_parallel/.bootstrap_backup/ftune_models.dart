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
    required this.autoSaveGarage,
    required this.overlayPreviewEnabled,
  });

  const AppPreferences.defaults()
      : useMetric = true,
        languageCode = 'en',
        autoSaveGarage = true,
        overlayPreviewEnabled = true;

  final bool useMetric;
  final String languageCode;
  final bool autoSaveGarage;
  final bool overlayPreviewEnabled;

  AppPreferences copyWith({
    bool? useMetric,
    String? languageCode,
    bool? autoSaveGarage,
    bool? overlayPreviewEnabled,
  }) {
    return AppPreferences(
      useMetric: useMetric ?? this.useMetric,
      languageCode: languageCode ?? this.languageCode,
      autoSaveGarage: autoSaveGarage ?? this.autoSaveGarage,
      overlayPreviewEnabled: overlayPreviewEnabled ?? this.overlayPreviewEnabled,
    );
  }
}

class SavedTuneDraft {
  const SavedTuneDraft({
    required this.title,
    required this.shareCode,
    required this.brand,
    required this.model,
    required this.result,
  });

  final String title;
  final String shareCode;
  final String brand;
  final String model;
  final TuneCalcResult result;
}

class SavedTuneRecord {
  const SavedTuneRecord({
    required this.id,
    required this.title,
    required this.shareCode,
    required this.brand,
    required this.model,
    required this.result,
    required this.createdAt,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final String shareCode;
  final String brand;
  final String model;
  final TuneCalcResult result;
  final DateTime createdAt;
  final bool isPinned;

  SavedTuneRecord copyWith({
    String? id,
    String? title,
    String? shareCode,
    String? brand,
    String? model,
    TuneCalcResult? result,
    DateTime? createdAt,
    bool? isPinned,
  }) {
    return SavedTuneRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      shareCode: shareCode ?? this.shareCode,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
