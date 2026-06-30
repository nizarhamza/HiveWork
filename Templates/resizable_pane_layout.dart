import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

/// Config for a single pane inside [ResizablePaneLayout].
/// Set [flex] = true on exactly one pane — it fills the remaining space.
class PaneConfig {
  const PaneConfig({
    required this.child,
    this.initialWidth = 280.0,
    this.minWidth = 120.0,
    this.maxWidth = double.infinity,
    this.flex = false,
  });

  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;

  /// If true this pane is [Expanded] and fills whatever space fixed panes leave.
  final bool flex;
}

/// Horizontal layout with draggable dividers between panes.
/// Exactly one [PaneConfig] should set [PaneConfig.flex] = true.
class ResizablePaneLayout extends StatefulWidget {
  const ResizablePaneLayout({super.key, required this.panes});
  final List<PaneConfig> panes;

  @override
  State<ResizablePaneLayout> createState() => _ResizablePaneLayoutState();
}

class _ResizablePaneLayoutState extends State<ResizablePaneLayout> {
  // null → flex pane (Expanded); non-null → fixed width in px
  late final List<double?> _widths;

  @override
  void initState() {
    super.initState();
    _widths = [for (final p in widget.panes) p.flex ? null : p.initialWidth];
  }

  void _drag(int paneIndex, double delta) {
    final w = _widths[paneIndex];
    if (w == null) return;
    final cfg = widget.panes[paneIndex];
    setState(() {
      _widths[paneIndex] = (w + delta).clamp(cfg.minWidth, cfg.maxWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (int i = 0; i < widget.panes.length; i++) {
      final w = _widths[i];
      final child = widget.panes[i].child;
      items.add(w == null ? Expanded(child: child) : SizedBox(width: w, child: child));

      if (i < widget.panes.length - 1) {
        // Prefer resizing the left pane; if left is flex, resize the right pane instead.
        final leftIsFixed = _widths[i] != null;
        final targetIndex = leftIsFixed ? i : i + 1;
        final sign = leftIsFixed ? 1.0 : -1.0;
        items.add(ResizablePaneDivider(onDrag: (d) => _drag(targetIndex, d * sign)));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}

/// A 1 px visual divider with an 8 px drag hit area.
/// Can be used standalone (e.g. in [AppShell] for the sidebar edge).
class ResizablePaneDivider extends StatefulWidget {
  const ResizablePaneDivider({super.key, required this.onDrag});

  /// Called with horizontal delta in logical pixels.
  final void Function(double delta) onDrag;

  @override
  State<ResizablePaneDivider> createState() => _ResizablePaneDividerState();
}

class _ResizablePaneDividerState extends State<ResizablePaneDivider> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // Listener bypasses the gesture arena — fires reliably on Flutter web
      // even when scroll views are nearby (GestureDetector loses to them).
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => setState(() => _dragging = true),
        onPointerUp: (_) => setState(() => _dragging = false),
        onPointerCancel: (_) => setState(() => _dragging = false),
        onPointerMove: (e) {
          if (_dragging) widget.onDrag(e.delta.dx);
        },
        child: SizedBox(
          width: 8,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 2 : 1,
              color: active
                  ? LinearColors.accent.withOpacity(0.55)
                  : LinearColors.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}
