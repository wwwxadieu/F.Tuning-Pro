import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftune_flutter/app/ftune_crash_reporter.dart';
import 'package:ftune_flutter/app/ftune_log_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FTuneCrashReporter', () {
    late List<Map<String, Object>> requests;

    setUp(() {
      requests = <Map<String, Object>>[];

      final reporter = FTuneCrashReporter.instance;
      reporter.resetForTesting();
      reporter.setCrashReportEndpointForTesting(
        Uri.parse('http://localhost/mock-endpoint'),
      );
      reporter.setSendOverrideForTesting((endpoint, payload, attachment) async {
        final decrypted = await FTuneLogCodec.decryptLogBytes(
          await attachment.readAsBytes(),
        );
        requests.add(<String, Object>{
          'endpoint': endpoint.toString(),
          'payload': Map<String, String>.from(payload),
          'attachmentPath': attachment.path,
          'decrypted': decrypted,
          'attachmentExists': await attachment.exists(),
        });
        return true;
      });
    });

    tearDown(() {
      FTuneCrashReporter.instance.resetForTesting();
    });

    testWidgets('shows confirmation dialog when a crash is captured',
      (WidgetTester tester) async {
      final reporter = FTuneCrashReporter.instance;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: reporter.navigatorKey,
          scaffoldMessengerKey: reporter.scaffoldMessengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      reporter.captureZoneError(Exception('boom'), StackTrace.current);
      await tester.pumpAndSettle();

      expect(find.text('The app encountered an error'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
    });

    test('creates and sends an attached crash log file', () async {
      final reporter = FTuneCrashReporter.instance;

      final sent = await reporter.sendZoneErrorForTesting(
        Exception('boom'),
        StackTrace.current,
      );

      expect(sent, isTrue);
      expect(requests.length, 1);
      final payload = requests.first['payload']! as Map<String, String>;
      expect(payload['subject'], '[F.Tune Pro Crash] runZonedGuarded');
      expect((payload['message'] as String).contains('Exception: boom'), isTrue);
      expect(requests.first['attachmentExists'], isTrue);
      expect(
        (requests.first['attachmentPath']! as String).endsWith('.ftlog'),
        isTrue,
      );
      final decrypted = requests.first['decrypted']! as Map<String, dynamic>;
      expect(
        ((decrypted['crash'] as Map<String, dynamic>)['error'] as String)
            .contains('Exception: boom'),
        isTrue,
      );
      expect(decrypted['app'], isA<Map<String, dynamic>>());
      expect(decrypted['device'], isA<Map<String, dynamic>>());
      expect(
        ((decrypted['device'] as Map<String, dynamic>).containsKey('userName')),
        isTrue,
      );
    });
  });
}
