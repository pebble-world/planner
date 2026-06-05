// Driver for the web `flutter drive` path. The Windows device path
// (`flutter test integration_test -d windows`, used by CI) does not need this
// file, but it is required to run the same suite against Chrome:
//
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart \
//     -d chrome
//
// See example/integration_test/README.md.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
