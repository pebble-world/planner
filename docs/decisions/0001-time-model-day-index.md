# ADR 0001 — Keep the day-index time model (no `DateTime` migration)

- **Status:** Accepted
- **Date:** 2026-06-06
- **Issue:** [#19](https://github.com/pebble-world/planner/issues/19)
- **Supersedes / relates to:** PROJECT_OVERVIEW.md §4 "the key design fork"

## Context

`PlannerTime` is `{ int day, int hour, int minutes, int duration }`, where `day` is
an **index into `config.labels`** — there are no real calendar dates anywhere. Issue
#19 framed three options:

1. **Keep the day-index model** — minimal change; stays a generic "N labelled columns
   of time-slots" widget (rooms, machines, lanes).
2. **Migrate to `DateTime` + `Duration`** — real calendar features; a breaking API
   change needing a migration guide and major version bump.
3. **Middle path** — keep columns, let each column *optionally* carry a `DateTime`.

The PROJECT_OVERVIEW listed week navigation, "today" highlighting, multi-day/all-day
events, time zones/DST, and `intl` formatting as features "blocked" by the index
model. We re-examined that claim against the actual code before deciding.

### What the code actually does with `day`

Across the widget, `day` is used **only** as an opaque column index:

- `lib/internal/event.dart` — `entry.time.day * blockWidth` → horizontal pixel
  position; drag-move snaps `day` to the nearest column.
- `lib/internal/manager.dart` — a tap position maps to a `day` clamped into
  `0..config.labels.length - 1`.
- `lib/internal/date_row.dart` — the header simply renders each `config.labels`
  string.
- `lib/internal/grid.dart` — the column count is `config.labels.length`.

The column header label is already a **free-form string**. The widget never reasons
about dates.

### Re-evaluating the "blocked" features

`DateTime` turns out to be an **ergonomics** decision, not a **capability** unlock.
Almost everything listed as blocked is already doable in consumer code on top of the
index model:

| Claimed "blocked" feature | Actually needs `DateTime` in the widget? |
|---|---|
| Week navigation | **No.** The consumer holds the current week, recomputes 7 labels + entries, and rebuilds. The widget never knows. |
| `intl` / date formatting | **No.** Pure label string — the consumer formats `DateTime` → `"Mon 8 Jun"` and passes it as a label. |
| "Today" highlight | **Almost no.** The widget only needs a *"highlight column index N"* flag, not a `DateTime`. |
| Multi-day / all-day events | **Partly.** Needs an event to *span* columns (start-col → end-col) plus an all-day band — both expressible as indices. |
| Time zones / DST | **The only genuine `DateTime` concern** — but it only bites if the *widget* computes durations across a DST boundary. For a wall-clock grid it does not; the consumer owns that math when building entries. |

Putting `DateTime` into the public API would **move responsibility into the library**;
it would not unlock anything the consumer cannot already do. The only things the
widget itself genuinely lacks are small, index-based primitives.

## Decision

**Keep the day-index time model.** `planner` remains a generic
"N labelled columns × hours" scheduling grid. Date semantics stay the consumer's
responsibility.

We will **not** migrate `PlannerTime` to `DateTime` and will **not** adopt the
middle-path optional-`DateTime`-per-column approach. Instead, we will add the few
primitives that are genuinely widget-level (and not consumer-doable) as separate,
non-breaking follow-up issues:

- **Highlight a column** ([#46](https://github.com/pebble-world/planner/issues/46))
  — a configurable "emphasize column index N" (enables a "today" style without the
  widget knowing dates).
- **Event column-span** ([#47](https://github.com/pebble-world/planner/issues/47))
  — let an entry render across a start→end column range (enables multi-day
  rendering).
- **All-day band** ([#48](https://github.com/pebble-world/planner/issues/48)) — a
  row above the time grid for all-day / full-column entries.
- **Optional consumer-side date helpers**
  ([#49](https://github.com/pebble-world/planner/issues/49)) — a small
  `date ↔ index` utility / week-builder (non-core) so the common calendar case is
  easy without changing the core model.

These are tracked as follow-up issues spun out of #19.

## Consequences

**Positive**

- No breaking API change; no forced major version bump or migration guide.
- The package stays honest about what it is — useful for non-calendar scheduling
  (rooms, lanes, machines) as well as calendars.
- Implementation effort moves from a large risky migration to small, focused,
  additive features.

**Negative / trade-offs**

- Consumers building an ordinary week-calendar must own `date ↔ index` mapping, week
  stepping, and "today" detection themselves (mitigated by the optional helpers
  above).
- DST / time-zone correctness for durations remains the consumer's responsibility.
- We forgo the "batteries-included calendar" positioning on pub.dev; the package
  competes as a flexible grid primitive instead.

## Notes

This ADR is an internal decision record and is excluded from the published pub.dev
archive (see `.pubignore`), mirroring how `PROJECT_OVERVIEW.md` is handled.
