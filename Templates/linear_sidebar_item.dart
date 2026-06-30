import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

/// A single sidebar row. Matches Linear's restrained selection: a subtle gray
/// background and brighter text — no loud accent bar. Supports nesting via
/// [indent] for a module's sub-pages.
class LinearSidebarItem extends StatelessWidget {
  const LinearSidebarItem({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.indent = 0,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final lt = context.linearTokens;
    final text = Theme.of(context).textTheme;

    final fg = selected ? LinearColors.textPrimary : LinearColors.textSecondary;
    final iconColor = selected ? LinearColors.textPrimary : LinearColors.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(LinearRadii.md),
          overlayColor: const WidgetStatePropertyAll(LinearColors.overlay),
          child: Container(
            height: lt.rowHeightDefault,
            padding: EdgeInsets.only(
              left: LinearSpacing.sm + indent,
              right: LinearSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? LinearColors.overlayActive : Colors.transparent,
              borderRadius: BorderRadius.circular(LinearRadii.md),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: lt.iconSizeMd, color: iconColor),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: text.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
