import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class FlogCodec {
  FlogCodec._();

  static const List<String> supportedExtensions = <String>['flog', 'ftlog'];
  static const String _fileMagic = 'FTLOG';
  static final AesGcm _algorithm = AesGcm.with256bits();
  static final SecretKey _secretKey = SecretKey(
    utf8.encode('FTuneProLogCodecKeyMaterial-2026'),
  );

  static Future<Map<String, dynamic>> decryptBytes(Uint8List bytes) async {
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
}
