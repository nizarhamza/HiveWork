import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

enum AppAvatarSize { xs, sm, md, lg }

/// A single user avatar — initials or network image.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.color,
    this.size = AppAvatarSize.md,
  });

  final String name;
  final String? imageUrl;
  final Color? color;
  final AppAvatarSize size;

  double get _dp => switch (size) {
    AppAvatarSize.xs => 16,
    AppAvatarSize.sm => 20,
    AppAvatarSize.md => 28,
    AppAvatarSize.lg => 36,
  };

  double get _fs => switch (size) {
    AppAvatarSize.xs =>  8,
    AppAvatarSize.sm =>  9,
    AppAvatarSize.md => 11,
    AppAvatarSize.lg => 14,
  };

  String get _initials {
    final parts = name.trim().split(' ');
    return parts.take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final bg = color ?? LinearColors.accent;

    return Semantics(
      label: name,
      child: Container(
        width: _dp, height: _dp,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: imageUrl != null ? null : bg,
          image: imageUrl != null
              ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: imageUrl == null
            ? Text(
                _initials,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontSize: _fs,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

/// A horizontal stack of avatars with an overflow count (e.g. +3).
class AppAvatarStack extends StatelessWidget {
  const AppAvatarStack({
    super.key,
    required this.names,
    this.colors,
    this.maxVisible = 3,
    this.size = AppAvatarSize.sm,
  });

  final List<String> names;
  final List<Color>? colors;
  final int maxVisible;
  final AppAvatarSize size;

  double get _dp => switch (size) {
    AppAvatarSize.xs => 16,
    AppAvatarSize.sm => 20,
    AppAvatarSize.md => 28,
    AppAvatarSize.lg => 36,
  };

  @override
  Widget build(BuildContext context) {
    final visible  = names.take(maxVisible).toList();
    final overflow = names.length - visible.length;
    final overlap  = _dp * 0.35;

    // Each avatar overlaps the previous by 35 %
    return SizedBox(
      height: _dp,
      width: _dp + (_dp - overlap) * (visible.length - 1) +
             (overflow > 0 ? (_dp - overlap) : 0),
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * (_dp - overlap),
              child: _bordered(
                AppAvatar(
                  name: visible[i],
                  color: colors != null && i < colors!.length
                      ? colors![i]
                      : null,
                  size: size,
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * (_dp - overlap),
              child: _bordered(
                Builder(builder: (context) {
                  final ext = context.linearExt;
                  return Container(
                    width: _dp, height: _dp,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ext.surfaceRaised,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflow',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: _dp * 0.35,
                        fontWeight: FontWeight.w500,
                        color: ext.textSecondary,
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bordered(Widget child) => Builder(
    builder: (context) {
      final ext = context.linearExt;
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: ext.surfaceBase, width: 1.5),
          ),
        ),
        child: child,
      );
    },
  );
}
