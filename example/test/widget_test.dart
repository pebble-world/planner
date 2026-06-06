// Widget smoke test for the example app.
//
// This used to be the default Flutter *counter* test (asserting a '0' -> '1'
// FloatingActionButton flow) left over from `flutter create`. The example app
// has no counter — it renders a Planner demo — so that test failed if ever run.
// It now verifies the example actually boots into the planner.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('example app boots into the Planner demo', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // The demo renders a single Planner inside a 'Planner Demo' scaffold.
    expect(find.byType(Planner), findsOneWidget);
    expect(find.text('Planner Demo'), findsOneWidget);

    // Guard against the old counter template creeping back in.
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
