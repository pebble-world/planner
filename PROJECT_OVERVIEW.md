# PROJECT_OVERVIEW — `planner`

> A Flutter widget that renders a scrollable, zoomable day-grid of events on a
> `CustomPaint` canvas. This document is the orientation map **and** the quality
> audit: it explains how the package is built today and enumerates every issue we
> need to address to make it a great, publishable pub.dev package.

- **Version:** 0.0.4
- **Repo:** https://github.com/pebble-world/planner
- **Status:** internal-only (`publish_to: none`); goal is pub.dev + cross-project reuse.
- **Last reviewed:** 2026-06-06

---

## 1. What the package does

`Planner` is a single widget. You give it a [`PlannerConfig`](lib/planner_config.dart)
and a `List<`[`PlannerEntry`](lib/planner_entry.dart)`>`, and it paints a grid of
columns (one per label) with horizontal hour lines, then draws each event as a
rectangle positioned by time. The user can:

- **Pan horizontally** to move across day-columns.
- **Pan / mouse-wheel scroll vertically** to move across hours.
- **Zoom** the time axis via pinch or the on-canvas +/- buttons.
- **Long-press + drag** an event to move it, or drag its top/bottom handle to resize.
- **Double-tap / right-click** to open a context menu that fires
  `onEntryCreate` / `onEntryEdit` / `onEntryDelete` / `onEntryMove` callbacks.

### The time model (important)

There are **no real calendar dates anywhere**. [`PlannerTime`](lib/planner_time.dart)
is `{ int day, int hour, int minutes, int duration }`, where `day` is an **index
into `config.labels`** (a `List<String>`). The widget is really a *generic grid of
time-slots in N labelled columns*, not a date-aware calendar. This was the single
biggest design fork — **now decided: keep the day-index model** (#19; see §4 and
`docs/decisions/0001-time-model-day-index.md`).

---

## 2. Architecture map

Public API (exported from [`lib/planner.dart`](lib/planner.dart)):

| File | Role |
|------|------|
| [`planner_class.dart`](lib/planner_class.dart) | `Planner` widget; builds the layout, wires gestures, hosts the painters. |
| [`planner_config.dart`](lib/planner_config.dart) | `PlannerConfig` — all sizing, colors, text styles, and callbacks. |
| [`planner_entry.dart`](lib/planner_entry.dart) | `PlannerEntry` — a single event (id, time, title, content, color, styles). |
| [`planner_time.dart`](lib/planner_time.dart) | `PlannerTime` — the day/hour/minute/duration value (⚠️ **not** re-exported). |

Internals ([`lib/internal/`](lib/internal/)):

| File | Role |
|------|------|
| [`manager.dart`](lib/internal/manager.dart) | `Manager` — owns the `Controller`, builds `Event`s, hit-tests positions. |
| [`controller.dart`](lib/internal/controller.dart) | Scroll/zoom/menu state + offset clamping (⚠️ uses `static` fields). |
| [`event.dart`](lib/internal/event.dart) | `Event` — per-entry geometry, painting, and drag move/resize math. |
| [`events_painter.dart`](lib/internal/events_painter.dart) | Draws grid + events (⚠️ also runs drag logic inside `paint()`). |
| [`grid.dart`](lib/internal/grid.dart) / [`line.dart`](lib/internal/line.dart) | Builds and draws the vertical/horizontal grid lines. |
| [`hour_column.dart`](lib/internal/hour_column.dart) / [`hour_label.dart`](lib/internal/hour_label.dart) | Left-hand hour labels. |
| [`date_row.dart`](lib/internal/date_row.dart) / [`date_label.dart`](lib/internal/date_label.dart) | Top label row. |
| [`contex_menu.dart`](lib/internal/contex_menu.dart) | Right-click/double-tap menu (⚠️ filename typo; hardcoded English). |
| [`scroll_detector.dart`](lib/internal/scroll_detector.dart) | Wraps `Listener` for mouse-wheel events. |
| [`positioned_tap_detector_2.dart`](lib/internal/positioned_tap_detector_2.dart) | ⚠️ Vendored copy of the `positioned_tap_detector_2` pub package. |
| [`widget_size.dart`](lib/internal/widget_size.dart) | ⚠️ Dead code — never referenced. |

### Data flow

```
Planner (StatefulWidget)
  └─ builds Manager(config, entries)        ← ⚠️ rebuilt on EVERY parent build
       ├─ Controller(config)                ← ⚠️ static scroll/zoom state
       └─ List<Event>                        ← TextPainters laid out here
  build():
    LayoutBuilder → controller.setSize()
      Column[
        DateRow painter,
        Row[ HourColumn painter,
             Stack[ EventsPainter (grid + events), zoom buttons, context menu ] ]
      ]
```

Repaint is driven by `controller.triggerUpdate` (a `ValueNotifier<int>` bumped on
every state change), passed as the painters' `repaint` listenable.

---

## 3. Issues — full audit

Severity: 🔴 blocker/bug · 🟠 important · 🟡 polish.

### A. pub.dev publishing blockers

| # | Sev | Issue | Fix |
|---|-----|-------|-----|
| A1 | 🔴 | [`LICENSE`](LICENSE) is literally `TODO: Add your license here.` — pub.dev rejects, and there is no legal grant to reuse the code. | Add MIT license text. ✅ *(this pass)* |
| A2 | 🔴 | [`README.md`](README.md) is the unmodified template (all `TODO:`). | Rewrite with description/features/usage/concepts. ✅ *(this pass)* |
| A3 | 🟠 | [`CHANGELOG.md`](CHANGELOG.md) is a `0.0.1 TODO` stub; doesn't match v0.0.4. | Reconstruct real entries. ✅ *(this pass)* |
| A4 | 🟠 | [`pubspec.yaml`](pubspec.yaml): `publish_to: 'none'`, empty `homepage`, no `repository`/`issue_tracker`/`topics`, terse description. | Add metadata + topics; drop `publish_to`. ✅ *(this pass)* |
| A5 | 🔴 | **Name + version collision.** `flutter pub publish --dry-run` reports the name `planner` is **already on pub.dev at `0.1.0`** (with a prior `0.0.3`). pub.dev refuses any version ≤ the latest, so `0.0.4` cannot be published, and uploading requires being an authorized uploader of that package. | **Decision needed** (deferred): if this is our package → bump to `> 0.1.0` (e.g. `1.0.0`) and publish as an uploader; if it isn't ours → **rename** the package (e.g. `pebble_planner`). |
| A6 | 🟡 | Dry-run warns that checked-in-but-gitignored IDE files (`.idea/*`, `planner.iml`) would leak into the archive. | `git rm --cached` them (or add a `.pubignore`). |

> ⚠️ **A5 is the gating blocker for actually publishing.** Everything else in this
> section is resolved, but until the name/version question is settled the package
> still cannot go to pub.dev. `flutter pub publish --dry-run` otherwise passes (only
> the warnings above remain).

### B. Dependencies

| # | Sev | Issue | Suggested fix |
|---|-----|-------|---------------|
| B1 | 🟠 | `after_layout: ^1.2.0` is declared but **never imported** anywhere. Dead weight that lowers the pub score. | Remove from `pubspec.yaml`. ✅ (this pass) |
| B2 | 🟡 | `flutter_lints: ^1.0.0` is several major versions behind (current ~5.x); modern lints are missed. | Bump to latest, fix any new findings. (deferred — may surface lints) |
| B3 | 🟠 | [`positioned_tap_detector_2.dart`](lib/internal/positioned_tap_detector_2.dart) is a **verbatim vendored copy** of a pub package — no attribution, no upstream fixes, possible license violation. | Kept the copy with its MIT license header + [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), removed the analysis exclude. ✅ (#24) |
| B4 | 🟠 | `pubspec.lock` is **committed** despite being in `.gitignore` (libraries must not pin it). | `git rm --cached pubspec.lock example/pubspec.lock`. ✅ (this pass) |

### C. Project structure / hygiene

| # | Sev | Issue | Suggested fix |
|---|-----|-------|---------------|
| C1 | 🟠 | `DragType` enum is declared **twice** — in [`planner_entry.dart`](lib/planner_entry.dart) (unused) and [`event.dart`](lib/internal/event.dart). | Delete the unused one in `planner_entry.dart`. |
| C2 | 🟠 | [`widget_size.dart`](lib/internal/widget_size.dart) (`WidgetSize`) is never referenced. | Delete. |
| C3 | 🟡 | Filename typo `contex_menu.dart`. | Rename to `context_menu.dart`. |
| C4 | 🟠 | [`planner_time.dart`](lib/planner_time.dart) is part of the public surface (the example imports it directly) but is **not exported** from [`planner.dart`](lib/planner.dart). | Add `export 'planner_time.dart';`. |
| C5 | 🟡 | Imports mix `package:planner/...` and relative paths inconsistently. | Standardize (relative within the package). |
| C6 | 🔴 | No real tests: [`test/planner_test.dart`](test/planner_test.dart) is an empty stub, and [`example/test/widget_test.dart`](example/test/widget_test.dart) is the default **counter** test that **fails** against the real example app. | Replace with widget/golden tests for the planner; delete/replace the example smoke test. |
| C7 | 🟡 | The `example/` app commits generated platform files (e.g. `example/windows/flutter/generated_*`), causing constant git churn (already shows as modified). | Gitignore generated platform output, or regenerate on demand. |

### D. Logic / correctness / design (the "convoluted/primitive calculations")

| # | Sev | Issue | Why it matters / suggested fix |
|---|-----|-------|--------------------------------|
| D1 | 🔴 | **Static mutable state** in [`controller.dart`](lib/internal/controller.dart): `_x, _y, _zoom, _previousZoom, _hDragStart, _hDrag` are `static`. | Every `Planner` in the app **shares one scroll/zoom position**; two planners fight each other and state leaks between unrelated screens. Make them instance fields. |
| D2 | 🔴 | **`Manager` is rebuilt on every frame**: `Planner({...}) : data = Manager(config, entries)` runs in the constructor, so each parent rebuild recreates the `Manager`, every `Event`, every `TextPainter.layout()`, and the whole `Grid` of `Line`s. | Wasteful and is the *reason* D1 exists (statics survive the churn). Hoist `Manager` into `State` (init in `initState`, refresh in `didUpdateWidget`) or expose a `PlannerController`. |
| D3 | 🔴 | **Geometry hardcodes `blockHeight == 40`**: in [`event.dart`](lib/internal/event.dart) `_calculateCanvasRect` uses `(minutes/15).round()*10.0` and `duration/60*40.0`. | Any `blockHeight` other than 40 mis-positions and mis-sizes every event relative to the grid. Derive from config: `minutes/60*blockHeight`, `duration/60*blockHeight`. |
| D4 | 🟠 | Minute placement quantizes to the 15-min grid (`round(minutes/15)*10`) instead of being proportional. | Events with arbitrary minutes snap visually even when the data is exact. Use a proportional `minutes/60*blockHeight`. |
| D5 | 🔴 | **Side effects inside `CustomPainter.paint()`**: [`events_painter.dart`](lib/internal/events_painter.dart) detects drag start/stop, mutates `Event` drag state, and calls `onEntryMove` *during painting*. | Painters must be pure; firing callbacks during paint runs at unpredictable times and is fragile. Move drag to gesture recognizers / hit-testing in the widget layer. |
| D6 | 🟠 | Every painter's `shouldRepaint` returns `true`. | Combined with recreating painters each build (D2), repaint optimization is fully defeated. Compare inputs or rely solely on the `repaint` listenable. |
| D7 | 🟡 | [`grid.dart`](lib/internal/grid.dart) `draw()` allocates fresh `Paint` objects (`div2paint`, `div3paint`) on **every frame**. | Cache them; recompute only when zoom changes. |
| D8 | 🟠 | **Inconsistent snapping**: create-time [`manager.dart`](lib/internal/manager.dart) `getTimeAtPos` (`zoom>2.25`, `/10*15`, `/20*30`) and drag-time `_roundedMinutes`/`endDrag` (`~/30`, `~/15`, `~/5`) use different ad-hoc thresholds. | Hard to reason about and behaves differently for create vs. drag. Centralize into one configurable `snapMinutes`. |
| D9 | 🟠 | **No clamping**: `getTimeAtPos` can return negative `day`/`hour` when tapping above/left of the grid; zoom is unbounded (can approach 0 or grow huge). | Clamp day/hour to valid ranges; add `minZoom`/`maxZoom`. |
| D10 | 🟡 | `maxHour` defaults to `24` and loops `i <= maxHour`, producing a spurious 25th row labelled "24". Hours render as bare ints with no formatting. | Default to `23`; add a label formatter (zero-pad / AM-PM / `intl`). |
| D11 | 🟠 | **No overlap handling** — concurrent events stack on top of each other at full column width. | Implement column-splitting layout (standard calendar behaviour). |
| D12 | 🟡 | Misc smells: `_paintHandle` uses redundant `color.withAlpha(255)`; ✅ labels centered in their columns (no more hardcoded 15/60 offsets) (#28); ✅ `verticalScroll` step now scales with zoom (#28); O(n) linear hit-testing; **hardcoded English** menu strings (no l10n); ✅ zoom buttons visibility/colors configurable via `PlannerConfig` (#28); legacy APIs (`RawMaterialButton`, `primarySwatch`, old `typedef` syntax); `PlannerEntry`/`PlannerTime` are mutable with no `==`/`copyWith`; **no `Semantics`/accessibility** on the canvas. | Address opportunistically during the refactor. |

### E. Tooling / CI

| # | Sev | Issue | Suggested fix |
|---|-----|-------|---------------|
| E1 | 🟠 | No CI — nothing runs `flutter analyze` / `flutter test` / `dart format` on push. | Add a GitHub Actions workflow. |
| E2 | 🟡 | [`analysis_options.yaml`](analysis_options.yaml) is minimal. | Enable stricter lints + doc lints once B2 lands. |

---

## 4. Prioritized roadmap

### P0 — Publish blockers
- ✅ *(done in this pass)* LICENSE (MIT), real README, real CHANGELOG, pubspec
  metadata + topics, remove `publish_to: none` and the unused `after_layout` dep,
  untrack the library `pubspec.lock`.
- ⏳ **Still required (A5):** resolve the name/version collision — `planner@0.1.0`
  already exists on pub.dev. Either bump to `> 0.1.0` and publish as an authorized
  uploader, or rename the package. Then optionally clean up A6 (gitignored IDE files).

### P1 — Correctness & architecture (do before relying on it broadly)
- **D1 + D2:** kill the static state and the per-frame `Manager` rebuild — introduce a
  persistent `Manager`/`PlannerController` owned by `State`. These two are coupled.
- **D3 + D4:** make event geometry derive from `blockHeight`; proportional minutes.
- **D5:** move drag logic out of `paint()` into gesture handling.
- **D8 + D9:** unify snapping into one configurable interval; clamp day/hour/zoom.
- **C4:** export `planner_time.dart`. **C1/C2/C3:** remove dead code / fix typo.
- **C6:** add a real test suite (widget + golden), fix the example smoke test.

### P2 — Make it a great *calendar* (direction decided — see below)
- ✅ **Time-model direction resolved (#19):** keep the day-index model; do **not**
  migrate to `DateTime`. See `docs/decisions/0001-time-model-day-index.md`.
- Add the genuine widget-level primitives as additive, non-breaking follow-ups:
  highlight-column ("today" style, #46), event column-span (multi-day, #47),
  all-day band (#48), optional `date ↔ index` consumer helpers (#49).
- **D11** overlap/column layout. Accessibility (`Semantics`), localization of menu strings.

### P3 — Polish & tooling
- **B2** bump `flutter_lints`; **E1/E2** CI + stricter analysis; **D6/D7** repaint &
  allocation optimizations; **B3** resolve the vendored dependency; **C7** example churn.

### The key design fork — time model (✅ DECIDED: keep day-index, #19)

**Decision (2026-06-06):** keep the abstract **day-index** model — `day` stays an
index into `config.labels`. We will **not** migrate to `DateTime`, and **not** take
the optional-`DateTime`-per-column middle path. Full rationale in
`docs/decisions/0001-time-model-day-index.md`.

The reasoning, in short: the widget treats `day` purely as a column index and the
label is already a free-form string, so `DateTime` turned out to be an **ergonomics**
choice, not a **capability** unlock. Week navigation, `intl` formatting, and even
"today" highlighting are all achievable in consumer code (or via tiny index-based
primitives) without putting `DateTime` in the public API. Adding `DateTime` would
only move responsibility into the library at the cost of a breaking change.

The options as originally framed (retained for the record):

**Option 1 — keep the abstract day-index model.** ← **chosen**
- ➕ Minimal change; stays a flexible "N labelled columns of time-slots" widget;
  useful for non-calendar scheduling (rooms, machines, lanes).
- ➖ Never a true calendar out-of-the-box; the consumer maps dates ↔ indices
  themselves (to be eased by optional, non-core helpers).

**Option 2 — migrate to `DateTime`.** ← rejected
- ➕ Batteries-included calendar ergonomics (week-stepping, today, multi-day) without
  the consumer hand-rolling date↔index mapping.
- ➖ Larger breaking API change (`PlannerTime` → `DateTime` + `Duration`), needs a
  migration guide and a major version bump — for convenience, not new capability.

**Middle path — optional `DateTime` per column.** ← rejected
- Keeps the column model but lets each column optionally carry a `DateTime`; judged
  not worth the added surface given the features are consumer-doable.

---

## 5. Verification

```sh
flutter pub get                                   # succeeds after removing after_layout
flutter analyze                                   # should be clean
dart format --output=none --set-exit-if-changed . # formatting gate
flutter test                                      # once real tests exist
flutter pub publish --dry-run                     # confirms blockers cleared
dart pub global run pana                          # pub.dev score delta
```
