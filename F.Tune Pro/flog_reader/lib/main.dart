import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'flog_codec.dart';

String? _initialFilePath;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  _initialFilePath = _extractInitialFilePath(args);

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  runApp(const FlogReaderApp());
}

String? _extractInitialFilePath(List<String> args) {
  for (final rawArg in args) {
    final candidate = rawArg.replaceAll('"', '').trim();
    if (candidate.isEmpty) {
      continue;
    }

    final normalized = candidate.toLowerCase();
    final isSupported = FlogCodec.supportedExtensions.any(
      (extension) => normalized.endsWith('.$extension'),
    );

    if (!isSupported) {
      continue;
    }

    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  return null;
}

const String kReaderAppName = 'F.Tune Log Reader';

class FlogReaderApp extends StatelessWidget {
  const FlogReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0A7C5A),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: kReaderAppName,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
      ),
      home: const _ReaderHomePage(),
    );
  }
}

class _ReaderHomePage extends StatefulWidget {
  const _ReaderHomePage();

  @override
  State<_ReaderHomePage> createState() => _ReaderHomePageState();
}

class _ReaderHomePageState extends State<_ReaderHomePage> {
  String? _selectedFileName;
  String? _decodedText;
  Map<String, dynamic>? _decodedJson;
  String? _statusMessage;
  bool _busy = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    // Auto-load file if opened via file association
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialFilePath != null && _initialFilePath!.isNotEmpty) {
        _loadFileFromPath(_initialFilePath!);
      }
    });
  }

  Future<void> _loadFileFromPath(String filePath) async {
    try {
      final file = XFile(filePath);
      await _loadEncryptedLogFile(file);
    } catch (error) {
      setState(() {
        _statusMessage = 'Could not open file: $error';
      });
    }
  }

  Future<void> _openEncryptedLog() async {
    const typeGroup = XTypeGroup(
      label: 'Encrypted F.Tune logs',
      extensions: FlogCodec.supportedExtensions,
    );

    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (file == null) return;

    await _loadEncryptedLogFile(file);
  }

  Future<void> _loadEncryptedLogFile(XFile file) async {
    if (!_isSupportedLogFile(file)) {
      setState(() {
        _statusMessage = 'Unsupported file type: ${file.name}';
      });
      return;
    }

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final decoded = await FlogCodec.decryptBytes(bytes);
      setState(() {
        _selectedFileName = file.name;
        _decodedJson = decoded;
        _decodedText = FlogCodec.prettyPrint(decoded);
        _statusMessage = 'Loaded and decrypted ${file.name}';
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Could not decrypt file: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    final XFile? supportedFile = files.cast<XFile?>().firstWhere(
          (candidate) => candidate != null && _isSupportedLogFile(candidate),
          orElse: () => null,
        );

    if (supportedFile == null) {
      setState(() {
        _statusMessage = 'Drop a .flog or .ftlog file to open it.';
      });
      return;
    }

    await _loadEncryptedLogFile(supportedFile);
  }

  bool _isSupportedLogFile(XFile file) {
    final normalizedName = file.name.toLowerCase();
    return FlogCodec.supportedExtensions.any(
      (extension) => normalizedName.endsWith('.$extension'),
    );
  }

  Future<void> _exportAsTxt() async {
    final decodedText = _decodedText;
    if (decodedText == null || decodedText.isEmpty) return;

    final suggestedBaseName = (_selectedFileName ?? 'decoded_log')
        .replaceAll(RegExp(r'\.(flog|ftlog)$', caseSensitive: false), '');

    final saveLocation = await getSaveLocation(
      suggestedName: '$suggestedBaseName.txt',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'Text files', extensions: <String>['txt']),
      ],
    );
    if (saveLocation == null) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final xFile = XFile.fromData(
        utf8.encode(decodedText),
        mimeType: 'text/plain',
        name: '$suggestedBaseName.txt',
      );
      await xFile.saveTo(saveLocation.path);
      setState(() {
        _statusMessage = 'Exported TXT to ${saveLocation.path}';
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Could not export TXT: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportAsJson() async {
    final decodedJson = _decodedJson;
    if (decodedJson == null) return;

    final suggestedBaseName = (_selectedFileName ?? 'decoded_log')
        .replaceAll(RegExp(r'\.(flog|ftlog)$', caseSensitive: false), '');

    final saveLocation = await getSaveLocation(
      suggestedName: '$suggestedBaseName.json',
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'JSON files', extensions: <String>['json']),
      ],
    );
    if (saveLocation == null) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });

    try {
      final jsonText = const JsonEncoder.withIndent('  ').convert(decodedJson);
      final xFile = XFile.fromData(
        utf8.encode(jsonText),
        mimeType: 'application/json',
        name: '$suggestedBaseName.json',
      );
      await xFile.saveTo(saveLocation.path);
      setState(() {
        _statusMessage = 'Exported JSON to ${saveLocation.path}';
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Could not export JSON: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final crash = (_decodedJson?['crash'] as Map<String, dynamic>?);
    final app = (_decodedJson?['app'] as Map<String, dynamic>?);
    final device = (_decodedJson?['device'] as Map<String, dynamic>?);

    return Scaffold(
      appBar: AppBar(
        title: const Text(kReaderAppName),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _busy ? null : _openEncryptedLog,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Open Log'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _busy || _decodedJson == null ? null : _exportAsJson,
            icon: const Icon(Icons.data_object_rounded),
            label: const Text('Export JSON'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _busy || _decodedText == null ? null : _exportAsTxt,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Export TXT'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) {
          setState(() => _dragging = true);
        },
        onDragExited: (_) {
          setState(() => _dragging = false);
        },
        onDragDone: (detail) {
          setState(() => _dragging = false);
          _handleDroppedFiles(detail.files);
        },
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Standalone reader for encrypted F.Tune log files.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Supports both .flog and .ftlog, decrypts the payload locally, and can export the result to .json or .txt. You can also drag a file straight into this window.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _statusMessage ?? 'No file loaded yet.',
                          style: TextStyle(color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedFileName != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        _InfoCard(label: 'File', value: _selectedFileName!),
                        _InfoCard(
                          label: 'Source',
                          value: (crash?['source'] ?? '-').toString(),
                        ),
                        _InfoCard(
                          label: 'App Version',
                          value: '${app?['version'] ?? '-'} (${app?['buildNumber'] ?? '-'})',
                        ),
                        _InfoCard(
                          label: 'OS',
                          value: (device?['platform'] ?? '-').toString(),
                        ),
                        _InfoCard(
                          label: 'Windows User',
                          value: (device?['userName'] ?? '-').toString(),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: _busy
                          ? const Center(child: CircularProgressIndicator())
                          : _decodedText == null
                              ? Center(
                                  child: Text(
                                    'Open or drop an encrypted log to inspect its contents.',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: SelectableText(
                                    _decodedText!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.45,
                                      fontFamily: 'Consolas',
                                    ),
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),
            if (_dragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: scheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.file_download_outlined,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Drop .flog or .ftlog here',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
