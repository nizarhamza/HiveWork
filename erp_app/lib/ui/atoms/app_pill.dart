import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// Status chips — Active, Lead, Inactive, etc.
enum AppStatusVariant { active, lead, inactive, pending, warning }

class AppStatusPill extends StatelessWidget {
  const AppStatusPill({super.key, required this.variant, this.label});

  final AppStatusVariant variant;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final (color, defaultLabel) = switch (variant) {
      AppStatusVariant.active   => (LinearColors.success, 'Active'),
      AppStatusVariant.lead     => (LinearColors.warning, 'Lead'),
      AppStatusVariant.inactive => (ext.textMuted, 'Inactive'),
      AppStatusVariant.pending  => (LinearColors.warning, 'Pending'),
      AppStatusVariant.warning  => (LinearColors.warning, 'Warning'),
    };
    return _Pill(label: label ?? defaultLabel, color: color);
  }
}

/// Priority pills — Urgent / High / Medium / Low / None
enum AppPriorityLevel { urgent, high, medium, low, none }

class AppPriorityPill extends StatelessWidget {
  const AppPriorityPill({super.key, required this.level, this.showLabel = true});

  final AppPriorityLevel level;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final (color, label, icon) = switch (level) {
      AppPriorityLevel.urgent => (LinearColors.danger,    'Urgent', Icons.double_arrow),
      AppPriorityLevel.high   => (LinearColors.warning,   'High',   Icons.north),
      AppPriorityLevel.medium => (LinearColors.accent,    'Medium', Icons.remove),
      AppPriorityLevel.low    => (ext.textSecondary,      'Low',    Icons.south),
      AppPriorityLevel.none   => (ext.textMuted,          'None',   Icons.radio_button_unchecked),
    };
    return _Pill(label: showLabel ? label : null, color: color, icon: icon);
  }
}

// ── Shared pill widget ────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String? label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: label != null ? LinearSpacing.sm : LinearSpacing.xs,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(LinearRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 11, color: color)
            else
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(LinearRadii.pill),
                ),
              ),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
