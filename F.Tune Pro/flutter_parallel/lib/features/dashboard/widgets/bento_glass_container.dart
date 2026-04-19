import 'dart:ui';

import 'package:flutter/material.dart';

/// A Glassmorphism container used as the base card for the Bento grid layout.
///
/// Features: frosted-glass blur, translucent fill, subtle border highlight,
/// optional inner glow, and rounded corners.
class BentoGlassContainer extends StatelessWidget {
  const BentoGlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.blurSigma = 36,
    this.enableBackdropBlur = true,
    this.fillGradient,
    this.fillOpacity,
    this.borderColor,
    this.glowColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final bool enableBackdropBlur;
  final Gradient? fillGradient;

  /// Override fill opacity (0-1). Defaults to 0.52 dark / 0.62 light.
  final double? fillOpacity;

  /// Override border colour (defaults to white18 dark / black10 light).
  final Color? borderColor;

  /// Optional subtle accent glow behind the card.
  final Color? glowColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = fillOpacity ?? (isDark ? 0.18 : 0.24);
    final border = borderColor ??
        (isDark
            ? const Color(0x30FFFFFF)
            : const Color(0x18000000));
    final radius = BorderRadius.circular(borderRadius);
    final gradient = fillGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? <Color>[
                  Color.fromRGBO(34, 46, 70, fill),
                  Color.fromRGBO(16, 20, 34, fill * 0.78),
                ]
              : <Color>[
                  Color.fromRGBO(255, 255, 255, fill),
                  Color.fromRGBO(236, 240, 255, fill * 0.85),
                ],
        );

    final panel = Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: gradient,
        border: Border.all(
          color: border,
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withAlpha(50),
              blurRadius: 40,
              spreadRadius: -6,
            ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const <double>[0.0, 0.35, 1.0],
          colors: isDark
              ? const <Color>[
                  Color(0x18FFFFFF),
                  Color(0x06FFFFFF),
                  Color(0x00FFFFFF),
                ]
              : const <Color>[
                  Color(0x12FFFFFF),
                  Color(0x04FFFFFF),
                  Color(0x00FFFFFF),
                ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    Widget content = ClipRRect(
      borderRadius: radius,
      child: enableBackdropBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma * 0.35,
                sigmaY: blurSigma * 0.35,
              ),
              child: panel,
            )
          : panel,
    );

    if (onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: content),
      );
    }

    return content;
  }
}
