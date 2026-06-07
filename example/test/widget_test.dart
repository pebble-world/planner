// Widget smoke test for the example app.
//
// This used to be the default Flutter *counter* test (asserting a '0' -> '1'
// FloatingActionButton flow) left over from `flutter create`. The example app
// has no counter — it boots a gallery of example pages (#90) — so that test
// failed if ever run. It now verifies the gallery boots and navigates.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'package:example/data.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('example app boots into the gallery of examples', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // The home is the gallery list, not a planner.
    expect(find.text('Planner Examples'), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-tile-basic')), findsOneWidget);

    // The Showcase row is last and lazily built; scroll it into view to confirm
    // the full list is present.
    final showcase = find.byKey(const ValueKey('gallery-tile-showcase'));
    await tester.scrollUntilVisible(showcase, 120);
    expect(showcase, findsOneWidget);

    // Guard against the old counter template creeping back in.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tapping the Basic row opens a planner page', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('gallery-tile-basic')));
    await tester.pumpAndSettle();

    expect(find.byType(Planner), findsOneWidget);
  });

  testWidgets('tapping the Showcase row opens the all-hooks demo',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('gallery-tile-showcase'));
    await tester.scrollUntilVisible(tile, 120);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // The showcase renders a single typed Planner inside a 'Planner Demo' page.
    expect(find.byType(Planner<ActivityMeta>), findsOneWidget);
    expect(find.text('Planner Demo'), findsOneWidget);
  });
}
