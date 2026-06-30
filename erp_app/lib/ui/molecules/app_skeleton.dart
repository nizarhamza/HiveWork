import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

/// Animated shimmer skeleton block. Use named constructors for common shapes.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  factory AppSkeleton.line({
    Key? key,
    double width = double.infinity,
    double height = 13,
  }) => AppSkeleton(key: key, width: width, height: height,
         borderRadius: LinearRadii.sm);

  factory AppSkeleton.avatar({Key? key, double size = 28}) =>
      AppSkeleton(key: key, width: size, height: size,
          borderRadius: LinearRadii.pill);

  factory AppSkeleton.block({
    Key? key,
    double width = double.infinity,
    double height = 80,
  }) => AppSkeleton(key: key, width: width, height: height,
         borderRadius: LinearRadii.md);

  final double width;
  final double height;
  final double? borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final pos = -1.5 + _ctrl.value * 3.0;
        return Container(
          width:  widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.borderRadius ?? LinearRadii.sm,
            ),
            gradient: LinearGradient(
              colors: [
                ext.surfaceBase,
                ext.surfaceRaised,
                ext.surfaceBase,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(pos - 1, 0),
              end:   Alignment(pos + 1, 0),
            ),
          ),
        );
      },
    );
  }
}

/// A ready-made contact-row skeleton for list placeholders.
class AppContactRowSkeleton extends StatelessWidget {
  const AppContactRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.base,
        vertical: LinearSpacing.sm,
      ),
      child: Row(
        children: [
          AppSkeleton.avatar(size: 20),
          const SizedBox(width: LinearSpacing.md),
          AppSkeleton.line(width: 120, height: 12),
          const SizedBox(width: LinearSpacing.md),
          Expanded(child: AppSkeleton.line(height: 12)),
          const SizedBox(width: LinearSpacing.md),
          AppSkeleton.line(width: 60, height: 20),
        ],
      ),
    );
  }
}
