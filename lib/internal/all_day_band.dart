import 'package:flutter/material.dart';

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
class AllDayBand extends CustomPainter {
  final Manager manager;

  // The manager's data revision when this delegate was built; compared in
  // shouldRepaint so the band repaints only when the data changed, not on every
  // unrelated parent rebuild (#25 / D6). Pan/zoom repaints come via `repaint`.
  final int _revision;

  AllDayBand({required this.manager, required Listenable repaint})
      : _revision = manager.revision,
        super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (final AllDayEvent event in manager.allDayEvents) {
      event.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(covariant AllDayBand oldDelegate) =>
      _revision != oldDelegate._revision;
}
