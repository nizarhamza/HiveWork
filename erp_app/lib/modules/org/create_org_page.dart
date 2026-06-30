import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/widgets/auth_form_widgets.dart';
import '../../auth/widgets/auth_layout.dart';
import '../../core/data/world_data.dart';
import '../../shell/widgets/search_picker_dialog.dart';
import '../../theme/linear_tokens.dart';
import 'org_providers.dart';
import 'org_repository.dart';

class CreateOrgPage extends ConsumerStatefulWidget {
  const CreateOrgPage({super.key});

  @override
  ConsumerState<CreateOrgPage> createState() => _CreateOrgPageState();
}

class _CreateOrgPageState extends ConsumerState<CreateOrgPage> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String  _currency = 'EUR';
  String  _timezone = 'UTC';
  bool    _loading  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final picked = await showSearchPicker(
      context: context,
      title: 'Select currency',
      current: _currency,
      options: kAllCurrencies
          .map((c) => (value: c.code, label: '${c.code} — ${c.name}'))
          .toList(),
    );
    if (picked != null && mounted) setState(() => _currency = picked);
  }

  Future<void> _pickTimezone() async {
    final picked = await showSearchPicker(
      context: context,
      title: 'Select timezone',
      current: _timezone,
      options: kAllTimezones.map((tz) => (value: tz, label: tz)).toList(),
    );
    if (picked != null && mounted) setState(() => _timezone = picked);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final org = await ref.read(orgRepositoryProvider).createOrg(
            name:     _nameCtrl.text.trim(),
            currency: _currency,
            timezone: _timezone,
          );
      await ref.read(currentOrgIdProvider.notifier).select(org['id'] as String);
      if (mounted) context.go('/crm/contacts');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AuthLayout(
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/org'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.xl,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: LinearColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(LinearRadii.lg),
                    border: Border.all(color: context.linearExt.borderBase),
                  ),
                  child: const Icon(
                    Icons.business_outlined,
                    color: LinearColors.accentHover,
                    size: 22,
                  ),
                ),
                const SizedBox(height: LinearSpacing.lg),

                Text('Create workspace', style: text.headlineLarge),
                const SizedBox(height: LinearSpacing.xs),
                Text(
                  'Set up your organisation in seconds.',
                  style: text.bodyMedium,
                ),

                const SizedBox(height: 28),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Name ───────────────────────────────────────────────
                      const AuthFieldLabel('Organisation name'),
                      const SizedBox(height: LinearSpacing.xs),
                      Semantics(
                        label: 'Organisation name',
                        textField: true,
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Acme Corp',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),

                      const SizedBox(height: LinearSpacing.lg),

                      // ── Currency + Timezone ────────────────────────────────
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 360) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _LabeledPicker(
                                    label: 'Currency',
                                    value:
                                        '$_currency — ${currencyName(_currency) ?? _currency}',
                                    hint: 'Select currency',
                                    onTap: _pickCurrency,
                                  ),
                                ),
                                const SizedBox(width: LinearSpacing.md),
                                Expanded(
                                  child: _LabeledPicker(
                                    label: 'Timezone',
                                    value: _timezone,
                                    hint: 'Select timezone',
                                    onTap: _pickTimezone,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _LabeledPicker(
                                label: 'Currency',
                                value:
                                    '$_currency — ${currencyName(_currency) ?? _currency}',
                                hint: 'Select currency',
                                onTap: _pickCurrency,
                              ),
                              const SizedBox(height: LinearSpacing.lg),
                              _LabeledPicker(
                                label: 'Timezone',
                                value: _timezone,
                                hint: 'Select timezone',
                                onTap: _pickTimezone,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: LinearSpacing.md),
                  AuthErrorBanner(message: _error!),
                ],

                const SizedBox(height: 28),

                Semantics(
                  button: true,
                  label: 'Create workspace',
                  child: FilledButton(
                    onPressed: _loading ? null : _create,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: _loading
                        ? const AuthButtonSpinner()
                        : const Text('Create workspace'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Labeled picker ─────────────────────────────────────────────────────────────

class _LabeledPicker extends StatelessWidget {
  const _LabeledPicker({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFieldLabel(label),
        const SizedBox(height: LinearSpacing.xs),
        SearchPickerField(
          value: value,
          hint: hint,
          onTap: onTap,
        ),
      ],
    );
  }
}
