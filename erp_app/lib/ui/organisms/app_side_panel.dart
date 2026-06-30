import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// The right-hand properties panel used in the three-pane layout.
/// Compose it in a [Row] alongside a list or detail pane.
class AppSidePanel extends StatelessWidget {
  const AppSidePanel({
    super.key,
    required this.title,
    required this.children,
    this.onClose,
    this.width = 260,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onClose;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: ext.surfaceBase,
        border: Border(left: BorderSide(color: ext.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ext.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  Semantics(
                    button: true, label: 'Close panel',
                    child: InkWell(
                      onTap: onClose,
                      borderRadius: BorderRadius.circular(LinearRadii.md),
                      overlayColor: WidgetStatePropertyAll(ext.overlayActive),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 14, color: ext.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LinearSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled property row inside a side panel.
class SidePanelProperty extends StatelessWidget {
  const SidePanelProperty({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A titled group of properties inside a side panel.
class SidePanelSection extends StatelessWidget {
  const SidePanelSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: LinearSpacing.sm),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.6,
              color: ext.textMuted,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: LinearSpacing.base),
        const Divider(),
        const SizedBox(height: LinearSpacing.base),
      ],
    );
  }
}
