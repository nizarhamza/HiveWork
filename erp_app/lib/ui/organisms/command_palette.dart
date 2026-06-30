import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/linear_tokens.dart';
import '../atoms/app_text_field.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class CommandAction {
  const CommandAction({
    required this.id,
    required this.label,
    required this.onExecute,
    this.icon,
    this.description,
    this.group,
    this.shortcut,
  });

  final String id;
  final String label;
  final VoidCallback onExecute;
  final IconData? icon;
  final String? description;
  final String? group;
  final ShortcutActivator? shortcut;
}

// ── Intent for Shortcuts system ───────────────────────────────────────────────

class ShowCommandPaletteIntent extends Intent {
  const ShowCommandPaletteIntent();
}

// ── Providers ─────────────────────────────────────────────────────────────────

class CommandNotifier extends Notifier<List<CommandAction>> {
  @override
  List<CommandAction> build() => const [];

  void register(CommandAction action) {
    if (state.any((a) => a.id == action.id)) return;
    state = [...state, action];
  }

  void unregister(String id) {
    state = state.where((a) => a.id != id).toList();
  }

  void registerAll(List<CommandAction> actions) {
    final existing = state.map((a) => a.id).toSet();
    final fresh = actions.where((a) => !existing.contains(a.id)).toList();
    if (fresh.isEmpty) return;
    state = [...state, ...fresh];
  }
}

final commandRegistryProvider =
    NotifierProvider<CommandNotifier, List<CommandAction>>(CommandNotifier.new);

class _PaletteOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void open()  => state = true;
  void close() => state = false;
}

final commandPaletteOpenProvider =
    NotifierProvider<_PaletteOpenNotifier, bool>(_PaletteOpenNotifier.new);

// ── Widget ────────────────────────────────────────────────────────────────────

/// Full-screen overlay — render inside a [Stack] in [AppShell].
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  final _keyboardFocus = FocusNode();
  int _highlighted = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onSearch() => setState(() => _highlighted = 0);

  List<CommandAction> _filtered(List<CommandAction> all) {
    final q = _searchCtrl.text.toLowerCase();
    final result = q.isEmpty
        ? [...all]
        : all.where((a) =>
            a.label.toLowerCase().contains(q) ||
            (a.description?.toLowerCase().contains(q) ?? false) ||
            (a.group?.toLowerCase().contains(q) ?? false)).toList();
    result.sort((a, b) => (a.group ?? '').compareTo(b.group ?? ''));
    return result;
  }

  void _close() => ref.read(commandPaletteOpenProvider.notifier).close();

  void _execute(CommandAction action) {
    _close();
    action.onExecute();
  }

  void _moveHighlight(int delta, int total) {
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, total - 1);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final all = ref.watch(commandRegistryProvider);
    final items = _filtered(all);

    // Build list entries: String = section header, CommandAction = row.
    final List<dynamic> entries = [];
    String? lastGroup;
    for (final action in items) {
      final g = action.group ?? '';
      if (g != lastGroup && g.isNotEmpty) {
        entries.add(g);
        lastGroup = g;
      }
      entries.add(action);
    }

    return KeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: false,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) _close();
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _moveHighlight(1, items.length);
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _moveHighlight(-1, items.length);
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && items.isNotEmpty) {
          _execute(items[_highlighted.clamp(0, items.length - 1)]);
        }
      },
      child: GestureDetector(
        onTap: _close,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps inside the panel
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560, maxHeight: 440),
                child: Container(
                  margin: const EdgeInsets.all(LinearSpacing.xl),
                  decoration: BoxDecoration(
                    color: ext.surfaceRaised,
                    borderRadius: BorderRadius.circular(LinearRadii.lg),
                    border: Border.all(color: ext.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          LinearSpacing.base, LinearSpacing.base,
                          LinearSpacing.base, 0,
                        ),
                        child: AppSearchField(
                          hint: 'Search actions…',
                          controller: _searchCtrl,
                          focusNode: _focus,
                        ),
                      ),
                      const SizedBox(height: LinearSpacing.xs),
                      const Divider(),
                      // Results
                      Flexible(
                        child: items.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(LinearSpacing.xl),
                                child: Text(
                                  'No actions found',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                  vertical: LinearSpacing.xs,
                                ),
                                itemCount: entries.length,
                                itemBuilder: (_, i) {
                                  final e = entries[i];
                                  if (e is String) return _GroupHeader(e);
                                  final action = e as CommandAction;
                                  final idx = items.indexOf(action);
                                  return _ActionTile(
                                    action:      action,
                                    highlighted: idx == _highlighted,
                                    onTap:       () => _execute(action),
                                    onHover:     (_) => setState(() => _highlighted = idx),
                                  );
                                },
                              ),
                      ),
                      // Footer hint
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                          horizontal: LinearSpacing.base,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: ext.borderSubtle),
                          ),
                        ),
                        child: Row(
                          children: [
                            _hint('↑↓', 'navigate'),
                            const SizedBox(width: LinearSpacing.base),
                            _hint('↵', 'select'),
                            const SizedBox(width: LinearSpacing.base),
                            _hint('Esc', 'close'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(String key, String label) {
    final ext = context.linearExt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: ext.surfaceBase,
            borderRadius: BorderRadius.circular(LinearRadii.xs),
            border: Border.all(color: ext.borderSubtle),
          ),
          child: Text(key, style: Theme.of(context).textTheme.labelSmall),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LinearSpacing.base, LinearSpacing.sm,
        LinearSpacing.base, LinearSpacing.xxs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: ext.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
  });

  final CommandAction action;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xs, vertical: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm),
          decoration: BoxDecoration(
            color: highlighted ? ext.overlayActive : Colors.transparent,
            borderRadius: BorderRadius.circular(LinearRadii.sm),
          ),
          child: Row(
            children: [
              if (action.icon != null) ...[
                Icon(
                  action.icon,
                  size: 15,
                  color: highlighted
                      ? ext.textPrimary
                      : ext.textMuted,
                ),
                const SizedBox(width: LinearSpacing.sm),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: highlighted
                            ? ext.textPrimary
                            : ext.textSecondary,
                      ),
                    ),
                    if (action.description != null)
                      Text(
                        action.description!,
                        style: Theme.of(context).textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
