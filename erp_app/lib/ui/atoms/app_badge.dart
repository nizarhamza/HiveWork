import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// A count badge that overlays a child widget (inbox count, notification dot).
/// Wraps Material 3's [Badge] for consistent sizing and positioning.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.child,
    this.count,
    this.dot = false,
    this.visible = true,
  }) : assert(
         count != null || dot,
         'Provide count or set dot:true',
       );

  final Widget child;
  final int? count;
  final bool dot;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return Badge(
      label: dot ? null : Text('${count ?? 0}'),
      isLabelVisible: visible,
      backgroundColor: LinearColors.danger,
      textColor: Colors.white,
      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600),
      child: child,
    );
  }
}

/// A standalone count pill — for use in nav or table cells.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ext.overlayActive,
        borderRadius: BorderRadius.circular(LinearRadii.pill),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
