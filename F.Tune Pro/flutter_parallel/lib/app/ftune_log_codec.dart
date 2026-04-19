import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FTuneEncryptedLog {
  const FTuneEncryptedLog({
    required this.fileName,
    required this.bytes,
    required this.previewBody,
  });

  final String fileName;
  final Uint8List bytes;
  final String previewBody;
}

class FTuneLogCodec {
  FTuneLogCodec._();

  static const String fileExtension = 'ftlog';
  static const String _fileMagic = 'FTLOG';
  static const int _formatVersion = 1;
  static final AesGcm _algorithm = AesGcm.with256bits();
  static final SecretKey _secretKey = SecretKey(
    utf8.encode('FTuneProLogCodecKeyMaterial-2026'),
  );

  static Future<FTuneEncryptedLog> createCrashLog({
    required String source,
    required String error,
    required String stackTrace,
    required DateTime timestamp,
    String? library,
    String? context,
    bool? silent,
  }) async {
    final payload = <String, dynamic>{
      'format': 'ftune-crash-log',
      'formatVersion': _formatVersion,
      'generatedAt': timestamp.toIso8601String(),
      'app': await _buildAppMetadata(),
      'device': await _buildDeviceMetadata(),
      'crash': <String, dynamic>{
        'source': source,
        'error': error,
        'stackTrace': stackTrace,
        if (library != null && library.isNotEmpty) 'library': library,
        if (context != null && context.isNotEmpty) 'context': context,
        if (silent != null) 'silent': silent,
      },
    };

    final plaintext = const JsonEncoder.withIndent('  ').convert(payload);
    final nonce = _randomBytes(12);
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _secretKey,
      nonce: nonce,
    );

    final envelope = <String, dynamic>{
      'magic': _fileMagic,
      'version': _formatVersion,
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    final safeSource = source.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final safeTimestamp = timestamp
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    return FTuneEncryptedLog(
      fileName: 'crash_${safeSource}_$safeTimestamp.$fileExtension',
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(envelope))),
      previewBody: plaintext,
    );
  }

  static Future<Map<String, dynamic>> decryptLogBytes(Uint8List bytes) async {
    final rawEnvelope = utf8.decode(bytes);
    final envelope = Map<String, dynamic>.from(jsonDecode(rawEnvelope) as Map);

    if (envelope['magic'] != _fileMagic) {
      throw const FormatException('Unsupported log file format.');
    }

    final nonce = base64Decode(envelope['nonce'] as String? ?? '');
    final cipherText = base64Decode(envelope['cipherText'] as String? ?? '');
    final macBytes = base64Decode(envelope['mac'] as String? ?? '');

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: _secretKey,
    );
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(clearBytes)) as Map,
    );
  }

  static String prettyPrint(Map<String, dynamic> decoded) {
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  static Future<Map<String, dynamic>> _buildAppMetadata() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return <String, dynamic>{
        'name': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (_) {
      return const <String, dynamic>{
        'name': 'F.Tune Pro',
        'packageName': 'ftune_flutter',
        'version': '0.1.0',
        'buildNumber': '1',
      };
    }
  }

  static Future<Map<String, dynamic>> _buildDeviceMetadata() async {
    final localIps = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          localIps.add(address.address);
        }
      }
    } catch (_) {}

    return <String, dynamic>{
      'platform': _platformName(),
      'platformVersion': _platformVersion(),
      'hostname': _hostname(),
      'userName': _userName(),
      'localIpAddresses': localIps,
    };
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  static String _platformVersion() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return 'unknown';
    }
  }

  static String? _hostname() {
    if (kIsWeb) return null;
    final env = Platform.environment;
    return env['COMPUTERNAME'] ?? env['HOSTNAME'];
  }

  static String? _userName() {
    if (kIsWeb) return null;
    final env = Platform.environment;
    return env['USERNAME'] ?? env['USER'] ?? env['LOGNAME'];
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}