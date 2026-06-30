import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

enum AppButtonVariant { filled, outlined, ghost, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.outlined,
    this.size = AppButtonSize.lg,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final padding = switch (size) {
      AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: 8,  vertical: 4),
      AppButtonSize.md => const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    };
    final minH = switch (size) {
      AppButtonSize.sm => 24.0,
      AppButtonSize.md => 28.0,
      AppButtonSize.lg => 36.0,
    };
    final fs = switch (size) {
      AppButtonSize.sm => 11.0,
      AppButtonSize.md => 12.0,
      AppButtonSize.lg => 13.0,
    };

    final onTap = loading ? null : onPressed;
    final child  = _child(fs);
    final shape  = RoundedRectangleBorder(borderRadius: BorderRadius.circular(LinearRadii.md));
    final style  = ButtonStyle(
      padding:     WidgetStatePropertyAll(padding),
      minimumSize: WidgetStatePropertyAll(Size(0, minH)),
      textStyle:   WidgetStatePropertyAll(TextStyle(fontFamily: 'Inter', fontSize: fs, fontWeight: FontWeight.w500)),
    );

    return Semantics(
      button: true,
      label: label,
      child: switch (variant) {
        AppButtonVariant.filled => FilledButton(onPressed: onTap, style: style, child: child),
        AppButtonVariant.outlined => OutlinedButton(onPressed: onTap, style: style, child: child),
        AppButtonVariant.ghost => TextButton(onPressed: onTap, style: style, child: child),
        AppButtonVariant.danger => FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: loading || onPressed == null
                ? LinearColors.danger.withValues(alpha: 0.5)
                : LinearColors.danger,
            foregroundColor: Colors.white,
            shape: shape,
          ).merge(style),
          child: child,
        ),
      },
    );
  }

  Widget _child(double fs) {
    if (loading) {
      return SizedBox(
        width: fs + 4, height: fs + 4,
        child: Builder(builder: (context) {
          final ext = context.linearExt;
          return CircularProgressIndicator(
            strokeWidth: 1.5,
            color: variant == AppButtonVariant.filled || variant == AppButtonVariant.danger
                ? Colors.white
                : ext.textSecondary,
          );
        }),
      );
    }
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fs + 2),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

/// Icon-only button with a tooltip.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 28.0,
    this.iconSize = 15.0,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final color = selected ? ext.textPrimary : ext.textMuted;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: size, height: size,
          child: Material(
            color: selected ? ext.overlayActive : Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadii.md),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(LinearRadii.md),
              overlayColor: WidgetStatePropertyAll(ext.overlayActive),
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
