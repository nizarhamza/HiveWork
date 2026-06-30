import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/linear_tokens.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

enum ToastVariant { info, success, warning, error }

class ToastEntry {
  ToastEntry({
    required this.message,
    required this.variant,
    required this.duration,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final String message;
  final ToastVariant variant;
  final Duration duration;
}

// ── Provider ──────────────────────────────────────────────────────────────────

class ToastNotifier extends Notifier<List<ToastEntry>> {
  @override
  List<ToastEntry> build() => const [];

  void show(
    String message, {
    ToastVariant variant = ToastVariant.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final entry = ToastEntry(message: message, variant: variant, duration: duration);
    state = [...state, entry];
    Future.delayed(duration, () => dismiss(entry.id));
  }

  void dismiss(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final toastProvider =
    NotifierProvider<ToastNotifier, List<ToastEntry>>(ToastNotifier.new);

// ── Overlay widget ────────────────────────────────────────────────────────────

/// Wrap the app content in this to display toasts.
/// Add it to [AppShell]'s Stack, positioned above everything else.
class ToastOverlay extends ConsumerWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toasts = ref.watch(toastProvider);
    if (toasts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: LinearSpacing.lg,
      bottom: LinearSpacing.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in toasts)
            Padding(
              padding: const EdgeInsets.only(top: LinearSpacing.sm),
              child: _ToastCard(entry: t),
            ),
        ],
      ),
    );
  }
}

class _ToastCard extends ConsumerWidget {
  const _ToastCard({required this.entry});
  final ToastEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = context.linearExt;
    final (color, icon) = switch (entry.variant) {
      ToastVariant.success => (LinearColors.success, Icons.check_circle_outline),
      ToastVariant.warning => (LinearColors.warning, Icons.warning_amber_outlined),
      ToastVariant.error   => (LinearColors.danger,  Icons.error_outline),
      ToastVariant.info    => (LinearColors.accent,  Icons.info_outline),
    };

    return Material(
      color: Colors.transparent,
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 240),
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base, vertical: LinearSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: ext.surfaceRaised,
            borderRadius: BorderRadius.circular(LinearRadii.md),
            border: Border.all(color: ext.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: LinearSpacing.sm),
              Flexible(
                child: Text(
                  entry.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ext.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              GestureDetector(
                onTap: () => ref.read(toastProvider.notifier).dismiss(entry.id),
                child: Icon(Icons.close, size: 12, color: ext.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
