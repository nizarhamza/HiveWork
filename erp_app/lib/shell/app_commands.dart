import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_providers.dart';
import '../ui/organisms/command_palette.dart';

/// Permanent navigation + app-level commands, mounted once in [AppShell].
/// These are always in the registry regardless of which page is open.
class AppCommands extends ConsumerStatefulWidget {
  const AppCommands({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppCommands> createState() => _AppCommandsState();
}

class _AppCommandsState extends ConsumerState<AppCommands> {
  static const _ids = [
    'nav.crm_contacts',
    'nav.crm_companies',
    'nav.sales_pipeline',
    'nav.sales_quotes',
    'nav.invoicing_invoices',
    'nav.invoicing_payments',
    'nav.projects_all',
    'nav.settings',
    'app.toggle_theme',
  ];

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
        id: 'nav.crm_contacts',
        label: 'Go to Contacts',
        group: 'Navigate',
        icon: Icons.people_outline,
        onExecute: () => context.go('/crm/contacts'),
      ),
      CommandAction(
        id: 'nav.crm_companies',
        label: 'Go to Companies',
        group: 'Navigate',
        icon: Icons.business_outlined,
        onExecute: () => context.go('/crm/companies'),
      ),
      CommandAction(
        id: 'nav.sales_pipeline',
        label: 'Go to Pipeline',
        group: 'Navigate',
        icon: Icons.view_kanban_outlined,
        onExecute: () => context.go('/sales/pipeline'),
      ),
      CommandAction(
        id: 'nav.sales_quotes',
        label: 'Go to Quotes',
        group: 'Navigate',
        icon: Icons.request_quote_outlined,
        onExecute: () => context.go('/sales/quotes'),
      ),
      CommandAction(
        id: 'nav.invoicing_invoices',
        label: 'Go to Invoices',
        group: 'Navigate',
        icon: Icons.receipt_long_outlined,
        onExecute: () => context.go('/invoicing/invoices'),
      ),
      CommandAction(
        id: 'nav.invoicing_payments',
        label: 'Go to Payments',
        group: 'Navigate',
        icon: Icons.payments_outlined,
        onExecute: () => context.go('/invoicing/payments'),
      ),
      CommandAction(
        id: 'nav.projects_all',
        label: 'Go to Projects',
        group: 'Navigate',
        icon: Icons.folder_outlined,
        onExecute: () => context.go('/projects/all'),
      ),
      CommandAction(
        id: 'nav.settings',
        label: 'Go to Settings',
        group: 'Navigate',
        icon: Icons.settings_outlined,
        onExecute: () => context.go('/settings'),
      ),
      CommandAction(
        id: 'app.toggle_theme',
        label: 'Toggle light / dark theme',
        group: 'App',
        icon: Icons.contrast_outlined,
        onExecute: () {
          final current = ref.read(themeModeProvider);
          ref.read(themeModeProvider.notifier).setMode(
            current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
          );
        },
      ),
    ]);
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
