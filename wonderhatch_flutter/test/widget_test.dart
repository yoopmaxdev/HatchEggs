import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderhatch_flutter/main.dart';
import 'package:wonderhatch_flutter/models/toy_series.dart';

void main() {
  test('All 10 series and 60 toys are defined', () {
    expect(kToySeriesList.length, 10);
    expect(kAllToys.length, 60);
  });

  testWidgets('Peel the foil hatches a toy and updates collection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WonderHatchApp());
    await tester.pump();

    expect(find.text('HatchEggs Wonder'), findsOneWidget);
    expect(find.text('Peel the foil'), findsOneWidget);
    expect(find.text('0/60'), findsOneWidget);

    // Tap the capsule 4 times (4 * 0.26 >= 1.0) to unwrap and hatch
    final capsuleFinder = find.text('Peel the foil');
    for (var i = 0; i < 4; i++) {
      await tester.tap(capsuleFinder);
      await tester.pump();
    }

    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.text('Hatch Another'), findsOneWidget);
    expect(find.text('1/60'), findsOneWidget);

    // Switch to Collection tab
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pump();
    expect(find.text('Toy Collection'), findsOneWidget);
  });
}
