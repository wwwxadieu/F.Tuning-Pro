import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ftune_models.dart';

class FTuneStorage {
  FTuneStorage();

  static const String _prefsKey = 'ftune.preferences.v1';
  static const String _welcomeSeenKey = 'ftune.welcomeSeen.v1';
  static const String _customBackgroundKey = 'ftune.customBackground.v1';
  static const String _overlayTuneKey = 'ftune.overlayTuneId.v1';
  static const String _garageFileName = 'garage_tunes.json';
  static const Set<String> _backgroundExtensions = <String>{
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.mp4',
    '.webm',
    '.mov',
    '.avi',
  };

  Future<Directory> _appDir() async {
    Directory root;
    try {
      root = await getApplicationSupportDirectory();
    } catch (_) {
      root = Directory.systemTemp;
    }
    final dir = Directory('${root.path}${Platform.pathSeparator}ftune_flutter');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<File> _garageFile() async {
    final dir = await _appDir();
    return File('${dir.path}${Platform.pathSeparator}$_garageFileName');
  }

  Future<AppPreferences> loadPreferences() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return const AppPreferences.defaults();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const AppPreferences.defaults();
    }
    try {
      return AppPreferences.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const AppPreferences.defaults();
    }
  }

  Future<void> savePreferences(AppPreferences preferences) async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return;
    await prefs.setString(_prefsKey, jsonEncode(preferences.toJson()));
  }

  Future<List<SavedTuneRecord>> loadGarage() async {
    final file = await _garageFile();
    if (!await file.exists()) {
      return const <SavedTuneRecord>[];
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => SavedTuneRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return const <SavedTuneRecord>[];
    }
  }

  Future<void> saveGarage(List<SavedTuneRecord> records) async {
    final file = await _garageFile();
    await file.writeAsString(
      jsonEncode(records.map((item) => item.toJson()).toList()),
      flush: true,
    );
  }

  Future<int> importTuneFile() async {
    const typeGroup = XTypeGroup(
      label: 'Tune files',
      extensions: <String>['tune', 'json'],
    );
    final result =
        await openFile(acceptedTypeGroups: const <XTypeGroup>[typeGroup]);
    if (result == null) return 0;
    final raw = await result.readAsString();
    final imported = _decodeTunePayload(raw);
    if (imported.isEmpty) return 0;
    final current = await loadGarage();
    final merged = <SavedTuneRecord>[...imported, ...current];
    await saveGarage(_dedupeRecords(merged));
    return imported.length;
  }

  Future<String?> exportTuneFile(List<SavedTuneRecord> records) async {
    if (records.isEmpty) return null;
    const typeGroup = XTypeGroup(
      label: 'Tune files',
      extensions: <String>['tune'],
    );
    final suggestedName = records.length == 1
        ? '${_safeFileName(records.first.title)}.tune'
        : 'garage-export-${DateTime.now().millisecondsSinceEpoch}.tune';
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (location == null) return null;
    final payload = jsonEncode(records.map((item) => item.toJson()).toList());
    final file = File(location.path);
    await file.writeAsString(payload, flush: true);
    return location.path;
  }

  List<SavedTuneRecord> _decodeTunePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map(
              (item) => SavedTuneRecord.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      if (decoded is Map) {
        return <SavedTuneRecord>[
          SavedTuneRecord.fromJson(Map<String, dynamic>.from(decoded)),
        ];
      }
    } catch (_) {
      return const <SavedTuneRecord>[];
    }
    return const <SavedTuneRecord>[];
  }

  List<SavedTuneRecord> _dedupeRecords(List<SavedTuneRecord> records) {
    final seen = <String>{};
    final unique = <SavedTuneRecord>[];
    for (final record in records) {
      final key = [
        record.id,
        record.title,
        record.brand,
        record.model,
        record.createdAt.toIso8601String(),
      ].join('|');
      if (seen.add(key)) {
        unique.add(record);
      }
    }
    return unique;
  }

  Future<bool> loadWelcomeSeen() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return false;
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  Future<void> saveWelcomeSeen(bool seen) async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return;
    await prefs.setBool(_welcomeSeenKey, seen);
  }

  Future<String?> loadCustomBackgroundPath() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return null;
    final raw = prefs.getString(_customBackgroundKey);
    if (raw == null || raw.trim().isEmpty) return null;
    final file = File(raw);
    if (!await file.exists()) return null;
    return file.path;
  }

  Future<String?> pickAndStoreCustomBackground() async {
    const typeGroup = XTypeGroup(
      label: 'Images & Videos',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'mp4', 'webm', 'mov', 'avi'],
    );
    final file =
        await openFile(acceptedTypeGroups: const <XTypeGroup>[typeGroup]);
    if (file == null) return null;
    return storeCustomBackgroundFromPath(file.path);
  }

  Future<String?> storeCustomBackgroundFromPath(String rawPath) async {
    final normalizedPath = rawPath.trim();
    if (normalizedPath.isEmpty) return null;

    final extension = _extensionOf(normalizedPath).toLowerCase();
    if (!_backgroundExtensions.contains(extension)) {
      return null;
    }

    final source = File(normalizedPath);
    if (!await source.exists()) return null;

    final appDir = await _appDir();
    final target = File(
      '${appDir.path}${Platform.pathSeparator}custom-background$extension',
    );
    await source.copy(target.path);
    final prefs = await _prefsOrNull();
    if (prefs == null) return target.path;
    await prefs.setString(_customBackgroundKey, target.path);
    return target.path;
  }

  Future<void> clearCustomBackground() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return;
    final path = prefs.getString(_customBackgroundKey);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_customBackgroundKey);
  }

  Future<String?> loadOverlayTuneId() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return null;
    final raw = prefs.getString(_overlayTuneKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  Future<void> saveOverlayTuneId(String? id) async {
    final prefs = await _prefsOrNull();
    if (prefs == null) return;
    if (id == null || id.isEmpty) {
      await prefs.remove(_overlayTuneKey);
      return;
    }
    await prefs.setString(_overlayTuneKey, id);
  }

  String _safeFileName(String input) {
    return input
        .replaceAll(RegExp(r'[<>:\"/\\\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(' ', '_');
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot == path.length - 1) {
      return '.dat';
    }
    return path.substring(dot);
  }
}
