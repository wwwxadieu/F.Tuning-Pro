import 'package:flutter/material.dart';

import '../../app/ftune_models.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.onBack,
    required this.onChanged,
  });

  final AppPreferences preferences;
  final VoidCallback onBack;
  final ValueChanged<AppPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _roundIconButton(Icons.arrow_back_ios_new_rounded, onBack),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            _SettingsCard(
              title: 'Measurement System',
              subtitle: 'Pick the default unit system for new tuning sessions.',
              child: SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: true, label: Text('Metric')),
                  ButtonSegment<bool>(value: false, label: Text('Imperial')),
                ],
                selected: <bool>{preferences.useMetric},
                onSelectionChanged: (selection) {
                  onChanged(preferences.copyWith(useMetric: selection.first));
                },
              ),
            ),
            _SettingsCard(
              title: 'Language',
              subtitle: 'Keep early Flutter migration flexible while localization is ported.',
              child: DropdownButtonFormField<String>(
                value: preferences.languageCode,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: 'en', child: Text('English')),
                  DropdownMenuItem<String>(value: 'vi', child: Text('Vietnamese')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  onChanged(preferences.copyWith(languageCode: value));
                },
              ),
            ),
            _SettingsCard(
              title: 'Garage Autosave',
              subtitle: 'Control whether save-to-garage stays ready as a core workflow.',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.autoSaveGarage,
                onChanged: (value) {
                  onChanged(preferences.copyWith(autoSaveGarage: value));
                },
                title: const Text('Enable garage autosave helpers'),
              ),
            ),
            _SettingsCard(
              title: 'Overlay Preview',
              subtitle: 'Preparation for overlay migration from Electron to Flutter.',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: preferences.overlayPreviewEnabled,
                onChanged: (value) {
                  onChanged(preferences.copyWith(overlayPreviewEnabled: value));
                },
                title: const Text('Show overlay preview controls'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0x5E2A1E39),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x24FFFFFF)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xBB2B1C34), Color(0xC718121D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xB7FFFFFF))),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
