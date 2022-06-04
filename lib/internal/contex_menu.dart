import 'package:flutter/material.dart';
import 'package:planner/internal/controller.dart';

import 'manager.dart';

class ContextMenu extends StatefulWidget {
  final Manager manager;

  const ContextMenu({Key? key, required this.manager}) : super(key: key);

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
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
                'Create Event',
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
              'Edit Event',
              style: widget.manager.config.contextMenuTextStyle,
            ),
            onPressed: () {
              if (widget.manager.config.onEntryEdit != null &&
                  widget.manager.controller.menuEvent != null) {
                widget.manager.config
                    .onEntryEdit!(widget.manager.controller.menuEvent!.entry);
              }
              widget.manager.controller.hideMenu();
            },
          ),
        ),
      );

      result.add(
        Expanded(
          child: TextButton(
            child: Text('Delete Event',
                style: widget.manager.config.contextMenuDeleteTextStyle),
            onPressed: () {
              if (widget.manager.config.onEntryDelete != null) {
                widget.manager.config
                    .onEntryDelete!(widget.manager.controller.menuEvent!.entry);
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
