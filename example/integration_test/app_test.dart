import 'package:integration_test/integration_test.dart';

import 'accessibility_scenarios.dart';
import 'app_smoke_scenarios.dart';
import 'context_menu_labels_scenarios.dart';
import 'context_menu_scenarios.dart';
import 'direct_manipulation_scenarios.dart';
import 'double_tap_scenarios.dart';
import 'drag_scenarios.dart';
import 'event_geometry_scenarios.dart';
import 'highlight_column_scenarios.dart';
import 'hour_label_scenarios.dart';
import 'multi_planner_scenarios.dart';
import 'overlap_scenarios.dart';
import 'snapping_scenarios.dart';
import 'span_scenarios.dart';
import 'zoom_scenarios.dart';

/// Single entry point for the integration suite.
///
/// On desktop, `flutter test` launches a fresh app per *test file*, and a second
/// launch within one invocation is unreliable. So every scenario is registered
/// here and runs in one app launch. Add new scenarios as functions (see
/// [app_smoke_scenarios.dart]) and call them below — do not add new
/// `*_test.dart` files to this directory.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  accessibilityScenarios();
  appSmokeScenarios();
  contextMenuLabelsScenarios();
  contextMenuScenarios();
  directManipulationScenarios();
  doubleTapScenarios();
  dragScenarios();
  eventGeometryScenarios();
  highlightColumnScenarios();
  hourLabelScenarios();
  multiPlannerScenarios();
  overlapScenarios();
  snappingScenarios();
  spanScenarios();
  zoomScenarios();
}
