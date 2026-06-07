import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../data.dart';

/// Host-driven zoom (#76): the planner's own zoom is replaced by the app's
/// chrome.
///
/// A [PlannerController] is constructed by the host, handed to the
/// `Planner(controller: ...)`, and driven from the app-bar toolbar's +/−
/// buttons. Pairing it with [PlannerConfig.showZoomControls] `= false` hides the
/// built-in on-canvas buttons, so the toolbar is the only zoom UI (pinch and
/// Ctrl+wheel still work). The controller is a [ChangeNotifier], so the toolbar
/// rebuilds to disable a button once zoom reaches a bound — guard reads on
/// [PlannerController.isAttached], since the getters throw before the planner
/// attaches.
class HostZoomExample extends StatefulWidget {
  const HostZoomExample({super.key});

  @override
  State<HostZoomExample> createState() => _HostZoomExampleState();
}

class _HostZoomExampleState extends State<HostZoomExample> {
  final PlannerController _controller = PlannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host zoom toolbar'),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final atMin = _controller.isAttached &&
                  _controller.zoom <= _controller.minZoom;
              final atMax = _controller.isAttached &&
                  _controller.zoom >= _controller.maxZoom;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.zoom_out),
                    onPressed: atMin ? null : _controller.zoomOut,
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    icon: const Icon(Icons.zoom_in),
                    onPressed: atMax ? null : _controller.zoomIn,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Planner(
        controller: _controller,
        config: PlannerConfig(
          labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          minHour: 7,
          maxHour: 19,
          // Hand zoom entirely to the host toolbar above.
          showZoomControls: false,
        ),
        entries: basicEntries(),
      ),
    );
  }
}
