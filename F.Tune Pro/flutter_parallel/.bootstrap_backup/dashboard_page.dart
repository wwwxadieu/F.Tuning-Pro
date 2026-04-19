import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onCreateTune,
    required this.onOpenGarage,
    required this.onOpenSettings,
  });

  final VoidCallback onCreateTune;
  final VoidCallback onOpenGarage;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = <Widget>[
          _DashboardCard(
            title: 'Create Tune',
            subtitle: 'Build a fresh setup profile',
            icon: Icons.tune_rounded,
            accent: const Color(0xFFFF5B87),
            onTap: onCreateTune,
          ),
          _DashboardCard(
            title: 'My Garage',
            subtitle: 'Review and manage saved tunes',
            icon: Icons.garage_rounded,
            accent: const Color(0xFFFF8B4F),
            onTap: onOpenGarage,
          ),
          _DashboardCard(
            title: 'Settings',
            subtitle: 'Adjust app preferences',
            icon: Icons.settings_rounded,
            accent: const Color(0xFF5B9BFF),
            onTap: onOpenSettings,
          ),
        ];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'F.Tuning Pro',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Advanced Performance Engineering Suite',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                    color: Color(0xB7FFFFFF),
                  ),
                ),
                const SizedBox(height: 32),
                if (constraints.maxWidth > 1020)
                  Row(
                    children: <Widget>[
                      for (var index = 0; index < cards.length; index++) ...<Widget>[
                        Expanded(child: cards[index]),
                        if (index != cards.length - 1) const SizedBox(width: 18),
                      ],
                    ],
                  )
                else
                  Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: cards
                        .map((card) => SizedBox(width: math.min(360, constraints.maxWidth).toDouble(), child: card))
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        height: 260,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x2EFFFFFF)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              accent.withOpacity(0.22),
              const Color(0xCC1A1320),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Color(0xB7FFFFFF))),
          ],
        ),
      ),
    );
  }
}
