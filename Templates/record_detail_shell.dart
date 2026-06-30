import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';
import '../../shell/widgets/resizable_pane_layout.dart';

/// Three-pane record-detail scaffold: list | record body | properties panel.
/// Drop this into any module's detail route; supply pane content as children.
///
/// Usage:
/// ```dart
/// RecordDetailShell(
///   listPane: ContactsListPane(selectedId: id),
///   recordPane: ContactRecordPane(id: id),
///   propertiesPane: ContactPropertiesPane(id: id),
/// )
/// ```
class RecordDetailShell extends StatelessWidget {
  const RecordDetailShell({
    super.key,
    required this.listPane,
    required this.recordPane,
    required this.propertiesPane,
    this.listPaneInitialWidth = 280.0,
    this.listPaneMinWidth = 160.0,
    this.listPaneMaxWidth = 480.0,
    this.propertiesPaneInitialWidth = 295.0,
    this.propertiesPaneMinWidth = 200.0,
    this.propertiesPaneMaxWidth = 520.0,
  });

  final Widget listPane;
  final Widget recordPane;
  final Widget propertiesPane;

  final double listPaneInitialWidth;
  final double listPaneMinWidth;
  final double listPaneMaxWidth;
  final double propertiesPaneInitialWidth;
  final double propertiesPaneMinWidth;
  final double propertiesPaneMaxWidth;

  @override
  Widget build(BuildContext context) {
    return ResizablePaneLayout(
      panes: [
        PaneConfig(
          child: _PaneSurface(child: listPane),
          initialWidth: listPaneInitialWidth,
          minWidth: listPaneMinWidth,
          maxWidth: listPaneMaxWidth,
        ),
        PaneConfig(
          flex: true,
          child: _PaneSurface(child: recordPane, borderLeft: true),
        ),
        PaneConfig(
          child: _PaneSurface(child: propertiesPane, borderLeft: true),
          initialWidth: propertiesPaneInitialWidth,
          minWidth: propertiesPaneMinWidth,
          maxWidth: propertiesPaneMaxWidth,
        ),
      ],
    );
  }
}

class _PaneSurface extends StatelessWidget {
  const _PaneSurface({required this.child, this.borderLeft = false});
  final Widget child;
  final bool borderLeft;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: borderLeft
            ? const Border(left: BorderSide(color: LinearColors.borderSubtle))
            : null,
      ),
      child: child,
    );
  }
}
