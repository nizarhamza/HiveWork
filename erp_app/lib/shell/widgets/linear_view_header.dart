import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

/// The thin top toolbar for a view: leading icon + title on the left, action
/// widgets on the right. Reused by every module page so toolbars stay identical.
class LinearViewHeader extends StatelessWidget {
  const LinearViewHeader({
    super.key,
    required this.icon,
    required this.title,
    this.center,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final Widget? center;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final lt  = context.linearTokens;
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;

    return Container(
      height: lt.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ext.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(icon, size: lt.iconSizeMd, color: ext.textSecondary),
          const SizedBox(width: 7),
          Text(title, style: text.titleMedium),
          if (center != null)
            Expanded(child: Center(child: center!))
          else
            const Spacer(),
          for (final a in actions) ...[
            a,
            const SizedBox(width: LinearSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Primary "New …" action button for view headers.
class LinearNewButton extends StatelessWidget {
  const LinearNewButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom().copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// A quiet, muted toolbar action (e.g. Filter, Display).
class LinearGhostButton extends StatelessWidget {
  const LinearGhostButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ext = context.linearExt;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: WidgetStatePropertyAll(ext.overlayActive),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: ext.textMuted),
              const SizedBox(width: LinearSpacing.xs),
              Text(
                label,
                style: text.bodySmall?.copyWith(
                  color: ext.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
