import 'dart:ui';
import 'package:flutter/material.dart';

import '../../create/data/brand_logo_repository.dart';
import '../../create/domain/car_spec.dart';
import '../../create/domain/tune_models.dart';
import 'bento_glass_container.dart';

/// Large center Bento card — shows the currently selected car's image,
/// brand badge, model name, PI class, and quick-result overlay.
class BentoCarPreview extends StatelessWidget {
  const BentoCarPreview({
    super.key,
    required this.accent,
    this.car,
    this.thumbnailUrl,
    this.currentPi,
    this.result,
  });

  final Color accent;
  final CarSpec? car;
  final String? thumbnailUrl;
  final int? currentPi;
  final TuneCalcResult? result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1A1E28);
    final muted = isDark ? const Color(0xFF8A95A8) : const Color(0xFF5E6470);
    final pi = currentPi ?? car?.pi;

    return BentoGlassContainer(
      padding: EdgeInsets.zero,
      glowColor: accent,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ── Background subtle gradient ──
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: RadialGradient(
                center: const Alignment(0.3, -0.2),
                radius: 1.2,
                colors: <Color>[
                  accent.withAlpha(isDark ? 18 : 10),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // ── Glass shimmer overlay ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: const Alignment(-1, -1),
                  end: const Alignment(1, 1),
                  stops: const <double>[0, 0.3, 0.5, 0.7, 1],
                  colors: <Color>[
                    Colors.white.withAlpha(isDark ? 6 : 12),
                    Colors.transparent,
                    Colors.white.withAlpha(isDark ? 4 : 8),
                    Colors.transparent,
                    Colors.white.withAlpha(isDark ? 3 : 6),
                  ],
                ),
              ),
            ),
          ),

          // ── Car image / placeholder ──
          if (car != null)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _CarPreviewImage(
                  key: ValueKey<String>('${car!.brand}_${car!.model}'),
                  car: car!,
                  thumbnailUrl: thumbnailUrl,
                  isDark: isDark,
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Opacity(
                    opacity: isDark ? 0.25 : 0.12,
                    child: Image.asset(
                      'assets/images/fvgc-logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select a car to begin',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),

          // ── Glass frost overlay at bottom for brand/model area ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 86,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        (isDark ? const Color(0xFF0D1117) : Colors.white)
                            .withAlpha(0),
                        (isDark ? const Color(0xFF0D1117) : Colors.white)
                            .withAlpha(isDark ? 120 : 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Brand + Model overlay (bottom-left) ──
          if (car != null)
            Positioned(
              left: 20,
              bottom: 16,
              right: pi != null ? 100 : 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _BrandLogo(
                        brand: car!.brand,
                        size: 36,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          car!.brand.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: muted,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    car!.model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

          // ── PI badge (bottom-right) ──
          if (pi != null)
            Positioned(
              right: 18,
              bottom: 18,
              child: _PiBadge(pi: pi, isDark: isDark),
            ),

          // ── Quick result overlay (top-right) when result available ──
          if (result != null)
            Positioned(
              right: 18,
              top: 18,
              child: _QuickResultPill(result: result!, accent: accent, isDark: isDark),
            ),
        ],
      ),
    );
  }
}

// ── Car preview image with error handling ──

class _CarPreviewImage extends StatefulWidget {
  const _CarPreviewImage({
    super.key,
    required this.car,
    required this.thumbnailUrl,
    required this.isDark,
  });

  final CarSpec car;
  final String? thumbnailUrl;
  final bool isDark;

  @override
  State<_CarPreviewImage> createState() => _CarPreviewImageState();
}

class _CarPreviewImageState extends State<_CarPreviewImage>
    with SingleTickerProviderStateMixin {
  bool _error = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant _CarPreviewImage old) {
    super.didUpdateWidget(old);
    if (old.car.brand != widget.car.brand ||
        old.car.model != widget.car.model) {
      _error = false;
      _animCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.thumbnailUrl;
    if (url == null || url.isEmpty || _error) {
      return Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 100,
          color: widget.isDark
              ? const Color(0xFF2A2F3A)
              : const Color(0xFFD0D3DA),
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          cacheWidth: 960,
          errorBuilder: (_, __, ___) {
            if (mounted) setState(() => _error = true);
            return Center(
              child: Icon(
                Icons.directions_car_rounded,
                size: 100,
                color: widget.isDark
                    ? const Color(0xFF252A34)
                    : const Color(0xFFD8DAE0),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Brand logo widget ──

class _BrandLogo extends StatefulWidget {
  const _BrandLogo({
    required this.brand,
    required this.size,
    required this.isDark,
  });

  final String brand;
  final double size;
  final bool isDark;

  @override
  State<_BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<_BrandLogo> {
  int _urlIndex = 0;
  bool _failed = false;

  List<String> get _urls =>
      BrandLogoRepository.getBrandLogoUrlCandidates(widget.brand);

  @override
  void didUpdateWidget(covariant _BrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brand != widget.brand) {
      _urlIndex = 0;
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (_failed || urls.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isDark
              ? const Color(0xFF252A34)
              : const Color(0xFFD8DAE0),
        ),
        child: Center(
          child: Text(
            BrandLogoRepository.getBrandLogoFallbackText(widget.brand),
            style: TextStyle(
              fontSize: widget.size * 0.35,
              fontWeight: FontWeight.w900,
              color: widget.isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
      );
    }
    return Image.network(
      urls[_urlIndex],
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            if (_urlIndex < urls.length - 1) {
              _urlIndex++;
            } else {
              _failed = true;
            }
          });
        });
        return const SizedBox.shrink();
      },
    );
  }
}

// ── PI class helpers ──

String _piClassLabel(int pi) {
  if (pi >= 999) return 'X';
  if (pi >= 900) return 'S2';
  if (pi >= 800) return 'S1';
  if (pi >= 700) return 'A';
  if (pi >= 600) return 'B';
  if (pi >= 500) return 'C';
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

class _PiBadge extends StatefulWidget {
  const _PiBadge({required this.pi, required this.isDark});

  final int pi;
  final bool isDark;

  @override
  State<_PiBadge> createState() => _PiBadgeState();
}

class _PiBadgeState extends State<_PiBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;
  late int _displayPi;

  @override
  void initState() {
    super.initState();
    _displayPi = widget.pi;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final target = (widget.pi / 999).clamp(0.0, 1.0);
    _progressAnim = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _PiBadge old) {
    super.didUpdateWidget(old);
    if (old.pi != widget.pi) {
      final oldTarget = (old.pi / 999).clamp(0.0, 1.0);
      final newTarget = (widget.pi / 999).clamp(0.0, 1.0);
      _progressAnim = Tween<double>(begin: oldTarget, end: newTarget).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _displayPi = widget.pi;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cls = _piClassLabel(_displayPi);
    final clsColor = _piClassColor(cls);
    const double size = 56;
    const double stroke = 4.0;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: _progressAnim.value,
                  strokeWidth: stroke,
                  strokeCap: StrokeCap.round,
                  backgroundColor: (widget.isDark ? Colors.white : Colors.black)
                      .withAlpha(widget.isDark ? 25 : 18),
                  valueColor: AlwaysStoppedAnimation<Color>(clsColor),
                ),
              ),
              child!,
            ],
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            cls,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: clsColor,
              height: 1,
            ),
          ),
          Text(
            '$_displayPi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: widget.isDark
                  ? const Color(0xFFF2F6FF)
                  : const Color(0xFF1A1E28),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickResultPill extends StatelessWidget {
  const _QuickResultPill({
    required this.result,
    required this.accent,
    required this.isDark,
  });

  final TuneCalcResult result;
  final Color accent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x60000000)
                : const Color(0x40FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? const Color(0x20FFFFFF)
                  : const Color(0x15000000),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check_circle_rounded, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                'Tuned',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
