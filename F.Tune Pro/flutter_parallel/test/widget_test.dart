import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:ftune_flutter/features/dashboard/dashboard_page.dart';

void main() {
  testWidgets('dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(
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
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
  });
}
