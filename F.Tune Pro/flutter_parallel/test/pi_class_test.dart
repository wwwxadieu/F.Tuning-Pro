import 'package:flutter_test/flutter_test.dart';

import 'package:ftune_flutter/app/ftune_ui.dart';

void main() {
  test('PI class boundaries match Forza ranges', () {
    expect(ftunePiClassDisplay(500), 'D 500');
    expect(ftunePiClassDisplay(501), 'C 501');
    expect(ftunePiClassDisplay(600), 'C 600');
    expect(ftunePiClassDisplay(601), 'B 601');
    expect(ftunePiClassDisplay(700), 'B 700');
    expect(ftunePiClassDisplay(701), 'A 701');
    expect(ftunePiClassDisplay(800), 'A 800');
    expect(ftunePiClassDisplay(801), 'S1 801');
    expect(ftunePiClassDisplay(900), 'S1 900');
    expect(ftunePiClassDisplay(901), 'S2 901');
    expect(ftunePiClassDisplay(998), 'S2 998');
    expect(ftunePiClassDisplay(999), 'X 999');
  });

  test('PI class can be recovered from legacy PI-only displays', () {
    expect(ftunePiClassLabelFromDisplay('PI 800'), 'A');
    expect(ftunePiClassLabelFromDisplay('PI 801'), 'S1');
    expect(ftunePiClassLabelFromDisplay('S1 900'), 'S1');
    expect(ftunePiClassLabelFromDisplay('S2 901'), 'S2');
  });
}
