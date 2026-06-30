import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';
import '../atoms/app_button.dart';

/// Base dialog widget — title + content + actions.
/// Use [AppDialog.show] / [AppDialog.confirm] helpers.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
    this.width = 480,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    List<Widget> actions = const [],
    double width = 480,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => AppDialog(
        title: title, content: content,
        actions: actions, width: width,
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: title,
        content: Text(message),
        actions: [
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          AppButton(
            label: confirmLabel,
            variant: destructive ? AppButtonVariant.danger : AppButtonVariant.filled,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.lg, LinearSpacing.base,
                LinearSpacing.sm, LinearSpacing.base,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: ext.textMuted,
                    splashRadius: 16,
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(LinearSpacing.lg),
                child: content,
              ),
            ),
            // Actions
            if (actions.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.lg, vertical: LinearSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: LinearSpacing.sm),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
