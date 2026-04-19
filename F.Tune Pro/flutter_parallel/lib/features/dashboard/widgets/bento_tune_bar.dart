import 'package:flutter/material.dart';

import 'bento_glass_container.dart';

/// Bottom Bento strip — horizontally scrollable tune feature cards.
///
/// Each card is a compact glassmorphic tile representing a tune section:
/// Config, Performance, Power Band, Tires, Results.
class BentoTuneBar extends StatelessWidget {
  const BentoTuneBar({
    super.key,
    required this.accent,
    required this.children,
  });

  final Color accent;

  /// The tune feature panels to lay out horizontally.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BentoGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 20,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _interleave(children),
          ),
        ),
      ),
    );
  }

  /// Insert thin vertical dividers between children.
  List<Widget> _interleave(List<Widget> items) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(const _TuneDivider());
      }
    }
    return result;
  }
}

class _TuneDivider extends StatelessWidget {
  const _TuneDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Container(
        width: 1,
        color: isDark
            ? const Color(0x20FFFFFF)
            : const Color(0x15000000),
      ),
    );
  }
}

/// A single tune feature tile inside the BentoTuneBar.
///
/// Shows an icon, label, and optional child content.
class BentoTuneTile extends StatefulWidget {
  const BentoTuneTile({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    this.isActive = false,
    this.onTap,
    this.child,
    this.width = 160,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool isActive;
  final VoidCallback? onTap;
  final Widget? child;
  final double width;

  @override
  State<BentoTuneTile> createState() => _BentoTuneTileState();
}

class _BentoTuneTileState extends State<BentoTuneTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF2F6FF) : const Color(0xFF1A1E28);
    final muted = isDark ? const Color(0xFF8A95A8) : const Color(0xFF5E6470);

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: widget.width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? widget.accent.withAlpha(isDark ? 25 : 15)
                : (_hovered
                    ? (isDark
                        ? const Color(0x10FFFFFF)
                        : const Color(0x08000000))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isActive
                  ? widget.accent.withAlpha(60)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    widget.icon,
                    size: 14,
                    color: widget.isActive ? widget.accent : muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.isActive ? widget.accent : textColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.child != null) ...<Widget>[
                const SizedBox(height: 8),
                widget.child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
