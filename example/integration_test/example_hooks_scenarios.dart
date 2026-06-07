import 'package:example/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

import 'package:example/main.dart' as app;

/// End-to-end verification that the *example app* wires all four customization
/// hooks together (#81) — the integration check the docs/example issue exists
/// for. It drives the **real** entrypoint (`app.main()`), so it exercises the
/// hooks in real composition: a `dayHeaderBuilder` row above an all-day band of
/// `allDayEntryBuilder` chips above the `entryBuilder` overlay, with zoom driven
/// from the host's own `PlannerController` toolbar (the built-in controls
/// hidden). Event titles/labels are real widgets here (the builders render real
/// `Text`), so they're assertable — unlike the painted defaults.
///
/// Registered from [app_test.dart]; not a standalone entry point (desktop can
/// only launch one app per `flutter test` invocation).
void exampleHooksScenarios() {
  testWidgets('the example wires all four customization hooks together (#81)',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // The typed Planner<ActivityMeta> proves the generic payload (#77) is in use.
    expect(find.byType(Planner<ActivityMeta>), findsOneWidget);

    // entryBuilder (#78): a custom "Pop Block" widget for an on-screen event.
    expect(find.byKey(const ValueKey('pop-block-0')), findsOneWidget);

    // dayHeaderBuilder (#79): a custom multi-part header for column 0.
    expect(find.byKey(const ValueKey('day-header-0')), findsOneWidget);

    // allDayEntryBuilder (#80): a custom chip in the all-day band (the day-2
    // event sits in view without scrolling).
    expect(find.byKey(const ValueKey('all-day-chip-ad-0')), findsOneWidget);

    // PlannerController (#76): the host owns zoom. `showZoomControls:false` hides
    // the on-canvas buttons, so the single remaining zoom_in icon is the host's.
    expect(find.byKey(const ValueKey('demo-zoom-in')), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget,
        reason: 'the built-in on-canvas zoom button is hidden');
  });

  testWidgets(
      'the host toolbar zooms the grid and the Pop Block sheds detail by '
      'height (#81)', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // The 01:00 column-0 event ('Coffee & planning') stays near the top as the
    // grid zooms, so it visibly grows from a bare title to the full card.
    final card = find.byKey(const ValueKey('pop-block-2'));
    final avatars = find.byKey(const ValueKey('pop-avatars-2'));
    expect(card, findsOneWidget);

    // At zoom 1 the 60-min card is 40px tall — below the 92px avatar tier.
    final baseHeight = tester.getSize(card).height;
    expect(baseHeight, moreOrLessEquals(40, epsilon: 0.5));
    expect(avatars, findsNothing,
        reason: 'a 40px card is below the avatar-stack threshold');

    // Zoom in from the host's *own* toolbar button. 40 * 1.1^10 ≈ 104 ≥ 92, and
    // the button stays enabled (zoom < maxZoom 4.0) the whole way.
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byKey(const ValueKey('demo-zoom-in')));
      await tester.pump();
    }

    expect(tester.getSize(card).height, greaterThan(baseHeight),
        reason: 'the host button drove the real grid zoom (#76)');
    expect(avatars, findsOneWidget,
        reason: 'the taller card now reveals its avatar stack (#78 shedding)');
  });
}
