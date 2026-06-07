import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../data.dart';

/// A fully custom timed-event widget for an [Planner.entryBuilder] (#78): a dark
/// card with a type-coloured left bar and a hard-offset shadow that **sheds
/// detail by pixel height**.
///
/// [PlannerEntryLayout.size]`.height` is the event's live on-screen height, so
/// as the grid zooms the same event reveals more: place ≥52, status ≥56, time
/// ≥60, the attendee avatar stack ≥92. It reads the typed [PlannerEntry.data]
/// ([ActivityMeta], #77) for its accent colour and metadata — no cast, no
/// side-map keyed by id.
///
/// Shared across the typed-data and showcase example pages.
class PopBlock extends StatelessWidget {
  const PopBlock({super.key, required this.entry, required this.layout});

  final PlannerEntry<ActivityMeta> entry;
  final PlannerEntryLayout layout;

  @override
  Widget build(BuildContext context) {
    final meta = entry.data;
    final h = layout.size.height;
    final accent = meta?.type.color ?? entry.color;

    final showPlace = h >= 52 && (meta?.place.isNotEmpty ?? false);
    final showStatus = h >= 56 && (meta?.status.isNotEmpty ?? false);
    final showTime = h >= 60;
    final showAvatars = h >= 92 && (meta?.attendees.isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2430),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), offset: Offset(3, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The type-coloured left bar.
              Container(width: 4, color: accent),
              Expanded(
                child: ClipRect(
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (showStatus)
                                _StatusBadge(text: meta!.status, color: accent),
                            ],
                          ),
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 11, color: Colors.white60),
                                  const SizedBox(width: 3),
                                  // Flexible + ellipsis so a narrow (overlap-
                                  // split) column clips the time rather than
                                  // overflowing the row.
                                  Flexible(
                                    child: Text(
                                      _timeRange(entry.time),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (showPlace)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                meta!.place,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          if (showAvatars)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _AvatarStack(
                                key: ValueKey('pop-avatars-${entry.id}'),
                                initials: meta!.attendees,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `HH:MM–HH:MM` for the entry's start and computed end time.
  static String _timeRange(PlannerTime time) {
    String hhmm(int totalMinutes) {
      final h = (totalMinutes ~/ 60) % 24;
      final m = totalMinutes % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    final start = time.hour * 60 + time.minutes;
    return '${hhmm(start)}–${hhmm(start + time.duration)}';
  }
}

/// A small status pill shown once the [PopBlock] clears the 56px tier.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The attendee avatar stack, shown only in the [PopBlock]'s tallest (≥92px)
/// tier.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({super.key, required this.initials});

  final List<String> initials;

  @override
  Widget build(BuildContext context) {
    const maxShown = 3;
    final shown = initials.take(maxShown).toList();
    final extra = initials.length - shown.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final i in shown)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _avatar(i, const Color(0xFF3A7BD5)),
          ),
        if (extra > 0) _avatar('+$extra', const Color(0xFF55607A)),
      ],
    );
  }

  Widget _avatar(String text, Color color) => Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 7),
        ),
      );
}
