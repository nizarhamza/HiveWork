import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/quote.dart';
import '../../data/providers/quotes_provider.dart';
import '../../modules/org/org_providers.dart';
import '../../ui/organisms/command_palette.dart';
import 'deal_form_dialog.dart';
import 'quote_form_dialog.dart';

/// Registers Sales creation actions into the command palette.
/// Mount inside a Sales page so actions are available while Sales is open.
class SalesCommands extends ConsumerStatefulWidget {
  const SalesCommands({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SalesCommands> createState() => _SalesCommandsState();
}

class _SalesCommandsState extends ConsumerState<SalesCommands> {
  static const _ids = ['sales.new_deal', 'sales.new_quote'];

  CommandNotifier? _registry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  void _register() {
    _registry = ref.read(commandRegistryProvider.notifier);
    _registry!.registerAll([
      CommandAction(
        id: 'sales.new_deal',
        label: 'New deal',
        group: 'Sales',
        icon: Icons.handshake_outlined,
        onExecute: () => showDealForm(context),
      ),
      CommandAction(
        id: 'sales.new_quote',
        label: 'New quote',
        group: 'Sales',
        icon: Icons.request_quote_outlined,
        onExecute: () => unawaited(_newQuote()),
      ),
    ]);
  }

  Future<void> _newQuote() async {
    final orgId = await ref.read(currentOrgIdProvider.future) ?? '';
    if (!mounted) return;
    final result = await showQuoteForm(
      context,
      initial: QuoteInput(orgId: orgId, lines: const []),
    );
    if (result == null || !mounted) return;
    await ref.read(quotesProvider.notifier).create(result);
  }

  @override
  void dispose() {
    final registry = _registry;
    if (registry != null) {
      Future.microtask(() {
        for (final id in _ids) {
          registry.unregister(id);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
