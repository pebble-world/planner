# Contributing to `planner`

Thanks for helping improve `planner`. This guide covers how the package is laid
out, how to run the checks, and the branching workflow.

## Architecture

`Planner` is a single widget. You give it a
[`PlannerConfig`](lib/planner_config.dart) and a
`List<`[`PlannerEntry`](lib/planner_entry.dart)`>`, and it paints a grid of
columns (one per label) with horizontal hour lines, then draws each event as a
rectangle positioned by time.

There are **no real calendar dates anywhere**. A "day" is an index into
`config.labels` (a `List<String>`), so the widget is a generic *grid of
time-slots in N labelled columns* — useful for days, rooms, machines, or any
lanes. The rationale for keeping this model (rather than migrating to
`DateTime`) is recorded in
[ADR 0001](doc/decisions/0001-time-model-day-index.md). Real dates are layered
on top in consumer code via the optional, non-core
[`package:planner/calendar.dart`](lib/calendar.dart) helpers.

### Public API

Exported from [`lib/planner.dart`](lib/planner.dart):

| File | Role |
|------|------|
| [`planner_class.dart`](lib/planner_class.dart) | `Planner` widget; builds the layout, wires gestures, hosts the painters. |
| [`planner_controller.dart`](lib/planner_controller.dart) | `PlannerController` — optional public handle that attaches to the internal `Controller` to drive/observe zoom (and read scroll) from outside the widget. |
| [`planner_builders.dart`](lib/planner_builders.dart) | The custom-widget builder surface: `PlannerEntryBuilder<T>` + `PlannerEntryLayout` (timed events & all-day chips), `PlannerDayHeaderBuilder`, and the public `DragType` enum. |
| [`planner_config.dart`](lib/planner_config.dart) | `PlannerConfig<T>` — all sizing, colors, text styles, and callbacks. |
| [`planner_entry.dart`](lib/planner_entry.dart) | `PlannerEntry<T>` — a single event (id, time, title, content, color, styles) plus an optional typed `data` payload. |
| [`planner_time.dart`](lib/planner_time.dart) | `PlannerTime` — the day/hour/minute/duration value (also re-exported from the barrel). |

Shipped separately, **not** in the main barrel — import explicitly:

| File | Role |
|------|------|
| [`calendar.dart`](lib/calendar.dart) | `CalendarWindow` — optional `date ↔ column-index` helper for building an ordinary week calendar on top of the date-agnostic widget. |

### Internals

Under [`lib/internal/`](lib/internal/):

| File | Role |
|------|------|
| [`manager.dart`](lib/internal/manager.dart) | `Manager` — owns the `Controller`, builds `Event`s, computes the per-column overlap layout, and hit-tests positions. |
| [`controller.dart`](lib/internal/controller.dart) | Per-instance scroll/zoom/menu state + offset clamping. |
| [`event.dart`](lib/internal/event.dart) | `Event` — per-entry geometry, painting, and drag move/resize math. |
| [`events_painter.dart`](lib/internal/events_painter.dart) | Draws the grid + events and emits per-event semantics nodes. |
| [`all_day_band.dart`](lib/internal/all_day_band.dart) / [`all_day_event.dart`](lib/internal/all_day_event.dart) | The all-day band above the grid and its chip geometry/painting. |
| [`grid.dart`](lib/internal/grid.dart) / [`line.dart`](lib/internal/line.dart) | Builds and draws the vertical/horizontal grid lines. |
| [`hour_column.dart`](lib/internal/hour_column.dart) / [`hour_label.dart`](lib/internal/hour_label.dart) | Left-hand hour labels. |
| [`date_row.dart`](lib/internal/date_row.dart) / [`date_label.dart`](lib/internal/date_label.dart) | Top label row. |
| [`context_menu.dart`](lib/internal/context_menu.dart) | Right-click / double-tap menu firing the `onEntry*` callbacks. |
| [`scroll_detector.dart`](lib/internal/scroll_detector.dart) | Wraps `Listener` for mouse-wheel events. |
| [`positioned_tap_detector_2.dart`](lib/internal/positioned_tap_detector_2.dart) | Vendored copy of the `positioned_tap_detector_2` pub package (see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)). |

### Data flow

```
Planner (StatefulWidget)
  └─ State holds Manager(config, entries)    ← created in initState, refreshed in didUpdateWidget
       ├─ Controller(config)                 ← per-instance scroll/zoom state
       └─ List<Event>                         ← TextPainters laid out here
  build():
    LayoutBuilder → controller.setSize()
      Column[
        DateRow painter,
        AllDayBand painter,                    ← only when there are all-day events
        Row[ HourColumn painter,
             Stack[ EventsPainter (grid + events), zoom buttons, context menu ] ]
      ]
```

Repaint is driven by `controller.triggerUpdate` (a `ValueNotifier<int>` bumped on
every state change), passed as the painters' `repaint` listenable.

## Development

### Analyze and format

Run from the repository root:

```sh
flutter pub get
flutter analyze                                   # must be clean
dart format --output=none --set-exit-if-changed . # formatting gate
```

Run `dart format .` before every commit — CI fails on unformatted Dart.

### Unit and widget tests

```sh
flutter test
```

### Integration tests

End-to-end tests drive the planner on a **real device** (real fonts, real
layout, real gestures) — the layer where the widget harness (Ahem font, fixed
surface) can miss rendering/geometry bugs. Run them from the `example/`
directory:

```sh
flutter config --enable-windows-desktop   # once, if not already enabled
flutter test integration_test -d windows  # what CI runs
```

A web (Chrome) path via `flutter drive` is also available — see
[`example/integration_test/README.md`](example/integration_test/README.md) for
the full setup, the per-scenario map, and how to add a test.

## Branching workflow

- Branch off `develop` and open pull requests **into `develop`**.
- A release is a separate `develop → main` pull request — the only place the
  Windows integration CI job runs.
- Reference the issue in commits (`(#N)`) so GitHub auto-links them.
- Run `dart format` before every commit.

New work is started with the issue → branch → PR flow: every substantive change
is tied to a GitHub issue and a focused branch. See the open
[issues](https://github.com/pebble-world/planner/issues) for what's planned.

## Releasing

Releases publish to [pub.dev](https://pub.dev/packages/planner) automatically
from GitHub Actions using pub.dev's OIDC integration — no tokens or secrets are
stored in the repo. The trigger is a **pushed version tag**, not a PR or a merge
to `main`: a merge to `main` is not necessarily a release, whereas a deliberate
`vX.Y.Z` tag is the explicit "publish this version" signal.

The flow:

1. Finalize the version on `develop`: bump `version:` in
   [`pubspec.yaml`](pubspec.yaml) and date the matching `CHANGELOG.md` entry.
2. Open the `develop → main` release PR and merge it once `verify` and
   `integration-windows` are green.
3. Sync local `main`, then tag the merge commit and push the tag:

   ```sh
   git checkout main && git pull
   git tag vX.Y.Z        # must match pubspec.yaml's version
   git push origin vX.Y.Z
   ```

4. The [`publish` workflow](.github/workflows/publish.yml) runs on the tag:
   it re-checks `flutter analyze` + `flutter test` as a safety net, then runs
   `flutter pub publish --force`. pub.dev verifies the tag matches the pubspec
   version (tag pattern `v{{version}}`), so a mismatched or accidental tag will
   not publish — an extra guardrail that doubles as the "did you mean to
   publish?" check.
5. After it finishes, confirm the new version on the
   [pub.dev page](https://pub.dev/packages/planner) (screenshots render, links
   resolve once analysis settles a few minutes after publish).

### One-time setup (maintainer, outside this repo)

Automated publishing must be enabled once on pub.dev by a package owner:
**pub.dev → `planner` → Admin → Automated publishing → enable GitHub Actions**,
repository `pebble-world/planner`, tag pattern `v{{version}}`. This cannot be
done from the repo; until it is enabled, tag pushes will fail to publish.
