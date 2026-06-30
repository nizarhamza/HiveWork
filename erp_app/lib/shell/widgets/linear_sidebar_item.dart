import 'package:flutter/material.dart';

import '../../theme/linear_tokens.dart';

/// A single sidebar row. Matches Linear's restrained selection: a subtle gray
/// background and brighter text — no loud accent bar. Supports nesting via
/// [indent] for a module's sub-pages.
///
/// Pass [onFavorite] + [isFavorited] to show a star that appears on hover and
/// toggles favorite state. The star is invisible (but reserves space) until
/// hovered or already favorited, avoiding layout shifts.
class LinearSidebarItem extends StatefulWidget {
  const LinearSidebarItem({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.selected = false,
    this.onTap,
    this.indent = 0,
    this.isFavorited = false,
    this.onFavorite,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final double indent;
  final bool isFavorited;
  final VoidCallback? onFavorite;

  @override
  State<LinearSidebarItem> createState() => _LinearSidebarItemState();
}

class _LinearSidebarItemState extends State<LinearSidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final lt  = context.linearTokens;
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;

    final fg        = widget.selected ? ext.textPrimary : ext.textSecondary;
    final iconColor = widget.selected ? ext.textPrimary : ext.textMuted;
    final showStar  = widget.isFavorited || _hovered;

    Widget? trailingWidget;
    if (widget.onFavorite != null) {
      trailingWidget = IgnorePointer(
        ignoring: !showStar,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: showStar ? 1.0 : 0.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onFavorite,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 4),
              child: Icon(
                widget.isFavorited ? Icons.star : Icons.star_border,
                size: 12,
                color: widget.isFavorited ? ext.textSecondary : ext.textMuted,
              ),
            ),
          ),
        ),
      );
    } else {
      trailingWidget = widget.trailing;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(LinearRadii.md),
            overlayColor: WidgetStatePropertyAll(ext.overlay),
            child: Container(
              height: lt.rowHeightDefault,
              padding: EdgeInsets.only(
                left: LinearSpacing.sm + widget.indent,
                right: LinearSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: widget.selected ? ext.overlayActive : Colors.transparent,
                borderRadius: BorderRadius.circular(LinearRadii.md),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: lt.iconSizeMd, color: iconColor),
                    const SizedBox(width: 9),
                  ],
                  Expanded(
                    child: Text(
                      widget.label,
                      style: text.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: widget.selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?trailingWidget,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
