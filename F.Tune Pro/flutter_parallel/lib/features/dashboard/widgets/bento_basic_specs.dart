import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../create/domain/car_spec.dart';
import 'bento_glass_container.dart';

/// Right-side Bento card showing the selected car's basic specifications
/// using ring gauges for numeric values and a PI badge at top.
class BentoBasicSpecs extends StatelessWidget {
  const BentoBasicSpecs({
    super.key,
    required this.accent,
    this.car,
    this.weightText,
    this.frontDistText,
    this.piText,
    this.torqueText,
    this.topSpeedText,
    this.driveType,
    this.metric = true,
  });

  final Color accent;
  final CarSpec? car;
  final String? weightText;
  final String? frontDistText;
  final String? piText;
  final String? torqueText;
  final String? topSpeedText;
  final String? driveType;
  final bool metric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1A1E28);
    final muted = isDark ? const Color(0xFF8A95A8) : const Color(0xFF5E6470);

    return BentoGlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                'Specs',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (car == null)
            Expanded(
              child: Center(
                child: Text(
                  'No car selected',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: <Widget>[
                    // ── PI Badge ──
                    _PiBadgeSpec(
                      piText: piText ?? '${car!.pi}',
                      car: car!,
                      accent: accent,
                      textColor: textColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    // ── Drive type chip ──
                    _DriveChip(
                      drive: driveType ?? car!.driveType,
                      accent: accent,
                      muted: muted,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    // ── Ring gauges (2-column grid) ──
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        _SpecRing(
                          label: metric ? 'Weight' : 'Weight',
                          value: _parseNum(weightText),
                          maxValue: 2500,
                          unit: metric ? 'kg' : 'lb',
                          accent: accent,
                          textColor: textColor,
                          muted: muted,
                          isDark: isDark,
                        ),
                        _SpecRing(
                          label: 'F.Dist',
                          value: _parseNum(frontDistText),
                          maxValue: 100,
                          unit: '%',
                          accent: const Color(0xFF42A5F5),
                          textColor: textColor,
                          muted: muted,
                          isDark: isDark,
                        ),
                        _SpecRing(
                          label: 'Torque',
                          value: _parseNum(torqueText),
                          maxValue: 2000,
                          unit: 'Nm',
                          accent: const Color(0xFFFF7043),
                          textColor: textColor,
                          muted: muted,
                          isDark: isDark,
                        ),
                        _SpecRing(
                          label: metric ? 'Top Spd' : 'Top Spd',
                          value: topSpeedText != null
                              ? _parseNum(topSpeedText)
                              : car!.topSpeedKmh,
                          maxValue: 500,
                          unit: metric ? 'km/h' : 'mph',
                          accent: const Color(0xFF66BB6A),
                          textColor: textColor,
                          muted: muted,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ── Tire & Diff rows (text only) ──
                    _SmallSpecRow(
                      icon: Icons.circle,
                      label: 'Tire',
                      value: car!.tireType,
                      muted: muted,
                      textColor: textColor,
                      accent: accent,
                    ),
                    _SmallSpecRow(
                      icon: Icons.settings_rounded,
                      label: 'Diff',
                      value: car!.differential,
                      muted: muted,
                      textColor: textColor,
                      accent: accent,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _parseNum(String? text) {
    if (text == null || text.isEmpty) return 0;
    return double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }
}

// ── PI Badge (special treatment) ──────────────────────────────────────────────

String _piClassLabel(int pi) {
  if (pi >= 999) return 'X';
  if (pi >= 901) return 'S2';
  if (pi >= 801) return 'S1';
  if (pi >= 701) return 'A';
  if (pi >= 601) return 'B';
  if (pi >= 501) return 'C';
  return 'D';
}

Color _piClassColor(String cls) {
  switch (cls) {
    case 'X':
      return const Color(0xFFE040FB);
    case 'S2':
      return const Color(0xFFE53935);
    case 'S1':
      return const Color(0xFFFF7043);
    case 'A':
      return const Color(0xFFFFB300);
    case 'B':
      return const Color(0xFF00BCD4);
    case 'C':
      return const Color(0xFF4CAF50);
    default:
      return const Color(0xFF9E9E9E);
  }
}

class _PiBadgeSpec extends StatelessWidget {
  const _PiBadgeSpec({
    required this.piText,
    required this.car,
    required this.accent,
    required this.textColor,
    required this.isDark,
  });

  final String piText;
  final CarSpec car;
  final Color accent, textColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final piNum =
        int.tryParse(piText.replaceAll(RegExp(r'[^0-9]'), '')) ?? car.pi;
    final cls = _piClassLabel(piNum);
    final clr = _piClassColor(cls);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[clr.withAlpha(isDark ? 30 : 18), Colors.transparent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: clr.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: clr,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cls,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$piNum',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: clr,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drive chip ────────────────────────────────────────────────────────────────

class _DriveChip extends StatelessWidget {
  const _DriveChip({
    required this.drive,
    required this.accent,
    required this.muted,
    required this.isDark,
  });

  final String drive;
  final Color accent, muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: accent.withAlpha(isDark ? 18 : 10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.drive_eta_rounded, size: 12, color: accent),
          const SizedBox(width: 6),
          Text(
            drive.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ring gauge spec item ──────────────────────────────────────────────────────

class _SpecRing extends StatelessWidget {
  const _SpecRing({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.unit,
    required this.accent,
    required this.textColor,
    required this.muted,
    required this.isDark,
  });

  final String label;
  final double value;
  final double maxValue;
  final String unit;
  final Color accent, textColor, muted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    const ringSize = 72.0;

    return SizedBox(
      width: ringSize + 6,
      child: Column(
        children: <Widget>[
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, animVal, child) {
                return CustomPaint(
                  painter: _RingPainter(
                    progress: animVal,
                    accent: accent,
                    trackColor: isDark
                        ? Colors.white.withAlpha(14)
                        : Colors.black.withAlpha(10),
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      value > 0 ? value.toStringAsFixed(0) : '--',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.accent,
    required this.trackColor,
  });

  final double progress;
  final Color accent;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 5;
    const strokeWidth = 5.0;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Accent arc
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent;
}

// ── Small spec row for text-only items (Tire, Diff) ──────────────────────────

class _SmallSpecRow extends StatelessWidget {
  const _SmallSpecRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
    required this.textColor,
    required this.accent,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color muted, textColor, accent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 10, color: accent.withAlpha(180)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: muted.withAlpha(30),
          ),
      ],
    );
  }
}
