import 'package:flutter/material.dart';

/// A segmented tab bar with glassmorphic styling and a **sliding pill
/// indicator** for the Bento layout.
///
/// Displays tabs as a pill-shaped segmented control at the top of the
/// dashboard.  The active indicator smoothly animates between tabs using
/// `AnimatedPositioned` + `AnimatedContainer`.
class BentoSegmentedBar extends StatefulWidget {
  const BentoSegmentedBar({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
    required this.accent,
    this.tabs = const <BentoTab>[
      BentoTab(icon: Icons.home_rounded, label: 'Home'),
      BentoTab(icon: Icons.garage_rounded, label: 'My Garage'),
      BentoTab(icon: Icons.settings_rounded, label: 'Settings'),
    ],
  });

  final int activeIndex;
  final ValueChanged<int> onTabChanged;
  final Color accent;
  final List<BentoTab> tabs;

  @override
  State<BentoSegmentedBar> createState() => _BentoSegmentedBarState();
}

class _BentoSegmentedBarState extends State<BentoSegmentedBar> {
  final List<GlobalKey> _tabKeys = <GlobalKey>[];

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant BentoSegmentedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) _syncKeys();
  }

  void _syncKeys() {
    while (_tabKeys.length < widget.tabs.length) {
      _tabKeys.add(GlobalKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor =
        isDark ? const Color(0x30FFFFFF) : const Color(0x18000000);
    final textMuted =
        isDark ? const Color(0xFF8A95A8) : const Color(0xFF6D778A);

    return Center(
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Measure tab sizes after first frame
            return _SlidingRow(
              tabKeys: _tabKeys,
              tabs: widget.tabs,
              activeIndex: widget.activeIndex,
              accent: widget.accent,
              textMuted: textMuted,
              isDark: isDark,
              onTabChanged: widget.onTabChanged,
            );
          },
        ),
      ),
    );
  }
}

// ─── Sliding row with animated indicator ─────────────────────

class _SlidingRow extends StatefulWidget {
  const _SlidingRow({
    required this.tabKeys,
    required this.tabs,
    required this.activeIndex,
    required this.accent,
    required this.textMuted,
    required this.isDark,
    required this.onTabChanged,
  });

  final List<GlobalKey> tabKeys;
  final List<BentoTab> tabs;
  final int activeIndex;
  final Color accent;
  final Color textMuted;
  final bool isDark;
  final ValueChanged<int> onTabChanged;

  @override
  State<_SlidingRow> createState() => _SlidingRowState();
}

class _SlidingRowState extends State<_SlidingRow> {
  final List<double> _offsets = <double>[];
  final List<double> _widths = <double>[];
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _SlidingRow old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final parent = context.findRenderObject() as RenderBox?;
    if (parent == null) return;

    final offsets = <double>[];
    final widths = <double>[];
    for (final key in widget.tabKeys) {
      final ro = key.currentContext?.findRenderObject() as RenderBox?;
      if (ro == null) return;
      final pos = ro.localToGlobal(Offset.zero, ancestor: parent);
      offsets.add(pos.dx);
      widths.add(ro.size.width);
    }
    if (offsets.length == widget.tabs.length) {
      setState(() {
        _offsets
          ..clear()
          ..addAll(offsets);
        _widths
          ..clear()
          ..addAll(widths);
        _measured = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTextColor = widget.accent.computeLuminance() > 0.5
        ? const Color(0xFF111111)
        : Colors.white;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: <Widget>[
          // Sliding indicator
          if (_measured)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: _offsets[widget.activeIndex],
              top: 0,
              bottom: 0,
              width: _widths[widget.activeIndex],
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: widget.accent.withAlpha(70),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

          // Tab buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(widget.tabs.length, (i) {
              final isActive = i == widget.activeIndex;
              return _TabButton(
                key: widget.tabKeys[i],
                tab: widget.tabs[i],
                isActive: isActive,
                activeTextColor: activeTextColor,
                textMuted: widget.textMuted,
                accent: widget.accent,
                onTap: () => widget.onTabChanged(i),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Individual tab button (no background — indicator handles it) ────

class _TabButton extends StatefulWidget {
  const _TabButton({
    super.key,
    required this.tab,
    required this.isActive,
    required this.activeTextColor,
    required this.textMuted,
    required this.accent,
    required this.onTap,
  });

  final BentoTab tab;
  final bool isActive;
  final Color activeTextColor;
  final Color textMuted;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            // Only show hover tint when NOT active (indicator covers active)
            color: !widget.isActive && _hovered
                ? widget.accent.withAlpha(20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: widget.tab.imageProvider != null
                    ? Container(
                        key: ValueKey<bool>(widget.isActive),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: widget.tab.imageProvider!,
                            fit: BoxFit.cover,
                          ),
                          border: Border.all(
                            color: widget.isActive
                                ? widget.activeTextColor.withAlpha(80)
                                : widget.textMuted.withAlpha(40),
                            width: 1.5,
                          ),
                        ),
                      )
                    : Icon(
                        widget.tab.icon,
                        key: ValueKey<bool>(widget.isActive),
                        size: 16,
                        color: widget.isActive
                            ? widget.activeTextColor
                            : widget.textMuted,
                      ),
              ),
              const SizedBox(width: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isActive
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: widget.isActive
                      ? widget.activeTextColor
                      : widget.textMuted,
                  letterSpacing: -0.2,
                ),
                child: Text(widget.tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BentoTab {
  const BentoTab({required this.icon, required this.label, this.imageProvider});
  final IconData icon;
  final String label;
  final ImageProvider? imageProvider;
}
