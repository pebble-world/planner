import 'package:flutter/material.dart';

import 'planner_entry.dart';
import 'planner_time.dart';

/// How a column-spanning event (one whose [PlannerTime.endDay] covers several
/// columns, #47) coexists with the per-column overlap layout that splits
/// concurrent single-column events into side-by-side sub-columns (#20 / D11).
enum SpanOverlap {
  /// The spanning event draws as one continuous rectangle across the full width
  /// of every column it covers, and is **excluded** from the sub-column packing.
  /// Concurrent single-column events keep their own side-by-side split and may
  /// visually overlap the span. The default — simplest and the usual look for a
  /// multi-day banner-style event.
  fullWidth,

  /// The spanning event takes part in each covered column's overlap cluster,
  /// reserving a sub-column beside the concurrent single-column events there.
  /// Because the sub-column it gets can differ per column, the span is drawn as
  /// one rectangle per column rather than a single continuous box.
  split,
}

class PlannerConfig {
  List<String> labels;

  int minHour;
  int maxHour;

  /// Formats the integer hour shown in the left-hand hour column. Receives the
  /// hour-of-day (`minHour`..`maxHour`) and returns the label text. When `null`
  /// the hour is rendered as the bare integer (e.g. `9`, `17`).
  ///
  /// Use it for zero-padding, AM/PM, or `intl` formatting, e.g.
  /// `hourLabelFormatter: (h) => h.toString().padLeft(2, '0')` → `09`, `17`.
  String Function(int hour)? hourLabelFormatter;

  int blockWidth;
  int blockHeight;

  /// Granularity, in minutes, that event times snap to — for **both** creating
  /// an event by tapping an empty cell and dragging/resizing an existing one,
  /// so the two behave identically (the old code used different ad-hoc,
  /// zoom-dependent thresholds for each).
  ///
  /// Use a value that divides 60 evenly (e.g. `5`, `10`, `15`, `30`, `60`) so
  /// snaps land on clean sub-hour boundaries. A value `<= 1` disables snapping
  /// (minute precision). Snapping truncates rather than rounds, so a within-hour
  /// offset never spills into the next hour.
  int snapMinutes;

  /// Optional zoom-aware override of [snapMinutes]. When non-null it is called
  /// with the current zoom factor and its result is used as the snap interval
  /// for that frame, letting events snap more finely as the user zooms in, e.g.
  /// `snapMinutesForZoom: (z) => z >= 3 ? 5 : z >= 2 ? 15 : 30`. When null (the
  /// default) the flat [snapMinutes] applies at every zoom level.
  int Function(double zoom)? snapMinutesForZoom;

  /// Lower/upper bounds applied to the pinch/zoom factor in
  /// [Controller.updateZoom]. Without these the zoom could shrink toward 0
  /// (blocks collapse, hit-testing explodes) or grow without limit.
  double minZoom;
  double maxZoom;

  double dateRowHeight;
  double hourColumnWidth;

  /// Whether the all-day band (#48) is shown at all. Opt-in: defaults to
  /// `false`, so by default no band is rendered and [PlannerTime.allDay] entries
  /// don't appear anywhere (they have no hour position, so they're simply not
  /// drawn). Set it to `true` to enable the band — it then appears above the
  /// time grid whenever there is at least one all-day event, and the chips
  /// become interactive and accessible (#72). With the band disabled,
  /// [allDayBandLaneHeight] / [allDayBandBackground] have no effect.
  bool showAllDayBand;

  /// Height, in logical pixels, of one stacked lane in the all-day band (#48).
  /// All-day events ([PlannerTime.allDay]) render as chips above the time grid;
  /// concurrent ones (sharing a column) stack into separate lanes, and the band
  /// auto-sizes to the number of lanes used. The band is omitted entirely (zero
  /// height) when [showAllDayBand] is `false` or there are no all-day events, so
  /// this has no effect then.
  double allDayBandLaneHeight;

  /// Background fill of the all-day band (#48). Defaults to a dark grey close to
  /// the [plannerBackground] so the band reads as the top of the column area;
  /// override it to match a light theme or to set it off from the grid. Ignored
  /// when [showAllDayBand] is `false` or there are no all-day events (the band
  /// isn't shown).
  Color allDayBandBackground;

  TextStyle hourLabelStyle;
  TextStyle dateLabelStyle;
  TextStyle contextMenuTextStyle;
  TextStyle contextMenuDeleteTextStyle;

  /// Label for the "create event" item shown when the context menu is opened on
  /// an empty grid cell. Override to translate or customize it; defaults to the
  /// English `'Create Event'`.
  String contextMenuCreateLabel;

  /// Label for the "edit event" item shown when the context menu is opened on an
  /// existing event. Override to translate or customize it; defaults to the
  /// English `'Edit Event'`.
  String contextMenuEditLabel;

  /// Label for the "delete event" item shown when the context menu is opened on
  /// an existing event. Override to translate or customize it; defaults to the
  /// English `'Delete Event'`.
  String contextMenuDeleteLabel;

  /// Index into [labels] of a column to emphasize — e.g. a "today" highlight —
  /// or `null` (the default) to highlight nothing. The widget stays
  /// date-agnostic: a consumer building a calendar maps `DateTime.now()` to a
  /// column index itself and passes it here (see ADR 0001 / #46), so no
  /// `DateTime` enters the public API. An out-of-range index highlights nothing.
  int? highlightedColumn;

  /// How column-spanning events (those whose [PlannerTime.endDay] covers several
  /// columns, #47) coexist with the per-column overlap split (#20). Defaults to
  /// [SpanOverlap.fullWidth] — the span draws as one continuous box across its
  /// columns; switch to [SpanOverlap.split] to fold it into each column's
  /// sub-column layout instead. Has no effect on single-column events.
  SpanOverlap spanOverlap;

  /// Fill colour painted across the [highlightedColumn], behind the grid lines
  /// and events. Defaults to a subtle translucent white wash so setting
  /// [highlightedColumn] alone is visible on the default dark [plannerBackground];
  /// override it for a different emphasis (e.g. a brand "today" tint, or a darker
  /// wash on a light background). Ignored when [highlightedColumn] is `null`.
  Color highlightColumnColor;

  Color hourBackground;
  Color dateBackground;
  Color plannerBackground = const Color.fromARGB(255, 50, 50, 50);
  Color horizontalLineColor = const Color.fromARGB(255, 100, 100, 100);
  Color verticalLineColor = const Color.fromARGB(255, 150, 150, 150);
  Color contextMenuBackground;

  /// Whether the on-canvas zoom +/- buttons are shown. Hosts that drive zoom by
  /// pinch (or their own chrome) can hide the built-in buttons by setting this
  /// to `false`. Defaults to `true`.
  bool showZoomControls;

  /// Fill colour of the zoom +/- buttons. When `null` (the default) the buttons
  /// fall back to the ambient `Theme.of(context).colorScheme.secondary`, the
  /// previous hardcoded behaviour; set a colour to override it.
  Color? zoomButtonColor;

  /// Colour of the +/- icons inside the zoom buttons. Defaults to white.
  Color zoomButtonIconColor;

  /// Base distance, in logical pixels, that one mouse-wheel notch scrolls the
  /// time axis at zoom 1. The effective step is scaled by the current zoom
  /// ([Controller.verticalScroll]) so a single notch always moves the same
  /// amount of *time* regardless of zoom (the old code used a fixed 20px step
  /// that moved less time the further you zoomed in). Defaults to `20`.
  double scrollStep;

  Function(PlannerTime time)? onEntryCreate;
  Function(PlannerEntry)? onEntryEdit;
  Function(PlannerEntry)? onEntryDelete;
  Function(PlannerEntry)? onEntryMove;

  /// Fired when the user long-presses an event, with the pressed [PlannerEntry].
  /// This is the primary way to act on an event by **touch**: touch has no
  /// right-click, and a one-finger drag now pans, so long-press is the freed-up
  /// gesture (#66). It also fires on a desktop long-press.
  ///
  /// The widget stays presentation-only and takes no action of its own — it
  /// neither selects nor highlights the event nor shows a menu. The host decides
  /// the response (open its own action sheet / selection UI, delete, start a move
  /// flow, …), so this single hook is more flexible than a baked-in touch UI.
  ///
  /// When `null` (the default) a long-press is a no-op. A long-press on empty
  /// space is always a no-op — create stays on double-tap / right-click.
  Function(PlannerEntry)? onEntryLongPress;

  PlannerConfig({
    required this.labels,
    this.minHour = 0,
    this.maxHour = 23,
    this.hourLabelFormatter,
    this.blockWidth = 200,
    this.blockHeight = 40,
    this.snapMinutes = 15,
    this.snapMinutesForZoom,
    this.minZoom = 0.5,
    this.maxZoom = 4.0,
    this.hourLabelStyle = const TextStyle(color: Colors.black),
    this.dateLabelStyle = const TextStyle(color: Colors.black),
    this.contextMenuTextStyle = const TextStyle(color: Colors.blue),
    this.contextMenuDeleteTextStyle = const TextStyle(color: Colors.red),
    this.contextMenuCreateLabel = 'Create Event',
    this.contextMenuEditLabel = 'Edit Event',
    this.contextMenuDeleteLabel = 'Delete Event',
    this.spanOverlap = SpanOverlap.fullWidth,
    this.highlightedColumn,
    this.highlightColumnColor = const Color.fromARGB(40, 255, 255, 255),
    this.hourBackground = Colors.white,
    this.dateBackground = Colors.white,
    this.contextMenuBackground = Colors.white,
    this.showZoomControls = true,
    this.zoomButtonColor,
    this.zoomButtonIconColor = Colors.white,
    this.scrollStep = 20,
    this.showAllDayBand = false,
    this.allDayBandLaneHeight = 24,
    this.allDayBandBackground = const Color.fromARGB(255, 60, 60, 60),
    this.plannerBackground = const Color.fromARGB(255, 50, 50, 50),
    this.horizontalLineColor = const Color.fromARGB(255, 100, 100, 100),
    this.verticalLineColor = const Color.fromARGB(255, 150, 150, 150),
    this.onEntryCreate,
    this.onEntryDelete,
    this.onEntryEdit,
    this.onEntryMove,
    this.onEntryLongPress,
    this.dateRowHeight = 50,
    this.hourColumnWidth = 50,
  });
}
