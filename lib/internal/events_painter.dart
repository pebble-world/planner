import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'event.dart';
import 'grid.dart';
import 'manager.dart';

class EventsPainter extends CustomPainter {
  final Grid _grid;
  final Manager manager;

  // The manager's data revision when this delegate was built; compared in
  // shouldRepaint so the canvas repaints (and its semantics rebuild) only when
  // the event data changed, not on every unrelated parent rebuild (#25 / D6).
  final int _revision;

  EventsPainter({required this.manager, required Listenable repaint})
      : _grid = Grid(manager: manager),
        _revision = manager.revision,
        super(repaint: repaint);

  // Pure rendering only: draw the grid, then each event using its own drag
  // state. Drag detection and the onEntryMove callback live in the widget layer
  // (gesture handlers -> Manager.start/update/endDrag), never here — a painter
  // must not mutate state or fire callbacks while painting.
  @override
  void paint(Canvas canvas, Size size) {
    _grid.draw(canvas);
    for (Event event in manager.events) {
      event.paint(canvas);
    }
  }

  // Expose each event to assistive technology (#21). A CustomPaint canvas is one
  // opaque semantics node, so screen readers can otherwise neither perceive
  // events nor act on them. For every event currently in view we emit one node
  // carrying its description (title, time, duration) and the host's actions.
  //
  // The actions map onto first-class semantics actions, NOT customSemanticsActions:
  // RenderCustomPaint forwards only the built-in SemanticsProperties callbacks to
  // the node and silently drops customSemanticsActions, so custom actions never
  // reach a screen reader through a painter. The built-ins are also the better
  // fit — they're native AT gestures rather than an actions submenu:
  //   * activate (onTap)            -> edit   (mirrors double-tap-to-edit)
  //   * dismiss  (onDismiss)        -> delete (the standard "remove" gesture)
  //   * increase/decrease           -> move later/earlier (a screen-reader user
  //     (onIncrease/onDecrease)        can't drag, so the event reads as an
  //                                     adjustable nudged in whole hours)
  // Only the actions whose onEntry* callback the host wired are offered. Stable
  // per-event keys (the entry id) keep node identity across the per-frame rebuilds.
  @override
  SemanticsBuilderCallback get semanticsBuilder => _buildSemantics;

  List<CustomPainterSemantics> _buildSemantics(Size size) {
    final config = manager.config;
    final viewport = Offset.zero & size;
    final nodes = <CustomPainterSemantics>[];

    for (final event in manager.events) {
      final rect = event.screenRect;
      // Skip events scrolled out of view: an off-canvas rect is no perceivable
      // target. Semantics rebuild on scroll (shouldRebuildSemantics tracks
      // shouldRepaint), so a scrolled-in event reappears.
      if (!rect.overlaps(viewport)) continue;

      final canEdit = config.onEntryEdit != null;
      final canMove = config.onEntryMove != null;

      nodes.add(CustomPainterSemantics(
        key: ValueKey(event.entry.id),
        rect: rect,
        properties: SemanticsProperties(
          label: event.semanticsLabel,
          textDirection: TextDirection.ltr,
          button: canEdit,
          enabled: true,
          onTap: canEdit ? () => manager.editEvent(event) : null,
          onDismiss: config.onEntryDelete != null
              ? () => manager.deleteEvent(event)
              : null,
          onIncrease: canMove ? () => manager.nudgeEvent(event, 1) : null,
          onDecrease: canMove ? () => manager.nudgeEvent(event, -1) : null,
        ),
      ));
    }

    return nodes;
  }

  @override
  bool shouldRepaint(covariant EventsPainter oldDelegate) =>
      _revision != oldDelegate._revision;
}
