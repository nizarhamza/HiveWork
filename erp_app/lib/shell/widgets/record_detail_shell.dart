import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';
import 'resizable_pane_layout.dart';

/// Three-pane record-detail scaffold: list | record body | properties panel.
/// Drop this into any module's detail route; supply pane content as children.
///
/// Usage:
/// ```dart
/// RecordDetailShell(
///   listPane: DealsListPane(selectedId: id),
///   recordPane: DealRecordPane(id: id),
///   propertiesPane: DealPropertiesPane(id: id),
/// )
/// ```
class RecordDetailShell extends StatelessWidget {
  const RecordDetailShell({
    super.key,
    required this.listPane,
    required this.recordPane,
    required this.propertiesPane,
    this.storageKey,
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

  /// Pass a unique key (e.g. `'crm.deals'`) to persist pane widths in the browser.
  final String? storageKey;

  final double listPaneInitialWidth;
  final double listPaneMinWidth;
  final double listPaneMaxWidth;
  final double propertiesPaneInitialWidth;
  final double propertiesPaneMinWidth;
  final double propertiesPaneMaxWidth;

  @override
  Widget build(BuildContext context) {
    return ResizablePaneLayout(
      storageKey: storageKey,
      panes: [
        PaneConfig(
          initialWidth: listPaneInitialWidth,
          minWidth: listPaneMinWidth,
          maxWidth: listPaneMaxWidth,
          child: _PaneSurface(child: listPane),
        ),
        PaneConfig(
          flex: true,
          child: _PaneSurface(borderLeft: true, child: recordPane),
        ),
        PaneConfig(
          initialWidth: propertiesPaneInitialWidth,
          minWidth: propertiesPaneMinWidth,
          maxWidth: propertiesPaneMaxWidth,
          child: _PaneSurface(borderLeft: true, child: propertiesPane),
        ),
      ],
    );
  }
}

class _PaneSurface extends StatelessWidget {
  const _PaneSurface({this.borderLeft = false, required this.child});
  final Widget child;
  final bool borderLeft;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: borderLeft
            ? Border(left: BorderSide(color: context.linearExt.borderSubtle))
            : null,
      ),
      child: child,
    );
  }
}
