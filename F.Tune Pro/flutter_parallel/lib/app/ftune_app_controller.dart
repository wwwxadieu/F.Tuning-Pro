import 'package:flutter/foundation.dart';

import '../features/create/domain/tune_models.dart';
import 'ftune_models.dart';
import 'ftune_storage.dart';

class FTuneAppController extends ChangeNotifier {
  FTuneAppController({FTuneStorage? storage})
      : _storage = storage ?? FTuneStorage();

  final FTuneStorage _storage;

  AppSection _section = AppSection.dashboard;
  AppPreferences _preferences = const AppPreferences.defaults();
  final List<SavedTuneRecord> _garageTunes = <SavedTuneRecord>[];
  bool _isReady = false;
  bool _showWelcome = false;
  String? _customBackgroundPath;
  SavedTuneRecord? _activeOverlayTune;
  CreateTuneSession? _pendingCreateSession;

  AppSection get section => _section;
  AppPreferences get preferences => _preferences;
  List<SavedTuneRecord> get garageTunes =>
      List<SavedTuneRecord>.unmodifiable(_garageTunes);
  bool get isReady => _isReady;
  bool get showWelcome => _showWelcome;
  String? get customBackgroundPath => _customBackgroundPath;
  SavedTuneRecord? get activeOverlayTune => _activeOverlayTune;
  CreateTuneSession? get pendingCreateSession => _pendingCreateSession;

  Future<void> initialize() async {
    _preferences = await _storage.loadPreferences();
    _garageTunes
      ..clear()
      ..addAll(await _storage.loadGarage());
    _sortGarage();
    _customBackgroundPath = await _storage.loadCustomBackgroundPath();
    final welcomeSeen = await _storage.loadWelcomeSeen();
    _showWelcome = !welcomeSeen;
    final overlayTuneId = await _storage.loadOverlayTuneId();
    if (overlayTuneId != null) {
      _activeOverlayTune = _garageTunes.cast<SavedTuneRecord?>().firstWhere(
            (record) => record?.id == overlayTuneId,
            orElse: () => null,
          );
    }
    _isReady = true;
    notifyListeners();
  }

  void goTo(AppSection section) {
    if (_section == section) return;
    _section = section;
    notifyListeners();
  }

  void startNewTune() {
    _pendingCreateSession = null;
    if (_section == AppSection.create) {
      notifyListeners();
      return;
    }
    _section = AppSection.create;
    notifyListeners();
  }

  void editTune(SavedTuneRecord record) {
    _pendingCreateSession = record.session ?? _buildFallbackSession(record);
    _section = AppSection.create;
    notifyListeners();
  }

  Future<void> updatePreferences(AppPreferences next) async {
    _preferences = next;
    notifyListeners();
    await _storage.savePreferences(next);
  }

  Future<void> setMeasurementSystem(bool useMetric) async {
    _preferences = _preferences.copyWith(useMetric: useMetric);
    notifyListeners();
    await _storage.savePreferences(_preferences);
  }

  Future<void> setLanguageCode(String languageCode) async {
    _preferences = _preferences.copyWith(languageCode: languageCode);
    notifyListeners();
    await _storage.savePreferences(_preferences);
  }

  Future<void> setThemeMode(String themeMode) async {
    _preferences = _preferences.copyWith(themeMode: themeMode);
    notifyListeners();
    await _storage.savePreferences(_preferences);
  }

  Future<void> setOverlayOnTop(bool overlayOnTop) async {
    _preferences = _preferences.copyWith(overlayOnTop: overlayOnTop);
    notifyListeners();
    await _storage.savePreferences(_preferences);
  }

  Future<void> setOverlayLocked(bool overlayLocked) async {
    _preferences = _preferences.copyWith(overlayLocked: overlayLocked);
    notifyListeners();
    await _storage.savePreferences(_preferences);
  }

  Future<void> setAccentColor(int colorValue) async {
    _preferences = _preferences.copyWith(accentColorValue: colorValue);
    notifyListeners();
    await _storage.savePreferences(_preferences);
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
      driveType: draft.driveType,
      surface: draft.surface,
      tuneType: draft.tuneType,
      piClass: draft.piClass,
      topSpeedDisplay: draft.topSpeedDisplay,
      result: draft.result,
      createdAt: timestamp,
      session: draft.session,
    );
    _garageTunes.insert(0, record);
    _sortGarage();
    notifyListeners();
    _storage.saveGarage(_garageTunes);
    return record;
  }

  Future<void> deleteTune(String id) async {
    _garageTunes.removeWhere((record) => record.id == id);
    if (_activeOverlayTune?.id == id) {
      _activeOverlayTune = null;
      await _storage.saveOverlayTuneId(null);
    }
    notifyListeners();
    await _storage.saveGarage(_garageTunes);
  }

  Future<void> togglePinned(String id) async {
    final index = _garageTunes.indexWhere((record) => record.id == id);
    if (index < 0) return;
    _garageTunes[index] = _garageTunes[index].copyWith(
      isPinned: !_garageTunes[index].isPinned,
    );
    _sortGarage();
    notifyListeners();
    await _storage.saveGarage(_garageTunes);
  }

  Future<int> importGarageTunes() async {
    final importedCount = await _storage.importTuneFile();
    if (importedCount <= 0) return 0;
    _garageTunes
      ..clear()
      ..addAll(await _storage.loadGarage());
    _sortGarage();
    notifyListeners();
    return importedCount;
  }

  Future<String?> exportGarageTunes(List<SavedTuneRecord> records) {
    return _storage.exportTuneFile(records);
  }

  Future<void> pickCustomBackground() async {
    _customBackgroundPath = await _storage.pickAndStoreCustomBackground();
    notifyListeners();
  }

  Future<bool> setCustomBackgroundFromPath(String path) async {
    final storedPath = await _storage.storeCustomBackgroundFromPath(path);
    if (storedPath == null) {
      return false;
    }
    _customBackgroundPath = storedPath;
    notifyListeners();
    return true;
  }

  Future<void> clearCustomBackground() async {
    await _storage.clearCustomBackground();
    _customBackgroundPath = null;
    notifyListeners();
  }

  Future<void> completeWelcome({bool dontShowAgain = true}) async {
    _showWelcome = false;
    notifyListeners();
    if (dontShowAgain) {
      await _storage.saveWelcomeSeen(true);
    }
  }

  void reopenWelcome() {
    _showWelcome = true;
    notifyListeners();
  }

  Future<void> setActiveOverlayTune(SavedTuneRecord? record) async {
    _activeOverlayTune = record;
    notifyListeners();
    await _storage.saveOverlayTuneId(record?.id);
  }

  Future<void> clearOverlayTune() => setActiveOverlayTune(null);

  CreateTuneSession _buildFallbackSession(SavedTuneRecord record) {
    final piDigits =
        RegExp(r'(\d+)').firstMatch(record.piClass)?.group(1) ?? '';
    final topSpeedDigits =
        RegExp(r'([\d.]+)').firstMatch(record.topSpeedDisplay)?.group(1) ?? '';
    final redlineRpm = record.result.gearing.redlineRpm.round();
    final torquePeakRpm = (redlineRpm * 0.68).round();
    return CreateTuneSession(
      metric: _preferences.useMetric,
      brand: record.brand,
      model: record.model,
      driveType: record.driveType,
      gameVersion: 'FH5',
      surface: record.surface,
      tuneType: record.tuneType,
      gearCount: record.result.gearing.ratios.length,
      weightKg: '',
      frontDistributionPercent: '',
      currentPi: piDigits,
      maxTorqueNm: '',
      topSpeed: topSpeedDigits,
      frontTireSize: '',
      rearTireSize: '',
      powerBand: TuneCalcPowerBand(
        scaleMax:
            redlineRpm <= 10000 ? 10000 : ((redlineRpm / 1000).ceil() * 1000),
        redlineRpm: redlineRpm,
        maxTorqueRpm: torquePeakRpm,
      ),
      tuneTitle: record.title,
      shareCode: record.shareCode,
    );
  }

  void _sortGarage() {
    _garageTunes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }
}
