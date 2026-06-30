import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/company.dart';
import '../../data/providers/companies_provider.dart';
import '../../theme/linear_tokens.dart';

/// Opens a modal search-and-select dialog for picking a company.
/// Returns the selected [Company], or null if the user cancelled or cleared.
Future<({Company? company, bool cleared})> showCompanyPicker(
  BuildContext context, {
  String? currentCompanyId,
}) async {
  final result = await showDialog<({Company? company, bool cleared})>(
    context: context,
    builder: (_) => _CompanyPickerDialog(currentCompanyId: currentCompanyId),
  );
  return result ?? (company: null, cleared: false);
}

// ── Dialog ─────────────────────────────────────────────────────────────────────

class _CompanyPickerDialog extends ConsumerStatefulWidget {
  const _CompanyPickerDialog({this.currentCompanyId});
  final String? currentCompanyId;

  @override
  ConsumerState<_CompanyPickerDialog> createState() =>
      _CompanyPickerDialogState();
}

class _CompanyPickerDialogState extends ConsumerState<_CompanyPickerDialog> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Company> _filter(List<Company> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            (c.industry?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;
    final companiesAsync = ref.watch(companiesProvider);

    return Dialog(
      backgroundColor: ext.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LinearSpacing.base, LinearSpacing.base,
                LinearSpacing.base, LinearSpacing.sm,
              ),
              child: Row(
                children: [
                  Text('Select company',
                      style: text.titleSmall),
                  const Spacer(),
                  if (widget.currentCompanyId != null)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop((company: null, cleared: true)),
                      style: TextButton.styleFrom(
                          foregroundColor: LinearColors.danger),
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: LinearSpacing.base),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: text.bodySmall?.copyWith(color: ext.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search companies…',
                  hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                  prefixIcon: Icon(Icons.search, size: 16, color: ext.textMuted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.sm,
                    vertical: LinearSpacing.sm,
                  ),
                  filled: true,
                  fillColor: ext.surfaceBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide: BorderSide(color: ext.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide: BorderSide(color: ext.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(LinearRadii.sm),
                    borderSide:
                        const BorderSide(color: LinearColors.accent),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: LinearSpacing.sm),
            const Divider(height: 1),
            // List
            Expanded(
              child: companiesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error loading companies',
                      style: text.bodySmall
                          ?.copyWith(color: ext.textMuted)),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No companies yet'
                            : 'No results for "$_query"',
                        style:
                            text.bodySmall?.copyWith(color: ext.textMuted),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _CompanyTile(
                      company: filtered[i],
                      selected:
                          filtered[i].id == widget.currentCompanyId,
                      onTap: () => Navigator.of(context).pop(
                        (company: filtered[i], cleared: false),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Company list tile ──────────────────────────────────────────────────────────

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({
    required this.company,
    required this.selected,
    required this.onTap,
  });

  final Company company;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected
          ? LinearColors.accent.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        overlayColor: WidgetStatePropertyAll(ext.overlay),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base,
            vertical: LinearSpacing.sm,
          ),
          child: Row(
            children: [
              _CompanyLogo(company: company),
              const SizedBox(width: LinearSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      company.name,
                      style: text.bodySmall?.copyWith(
                        color: ext.textPrimary,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (company.industry != null)
                      Text(
                        company.industry!,
                        style: text.labelSmall
                            ?.copyWith(color: ext.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 16, color: LinearColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: company.avatarColor,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        company.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
