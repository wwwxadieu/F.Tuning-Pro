import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

const List<String> ftuneAppleFontFallback = <String>[
  '.SF Pro Display',
  '.SF Pro Text',
  'SF Pro Display',
  'SF Pro Text',
  'CupertinoSystemDisplay',
  'CupertinoSystemText',
  'Helvetica Neue',
  'Segoe UI Variable Display',
  'Segoe UI Variable Text',
  'Segoe UI',
  'Arial',
  'sans-serif',
];

TextTheme buildFTuneTextTheme(
  TextTheme base, {
  required Color bodyColor,
  required Color displayColor,
}) {
  return base.apply(bodyColor: bodyColor, displayColor: displayColor).copyWith(
        displayLarge: _withAppleFallback(
          base.displayLarge,
          color: displayColor,
          weight: FontWeight.w800,
          letterSpacing: -1.8,
        ),
        displayMedium: _withAppleFallback(
          base.displayMedium,
          color: displayColor,
          weight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        displaySmall: _withAppleFallback(
          base.displaySmall,
          color: displayColor,
          weight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        headlineLarge: _withAppleFallback(
          base.headlineLarge,
          color: displayColor,
          weight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        headlineMedium: _withAppleFallback(
          base.headlineMedium,
          color: displayColor,
          weight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: _withAppleFallback(
          base.headlineSmall,
          color: displayColor,
          weight: FontWeight.w700,
        ),
        titleLarge: _withAppleFallback(
          base.titleLarge,
          color: displayColor,
          weight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: _withAppleFallback(
          base.titleMedium,
          color: bodyColor,
          weight: FontWeight.w700,
        ),
        titleSmall: _withAppleFallback(
          base.titleSmall,
          color: bodyColor,
          weight: FontWeight.w700,
        ),
        bodyLarge: _withAppleFallback(base.bodyLarge, color: bodyColor),
        bodyMedium: _withAppleFallback(base.bodyMedium, color: bodyColor),
        bodySmall: _withAppleFallback(base.bodySmall, color: bodyColor),
        labelLarge: _withAppleFallback(
          base.labelLarge,
          color: bodyColor,
          weight: FontWeight.w700,
        ),
        labelMedium: _withAppleFallback(
          base.labelMedium,
          color: bodyColor,
          weight: FontWeight.w700,
        ),
        labelSmall: _withAppleFallback(
          base.labelSmall,
          color: bodyColor,
          weight: FontWeight.w700,
        ),
      );
}

TextStyle _withAppleFallback(
  TextStyle? style, {
  Color? color,
  FontWeight? weight,
  double? letterSpacing,
}) {
  final base = style ?? const TextStyle();
  return base.copyWith(
    fontFamily: '.SF Pro Display',
    fontFamilyFallback: ftuneAppleFontFallback,
    color: color ?? base.color,
    fontWeight: weight ?? base.fontWeight,
    letterSpacing: letterSpacing ?? base.letterSpacing,
  );
}

class FTunePalette {
  static const Color shell = Color(0xFF09111D);
  static const Color shellTop = Color(0xFF182235);
  static const Color shellBottom = Color(0xFF060A12);
  static const Color panel = Color(0xB31A2333);
  static const Color panelSoft = Color(0xAA202B3F);
  static const Color panelRaised = Color(0xCC243046);
  static const Color panelStroke = Color(0x35FFFFFF);
  static const Color divider = Color(0x1FFFFFFF);
  // Electron brand colours
  static const Color accent = Color(0xFFA6051A);
  static const Color accentDark = Color(0xFF8F0415);
  static const Color highlight = Color(0xFFFFEB00);
  static const Color select = Color(0xFF111111);
  static const Color accentWarm = Color(0xFFFFB06A);
  static const Color accentCool = Color(0xFF76B8FF);
  static const Color success = Color(0xFF67D49E);
  static const Color textMuted = Color(0xEAF6FAFF);
  static const Color textFaint = Color(0xBFD7E1EF);
  static const Color electronText = Color(0xFF0B1220);
  static const Color electronMuted = Color(0xFF556274);
  static const Color electronSoft = Color(0xFFF5F8FD);
  static const Color electronSurface = Color(0xFFFDFEFF);
  static const Color electronSurfaceAlt = Color(0xFFF2F6FB);
  static const Color electronStroke = Color(0xFFDCE4EF);
  static const Color electronBorder = Color(0xFF111827);
  static const Color electronAccent = Color(0xFFA6051A);
}

@immutable
class FTuneElectronPaletteData {
  const FTuneElectronPaletteData({
    required this.isDark,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.surfaceHover,
    required this.surfaceHoverStrong,
    required this.text,
    required this.muted,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.backdrop,
    required this.headerDivider,
    required this.chromeTop,
    required this.chromeBottom,
    required this.chromeHighlight,
    required this.glow,
    required this.accent,
    required this.accentSoft,
    required this.surfaceGradient,
    required this.panelGradient,
  });

  factory FTuneElectronPaletteData.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    if (isDark) {
      return FTuneElectronPaletteData(
        isDark: true,
        surface: const Color(0xA6172131),
        surfaceAlt: const Color(0xC81B2738),
        surfaceSoft: const Color(0xCC202C3F),
        surfaceHover: const Color(0xD0213045),
        surfaceHoverStrong: const Color(0xE1283850),
        text: const Color(0xFFF6FAFF),
        muted: const Color(0xFFB4C2D8),
        border: const Color(0x33F7FBFF),
        borderStrong: accent.withAlpha(0x66),
        shadow: const Color(0x14000000),
        backdrop: const Color(0xA1060B12),
        headerDivider: const Color(0x24FFFFFF),
        chromeTop: const Color(0x881D2A3D),
        chromeBottom: const Color(0x66202D42),
        chromeHighlight: const Color(0x42FFFFFF),
        glow: accent.withAlpha(0x33),
        accent: accent,
        accentSoft: accent.withAlpha(0x22),
        surfaceGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xD61B273A),
            Color(0xC61A2534),
            Color(0xB4141E2A),
          ],
        ),
        panelGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0x66FFFFFF),
            Color(0x10FFFFFF),
          ],
        ),
      );
    }

    return FTuneElectronPaletteData(
      isDark: false,
      surface: const Color(0xD9FFFFFF),
      surfaceAlt: const Color(0xF3F5F8FF),
      surfaceSoft: const Color(0xEEF1F5FF),
      surfaceHover: const Color(0xF7F9FCFF),
      surfaceHoverStrong: const Color(0xFFF0F3F8),
      text: FTunePalette.electronText,
      muted: FTunePalette.electronMuted,
      border: const Color(0x73D5DEEA),
      borderStrong: accent.withAlpha(0x99),
      shadow: const Color(0x080A1320),
      backdrop: const Color(0x75060B12),
      headerDivider: const Color(0x1A0F172A),
      chromeTop: const Color(0x73FFFFFF),
      chromeBottom: const Color(0xA8EAF1FB),
      chromeHighlight: const Color(0xCCFFFFFF),
      glow: accent.withAlpha(0x1C),
      accent: accent,
      accentSoft: accent.withAlpha(0x14),
      surfaceGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xF8FFFFFF),
          Color(0xF0F6FBFF),
          Color(0xE9EEF7FF),
        ],
      ),
      panelGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xC8FFFFFF),
        ],
      ),
    );
  }

  final bool isDark;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSoft;
  final Color surfaceHover;
  final Color surfaceHoverStrong;
  final Color text;
  final Color muted;
  final Color border;
  final Color borderStrong;
  final Color shadow;
  final Color backdrop;
  final Color headerDivider;
  final Color chromeTop;
  final Color chromeBottom;
  final Color chromeHighlight;
  final Color glow;
  final Color accent;
  final Color accentSoft;
  final Gradient surfaceGradient;
  final Gradient panelGradient;
}

class FTuneScenicScaffold extends StatelessWidget {
  const FTuneScenicScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.showWatermark = true,
    this.centerChild = false,
    this.backgroundImagePath,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showWatermark;
  final bool centerChild;
  final String? backgroundImagePath;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: centerChild ? Center(child: child) : child,
    );

    return Scaffold(
      backgroundColor: FTunePalette.shellBottom,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          buildScenicBackgroundLayer(backgroundImagePath),
          const _FTuneBackgroundOverlays(),
          if (showWatermark)
            const Positioned(
              top: 24,
              right: 28,
              child: IgnorePointer(child: _FTuneWatermark()),
            ),
          SafeArea(child: content),
        ],
      ),
    );
  }
}

Widget buildScenicBackgroundLayer(String? backgroundImagePath) {
  final path = backgroundImagePath?.trim();
  if (path != null && path.isNotEmpty && _isSupportedBackground(path)) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
  }
  return Image.asset('assets/images/fh6-main-bg.jpg', fit: BoxFit.cover);
}

bool _isSupportedBackground(String path) {
  final normalized = path.toLowerCase();
  return normalized.endsWith('.png') ||
      normalized.endsWith('.jpg') ||
      normalized.endsWith('.jpeg') ||
      normalized.endsWith('.webp');
}

class FTuneElectronSurface extends StatelessWidget {
  const FTuneElectronSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    return _FTuneGlassFrame(
      radius: radius,
      blurSigma: 26,
      borderColor: palette.borderStrong,
      backgroundColor: palette.surface,
      surfaceGradient: palette.surfaceGradient,
      innerGlow: palette.glow,
      padding: padding,
      child: child,
    );
  }
}

class FTunePanel extends StatelessWidget {
  const FTunePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    return _FTuneGlassFrame(
      radius: radius,
      blurSigma: 18,
      borderColor: highlight ? palette.borderStrong : palette.border,
      backgroundColor: highlight ? palette.surfaceHoverStrong : palette.surface,
      surfaceGradient:
          highlight ? palette.panelGradient : palette.surfaceGradient,
      innerGlow: highlight ? palette.glow : palette.accentSoft,
      padding: padding,
      child: child,
    );
  }
}

class FTuneRoundIconButton extends StatelessWidget {
  const FTuneRoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final child = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                palette.surfaceHover,
                palette.surface,
              ],
            ),
            border: Border.all(color: palette.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.glow,
                blurRadius: 18,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: palette.text),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return child;
    }
    return Tooltip(message: tooltip!, child: child);
  }
}

class FTunePill extends StatelessWidget {
  const FTunePill(
    this.label, {
    super.key,
    this.filled = false,
    this.color,
    this.compact = false,
  });

  final String label;
  final bool filled;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final accent = color ?? palette.accent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: filled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent,
                  Color.lerp(accent, FTunePalette.accentWarm, 0.52) ?? accent,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  palette.surfaceHover,
                  palette.surface,
                ],
              ),
        border: Border.all(
          color: filled ? _withAlpha(Colors.white, 0.22) : palette.border,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: filled ? _withAlpha(accent, 0.22) : palette.glow,
            blurRadius: filled ? 18 : 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: filled
              ? (palette.isDark ? const Color(0xFF170D16) : Colors.white)
              : palette.text,
        ),
      ),
    );
  }
}

String ftunePiClassLabel(int? pi) {
  if (pi == null) return '--';
  if (pi >= 999) return 'X';
  if (pi >= 901) return 'S2';
  if (pi >= 801) return 'S1';
  if (pi >= 701) return 'A';
  if (pi >= 601) return 'B';
  if (pi >= 501) return 'C';
  return 'D';
}

String ftunePiClassDisplay(int? pi) {
  if (pi == null) return '--';
  return '${ftunePiClassLabel(pi)} $pi';
}

String ftunePiClassLabelFromDisplay(String display) {
  final normalized = display.trim().toUpperCase();
  final labelMatch = RegExp(r'\b(X|S2|S1|A|B|C|D)\b').firstMatch(normalized);
  if (labelMatch != null) return labelMatch.group(1) ?? '--';

  final value = int.tryParse(ftunePiValueFromDisplay(normalized));
  return ftunePiClassLabel(value);
}

String ftunePiValueFromDisplay(String display) {
  final match = RegExp(r'(\d+)').firstMatch(display);
  return match?.group(1) ?? '--';
}

Color ftunePiClassColor(String label) {
  switch (label.trim().toUpperCase()) {
    case 'D':
      return const Color(0xFF52C56E);
    case 'C':
      return const Color(0xFFB9D750);
    case 'B':
      return const Color(0xFFF2B55A);
    case 'A':
      return const Color(0xFF75B7FF);
    case 'S1':
      return const Color(0xFF3B82F6);
    case 'S2':
      return const Color(0xFFFF5F79);
    case 'X':
      return const Color(0xFF8B63FF);
    default:
      return const Color(0xFFB5C0D0);
  }
}

Color ftunePiClassTextColor(String label) {
  switch (label.trim().toUpperCase()) {
    case 'S1':
    case 'S2':
    case 'X':
      return Colors.white;
    default:
      return const Color(0xFF101726);
  }
}

class FTunePiBadge extends StatelessWidget {
  const FTunePiBadge({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
  });

  factory FTunePiBadge.fromPi(
    int? pi, {
    Key? key,
    bool compact = false,
  }) {
    return FTunePiBadge(
      key: key,
      label: ftunePiClassLabel(pi),
      value: pi?.toString() ?? '--',
      compact: compact,
    );
  }

  factory FTunePiBadge.fromDisplay(
    String display, {
    Key? key,
    bool compact = false,
  }) {
    return FTunePiBadge(
      key: key,
      label: ftunePiClassLabelFromDisplay(display),
      value: ftunePiValueFromDisplay(display),
      compact: compact,
    );
  }

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final background = ftunePiClassColor(label);
    final foreground = ftunePiClassTextColor(label);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 15,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(background, Colors.white, 0.08) ?? background,
            background,
          ],
        ),
        border: Border.all(color: _withAlpha(Colors.white, 0.24)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _withAlpha(background, 0.26),
            blurRadius: compact ? 16 : 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w800,
          color: foreground,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class FTunePrimaryButton extends StatelessWidget {
  const FTunePrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.minWidth,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final enabled = onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth ?? 0,
            minHeight: 48,
          ),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: enabled
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFFC20A22),
                        FTunePalette.accent,
                      ],
                    )
                  : LinearGradient(
                      colors: <Color>[
                        palette.surfaceSoft,
                        palette.surfaceSoft,
                      ],
                    ),
              border: Border.all(
                color:
                    enabled ? _withAlpha(Colors.white, 0.28) : palette.border,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: enabled
                      ? _withAlpha(FTunePalette.accent, 0.24)
                      : palette.glow,
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? (palette.isDark
                            ? const Color(0xFF201019)
                            : Colors.white)
                        : palette.muted,
                  ),
                ),
                if (icon != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    size: 18,
                    color: enabled
                        ? (palette.isDark
                            ? const Color(0xFF201019)
                            : Colors.white)
                        : palette.muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FTuneGhostButton extends StatelessWidget {
  const FTuneGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final enabled = onTap != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                enabled ? palette.surfaceHover : palette.surfaceSoft,
                enabled ? palette.surface : palette.surfaceSoft,
              ],
            ),
            border: Border.all(color: palette.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: enabled ? palette.glow : Colors.transparent,
                blurRadius: 14,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? palette.text : palette.muted,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: enabled ? palette.text : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FTunePageWidth extends StatelessWidget {
  const FTunePageWidth({
    super.key,
    required this.child,
    this.maxWidth = 1240,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class FTunePageHeader extends StatelessWidget {
  const FTunePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 25 : 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: palette.text,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              color: palette.muted,
              height: 1.35,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = compact || constraints.maxWidth < 760;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: titleBlock),
                ],
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(height: 14),
                trailing!,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: titleBlock),
                ],
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        );
      },
    );
  }
}

class FTuneSectionCard extends StatelessWidget {
  const FTuneSectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    return FTunePanel(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null ||
              subtitle != null ||
              trailing != null) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (title != null)
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                      if (subtitle != null &&
                          subtitle!.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: palette.muted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class FTuneStatCard extends StatelessWidget {
  const FTuneStatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.accent,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    final chipColor = accent ?? FTunePalette.accentCool;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.surfaceHover,
            palette.surface,
          ],
        ),
        border: Border.all(color: palette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.glow,
            blurRadius: 16,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: chipColor,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _withAlpha(chipColor, 0.22),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          if (caption != null && caption!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              caption!,
              style: TextStyle(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _FTuneGlassFrame extends StatelessWidget {
  const _FTuneGlassFrame({
    required this.child,
    required this.radius,
    required this.blurSigma,
    required this.borderColor,
    required this.backgroundColor,
    required this.surfaceGradient,
    required this.innerGlow,
    required this.padding,
  });

  final Widget child;
  final double radius;
  final double blurSigma;
  final Color borderColor;
  final Color backgroundColor;
  final Gradient surfaceGradient;
  final Color innerGlow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: surfaceGradient,
            color: backgroundColor,
            border: Border.all(color: borderColor),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: innerGlow,
                blurRadius: 24,
                spreadRadius: -8,
              ),
              const BoxShadow(
                color: Color(0x08000000),
                blurRadius: 18,
                spreadRadius: -12,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _withAlpha(Colors.white, 0.16),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FTuneBackgroundOverlays extends StatelessWidget {
  const _FTuneBackgroundOverlays();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                _withAlpha(FTunePalette.shellTop, 0.54),
                _withAlpha(FTunePalette.shell, 0.50),
                _withAlpha(FTunePalette.shellBottom, 0.76),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.86, -0.88),
                radius: 0.76,
                colors: <Color>[
                  _withAlpha(FTunePalette.accentCool, 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.92, -0.76),
                radius: 0.94,
                colors: <Color>[
                  _withAlpha(FTunePalette.accent, 0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.72, 1.02),
                radius: 0.92,
                colors: <Color>[
                  _withAlpha(FTunePalette.accentWarm, 0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -120,
          top: 88,
          child: _softOrb(
            size: 280,
            colors: const <Color>[
              Color(0x28FFFFFF),
              Color(0x00FFFFFF),
            ],
          ),
        ),
        Positioned(
          right: -90,
          bottom: -60,
          child: _softOrb(
            size: 320,
            colors: const <Color>[
              Color(0x22FF8BA5),
              Color(0x00FF8BA5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _softOrb({
    required double size,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _FTuneWatermark extends StatelessWidget {
  const _FTuneWatermark();

  @override
  Widget build(BuildContext context) {
    final palette = FTuneElectronPaletteData.of(context);
    return Opacity(
      opacity: palette.isDark ? 0.18 : 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(
              4,
              (index) => Container(
                width: 38 - (index * 4),
                height: 7,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'F.TUNE',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
              color: Colors.white,
            ),
          ),
          Text(
            'PRO',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: <Color>[
                    FTunePalette.accent,
                    FTunePalette.accentWarm,
                  ],
                ).createShader(const Rect.fromLTWH(0, 0, 120, 40)),
            ),
          ),
        ],
      ),
    );
  }
}

Color _withAlpha(Color color, double opacity) {
  final alpha = (opacity * 255).round().clamp(0, 255).toInt();
  return color.withAlpha(alpha);
}

// ═══════════════════════════════════════════════════════════════════════════
// Unified ThemeExtension for F.Tune Custom Colors
// This replaces the multiple custom palette classes throughout the app
// Usage: final customColors = Theme.of(context).extension<FTuneCustomColors>()!;
// ═══════════════════════════════════════════════════════════════════════════

@immutable
class FTuneCustomColors extends ThemeExtension<FTuneCustomColors> {
  const FTuneCustomColors({
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.surfaceHover,
    required this.surfaceHoverStrong,
    required this.muted,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.backdrop,
    required this.headerDivider,
    required this.chromeTop,
    required this.chromeBottom,
    required this.chromeHighlight,
    required this.glow,
    required this.accentSoft,
    required this.surfaceGradient,
    required this.panelGradient,
  });

  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSoft;
  final Color surfaceHover;
  final Color surfaceHoverStrong;
  final Color muted;
  final Color border;
  final Color borderStrong;
  final Color shadow;
  final Color backdrop;
  final Color headerDivider;
  final Color chromeTop;
  final Color chromeBottom;
  final Color chromeHighlight;
  final Color glow;
  final Color accentSoft;
  final Gradient surfaceGradient;
  final Gradient panelGradient;

  /// Creates custom colors based on brightness and accent color
  factory FTuneCustomColors.forBrightness(Brightness brightness, Color accent) {
    if (brightness == Brightness.dark) {
      return FTuneCustomColors(
        surface: const Color(0xA6172131),
        surfaceAlt: const Color(0xC81B2738),
        surfaceSoft: const Color(0xCC202C3F),
        surfaceHover: const Color(0xD0213045),
        surfaceHoverStrong: const Color(0xE1283850),
        muted: const Color(0xFFB4C2D8),
        border: const Color(0x33F7FBFF),
        borderStrong: accent.withAlpha(0x66),
        shadow: const Color(0x14000000),
        backdrop: const Color(0xA1060B12),
        headerDivider: const Color(0x24FFFFFF),
        chromeTop: const Color(0x881D2A3D),
        chromeBottom: const Color(0x66202D42),
        chromeHighlight: const Color(0x42FFFFFF),
        glow: accent.withAlpha(0x33),
        accentSoft: accent.withAlpha(0x22),
        surfaceGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xD61B273A),
            Color(0xC61A2534),
            Color(0xB4141E2A),
          ],
        ),
        panelGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0x66FFFFFF),
            Color(0x10FFFFFF),
          ],
        ),
      );
    }

    return FTuneCustomColors(
      surface: const Color(0xD9FFFFFF),
      surfaceAlt: const Color(0xF3F5F8FF),
      surfaceSoft: const Color(0xEEF1F5FF),
      surfaceHover: const Color(0xF7F9FCFF),
      surfaceHoverStrong: const Color(0xFFF0F3F8),
      muted: FTunePalette.electronMuted,
      border: const Color(0x73D5DEEA),
      borderStrong: accent.withAlpha(0x99),
      shadow: const Color(0x080A1320),
      backdrop: const Color(0x75060B12),
      headerDivider: const Color(0x1A0F172A),
      chromeTop: const Color(0x73FFFFFF),
      chromeBottom: const Color(0xA8EAF1FB),
      chromeHighlight: const Color(0xCCFFFFFF),
      glow: accent.withAlpha(0x1C),
      accentSoft: accent.withAlpha(0x14),
      surfaceGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xF8FFFFFF),
          Color(0xF0F6FBFF),
          Color(0xE9EEF7FF),
        ],
      ),
      panelGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color(0xFFFFFFFF),
          Color(0xC8FFFFFF),
        ],
      ),
    );
  }

  @override
  FTuneCustomColors copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSoft,
    Color? surfaceHover,
    Color? surfaceHoverStrong,
    Color? muted,
    Color? border,
    Color? borderStrong,
    Color? shadow,
    Color? backdrop,
    Color? headerDivider,
    Color? chromeTop,
    Color? chromeBottom,
    Color? chromeHighlight,
    Color? glow,
    Color? accentSoft,
    Gradient? surfaceGradient,
    Gradient? panelGradient,
  }) {
    return FTuneCustomColors(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceHoverStrong: surfaceHoverStrong ?? this.surfaceHoverStrong,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      shadow: shadow ?? this.shadow,
      backdrop: backdrop ?? this.backdrop,
      headerDivider: headerDivider ?? this.headerDivider,
      chromeTop: chromeTop ?? this.chromeTop,
      chromeBottom: chromeBottom ?? this.chromeBottom,
      chromeHighlight: chromeHighlight ?? this.chromeHighlight,
      glow: glow ?? this.glow,
      accentSoft: accentSoft ?? this.accentSoft,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
      panelGradient: panelGradient ?? this.panelGradient,
    );
  }

  @override
  FTuneCustomColors lerp(FTuneCustomColors? other, double t) {
    if (other is! FTuneCustomColors) return this;
    return FTuneCustomColors(
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t) ?? surfaceAlt,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t) ?? surfaceSoft,
      surfaceHover:
          Color.lerp(surfaceHover, other.surfaceHover, t) ?? surfaceHover,
      surfaceHoverStrong:
          Color.lerp(surfaceHoverStrong, other.surfaceHoverStrong, t) ??
              surfaceHoverStrong,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      backdrop: Color.lerp(backdrop, other.backdrop, t) ?? backdrop,
      headerDivider:
          Color.lerp(headerDivider, other.headerDivider, t) ?? headerDivider,
      chromeTop: Color.lerp(chromeTop, other.chromeTop, t) ?? chromeTop,
      chromeBottom:
          Color.lerp(chromeBottom, other.chromeBottom, t) ?? chromeBottom,
      chromeHighlight: Color.lerp(chromeHighlight, other.chromeHighlight, t) ??
          chromeHighlight,
      glow: Color.lerp(glow, other.glow, t) ?? glow,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t) ?? accentSoft,
      surfaceGradient: t < 0.5 ? surfaceGradient : other.surfaceGradient,
      panelGradient: t < 0.5 ? panelGradient : other.panelGradient,
    );
  }
}

/// Extension on ThemeData to easily add FTune custom colors
extension FTuneThemeDataExtension on ThemeData {
  /// Returns the custom FTune colors from the theme
  FTuneCustomColors get ftuneColors {
    return extension<FTuneCustomColors>() ??
        FTuneCustomColors.forBrightness(
          brightness,
          colorScheme.primary,
        );
  }
}

/// Extension on BuildContext for easy access to FTune custom colors
extension FTuneThemeContextExtension on BuildContext {
  /// Returns the custom FTune colors from the current theme
  FTuneCustomColors get ftuneColors {
    return Theme.of(this).ftuneColors;
  }
}
