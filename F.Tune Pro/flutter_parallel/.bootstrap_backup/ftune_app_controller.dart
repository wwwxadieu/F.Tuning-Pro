import 'package:flutter/foundation.dart';

import 'ftune_models.dart';

class FTuneAppController extends ChangeNotifier {
  AppSection _section = AppSection.dashboard;
  AppPreferences _preferences = const AppPreferences.defaults();
  final List<SavedTuneRecord> _garageTunes = <SavedTuneRecord>[];

  AppSection get section => _section;
  AppPreferences get preferences => _preferences;
  List<SavedTuneRecord> get garageTunes => List<SavedTuneRecord>.unmodifiable(_garageTunes);

  void goTo(AppSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }

  void updatePreferences(AppPreferences next) {
    _preferences = next;
    notifyListeners();
  }

  void setMeasurementSystem(bool useMetric) {
    _preferences = _preferences.copyWith(useMetric: useMetric);
    notifyListeners();
  }

  SavedTuneRecord saveTune(SavedTuneDraft draft) {
    final timestamp = DateTime.now();
    final normalizedTitle = draft.title.trim().isEmpty
        ? '${draft.brand} ${draft.model}'
        : draft.title.trim();
    final record = SavedTuneRecord(
      id: '${timestamp.microsecondsSinceEpoch}-${draft.brand.hashCode.abs()}',
      title: normalizedTitle,
      shareCode: draft.shareCode.trim(),
      brand: draft.brand,
      model: draft.model,
      result: draft.result,
      createdAt: timestamp,
    );
    _garageTunes.insert(0, record);
    notifyListeners();
    return record;
  }

  void deleteTune(String id) {
    _garageTunes.removeWhere((record) => record.id == id);
    notifyListeners();
  }

  void togglePinned(String id) {
    final index = _garageTunes.indexWhere((record) => record.id == id);
    if (index < 0) return;
    _garageTunes[index] = _garageTunes[index].copyWith(
      isPinned: !_garageTunes[index].isPinned,
    );
    _garageTunes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    notifyListeners();
  }
}
