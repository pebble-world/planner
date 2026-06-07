import 'package:flutter/material.dart';
import 'package:planner/planner.dart';

import '../data.dart';

/// A fully custom all-day chip for an [Planner.allDayEntryBuilder] (#80): a
/// rounded pill filled with the entry's type accent and a small event icon.
///
/// Reuses the same typed [PlannerEntry.data] ([ActivityMeta], #77) as the timed
/// [PopBlock] for its colour. The supplied [PlannerEntryLayout] carries
/// `allDay: true`, so a host could wire one builder to both the timed and
/// all-day hooks and branch on it; this example keeps them as two focused
/// widgets.
///
/// Shared across the all-day and showcase example pages.
class AllDayChip extends StatelessWidget {
  const AllDayChip({super.key, required this.entry});

  final PlannerEntry<ActivityMeta> entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.data?.type.color ?? entry.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
