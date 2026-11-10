import 'package:flutter/material.dart';

import 'controller.dart';
import 'manager.dart';

/// Places the lifted context menu (#72) inside the planner's bounds (#123).
///
/// The menu opens with its top-left at [anchor], the planner-local click point.
/// Near the right or bottom edge that would push part of it off the planner,
/// where its items can't be tapped, so once the menu's size is known it flips
/// to the left of / above the click point when it would overflow, and is then
/// clamped into the planner rect. A menu larger than the planner pins to its
/// top-left edge so the first items stay reachable.
class ContextMenuLayout extends SingleChildLayoutDelegate {
  ContextMenuLayout(this.anchor);

  /// The click point the menu opens from, in planner-local coordinates.
  final Offset anchor;

  /// The menu's top-left for a [menu] of the given size opened at [anchor]
  /// inside a planner of size [bounds]. Pure, for unit testing.
  static Offset positionFor(Offset anchor, Size bounds, Size menu) {
    double place(double click, double extent, double limit) {
      var start = click;
      if (start + extent > limit) start = click - extent; // flip
      final max = limit - extent;
      return start.clamp(0.0, max < 0 ? 0.0 : max).toDouble();
    }

    return Offset(
      place(anchor.dx, menu.width, bounds.width),
      place(anchor.dy, menu.height, bounds.height),
    );
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      positionFor(anchor, size, childSize);

  @override
  bool shouldRelayout(ContextMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor;
}

class ContextMenu<T> extends StatefulWidget {
  final Manager<T> manager;

  const ContextMenu({super.key, required this.manager});

  @override
  State<ContextMenu<T>> createState() => _ContextMenuState<T>();
}

class _ContextMenuState<T> extends State<ContextMenu<T>> {
  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: IntrinsicHeight(
        child: Card(
          color: widget.manager.config.contextMenuBackground,
          elevation: 2,
          child: _generateMenu(),
        ),
      ),
    );
  }

  Column _generateMenu() {
    List<Widget> result = [];
    if (widget.manager.controller.menuType == MenuType.planner) {
      result.add(
        Expanded(
          child: TextButton(
              child: Text(
                widget.manager.config.contextMenuCreateLabel,
                style: widget.manager.config.contextMenuTextStyle,
              ),
              onPressed: () {
                if (widget.manager.config.onEntryCreate != null &&
                    widget.manager.controller.menuTime != null) {
                  widget.manager.config
                      .onEntryCreate!(widget.manager.controller.menuTime!);
                }
                widget.manager.controller.hideMenu();
              }),
        ),
      );
    } else if (widget.manager.controller.menuType == MenuType.entry) {
      result.add(
        Expanded(
          child: TextButton(
            child: Text(
              widget.manager.config.contextMenuEditLabel,
              style: widget.manager.config.contextMenuTextStyle,
            ),
            onPressed: () {
              if (widget.manager.config.onEntryEdit != null &&
                  widget.manager.controller.menuEntry != null) {
                widget.manager.config
                    .onEntryEdit!(widget.manager.controller.menuEntry!);
              }
              widget.manager.controller.hideMenu();
            },
          ),
        ),
      );

      result.add(
        Expanded(
          child: TextButton(
            child: Text(widget.manager.config.contextMenuDeleteLabel,
                style: widget.manager.config.contextMenuDeleteTextStyle),
            onPressed: () {
              if (widget.manager.config.onEntryDelete != null &&
                  widget.manager.controller.menuEntry != null) {
                widget.manager.config
                    .onEntryDelete!(widget.manager.controller.menuEntry!);
              }
              widget.manager.controller.hideMenu();
              setState(() {});
            },
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: result,
    );
  }
}
