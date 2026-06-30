import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/organisms/command_palette.dart';
import 'contact_form_dialog.dart';
import 'company_form_dialog.dart';

/// Registers CRM creation actions into the command palette for the lifetime
/// of this widget. Mount once inside a CRM page.
class CrmCommands extends ConsumerStatefulWidget {
  const CrmCommands({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CrmCommands> createState() => _CrmCommandsState();
}

class _CrmCommandsState extends ConsumerState<CrmCommands> {
  static const _actions = [
    'crm.new_contact',
    'crm.new_company',
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
        id: 'crm.new_contact',
        label: 'New contact',
        group: 'CRM',
        icon: Icons.person_add_outlined,
        onExecute: () => showContactForm(context),
      ),
      CommandAction(
        id: 'crm.new_company',
        label: 'New company',
        group: 'CRM',
        icon: Icons.add_business_outlined,
        onExecute: () => showCompanyForm(context),
      ),
    ]);
  }

  @override
  void dispose() {
    final registry = _registry;
    if (registry != null) {
      Future.microtask(() {
        for (final id in _actions) {
          registry.unregister(id);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
