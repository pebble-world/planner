import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/planner.dart';

void main() {
  // D12 (#28): the zoom +/- buttons' visibility and colours were hardcoded.
  // They're now driven by PlannerConfig.

  Widget app(PlannerConfig config, {ThemeData? theme}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Planner(config: config, entries: const []),
        ),
      );

  PlannerConfig config({
    bool showZoomControls = true,
    Color? zoomButtonColor,
    Color zoomButtonIconColor = Colors.white,
  }) =>
      PlannerConfig(
        labels: const ['c1', 'c2', 'c3'],
        showZoomControls: showZoomControls,
        zoomButtonColor: zoomButtonColor,
        zoomButtonIconColor: zoomButtonIconColor,
      );

  test('PlannerConfig has sensible zoom-control / scroll defaults', () {
    final c = PlannerConfig(labels: const ['A']);
    expect(c.showZoomControls, isTrue);
    expect(c.zoomButtonColor, isNull);
    expect(c.zoomButtonIconColor, Colors.white);
    expect(c.scrollStep, 20);
  });

  testWidgets('zoom +/- buttons are shown by default', (tester) async {
    await tester.pumpWidget(app(config()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.zoom_in), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out), findsOneWidget);
  });

  testWidgets('showZoomControls: false hides the zoom buttons', (tester) async {
    await tester.pumpWidget(app(config(showZoomControls: false)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.zoom_in), findsNothing);
    expect(find.byIcon(Icons.zoom_out), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('zoomButtonColor / zoomButtonIconColor override the styling',
      (tester) async {
    const fill = Color(0xFF123456);
    const iconColor = Color(0xFFABCDEF);
    await tester.pumpWidget(
        app(config(zoomButtonColor: fill, zoomButtonIconColor: iconColor)));
    await tester.pumpAndSettle();

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, hasLength(2));
    for (final button in buttons) {
      expect(_fillOf(button), fill);
    }
    expect(tester.widget<Icon>(find.byIcon(Icons.zoom_in)).color, iconColor);
    expect(tester.widget<Icon>(find.byIcon(Icons.zoom_out)).color, iconColor);
  });

  testWidgets('zoom buttons fall back to the theme secondary colour when unset',
      (tester) async {
    const secondary = Color(0xFF00AA00);
    final theme = ThemeData(
      colorScheme: const ColorScheme.light().copyWith(secondary: secondary),
    );
    await tester.pumpWidget(app(config(), theme: theme));
    await tester.pumpAndSettle();

    final button = tester.widgetList<IconButton>(find.byType(IconButton)).first;
    expect(_fillOf(button), secondary,
        reason: 'null zoomButtonColor preserves the old theme-driven fill');
  });
}

/// Resolves the background fill an [IconButton] paints. `RawMaterialButton`
/// exposed `fillColor` directly; its replacement carries the fill in
/// `style.backgroundColor`, a [WidgetStateProperty] that must be resolved.
Color? _fillOf(IconButton button) =>
    button.style?.backgroundColor?.resolve(<WidgetState>{});
