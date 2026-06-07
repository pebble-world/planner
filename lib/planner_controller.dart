import 'package:flutter/foundation.dart';

import 'internal/controller.dart';

/// A public handle a host constructs and hands to a `Planner` to drive and
/// observe its zoom from outside the widget (#76) — for example a custom zoom
/// toolbar that lives in the host's own chrome rather than the planner's
/// on-canvas buttons.
///
/// It is intentionally **not** a general-purpose controller: it only deals with
/// zoom and exposes scroll read-back. Internally it attaches to the planner's
/// private zoom/scroll [Controller], which stays the single source of truth — no
/// state is duplicated here, and clamping to `minZoom`/`maxZoom` stays in the
/// [Controller]. Pass one to `Planner(controller: ...)` and typically set
/// `showZoomControls: false` so the built-in buttons make way for your own.
///
/// As a [ChangeNotifier] it re-emits a notification on every view change (zoom
/// **and** scroll), so a host toolbar can rebuild to, say, disable its `+`
/// button once [zoom] reaches [maxZoom]. Notifications only fire while the
/// controller is attached to a mounted planner; read [zoom]/[minZoom]/[maxZoom]/
/// [dayScroll]/[timeScroll] only while [isAttached] (the read getters throw
/// otherwise, since there is no planner to read from).
///
/// Lifecycle (attach/detach) is handled by `Planner`; a host only constructs the
/// controller, optionally listens to it, calls the zoom methods, and disposes it
/// like any other [ChangeNotifier].
class PlannerController extends ChangeNotifier {
  /// The attached planner's internal zoom/scroll controller, or `null` while
  /// this controller isn't bound to a mounted planner. Set by [attach]/[detach].
  Controller? _inner;

  /// Whether this controller is currently bound to a mounted `Planner`. Zoom
  /// methods are no-ops and the read getters throw while this is `false`, so a
  /// host that reads zoom/scroll outside a listener notification should guard on
  /// it (a freshly constructed controller, or one whose planner has been
  /// unmounted, is not attached).
  bool get isAttached => _inner != null;

  /// The current zoom factor of the attached planner, in `[minZoom, maxZoom]`.
  /// Throws a [StateError] when not [isAttached].
  double get zoom => _requireInner().zoom;

  /// The minimum zoom the attached planner clamps to (its
  /// `PlannerConfig.minZoom`). Throws a [StateError] when not [isAttached].
  double get minZoom => _requireInner().config.minZoom;

  /// The maximum zoom the attached planner clamps to (its
  /// `PlannerConfig.maxZoom`). Throws a [StateError] when not [isAttached].
  double get maxZoom => _requireInner().config.maxZoom;

  /// The day-axis (horizontal) scroll offset of the attached planner, in logical
  /// pixels (`<= 0`; `0` is the leftmost column). Read-only — this controller
  /// drives zoom, not scroll. Throws a [StateError] when not [isAttached].
  double get dayScroll => _requireInner().x;

  /// The time-axis (vertical) scroll offset of the attached planner, in logical
  /// pixels (`<= 0`; `0` is the top of the grid). Read-only. Throws a
  /// [StateError] when not [isAttached].
  double get timeScroll => _requireInner().y;

  /// Zooms in by [factor] (default `1.1`), multiplying the current zoom and
  /// clamping to [maxZoom] in the [Controller]. A no-op when not [isAttached].
  void zoomIn([double factor = 1.1]) => _multiplyZoom(factor);

  /// Zooms out by [factor] (default `0.9`), multiplying the current zoom and
  /// clamping to [minZoom] in the [Controller]. A no-op when not [isAttached].
  void zoomOut([double factor = 0.9]) => _multiplyZoom(factor);

  /// Sets the zoom to an absolute [target], clamped to `[minZoom, maxZoom]` by
  /// the [Controller]. A no-op when not [isAttached].
  ///
  /// The [Controller] only zooms multiplicatively (relative to the zoom captured
  /// by `startZoom`), so this asks it to scale from the current zoom to [target];
  /// the clamp still applies. A current zoom of `0` (only reachable with a
  /// `minZoom <= 0`) has no defined scale to [target], so it is left untouched.
  void zoomTo(double target) {
    final inner = _inner;
    if (inner == null) return;
    final current = inner.zoom;
    if (current <= 0) return;
    inner.startZoom();
    inner.updateZoom(target / current);
  }

  void _multiplyZoom(double factor) {
    final inner = _inner;
    if (inner == null) return;
    inner.startZoom();
    inner.updateZoom(factor);
  }

  Controller _requireInner() {
    final inner = _inner;
    if (inner == null) {
      throw StateError(
        'PlannerController is not attached to a Planner. Read zoom/scroll only '
        'while attached — guard with `isAttached`, or read inside a listener '
        'notification (which only fires while attached).',
      );
    }
    return inner;
  }

  /// Binds this controller to a planner's internal zoom/scroll [Controller].
  /// Called by `Planner` from its `initState`/`didUpdateWidget` — **not** part of
  /// the consumer API. Re-binding to the same [inner] is a no-op; binding to a
  /// different one detaches the previous first, so the listener is never doubled.
  void attach(Controller inner) {
    if (identical(_inner, inner)) return;
    _inner?.triggerUpdate.removeListener(notifyListeners);
    _inner = inner;
    inner.triggerUpdate.addListener(notifyListeners);
  }

  /// Unbinds from the current planner, removing the re-emit listener so nothing
  /// leaks past the planner's lifetime. Called by `Planner` from its `dispose`
  /// and on a controller swap — **not** part of the consumer API. Safe to call
  /// when already detached.
  void detach() {
    _inner?.triggerUpdate.removeListener(notifyListeners);
    _inner = null;
  }

  /// Detaches before disposing so a still-attached controller can't fire
  /// [notifyListeners] after disposal (its planner normally detaches it first,
  /// but disposal order isn't guaranteed).
  @override
  void dispose() {
    detach();
    super.dispose();
  }
}
