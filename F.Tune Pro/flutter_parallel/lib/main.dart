import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app/ftune_app.dart';
import 'app/ftune_crash_reporter.dart';
import 'app/ftune_overlay_window.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    try {
      final windowController = await WindowController.fromCurrentEngine();
      final launchData =
          FTuneWindowLaunchData.fromJsonString(windowController.arguments);
      if (launchData.isOverlay && launchData.overlayPayload != null) {
        runApp(FTuneOverlayWindowApp(payload: launchData.overlayPayload!));
        return;
      }
    } catch (_) {}
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
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
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    final lib = details.library ?? '';
    if (lib.contains('image resource service')) return;
    FlutterError.presentError(details);
    FTuneCrashReporter.instance.captureFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Caught platform error: $error');
    FTuneCrashReporter.instance.capturePlatformError(error, stack);
    return true;
  };

  runZonedGuarded(
    () {
      runApp(const FTuneApp());
    },
    (Object error, StackTrace stack) {
      FTuneCrashReporter.instance.captureZoneError(error, stack);
    },
  );
}
