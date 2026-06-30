import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';
import '../atoms/app_button.dart';

/// Guided empty state — centered icon, title, description, optional CTA.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;

  // Pass a custom [action] widget OR use [actionLabel] + [onAction] for a default button.
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cta = action ??
        (actionLabel != null
            ? AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.outlined,
                onPressed: onAction,
              )
            : null);

    final ext = context.linearExt;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: ext.surfaceRaised,
                  borderRadius: BorderRadius.circular(LinearRadii.lg),
                  border: Border.all(color: ext.borderSubtle),
                ),
                child: Icon(icon, size: 22, color: ext.textMuted),
              ),
              const SizedBox(height: LinearSpacing.base),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              if (cta != null) ...[
                const SizedBox(height: LinearSpacing.lg),
                cta,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
