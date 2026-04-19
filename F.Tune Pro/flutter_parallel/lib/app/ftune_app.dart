import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ftune_crash_reporter.dart';
import 'ftune_app_controller.dart';
import 'ftune_shell.dart';
import 'ftune_ui.dart';

class FTuneApp extends StatefulWidget {
  const FTuneApp({super.key});

  @override
  State<FTuneApp> createState() => _FTuneAppState();
}

class _FTuneAppState extends State<FTuneApp> {
  late final FTuneAppController _controller;
  late final Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _controller = FTuneAppController();
    _bootstrapFuture = _controller.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        var themeMode = ThemeMode.dark;
        if (_controller.preferences.themeMode == 'light') {
          themeMode = ThemeMode.light;
        } else if (_controller.preferences.themeMode == 'system') {
          themeMode = ThemeMode.system;
        }

        final accentColor = Color(_controller.preferences.accentColorValue);
        return MaterialApp(
          navigatorKey: FTuneCrashReporter.instance.navigatorKey,
          scaffoldMessengerKey: FTuneCrashReporter.instance.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'F.Tuning Pro',
          themeMode: themeMode,
          theme: _buildTheme(brightness: Brightness.light, accent: accentColor),
          darkTheme: _buildTheme(brightness: Brightness.dark, accent: accentColor),
          home: FutureBuilder<void>(
            future: _bootstrapFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return FTuneShell(controller: _controller);
            },
          ),
        );
      },
    );
  }
}

/// Converts raw [accent] to HSL, then:
/// - Boosts saturation to ≥ 65 % so the colour is vivid (never "blurry")
/// - Clamps lightness to 42–60 % so it reads on both dark and light surfaces
/// - Preserves the original hue (so brand colour is still recognisable)
Color _normalizeAccent(Color accent) {
  final r = accent.r / 255.0;
  final g = accent.g / 255.0;
  final b = accent.b / 255.0;

  final cMax = math.max(r, math.max(g, b));
  final cMin = math.min(r, math.min(g, b));
  final delta = cMax - cMin;

  double l = (cMax + cMin) / 2.0;

  double s = delta < 0.0001
      ? 0.0
      : delta / (1.0 - (2.0 * l - 1.0).abs());

  double h = 0.0;
  if (delta > 0.0001) {
    if (cMax == r) {
      h = ((g - b) / delta) % 6;
    } else if (cMax == g) {
      h = (b - r) / delta + 2;
    } else {
      h = (r - g) / delta + 4;
    }
    h /= 6.0;
    if (h < 0) h += 1.0;
  }

  // Boost desaturated / grey colours
  if (s < 0.55) s = math.max(s + 0.30, 0.65);
  s = s.clamp(0.65, 1.0);

  // Mid-range lightness — visible on dark AND light backgrounds
  l = l.clamp(0.42, 0.60);

  return _hslToColor(h, s, l);
}

Color _hslToColor(double h, double s, double l) {
  final c = (1.0 - (2.0 * l - 1.0).abs()) * s;
  final x = c * (1.0 - ((h * 6.0) % 2.0 - 1.0).abs());
  final m = l - c / 2.0;
  double r, g, b;
  switch ((h * 6.0).floor() % 6) {
    case 0:  r = c; g = x; b = 0; break;
    case 1:  r = x; g = c; b = 0; break;
    case 2:  r = 0; g = c; b = x; break;
    case 3:  r = 0; g = x; b = c; break;
    case 4:  r = x; g = 0; b = c; break;
    default: r = c; g = 0; b = x; break;
  }
  return Color.fromARGB(
    255,
    ((r + m) * 255).round().clamp(0, 255),
    ((g + m) * 255).round().clamp(0, 255),
    ((b + m) * 255).round().clamp(0, 255),
  );
}

ThemeData _buildTheme({required Brightness brightness, required Color accent}) {
  final isDark = brightness == Brightness.dark;
  // Normalise the raw accent before use — guarantees vivid, contrast-safe colour
  final primary = _normalizeAccent(accent);
  // onPrimary derived from the normalised colour so contrast is accurate
  final onPrimary = primary.computeLuminance() > 0.4 ? const Color(0xFF111111) : Colors.white;
  final palette = isDark
      ? FTuneElectronPaletteData(
          isDark: true,
          surface: const Color(0xCC1F2228),
          surfaceAlt: const Color(0xDB252A31),
          surfaceSoft: const Color(0xE0262C34),
          surfaceHover: const Color(0xE0313740),
          surfaceHoverStrong: const Color(0xE83A414C),
          text: const Color(0xFFF5F7FA),
          muted: const Color(0xFFC2C8D0),
          border: const Color(0x4DF2F4F7),
          borderStrong: primary.withAlpha(0x88),
          shadow: const Color(0x14000000),
          backdrop: const Color(0xA10A0D12),
          headerDivider: const Color(0x33FFFFFF),
          chromeTop: const Color(0x88262C35),
          chromeBottom: const Color(0x6622272E),
          chromeHighlight: const Color(0x42FFFFFF),
          glow: primary.withAlpha(0x44),
          accent: primary,
          accentSoft: primary.withAlpha(0x2A),
          surfaceGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xE01F242B),
              Color(0xD7262B33),
              Color(0xCB1E232A),
            ],
          ),
          panelGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0x38FFFFFF),
              Color(0x08FFFFFF),
            ],
          ),
        )
      : FTuneElectronPaletteData(
          isDark: false,
          surface: const Color(0xECFDFDFD),
          surfaceAlt: const Color(0xF7F5F7FA),
          surfaceSoft: const Color(0xF3F1F4F8),
          surfaceHover: const Color(0xFFFDFEFF),
          surfaceHoverStrong: const Color(0xFFF4F8FC),
          text: const Color(0xFF1D1F22),
          muted: const Color(0xFF5E636B),
          border: const Color(0xA6D3D8E2),
          borderStrong: primary.withAlpha(0xCC),
          shadow: const Color(0x080A1320),
          backdrop: const Color(0x750A0D12),
          headerDivider: const Color(0x241F2430),
          chromeTop: const Color(0xA8FFFFFF),
          chromeBottom: const Color(0xCCEDEFF4),
          chromeHighlight: const Color(0xCCFFFFFF),
          glow: primary.withAlpha(0x2A),
          accent: primary,
          accentSoft: primary.withAlpha(0x1F),
          surfaceGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFCFFFFFF),
              Color(0xF8F7F9FC),
              Color(0xF1EFF3F8),
            ],
          ),
          panelGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFDFEFE),
              Color(0xD8FFFFFF),
            ],
          ),
        );

  final textTheme = buildFTuneTextTheme(
    ThemeData(brightness: brightness).textTheme,
    bodyColor: palette.text,
    displayColor: palette.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: isDark ? const Color(0xFFFF4D6D) : const Color(0xFF8F0415),
      surface: palette.surface,
      onSurface: palette.text,
      onPrimary: onPrimary,
    ),
    textTheme: textTheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF171A1F) : const Color(0xFFF3F4F7),
    dividerColor: palette.border,
    iconTheme: IconThemeData(color: palette.text),
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceAlt,
      hintStyle: TextStyle(color: palette.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.borderStrong, width: 1.2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: palette.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.border),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withAlpha(isDark ? 90 : 48);
          }
          return palette.surfaceAlt;
        }),
        foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return palette.text;
          return palette.muted;
        }),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: palette.border),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor:
          isDark ? const Color(0xEE1D2839) : const Color(0xFFF8FBFF),
      contentTextStyle:
          TextStyle(color: palette.text, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: palette.border),
      ),
    ),
  );
}
