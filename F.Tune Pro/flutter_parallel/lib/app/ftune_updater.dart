import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads the new portable .exe and performs a self-replacing update.
///
/// Flow:
///  1. Download new exe to %TEMP%\ftune_update\FTunePro_new.exe
///  2. Write a PowerShell helper script that waits for THIS process to exit,
///     then replaces the old exe and re-launches it.
///  3. Launch the PS script hidden in the background.
///  4. Exit this process — the script takes over.
class FTuneUpdater {
  FTuneUpdater._();
  static final FTuneUpdater instance = FTuneUpdater._();

  /// Downloads [exeUrl] and reports progress via [onProgress] (0.0 – 1.0).
  /// Returns `true` when the update has been launched and the app should exit.
  Future<bool> downloadAndApply({
    required String exeUrl,
    required void Function(double progress) onProgress,
  }) async {
    final tmpDir = await getTemporaryDirectory();
    final updateDir = Directory('${tmpDir.path}\\ftune_update');
    if (!updateDir.existsSync()) updateDir.createSync(recursive: true);

    final newExePath = '${updateDir.path}\\FTunePro_new.exe';

    // ── Download ──────────────────────────────────────────────────────────────
    try {
      final request = http.Request('GET', Uri.parse(exeUrl));
      final response = await request.send().timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) return false;

      final total = response.contentLength ?? 0;
      var received = 0;

      final sink = File(newExePath).openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      return false;
    }

    // ── Write PowerShell updater script ──────────────────────────────────────
    final currentExe = Platform.resolvedExecutable;
    final scriptPath = '${updateDir.path}\\do_update.ps1';

    // Escape backslashes for PS string
    final escapedOld = currentExe.replaceAll("'", "''");
    final escapedNew = newExePath.replaceAll("'", "''");
    final pid = pid_; // current process ID

    final script = r'''
param([string]$OldExe, [string]$NewExe, [int]$Pid)
try { Wait-Process -Id $Pid -ErrorAction SilentlyContinue } catch {}
Start-Sleep -Milliseconds 800
Copy-Item -Path $NewExe -Destination $OldExe -Force
Start-Process -FilePath $OldExe
'''
        .trim();

    File(scriptPath).writeAsStringSync(script);

    // ── Launch the script then exit ───────────────────────────────────────────
    await Process.start(
      'powershell.exe',
      [
        '-NonInteractive',
        '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'Bypass',
        '-File', scriptPath,
        '-OldExe', escapedOld,
        '-NewExe', escapedNew,
        '-Pid', '$pid',
      ],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  // Exposes the current process ID.
  static int get pid_ => pid;
}
