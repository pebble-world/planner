# Integration tests

End-to-end tests that drive the planner on a **real device** (real fonts, real
layout, real gestures) — the layer where the widget harness (Ahem font, fixed
surface) can miss rendering/geometry bugs.

| File | What it covers |
|------|----------------|
| [`app_test.dart`](app_test.dart) | The single entry point. Registers every scenario so the whole suite runs in **one** app launch (desktop can only launch one app per `flutter test` invocation). |
| [`app_smoke_scenarios.dart`](app_smoke_scenarios.dart) | Boots the real example app; asserts a `Planner` renders and the real secondary-tap menu opens. |
| [`drag_scenarios.dart`](drag_scenarios.dart) | Long-press-dragging an event moves it and fires `onEntryMove` with no paint-phase side effects (device-level counterpart of the #11 / D5 regression). |
| [`event_geometry_scenarios.dart`](event_geometry_scenarios.dart) | An event's hit-area derives from `config.blockHeight` with proportional minutes (#10 / D3 + D4). |
| [`hour_label_scenarios.dart`](hour_label_scenarios.dart) | The default `maxHour` (23) clamps a below-grid tap to hour 23, not the invalid 24 (#13 / D10). |
| [`multi_planner_scenarios.dart`](multi_planner_scenarios.dart) | Two planners on one screen keep independent scroll state (device-level counterpart of the #9 / D1 regression). |
| [`planner_harness.dart`](planner_harness.dart) | Reusable `PlannerHarness` for multi-planner / multi-config flows, plus shared gesture helpers (`gridPointFor`, `createViaMenu`, `wheelScroll`, `longPressDrag`). |

## Running

Run from the `example/` directory.

### Windows (what CI runs)

```sh
flutter config --enable-windows-desktop   # once, if not already enabled
flutter test integration_test -d windows
```

### Web (Chrome)

Needs a matching [ChromeDriver](https://chromedriver.chromium.org/) on
`--port=4444`, run per target file via the driver:

```sh
chromedriver --port=4444 &
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d chrome
```

## Adding a test

Add scenarios as **functions called from [`app_test.dart`](app_test.dart)**, not
as new `*_test.dart` files — desktop launches one app per test file and a second
launch within an invocation is unreliable, so the suite is kept to a single
entry point.

Multi-planner or multi-config scenarios should build on `PlannerHarness` rather
than the single-`Planner` example app:

```dart
await tester.pumpWidget(PlannerHarness(planners: [
  PlannerSpec(config: configA, entries: entriesA),
  PlannerSpec(config: configB),
]));
final pointA = gridPointFor(tester.getRect(find.byKey(PlannerHarness.keyFor(0))));
```
