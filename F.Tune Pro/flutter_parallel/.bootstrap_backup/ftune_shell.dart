import 'package:flutter/material.dart';

import '../features/create/create_tune_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/garage/garage_page.dart';
import '../features/settings/settings_page.dart';
import 'ftune_app_controller.dart';
import 'ftune_models.dart';

class FTuneShell extends StatelessWidget {
  const FTuneShell({
    super.key,
    required this.controller,
  });

  final FTuneAppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.section == AppSection.create) {
          return CreateTunePage(
            initialMetric: controller.preferences.useMetric,
            onBack: () => controller.goTo(AppSection.dashboard),
            onMetricChanged: controller.setMeasurementSystem,
            onSaveTune: (draft) {
              controller.saveTune(draft);
            },
            onGarageRequested: () => controller.goTo(AppSection.garage),
          );
        }

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF140E1A),
                      Color(0xFF24152A),
                      Color(0xFF0F0B14),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/images/fh6-main-bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: KeyedSubtree(
                      key: ValueKey<AppSection>(controller.section),
                      child: _buildSection(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context) {
    switch (controller.section) {
      case AppSection.dashboard:
        return DashboardPage(
          onCreateTune: () => controller.goTo(AppSection.create),
          onOpenGarage: () => controller.goTo(AppSection.garage),
          onOpenSettings: () => controller.goTo(AppSection.settings),
        );
      case AppSection.garage:
        return GaragePage(
          records: controller.garageTunes,
          onBack: () => controller.goTo(AppSection.dashboard),
          onCreateNew: () => controller.goTo(AppSection.create),
          onDelete: controller.deleteTune,
          onTogglePinned: controller.togglePinned,
        );
      case AppSection.settings:
        return SettingsPage(
          preferences: controller.preferences,
          onBack: () => controller.goTo(AppSection.dashboard),
          onChanged: controller.updatePreferences,
        );
      case AppSection.create:
        return const SizedBox.shrink();
    }
  }
}
