import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

/// The thin top toolbar for a view: leading icon + title on the left, action
/// widgets on the right. Reused by every module page so toolbars stay identical.
class LinearViewHeader extends StatelessWidget {
  const LinearViewHeader({
    super.key,
    required this.icon,
    required this.title,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final lt = context.linearTokens;
    final text = Theme.of(context).textTheme;

    return Container(
      height: lt.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LinearColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Icon(icon, size: lt.iconSizeMd, color: LinearColors.textSecondary),
          const SizedBox(width: 7),
          Text(title, style: text.titleMedium),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: const WidgetStatePropertyAll(LinearColors.overlayActive),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: LinearColors.textMuted),
              const SizedBox(width: LinearSpacing.xs),
              Text(
                label,
                style: text.labelMedium?.copyWith(color: LinearColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
