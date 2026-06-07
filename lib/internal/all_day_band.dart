import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'all_day_event.dart';
import 'manager.dart';

/// Paints the all-day band (#48): the row of chips above the time grid for
/// events flagged [PlannerTime.allDay]. The host `Planner` only mounts this
/// painter when there is at least one all-day event (the band auto-sizes to its
/// lanes and is omitted at zero height otherwise), so [paint] always has chips.
///
/// The band's background is supplied by the wrapping `Container`, so this only
/// draws the [AllDayEvent] chips. Like [DateRow] it repaints on the controller's
/// update listenable (so a day-axis pan re-lays the chips) and otherwise only
/// when the event data revision changes.
// Generic over the entry payload [T] (#77), for the same reason as
// [EventsPainter]: its semanticsBuilder reads the now-generic entry callbacks
// (`config.onEntryEdit`/`onEntryDelete`, typed `void Function(PlannerEntry<T>)`),
// which would trip a runtime covariance check if read through a covariant
// `Manager<dynamic>`. So it carries `T` and holds a `Manager<T>`.
class AllDayBand<T> extends CustomPainter {
  final Manager<T> manager;

  // The manager's data revision when this delegate was built; compared in
  // shouldRepaint so the band repaints only when the data changed, not on every
  // unrelated parent rebuild (#25 / D6). Pan/zoom repaints come via `repaint`.
  final int _revision;

  // Whether to paint the chip bodies on the canvas (#80). When a host supplies
  // an `allDayEntryBuilder`, real widgets are layered over the band to render
  // each chip, so the canvas skips its own body paint to avoid drawing each chip
  // twice — but it still exposes the per-chip accessibility semantics (those
  // stay canvas-owned; the overlay is ExcludeSemantics). Mirrors
  // `EventsPainter.drawEventBodies` (#78). Defaults to `true` — the canvas paints
  // the chips itself.
  final bool drawChipBodies;

  AllDayBand({
    required this.manager,
    required Listenable repaint,
    this.drawChipBodies = true,
  })  : _revision = manager.revision,
        super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (!drawChipBodies) return;
    for (final AllDayEvent event in manager.allDayEvents) {
      event.paint(canvas);
    }
  }

  // Expose each all-day chip to assistive technology (#72), bringing the band to
  // parity with the timed-event canvas (#21/#56). Mirrors [EventsPainter]'s
  // semantics: one node per chip carrying its description and the host's actions,
  // mapped onto first-class semantics actions (RenderCustomPaint drops
  // customSemanticsActions) — activate (onTap) -> edit, dismiss (onDismiss) ->
  // delete. There is no increase/decrease: an all-day chip has no time axis to
  // nudge along (drag/resize is out of scope for #72). A node is emitted for
  // every chip regardless of horizontal scroll; its rect is the chip's live
  // on-screen rect, so `_PlannerState` pokes this canvas to rebuild semantics on
  // a day-axis pan (the `repaint` listenable only triggers markNeedsPaint), the
  // same way it does for the event canvas. Stable per-chip keys (the entry id)
  // keep node identity across those rebuilds.
  @override
  SemanticsBuilderCallback get semanticsBuilder => _buildSemantics;

  List<CustomPainterSemantics> _buildSemantics(Size size) {
    final config = manager.config;
    final canEdit = config.onEntryEdit != null;
    final canDelete = config.onEntryDelete != null;

    return [
      for (final AllDayEvent<T> chip in manager.allDayEvents)
        CustomPainterSemantics(
          key: ValueKey(chip.entry.id),
          rect: chip.screenRect,
          properties: SemanticsProperties(
            label: chip.semanticsLabel,
            textDirection: TextDirection.ltr,
            button: canEdit,
            enabled: true,
            onTap: canEdit ? () => manager.editAllDayEvent(chip) : null,
            onDismiss: canDelete ? () => manager.deleteAllDayEvent(chip) : null,
          ),
        ),
    ];
  }

  @override
  bool shouldRepaint(covariant AllDayBand oldDelegate) =>
      _revision != oldDelegate._revision ||
      drawChipBodies != oldDelegate.drawChipBodies;
}
