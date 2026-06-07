import 'package:flutter/material.dart';

import 'examples/all_day_example.dart';
import 'examples/basic_example.dart';
import 'examples/custom_headers_example.dart';
import 'examples/host_zoom_example.dart';
import 'examples/showcase_example.dart';
import 'examples/typed_data_example.dart';
import 'examples/week_calendar_example.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planner Examples',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const GalleryHome(),
    );
  }
}

/// One row in the gallery: a title, a one-line description, and the page it
/// opens. The [id] is also the suffix of the row's `ValueKey`, so finders can
/// target a specific example.
class _Example {
  const _Example({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final String id;
  final String title;
  final String subtitle;
  final Widget page;
}

/// The gallery home: a list of focused example pages, ordered basic → complex,
/// each demonstrating one feature of the planner on its own. Tapping a row
/// pushes that page; the final showcase combines every customization hook.
class GalleryHome extends StatelessWidget {
  const GalleryHome({super.key});

  static const List<_Example> _examples = [
    _Example(
      id: 'basic',
      title: 'Basic',
      subtitle: 'Minimal planner with the default look and onEntry* callbacks.',
      page: BasicExample(),
    ),
    _Example(
      id: 'typed-data',
      title: 'Typed data + entryBuilder',
      subtitle:
          'Carry a typed payload (#77) and draw a custom event card (#78).',
      page: TypedDataExample(),
    ),
    _Example(
      id: 'custom-headers',
      title: 'Custom headers',
      subtitle: 'A CalendarWindow + dayHeaderBuilder with a "today" highlight.',
      page: CustomHeadersExample(),
    ),
    _Example(
      id: 'all-day',
      title: 'All-day band',
      subtitle: 'Enable the all-day band and draw custom chips (#48 / #80).',
      page: AllDayExample(),
    ),
    _Example(
      id: 'host-zoom',
      title: 'Host zoom toolbar',
      subtitle:
          'Drive zoom from your own chrome via a PlannerController (#76).',
      page: HostZoomExample(),
    ),
    _Example(
      id: 'week-calendar',
      title: 'Week calendar',
      subtitle: 'A real week with prev/next navigation built on calendar.dart.',
      page: WeekCalendarExample(),
    ),
    _Example(
      id: 'showcase',
      title: 'Showcase',
      subtitle: 'Every customization hook wired together on one screen (#81).',
      page: ShowcaseExample(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planner Examples')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'A gallery of focused examples, basic to advanced. Each page shows '
              'one feature of the planner on its own; the final Showcase combines '
              'them all.',
            ),
          ),
          const Divider(height: 1),
          for (final example in _examples) ...[
            ListTile(
              key: ValueKey('gallery-tile-${example.id}'),
              title: Text(example.title),
              subtitle: Text(example.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => example.page),
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
