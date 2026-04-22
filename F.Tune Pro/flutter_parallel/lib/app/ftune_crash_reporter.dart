import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ftune_log_codec.dart';

typedef CrashReportSender = Future<bool> Function(
  Uri endpoint,
  Map<String, String> fields,
  File attachment,
);

class FTuneCrashReporter {
  FTuneCrashReporter._();

  static final FTuneCrashReporter instance = FTuneCrashReporter._();
  static const Map<String, String> _formSubmitMultipartHeaders =
      <String, String>{
    'Accept': 'application/json',
    'Origin': 'https://ftune.app',
    'Referer': 'https://ftune.app/desktop',
  };

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _dialogVisible = false;
  _CrashLogEntry? _pending;
  String? _lastResponseMessage;
  Uri _crashReportEndpoint =
      Uri.parse('https://formsubmit.co/contact.vndrift@gmail.com');
  CrashReportSender? _sendOverride;

  @visibleForTesting
  void setCrashReportEndpointForTesting(Uri endpoint) {
    _crashReportEndpoint = endpoint;
  }

  @visibleForTesting
  void resetForTesting() {
    _dialogVisible = false;
    _pending = null;
    _lastResponseMessage = null;
    _crashReportEndpoint =
        Uri.parse('https://formsubmit.co/contact.vndrift@gmail.com');
    _sendOverride = null;
  }

  @visibleForTesting
  void setSendOverrideForTesting(
    CrashReportSender? sender,
  ) {
    _sendOverride = sender;
  }

  @visibleForTesting
  Future<bool> sendZoneErrorForTesting(Object error, StackTrace stackTrace) {
    return _sendCrashReport(
      _CrashLogEntry(
        source: 'runZonedGuarded',
        error: error.toString(),
        stackTrace: stackTrace.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  void captureFlutterError(FlutterErrorDetails details) {
    final stack = details.stack ?? StackTrace.current;
    debugPrint('[CrashReporter] FlutterError: ${details.exceptionAsString()}');
    debugPrint('[CrashReporter] Stack: ${stack.toString()}');
    _enqueue(
      _CrashLogEntry(
        source: details.library ?? 'FlutterError',
        error: details.exceptionAsString(),
        stackTrace: stack.toString(),
        timestamp: DateTime.now(),
        library: details.library,
        context: details.context?.toDescription(),
        silent: details.silent,
      ),
    );
  }

  void capturePlatformError(Object error, StackTrace stackTrace) {
    debugPrint('[CrashReporter] PlatformError: $error');
    debugPrint('[CrashReporter] Stack: ${stackTrace.toString()}');
    _enqueue(
      _CrashLogEntry(
        source: 'PlatformDispatcher',
        error: error.toString(),
        stackTrace: stackTrace.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  void captureZoneError(Object error, StackTrace stackTrace) {
    debugPrint('[CrashReporter] ZoneError: $error');
    debugPrint('[CrashReporter] Stack: ${stackTrace.toString()}');
    _enqueue(
      _CrashLogEntry(
        source: 'runZonedGuarded',
        error: error.toString(),
        stackTrace: stackTrace.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  void _enqueue(_CrashLogEntry entry) {
    _pending = entry;
    unawaited(_showPromptIfPossible());
  }

  Future<void> _showPromptIfPossible() async {
    if (_dialogVisible) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 350),
          _showPromptIfPossible,
        ),
      );
      return;
    }

    final current = _pending;
    if (current == null) return;
    _pending = null;
    _dialogVisible = true;

    final isVietnamese =
        (Localizations.maybeLocaleOf(ctx)?.languageCode ?? 'en') == 'vi';
    final shouldSend = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isVietnamese
                ? 'Ứng dụng vừa gặp lỗi'
                : 'The app encountered an error',
          ),
          content: Text(
            isVietnamese
                ? 'Bạn có muốn gửi log lỗi cho nhà phát triển không?'
                : 'Do you want to send the crash log to the developer?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(isVietnamese ? 'Không' : 'No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(isVietnamese ? 'Có' : 'Yes'),
            ),
          ],
        );
      },
    );

    if (shouldSend == true) {
      final sent = await _sendCrashReport(current);
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger != null) {
        final failureSuffix = (_lastResponseMessage != null && !sent)
            ? ' ($_lastResponseMessage)'
            : '';
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              sent
                  ? (isVietnamese
                      ? 'Đã gửi log lỗi thành công.'
                      : 'Crash log sent successfully.')
                  : (isVietnamese
                      ? 'Không thể gửi log lỗi. Vui lòng thử lại sau$failureSuffix'
                      : 'Could not send crash log. Please try again later.$failureSuffix'),
            ),
          ),
        );
      }
    }

    _dialogVisible = false;
    if (_pending != null) {
      unawaited(_showPromptIfPossible());
    }
  }

  Future<bool> _sendCrashReport(_CrashLogEntry entry) async {
    final encryptedLog = await FTuneLogCodec.createCrashLog(
      source: entry.source,
      error: entry.error,
      stackTrace: entry.stackTrace,
      timestamp: entry.timestamp,
      library: entry.library,
      context: entry.context,
      silent: entry.silent,
    );
    final payload = <String, String>{
      'name': 'F.Tune Pro Crash Reporter',
      'subject': '[F.Tune Pro Crash] ${entry.source}',
      'message': _buildEmailSummary(entry),
      '_subject': '[F.Tune Pro Crash] ${entry.source}',
      '_template': 'table',
      '_captcha': 'false',
    };
    final attachment = await _writeEncryptedLogFile(encryptedLog);
    _lastResponseMessage = null;

    try {
      if (_sendOverride != null) {
        return _sendOverride!(_crashReportEndpoint, payload, attachment);
      }

      final request = http.MultipartRequest('POST', _crashReportEndpoint)
        ..headers.addAll(_formSubmitMultipartHeaders)
        ..fields.addAll(payload)
        ..files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            attachment.path,
            filename: attachment.uri.pathSegments.last,
          ),
        );

      final streamed =
          await request.send().timeout(const Duration(seconds: 20));
      final body = await streamed.stream.bytesToString();
      return _isSuccessfulFormSubmitResponse(
        statusCode: streamed.statusCode,
        body: body,
      );
    } catch (_) {
      return false;
    } finally {
      try {
        if (await attachment.exists()) {
          await attachment.delete();
        }
      } catch (_) {}
    }
  }

  String _buildEmailSummary(_CrashLogEntry entry) {
    return <String>[
      'Encrypted crash log attached.',
      'Timestamp: ${entry.timestamp.toIso8601String()}',
      'Source: ${entry.source}',
      'Error: ${entry.error}',
    ].join('\n');
  }

  bool _isSuccessfulFormSubmitResponse({
    required int statusCode,
    required String body,
  }) {
    if (statusCode < 200 || statusCode >= 400) return false;

    final normalizedBody = body.toLowerCase();
    if (normalizedBody.contains('"success":"true"') ||
        normalizedBody.contains('"success":true')) {
      _lastResponseMessage = 'success';
      return true;
    }

    final htmlSuccess = normalizedBody.contains('thank') &&
        normalizedBody.contains('submitted') &&
        normalizedBody.contains('success');
    final compactBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    _lastResponseMessage = htmlSuccess
        ? 'html-success'
        : compactBody.substring(
            0,
            compactBody.length > 120 ? 120 : compactBody.length,
          );
    return htmlSuccess;
  }

  Future<File> _writeEncryptedLogFile(FTuneEncryptedLog log) async {
    final tempPath = Directory.systemTemp.path;
    final file = File(
      '$tempPath${Platform.pathSeparator}${log.fileName}',
    );
    await file.writeAsBytes(log.bytes, flush: true);
    return file;
  }
}

class _CrashLogEntry {
  const _CrashLogEntry({
    required this.source,
    required this.error,
    required this.stackTrace,
    required this.timestamp,
    this.library,
    this.context,
    this.silent,
  });

  final String source;
  final String error;
  final String stackTrace;
  final DateTime timestamp;
  final String? library;
  final String? context;
  final bool? silent;
}
