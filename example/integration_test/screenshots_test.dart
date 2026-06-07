import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:example/examples/all_day_example.dart';
import 'package:example/examples/basic_example.dart';
import 'package:example/examples/custom_headers_example.dart';
import 'package:example/examples/host_zoom_example.dart';
import 'package:example/examples/showcase_example.dart';
import 'package:example/examples/typed_data_example.dart';
import 'package:example/examples/week_calendar_example.dart';

/// Documentation screenshot capture target (#93).
///
/// Deliberately **not** registered in [app_test.dart]: the rest of the suite
/// runs in one `app.main()` launch (desktop allows only one app per `flutter
/// test`), but this target pumps its own widget tree per shot, so that rule
/// doesn't apply. It writes PNGs to disk via `dart:io`, so run it on its own and
/// on a real device (Windows) for real fonts/icons:
///
/// ```sh
/// # from example/
/// flutter test integration_test/screenshots_test.dart -d windows
/// ```
///
/// Each shot renders a gallery page on a fixed surface inside a keyed
/// [RepaintBoundary] and reads the boundary back as a PNG, so the dimensions are
/// reproducible regardless of the host window and the image bakes in the real
/// Windows fonts (a test font like Ahem would distort sizing and trip false
/// overflows). Filenames match the gallery `id`s — what `README.md` references.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture documentation screenshots', (tester) async {
    // Five-label (Mon–Fri) pages.
    await screenshotWidget(tester, 'basic', _app(const BasicExample()),
        size: _surfaceFor(5));
    await screenshotWidget(tester, 'typed-data', _app(const TypedDataExample()),
        size: _surfaceFor(5));
    await screenshotWidget(tester, 'all-day', _app(const AllDayExample()),
        size: _surfaceFor(5));
    await screenshotWidget(tester, 'host-zoom', _app(const HostZoomExample()),
        size: _surfaceFor(5));

    // Seven-column `CalendarWindow` (Mon–Sun) pages.
    await screenshotWidget(
        tester, 'custom-headers', _app(const CustomHeadersExample()),
        size: _surfaceFor(7));
    await screenshotWidget(
        tester, 'week-calendar', _app(const WeekCalendarExample()),
        size: _surfaceFor(7));
    await screenshotWidget(tester, 'showcase', _app(const ShowcaseExample()),
        size: _surfaceFor(7));
  });
}

/// Wraps a gallery [page] in the same `MaterialApp`/theme `main.dart` uses, so a
/// shot matches what a user sees opening that page from the example app. The
/// pages are bare `Scaffold`s pushed onto the gallery's navigator, so they need
/// a `MaterialApp` ancestor for theme + directionality.
Widget _app(Widget page) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: page,
    );

/// The logical surface that frames a [columns]-column grid exactly — no column
/// clipped off the right and no empty band beside it.
///
/// The planner lays each column out at a fixed [PlannerConfig.blockWidth]
/// (default 200) after a fixed [PlannerConfig.hourColumnWidth] gutter (default
/// 50); columns don't stretch to fill, so the grid's natural width is the only
/// width that frames it cleanly. Height follows a single 16:10 aspect ratio
/// across page sizes so the README's thumbnail row stays uniform. The example
/// pages all use the default block/gutter widths; adjust here if one overrides
/// them.
Size _surfaceFor(int columns) {
  const blockWidth = 200.0;
  const hourColumnWidth = 50.0;
  final width = hourColumnWidth + blockWidth * columns;
  return Size(width, (width / (16 / 10)).roundToDouble());
}

/// Capture scale — the PNG is the surface size × [_pixelRatio] pixels. 2× gives a
/// crisp image for the docs; the mostly flat-colour UI still compresses small.
const double _pixelRatio = 2.0;

/// Captures [widget] as a deterministic PNG at `../docs/screenshots/<name>.png`
/// (paths are relative to `example/`, the directory the suite runs from).
///
/// Pins the surface to [size] at [_pixelRatio] (reset after the test via
/// `addTearDown`) so the output size never depends on the host window, pumps
/// [widget] inside a keyed [RepaintBoundary], settles, then reads the boundary's
/// layer back with [RenderRepaintBoundary.toImage] and writes the PNG with
/// `dart:io`.
///
/// Lives here rather than in `planner_harness.dart` (where issue #93 first placed
/// it) because the `dart:io` import would break the web `flutter drive` path,
/// which compiles `app_test.dart` and, through it, `planner_harness.dart`.
Future<void> screenshotWidget(
  WidgetTester tester,
  String name,
  Widget widget, {
  required Size size,
}) async {
  tester.view.physicalSize = size * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final boundaryKey = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: widget));
  await tester.pumpAndSettle();

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  final image = await boundary.toImage(pixelRatio: _pixelRatio);
  try {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}
