import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// A labelled form field row: label (left or above) + child + helper/error.
class AppFormRow extends StatelessWidget {
  const AppFormRow({
    super.key,
    required this.label,
    required this.child,
    this.helper,
    this.error,
    this.required = false,
    this.horizontal = false,
  });

  final String label;
  final Widget child;
  final String? helper;
  final String? error;
  final bool required;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: ext.textSecondary,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: LinearColors.danger, fontSize: 11),
          ),
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        if (error != null) ...[
          const SizedBox(height: 3),
          Text(
            error!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: LinearColors.danger,
            ),
          ),
        ] else if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper!,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );

    if (horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: labelWidget,
          )),
          const SizedBox(width: LinearSpacing.base),
          Expanded(child: body),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        labelWidget,
        const SizedBox(height: LinearSpacing.xs),
        body,
      ],
    );
  }
}

/// Divides a form into sections with a title.
class AppFormSection extends StatelessWidget {
  const AppFormSection({
    super.key,
    this.title,
    required this.children,
    this.spacing = LinearSpacing.md,
  });

  final String? title;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: context.linearExt.textMuted,
            letterSpacing: 0.5,
          )),
          const SizedBox(height: LinearSpacing.sm),
          const Divider(),
          const SizedBox(height: LinearSpacing.sm),
        ],
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
