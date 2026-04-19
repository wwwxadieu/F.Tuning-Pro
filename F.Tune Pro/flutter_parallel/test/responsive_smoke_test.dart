import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftune_flutter/app/ftune_models.dart';
import 'package:ftune_flutter/features/create/create_tune_page.dart';
import 'package:ftune_flutter/features/create/domain/tune_models.dart';
import 'package:ftune_flutter/features/dashboard/dashboard_page.dart';
import 'package:ftune_flutter/features/garage/garage_page.dart';
import 'package:ftune_flutter/features/settings/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dashboard stays stable on mobile and desktop', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            onCreateTune: () {},
            onOpenGarage: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    _expectNoFlutterExceptions(tester);

    await _pumpAtSize(
      tester,
      const Size(1366, 900),
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            onCreateTune: () {},
            onOpenGarage: () {},
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    _expectNoFlutterExceptions(tester);
  });

  testWidgets('settings stays stable on mobile and desktop', (tester) async {
    final page = SettingsPage(
      preferences: const AppPreferences.defaults(),
      hasCustomBackground: false,
      onBack: () {},
      onChanged: (_) {},
      onPickBackground: () async {},
      onClearBackground: () async {},
      onDropBackground: (_) async => true,
      onOpenWelcomeTour: () {},
      languageCode: 'en',
    );

    await _pumpAtSize(
      tester,
      const Size(390, 844),
      MaterialApp(home: Scaffold(body: page)),
    );
    expect(find.text('Appearance'.toUpperCase()), findsOneWidget);
    _expectNoFlutterExceptions(tester);

    await _pumpAtSize(
      tester,
      const Size(1280, 900),
      MaterialApp(home: Scaffold(body: page)),
    );
    expect(find.text('Settings'), findsOneWidget);
    _expectNoFlutterExceptions(tester);
  });

  testWidgets('garage detail dialog stays stable on mobile', (tester) async {
    final record = _sampleRecord();
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      MaterialApp(
        home: Scaffold(
          body: GaragePage(
            records: <SavedTuneRecord>[record],
            overlayPreviewEnabled: true,
            onBack: () {},
            onCreateNew: () {},
            onDelete: (_) {},
            onTogglePinned: (_) {},
            onImport: () async {},
            onExport: (_) async {},
            onSetOverlayTune: (_) async {},
            onEditInCreate: (_) {},
            languageCode: 'en',
          ),
        ),
      ),
    );

    await tester.tap(find.text(record.title));
    await tester.pumpAndSettle();

    expect(find.text('Edit in Create'), findsOneWidget);
    _expectNoFlutterExceptions(tester);
  });

  testWidgets('create page stays stable on mobile', (tester) async {
    await _pumpAtSize(
      tester,
      const Size(390, 844),
      MaterialApp(
        home: Scaffold(
          body: CreateTunePage(
            onSaveTune: (_) {},
            onGarageRequested: () {},
          ),
        ),
      ),
      settleForAssets: true,
    );

    expect(find.text('Create New Tune'), findsOneWidget);
    expect(find.text('4. Info Snapshot'), findsOneWidget);
    _expectNoFlutterExceptions(tester);
  });
}

Future<void> _pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child, {
  bool settleForAssets = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(child);
  await tester.pump();
  if (settleForAssets) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }
  return;
}

void _expectNoFlutterExceptions(WidgetTester tester) {
  final exceptions = <Object>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    exceptions.add(error!);
  }

  expect(
    exceptions,
    isEmpty,
    reason: exceptions.map((item) => item.toString()).join('\n\n'),
  );
}

SavedTuneRecord _sampleRecord() {
  return SavedTuneRecord(
    id: 'sample-1',
    title: 'Ariel Nomad Grip',
    shareCode: '123 456 789',
    brand: 'Ariel',
    model: 'Nomad',
    driveType: 'RWD',
    surface: 'Street',
    tuneType: 'Race',
    piClass: 'A 711',
    topSpeedDisplay: '232 km/h',
    result: _sampleResult(),
    createdAt: DateTime(2026, 4, 4),
  );
}

TuneCalcResult _sampleResult() {
  return const TuneCalcResult(
    cards: <TuneCalcCard>[
      TuneCalcCard(
        title: 'Pressure',
        sliders: <TuneCalcSlider>[
          TuneCalcSlider(
            side: 'Front',
            value: 2.1,
            min: 1.0,
            max: 3.5,
            decimals: 1,
            suffix: ' bar',
          ),
          TuneCalcSlider(
            side: 'Rear',
            value: 2.1,
            min: 1.0,
            max: 3.5,
            decimals: 1,
            suffix: ' bar',
          ),
        ],
      ),
      TuneCalcCard(
        title: 'Braking',
        sliders: <TuneCalcSlider>[
          TuneCalcSlider(
            side: 'Balance',
            value: 52.9,
            min: 30,
            max: 70,
            decimals: 1,
            suffix: '%',
          ),
        ],
      ),
    ],
    overview: TuneCalcOverview(
      topSpeedDisplay: '232 km/h',
      tireType: 'Sport',
      differentialType: 'Race',
      metrics: <TuneCalcMetric>[
        TuneCalcMetric(
          key: 'speed',
          label: 'Speed',
          color: Color(0xFFFF7A2F),
          score: 55,
          value: '55',
        ),
        TuneCalcMetric(
          key: 'handling',
          label: 'Handling',
          color: Color(0xFF26D4CF),
          score: 90,
          value: '90',
        ),
      ],
      detailSections: <TuneCalcDetailSection>[
        TuneCalcDetailSection(
          key: 'balance',
          title: 'Balance',
          color: Color(0xFF26D4CF),
          rows: <TuneCalcDetailRow>[
            TuneCalcDetailRow(label: 'Front', value: '52%', progress: 52),
            TuneCalcDetailRow(label: 'Rear', value: '48%', progress: 48),
          ],
        ),
      ],
    ),
    subtitle: 'Ariel Nomad • RWD • Street • Race • PI 711',
    gearing: TuneCalcGearingData(
      finalDrive: 2.51,
      redlineRpm: 10000,
      scaleMaxKmh: 260,
      ratios: <TuneCalcGearRatio>[
        TuneCalcGearRatio(gear: 1, ratio: 3.1, topSpeedKmh: 72),
        TuneCalcGearRatio(gear: 2, ratio: 2.1, topSpeedKmh: 108),
      ],
    ),
  );
}
