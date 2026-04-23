import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads and applies a Windows update after the app exits.
///
/// Flow:
///  1. Download the installer or portable ZIP to %TEMP%\ftune_update.
///  2. Write a PowerShell helper script that waits for THIS process to exit,
///     then runs the installer or replaces the portable app files.
///  3. Launch the PS script hidden in the background.
///  4. Exit this process — the script takes over.
class FTuneUpdater {
  FTuneUpdater._();
  static final FTuneUpdater instance = FTuneUpdater._();

  /// Downloads the best update package and reports progress via [onProgress].
  /// Returns `true` when the update has been launched and the app should exit.
  Future<bool> downloadAndApply({
    required String installerUrl,
    required String portableUrl,
    required void Function(double progress) onProgress,
  }) async {
    final currentExe = Platform.resolvedExecutable;
    final usePortablePackage =
        portableUrl.isNotEmpty && !_isLikelyInstalled(currentExe);
    final updateUrl = usePortablePackage ? portableUrl : installerUrl;
    if (updateUrl.isEmpty) return false;

    final tmpDir = await getTemporaryDirectory();
    final updateDir = Directory('${tmpDir.path}\\ftune_update');
    if (!updateDir.existsSync()) updateDir.createSync(recursive: true);

    final packagePath = usePortablePackage
        ? '${updateDir.path}\\F.Tune-Pro-Portable.zip'
        : '${updateDir.path}\\F.Tune-Pro-Setup.exe';

    // ── Download ──────────────────────────────────────────────────────────────
    try {
      final request = http.Request('GET', Uri.parse(updateUrl));
      final response = await request.send().timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) return false;

      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = File(packagePath).openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
      onProgress(1);
    } catch (_) {
      return false;
    }

    // ── Write PowerShell updater script ──────────────────────────────────────
    final scriptPath = '${updateDir.path}\\do_update.ps1';

    final script =
        usePortablePackage ? _portableUpdateScript : _installerScript;
    File(scriptPath).writeAsStringSync(script);

    // ── Launch the script then exit ───────────────────────────────────────────
    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptPath,
        '-Package',
        packagePath,
        '-Pid',
        '$pid',
        '-AppExe',
        currentExe,
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  bool _isLikelyInstalled(String exePath) {
    if (!Platform.isWindows) return false;
    final normalizedExe = exePath.toLowerCase();
    final roots = <String?>[
      Platform.environment['ProgramFiles'],
      Platform.environment['ProgramFiles(x86)'],
      Platform.environment['ProgramW6432'],
    ].whereType<String>();

    return roots.any((root) {
      final normalizedRoot = root.toLowerCase();
      return normalizedExe == normalizedRoot ||
          normalizedExe.startsWith('$normalizedRoot\\');
    });
  }

  static const String _installerScript = r'''
param(
  [Parameter(Mandatory=$true)][string]$Package,
  [Parameter(Mandatory=$true)][int]$Pid,
  [Parameter(Mandatory=$true)][string]$AppExe
)
try { Wait-Process -Id $Pid -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 800
$installerArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS')
$process = Start-Process -FilePath $Package -ArgumentList $installerArgs -Wait -PassThru
if ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath $AppExe)) {
  Start-Process -FilePath $AppExe
}
''';

  static const String _portableUpdateScript = r'''
param(
  [Parameter(Mandatory=$true)][string]$Package,
  [Parameter(Mandatory=$true)][int]$Pid,
  [Parameter(Mandatory=$true)][string]$AppExe
)
try { Wait-Process -Id $Pid -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 800

$updateRoot = Split-Path -Parent $Package
$extractDir = Join-Path $updateRoot 'portable_extract'
if (Test-Path -LiteralPath $extractDir) {
  Remove-Item -LiteralPath $extractDir -Recurse -Force
}
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
Expand-Archive -LiteralPath $Package -DestinationPath $extractDir -Force

$appDir = Split-Path -Parent $AppExe
$sourceDir = $extractDir
$innerDirs = @(Get-ChildItem -LiteralPath $extractDir -Directory)
if ($innerDirs.Count -eq 1) {
  $sourceDir = $innerDirs[0].FullName
}

Get-ChildItem -LiteralPath $sourceDir -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $appDir -Recurse -Force
}

if (Test-Path -LiteralPath $AppExe) {
  Start-Process -FilePath $AppExe
}
''';
}
