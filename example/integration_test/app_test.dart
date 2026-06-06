import 'package:integration_test/integration_test.dart';

import 'app_smoke_scenarios.dart';
import 'drag_scenarios.dart';
import 'event_geometry_scenarios.dart';
import 'hour_label_scenarios.dart';
import 'multi_planner_scenarios.dart';
import 'snapping_scenarios.dart';

/// Single entry point for the integration suite.
///
/// On desktop, `flutter test` launches a fresh app per *test file*, and a second
/// launch within one invocation is unreliable. So every scenario is registered
/// here and runs in one app launch. Add new scenarios as functions (see
/// [app_smoke_scenarios.dart]) and call them below — do not add new
/// `*_test.dart` files to this directory.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  appSmokeScenarios();
  dragScenarios();
  eventGeometryScenarios();
  hourLabelScenarios();
  multiPlannerScenarios();
  snappingScenarios();
}
