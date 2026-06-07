# Driving zoom from a host toolbar

By default zoom lives entirely inside the widget (pinch, `Ctrl`+wheel, the
built-in +/- buttons). To drive it from your own chrome — a toolbar, a slider,
keyboard shortcuts — construct a `PlannerController`, hand it to the `Planner`,
and (usually) hide the on-canvas buttons with `showZoomControls: false`:

```dart
class ZoomablePlanner extends StatefulWidget {
  const ZoomablePlanner({super.key});
  @override
  State<ZoomablePlanner> createState() => _ZoomablePlannerState();
}

class _ZoomablePlannerState extends State<ZoomablePlanner> {
  final _zoom = PlannerController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // A host toolbar that listens to the controller so it can disable
        // a button once the zoom hits a bound.
        AnimatedBuilder(
          animation: _zoom,
          builder: (context, _) => Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: !_zoom.isAttached || _zoom.zoom <= _zoom.minZoom
                    ? null
                    : _zoom.zoomOut,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: !_zoom.isAttached || _zoom.zoom >= _zoom.maxZoom
                    ? null
                    : _zoom.zoomIn,
              ),
            ],
          ),
        ),
        Expanded(
          child: Planner(
            controller: _zoom,
            config: PlannerConfig(
              labels: const ['Mon', 'Tue', 'Wed'],
              showZoomControls: false, // the host owns the controls now
            ),
            entries: const [],
          ),
        ),
      ],
    );
  }
}
```

A runnable version is the
[Host zoom example](../example/lib/examples/host_zoom_example.dart).

## `PlannerController` API

`PlannerController` is a `ChangeNotifier` and deals only with zoom (plus scroll
read-back):

| Member | Purpose |
|--------|---------|
| `zoomIn([factor = 1.1])` / `zoomOut([factor = 0.9])` | Multiply the current zoom; clamped to `minZoom`/`maxZoom`. |
| `zoomTo(target)` | Set an absolute zoom; clamped to `minZoom`/`maxZoom`. |
| `zoom`, `minZoom`, `maxZoom` | Read the current zoom and its bounds. |
| `dayScroll`, `timeScroll` | Read the current day-axis / time-axis scroll offset. |
| `isAttached` | Whether it's bound to a mounted `Planner`. |

It attaches to the planner's internal zoom/scroll state — the single source of
truth — so the controller, pinch, `Ctrl`+wheel and the built-in buttons all move
the *same* zoom; there's no duplicated state to keep in sync. The read getters
throw while not `isAttached` (before the `Planner` mounts or after it's gone), so
read them in response to a notification or guard with `isAttached`; the zoom
methods are no-ops then. Dispose the controller like any other `ChangeNotifier`.

---

**More docs:** [Core concepts](core-concepts.md) · [Builders](builders.md) · [Calendar](calendar.md) · [Controller](controller.md) · [Interactions](interactions.md) · [README](../README.md)
