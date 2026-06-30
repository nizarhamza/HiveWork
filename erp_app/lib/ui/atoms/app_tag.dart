import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// A coloured label/tag. Pass [onRemove] to show an × button.
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    this.color,
    this.onRemove,
  });

  final String label;
  final Color? color;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = color ?? LinearColors.accent;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LinearSpacing.sm, vertical: 2,
        ),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(LinearRadii.sm),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: c.withValues(alpha: 0.9),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 3),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 10, color: c.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
