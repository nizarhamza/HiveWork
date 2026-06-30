import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/platform/file_saver.dart' as file_saver;
import '../../core/platform/folder_picker.dart' as folder_picker;
import '../../core/platform/image_picker.dart' as img_picker;
import '../../core/prefs/export_prefs.dart';
import '../../core/supabase_client.dart';
import '../../data/models/payment_term_template.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../theme/linear_tokens.dart';
import '../../theme/theme_providers.dart';
import '../../core/data/world_data.dart';
import '../../shell/widgets/search_picker_dialog.dart';
import '../org/org_details.dart';
import '../org/org_providers.dart';
import '../org/org_repository.dart';
import '../sales/payment_term_builder_dialog.dart';
import '../sales/payment_term_providers.dart';

enum _Tab { theme, orgInfo, quoteInvoice, exportImport, deleteOrg }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _Tab _tab = _Tab.theme;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearViewHeader(icon: Icons.settings_outlined, title: 'Settings'),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 176,
                child: Container(
                  color: ext.surfaceBase,
                  padding: const EdgeInsets.all(LinearSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NavItem(
                        label: 'Theme',
                        icon: Icons.palette_outlined,
                        selected: _tab == _Tab.theme,
                        onTap: () => setState(() => _tab = _Tab.theme),
                      ),
                      _NavItem(
                        label: 'Org Info',
                        icon: Icons.business_outlined,
                        selected: _tab == _Tab.orgInfo,
                        onTap: () => setState(() => _tab = _Tab.orgInfo),
                      ),
                      _NavItem(
                        label: 'Quote / Invoice',
                        icon: Icons.receipt_long_outlined,
                        selected: _tab == _Tab.quoteInvoice,
                        onTap: () => setState(() => _tab = _Tab.quoteInvoice),
                      ),
                      _NavItem(
                        label: 'Export / Import',
                        icon: Icons.import_export_outlined,
                        selected: _tab == _Tab.exportImport,
                        onTap: () => setState(() => _tab = _Tab.exportImport),
                      ),
                      _NavItem(
                        label: 'Delete Org',
                        icon: Icons.delete_outline,
                        selected: _tab == _Tab.deleteOrg,
                        onTap: () => setState(() => _tab = _Tab.deleteOrg),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: switch (_tab) {
                  _Tab.theme        => const _ThemeTab(),
                  _Tab.orgInfo      => const _OrgInfoTab(),
                  _Tab.quoteInvoice => const _QuoteInvoiceTab(),
                  _Tab.exportImport => const _ExportImportTab(),
                  _Tab.deleteOrg    => const _DeleteOrgTab(),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    return Material(
      color: selected ? ext.overlayActive : Colors.transparent,
      borderRadius: BorderRadius.circular(LinearRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        overlayColor: WidgetStatePropertyAll(ext.overlay),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm,
            vertical: 6,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? ext.textPrimary : ext.textMuted,
              ),
              const SizedBox(width: LinearSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? ext.textPrimary : ext.textSecondary,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme tab ─────────────────────────────────────────────────────────────────

class _ThemeTab extends ConsumerWidget {
  const _ThemeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent        = ref.watch(accentColorProvider);
    final themeMode     = ref.watch(themeModeProvider);
    final darkShadeIdx  = ref.watch(darkShadeProvider);
    final lightShadeIdx = ref.watch(lightShadeProvider);
    final fontFamily    = ref.watch(fontFamilyProvider);
    final fontSizeIdx   = ref.watch(fontSizeProvider);
    final ext           = context.linearExt;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Appearance', style: context.text.titleMedium),
          const SizedBox(height: LinearSpacing.md),

          // ── Mode ──────────────────────────────────────────────────────────
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LinearSpacing.md,
                  vertical: LinearSpacing.base,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Color mode',
                              style: context.text.bodySmall?.copyWith(
                                color: ext.textPrimary,
                                fontWeight: FontWeight.w500,
                              )),
                          const SizedBox(height: 2),
                          Text('Choose light, dark, or follow system setting.',
                              style: context.text.labelMedium?.copyWith(
                                color: ext.textMuted,
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(width: LinearSpacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ModeButton(
                          icon: Icons.light_mode_outlined,
                          label: 'Light',
                          selected: themeMode == ThemeMode.light,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.light),
                        ),
                        const SizedBox(width: LinearSpacing.xs),
                        _ModeButton(
                          icon: Icons.dark_mode_outlined,
                          label: 'Dark',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.dark),
                        ),
                        const SizedBox(width: LinearSpacing.xs),
                        _ModeButton(
                          icon: Icons.brightness_auto_outlined,
                          label: 'System',
                          selected: themeMode == ThemeMode.system,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(ThemeMode.system),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: LinearSpacing.md),

          // ── Surface shades ────────────────────────────────────────────────
          _SettingsCard(
            children: [
              _ShadeRow(
                label: 'Dark base',
                description: 'Background depth when in dark mode.',
                presets: kDarkShadePresets,
                selectedIndex: darkShadeIdx,
                onSelect: (i) =>
                    ref.read(darkShadeProvider.notifier).setShade(i),
              ),
              _ShadeRow(
                label: 'Light base',
                description: 'Background tone when in light mode.',
                presets: kLightShadePresets,
                selectedIndex: lightShadeIdx,
                onSelect: (i) =>
                    ref.read(lightShadeProvider.notifier).setShade(i),
              ),
            ],
          ),

          const SizedBox(height: LinearSpacing.md),

          // ── Typography ────────────────────────────────────────────────────
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Police',
                description: 'Typographie utilisée dans toute l\'interface.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final preset in kFontPresets)
                      _FontButton(
                        label: preset.label,
                        family: preset.family,
                        selected: fontFamily == preset.family,
                        onTap: () => ref
                            .read(fontFamilyProvider.notifier)
                            .setFamily(preset.family),
                      ),
                  ],
                ),
              ),
              _SettingsRow(
                label: 'Taille',
                description: 'Taille de base du texte dans l\'interface.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < kFontSizePresets.length; i++)
                      _SizeButton(
                        label: kFontSizePresets[i].label,
                        selected: fontSizeIdx == i,
                        onTap: () =>
                            ref.read(fontSizeProvider.notifier).setSize(i),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: LinearSpacing.md),

          // ── Accent color ──────────────────────────────────────────────────
          _SettingsCard(
            children: [
              _SettingsRow(
                label: 'Accent color',
                description: 'Buttons, links, and interactive highlights.',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final preset in kAccentPresets)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: LinearSpacing.xs,
                        ),
                        child: _ColorSwatch(
                          color: preset.color,
                          label: preset.label,
                          selected: accent == preset.color,
                          onTap: () => ref
                              .read(accentColorProvider.notifier)
                              .setAccent(preset.color),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mode button ───────────────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext    = context.linearExt;
    final accent = context.colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : ext.surfaceRaised,
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border: Border.all(
            color: selected ? accent : ext.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? accent : ext.textMuted,
            ),
            const SizedBox(width: LinearSpacing.xs),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: selected ? accent : ext.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shade row + swatch ────────────────────────────────────────────────────────

class _ShadeRow extends StatelessWidget {
  const _ShadeRow({
    required this.label,
    required this.description,
    required this.presets,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String label;
  final String description;
  final List<LinearShadePreset> presets;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.md,
        vertical: LinearSpacing.base,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.text.bodySmall?.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(description,
                    style: context.text.labelMedium
                        ?.copyWith(color: ext.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: LinearSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < presets.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: _ShadeSwatch(
                    color: presets[i].pageBg,
                    label: presets[i].label,
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShadeSwatch extends StatelessWidget {
  const _ShadeSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    final ext    = context.linearExt;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            border: Border.all(
              color: selected ? accent : ext.borderBase,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = context.linearExt.textPrimary;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? ringColor : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]
                : null,
          ),
        ),
      ),
    );
  }
}

// ── Font button ───────────────────────────────────────────────────────────────

class _FontButton extends StatelessWidget {
  const _FontButton({
    required this.label,
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String family;
  final bool selected;
  final VoidCallback onTap;

  TextStyle _fontStyle(bool selected) {
    final w = selected ? FontWeight.w600 : FontWeight.w400;
    switch (family) {
      case 'DM Sans':           return GoogleFonts.dmSans(fontSize: 12, fontWeight: w);
      case 'Plus Jakarta Sans': return GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: w);
      case 'IBM Plex Sans':     return GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: w);
      case 'Roboto':            return GoogleFonts.roboto(fontSize: 12, fontWeight: w);
      default:                  return GoogleFonts.inter(fontSize: 12, fontWeight: w);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext    = context.linearExt;
    final accent = context.colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsetsDirectional.only(start: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : ext.surfaceRaised,
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border: Border.all(
            color: selected ? accent : ext.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: _fontStyle(selected).copyWith(
            color: selected ? accent : ext.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Size button ───────────────────────────────────────────────────────────────

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext    = context.linearExt;
    final accent = context.colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsetsDirectional.only(start: LinearSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : ext.surfaceRaised,
          borderRadius: BorderRadius.circular(LinearRadii.md),
          border: Border.all(
            color: selected ? accent : ext.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: selected ? accent : ext.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Org Info tab ──────────────────────────────────────────────────────────────

class _OrgInfoTab extends ConsumerStatefulWidget {
  const _OrgInfoTab();

  @override
  ConsumerState<_OrgInfoTab> createState() => _OrgInfoTabState();
}

class _OrgInfoTabState extends ConsumerState<_OrgInfoTab> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _taxIdCtrl  = TextEditingController();
  final _logoCtrl   = TextEditingController();
  final _rcNumberCtrl  = TextEditingController();
  final _rneNumberCtrl = TextEditingController();
  final _bankNameCtrl  = TextEditingController();
  final _bankRibCtrl   = TextEditingController();
  final _bankIbanCtrl  = TextEditingController();
  final _bankBicCtrl   = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();

  String  _currency = 'USD';
  String  _timezone = 'UTC';
  bool    _dirty    = false;
  bool    _saving   = false;
  bool    _saved    = false;
  String? _orgId;
  bool    _uploadingLogo   = false;
  String? _logoUploadError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _taxIdCtrl.dispose();
    _logoCtrl.dispose();
    _rcNumberCtrl.dispose();
    _rneNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankRibCtrl.dispose();
    _bankIbanCtrl.dispose();
    _bankBicCtrl.dispose();
    _paymentTermsCtrl.dispose();
    super.dispose();
  }

  void _initFrom(OrgDetails org) {
    _orgId = org.id;
    _nameCtrl.text    = org.name;
    _addressCtrl.text = org.address  ?? '';
    _countryCtrl.text = org.country  ?? '';
    _phoneCtrl.text   = org.phone    ?? '';
    _emailCtrl.text   = org.email    ?? '';
    _websiteCtrl.text = org.website  ?? '';
    _taxIdCtrl.text   = org.taxId    ?? '';
    _logoCtrl.text    = org.logoUrl  ?? '';
    _rcNumberCtrl.text     = org.rcNumber            ?? '';
    _rneNumberCtrl.text    = org.rneNumber           ?? '';
    _bankNameCtrl.text     = org.bankName            ?? '';
    _bankRibCtrl.text      = org.bankRib             ?? '';
    _bankIbanCtrl.text     = org.bankIban            ?? '';
    _bankBicCtrl.text      = org.bankBic             ?? '';
    _paymentTermsCtrl.text = org.defaultPaymentTerms ?? '';
    _currency = org.currency;
    _timezone = org.timezone ?? 'UTC';
    _dirty    = false;
    _saved    = false;
  }

  void _discard(OrgDetails org) {
    _orgId = null; // force re-init
    _initFrom(org);
    setState(() {});
  }

  /// S-8: allowed image signatures (magic bytes).
  static const _allowedMimes = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'};

  static const _magicBytes = <String, List<int>>{
    'image/jpeg': [0xFF, 0xD8, 0xFF],
    'image/png':  [0x89, 0x50, 0x4E, 0x47],
    'image/gif':  [0x47, 0x49, 0x46, 0x38],
    'image/webp': [0x52, 0x49, 0x46, 0x46],  // 'RIFF'
  };

  bool _hasValidMagicBytes(List<int> bytes, String mime) {
    final sig = _magicBytes[mime];
    if (sig == null || bytes.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[i] != sig[i]) return false;
    }
    return true;
  }

  Future<void> _pickAndUploadLogo() async {
    final picked = await img_picker.pickImageBytes();
    if (picked == null || !mounted) return;

    setState(() { _uploadingLogo = true; _logoUploadError = null; });

    // S-8: validate MIME against allowlist and verify magic bytes.
    if (!_allowedMimes.contains(picked.mimeType)) {
      if (mounted) setState(() { _uploadingLogo = false; _logoUploadError = 'Only JPEG, PNG, GIF and WebP images are allowed.'; });
      return;
    }
    if (!_hasValidMagicBytes(picked.bytes, picked.mimeType)) {
      if (mounted) setState(() { _uploadingLogo = false; _logoUploadError = 'File content does not match its type. Please use a real image.'; });
      return;
    }

    try {
      final supabase = ref.read(supabaseClientProvider);
      final ext = picked.mimeType.split('/').last;
      final path = '${_orgId!}/logo.$ext';
      await supabase.storage.from('org-logos').uploadBinary(
        path,
        picked.bytes,
        fileOptions: FileOptions(contentType: picked.mimeType, upsert: true),
      );
      final url = supabase.storage.from('org-logos').getPublicUrl(path);
      if (!mounted) return;
      setState(() {
        _logoCtrl.text = url;
        _dirty          = true;
        _saved          = false;
        _uploadingLogo  = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingLogo   = false;
          _logoUploadError = e.toString();
        });
      }
    }
  }

  Future<void> _save(OrgDetails org) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _saved = false; });
    try {
      String? nullable(String s) => s.trim().isEmpty ? null : s.trim();
      await ref.read(orgRepositoryProvider).updateOrgDetails(org.id, {
        'name':     _nameCtrl.text.trim(),
        'address':  nullable(_addressCtrl.text),
        'country':  nullable(_countryCtrl.text),
        'phone':    nullable(_phoneCtrl.text),
        'email':    nullable(_emailCtrl.text),
        'website':  nullable(_websiteCtrl.text),
        'tax_id':   nullable(_taxIdCtrl.text),
        'logo_url': nullable(_logoCtrl.text),
        'currency': _currency,
        'timezone': _timezone,
        'rc_number':             nullable(_rcNumberCtrl.text),
        'rne_number':            nullable(_rneNumberCtrl.text),
        'bank_name':             nullable(_bankNameCtrl.text),
        'bank_rib':              nullable(_bankRibCtrl.text),
        'bank_iban':             nullable(_bankIbanCtrl.text),
        'bank_bic':              nullable(_bankBicCtrl.text),
        'default_payment_terms': nullable(_paymentTermsCtrl.text),
      });
      if (!mounted) return;
      ref.invalidate(orgDetailsProvider);
      ref.invalidate(userOrgsProvider);
      ref.invalidate(currentOrgMembershipProvider);
      setState(() { _dirty = false; _saving = false; _saved = true; });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext       = context.linearExt;
    final orgAsync  = ref.watch(orgDetailsProvider);
    final membership = ref.watch(currentOrgMembershipProvider);
    final canEdit   = membership.value?.role.canEdit ?? false;

    return orgAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Failed to load org: $e',
            style: TextStyle(color: ext.textMuted))),
      data: (org) {
        if (org == null) return const SizedBox.shrink();
        if (_orgId != org.id) _initFrom(org);

        return Form(
          key: _formKey,
          onChanged: () => setState(() { _dirty = true; _saved = false; }),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LinearSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organization', style: context.text.titleMedium),
                const SizedBox(height: LinearSpacing.md),

                // ── General ───────────────────────────────────────────────────
                _SettingsCard(
                  children: [
                    _OrgFieldRow(
                      label: 'Name',
                      description: 'Legal name shown on invoices and documents.',
                      child: TextFormField(
                        controller: _nameCtrl,
                        enabled: canEdit,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            hintText: 'Acme Corp', isDense: true),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Logo',
                      description: 'Upload your organization logo.',
                      child: _LogoPickerRow(
                        logoUrl: _logoCtrl.text.isNotEmpty
                            ? _logoCtrl.text
                            : null,
                        uploading: _uploadingLogo,
                        error: _logoUploadError,
                        enabled: canEdit,
                        onPick: _pickAndUploadLogo,
                        onClear: canEdit
                            ? () => setState(() {
                                  _logoCtrl.text = '';
                                  _dirty = true;
                                  _saved = false;
                                })
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: LinearSpacing.md),
                Text('Location & Contact',
                    style: context.text.titleSmall?.copyWith(
                        color: ext.textSecondary)),
                const SizedBox(height: LinearSpacing.sm),

                // ── Location & Contact ────────────────────────────────────────
                _SettingsCard(
                  children: [
                    _OrgFieldRow(
                      label: 'Country',
                      child: TextFormField(
                        controller: _countryCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'Morocco', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Address',
                      description: 'Street, city, postal code.',
                      child: TextFormField(
                        controller: _addressCtrl,
                        enabled: canEdit,
                        maxLines: 3,
                        minLines: 2,
                        decoration: const InputDecoration(
                            hintText: '123 Main St\nCasablanca, 20000',
                            isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Phone',
                      child: TextFormField(
                        controller: _phoneCtrl,
                        enabled: canEdit,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                            hintText: '+1 555 000 0000', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Email',
                      description: 'Appears on invoices as reply-to.',
                      child: TextFormField(
                        controller: _emailCtrl,
                        enabled: canEdit,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                            hintText: 'info@acme.com', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Website',
                      child: TextFormField(
                        controller: _websiteCtrl,
                        enabled: canEdit,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                            hintText: 'https://acme.com', isDense: true),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: LinearSpacing.md),
                Text('Financial & Regional',
                    style: context.text.titleSmall?.copyWith(
                        color: ext.textSecondary)),
                const SizedBox(height: LinearSpacing.sm),

                // ── Financial & Regional ──────────────────────────────────────
                _SettingsCard(
                  children: [
                    _OrgFieldRow(
                      label: 'Currency',
                      description: 'Default currency for all transactions.',
                      child: SearchPickerField(
                        value: '$_currency — ${currencyName(_currency) ?? _currency}',
                        hint: 'Select currency',
                        enabled: canEdit,
                        onTap: () async {
                          final picked = await showSearchPicker(
                            context: context,
                            title: 'Select currency',
                            current: _currency,
                            options: kAllCurrencies
                                .map((c) => (
                                      value: c.code,
                                      label: '${c.code} — ${c.name}',
                                    ))
                                .toList(),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _currency = picked;
                              _dirty = true;
                              _saved = false;
                            });
                          }
                        },
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'VAT / Tax ID',
                      description:
                          'Printed on invoices in the legal notice section.',
                      child: TextFormField(
                        controller: _taxIdCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'FR 00 123456789', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Timezone',
                      description: 'Used for dates and scheduling.',
                      child: SearchPickerField(
                        value: _timezone,
                        hint: 'Select timezone',
                        enabled: canEdit,
                        onTap: () async {
                          final picked = await showSearchPicker(
                            context: context,
                            title: 'Select timezone',
                            current: _timezone,
                            options: kAllTimezones
                                .map((tz) => (value: tz, label: tz))
                                .toList(),
                          );
                          if (picked != null && mounted) {
                            setState(() {
                              _timezone = picked;
                              _dirty = true;
                              _saved = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: LinearSpacing.md),
                Text('Legal & Banking (Tunisia)',
                    style: context.text.titleSmall?.copyWith(
                        color: ext.textSecondary)),
                const SizedBox(height: LinearSpacing.sm),

                // ── Legal & Banking ────────────────────────────────────────────
                _SettingsCard(
                  children: [
                    _OrgFieldRow(
                      label: 'RC number',
                      description: 'Registre de Commerce — printed on documents.',
                      child: TextFormField(
                        controller: _rcNumberCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'B 123456 2015', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'RNE number',
                      child: TextFormField(
                        controller: _rneNumberCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'J12345678', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Bank name',
                      child: TextFormField(
                        controller: _bankNameCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'Banque de Tunisie (BT)', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'RIB',
                      child: TextFormField(
                        controller: _bankRibCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: '08 006 0123456789 12', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'IBAN',
                      child: TextFormField(
                        controller: _bankIbanCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'TN59 08 006 0123456789 12', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'BIC',
                      child: TextFormField(
                        controller: _bankBicCtrl,
                        enabled: canEdit,
                        decoration: const InputDecoration(
                            hintText: 'BTUNTNTT', isDense: true),
                      ),
                    ),
                    _OrgFieldRow(
                      label: 'Default payment terms',
                      description: 'Shown on quotes/invoices unless overridden.',
                      child: TextFormField(
                        controller: _paymentTermsCtrl,
                        enabled: canEdit,
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                            hintText: 'Paiement à 30 jours date de facture.',
                            isDense: true),
                      ),
                    ),
                  ],
                ),

                // ── Save / discard bar ────────────────────────────────────────
                const SizedBox(height: LinearSpacing.lg),
                if (_saved)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(bottom: LinearSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 14, color: LinearColors.success),
                        const SizedBox(width: LinearSpacing.xs),
                        Text('Saved',
                            style: context.text.labelMedium
                                ?.copyWith(color: LinearColors.success)),
                      ],
                    ),
                  ),
                if (!canEdit)
                  Text(
                    'You need admin access or higher to edit org settings.',
                    style: context.text.labelMedium
                        ?.copyWith(color: ext.textMuted),
                  )
                else
                  Row(
                    children: [
                      FilledButton(
                        onPressed:
                            (!_dirty || _saving) ? null : () => _save(org),
                        child: _saving
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.5, color: Colors.white),
                              )
                            : const Text('Save changes'),
                      ),
                      if (_dirty) ...[
                        const SizedBox(width: LinearSpacing.sm),
                        TextButton(
                          onPressed: _saving ? null : () => _discard(org),
                          child: const Text('Discard'),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Logo picker row ───────────────────────────────────────────────────────────

class _LogoPickerRow extends StatelessWidget {
  const _LogoPickerRow({
    required this.logoUrl,
    required this.uploading,
    required this.error,
    required this.enabled,
    required this.onPick,
    this.onClear,
  });

  final String?      logoUrl;
  final bool         uploading;
  final String?      error;
  final bool         enabled;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ext.surfaceRaised,
            borderRadius: BorderRadius.circular(LinearRadii.sm),
            border: Border.all(color: ext.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: logoUrl != null
              ? Image.network(
                  logoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, e, _) => Icon(
                    Icons.broken_image_outlined,
                    size: 20,
                    color: ext.textMuted,
                  ),
                )
              : Icon(Icons.image_outlined, size: 20, color: ext.textMuted),
        ),
        const SizedBox(width: LinearSpacing.sm),
        if (uploading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.upload_outlined, size: 14),
            label: Text(
              logoUrl != null ? 'Change' : 'Upload logo',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: context.text.labelMedium,
            ),
          ),
          if (logoUrl != null && onClear != null) ...[
            const SizedBox(width: LinearSpacing.xs),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 14),
              color: ext.textMuted,
              tooltip: 'Remove logo',
              style: IconButton.styleFrom(
                minimumSize: const Size(28, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
        if (error != null) ...[
          const SizedBox(width: LinearSpacing.sm),
          Text(
            error!,
            style: context.text.labelMedium
                ?.copyWith(color: LinearColors.danger),
          ),
        ],
      ],
    );
  }
}

// ── Org field row ─────────────────────────────────────────────────────────────

class _OrgFieldRow extends StatelessWidget {
  const _OrgFieldRow({
    required this.label,
    required this.child,
    this.description,
  });

  final String  label;
  final String? description;
  final Widget  child;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.md,
        vertical: LinearSpacing.base,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 148,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(
                    color: ext.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style:
                        context.text.labelMedium?.copyWith(color: ext.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: LinearSpacing.md),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Quote / Invoice tab ───────────────────────────────────────────────────────

class _QuoteInvoiceTab extends ConsumerStatefulWidget {
  const _QuoteInvoiceTab();

  @override
  ConsumerState<_QuoteInvoiceTab> createState() => _QuoteInvoiceTabState();
}

class _QuoteInvoiceTabState extends ConsumerState<_QuoteInvoiceTab> {
  final _defaultNoteCtrl = TextEditingController();

  bool    _enableFodec        = false;
  bool    _enableTimbreFiscal = false;
  bool    _enableRetenuSource = false;
  bool    _dirty  = false;
  bool    _saving = false;
  bool    _saved  = false;
  String? _orgId;

  @override
  void dispose() {
    _defaultNoteCtrl.dispose();
    super.dispose();
  }

  void _initFrom(OrgDetails org) {
    _orgId              = org.id;
    _enableFodec        = org.enableFodec;
    _enableTimbreFiscal = org.enableTimbreFiscal;
    _enableRetenuSource = org.enableRetenuSource;
    _defaultNoteCtrl.text = org.defaultQuoteNotes ?? '';
    _dirty = false;
    _saved = false;
  }

  void _discard(OrgDetails org) {
    _orgId = null;
    _initFrom(org);
    setState(() {});
  }

  Future<void> _save(OrgDetails org) async {
    setState(() { _saving = true; _saved = false; });
    try {
      String? nullable(String s) => s.trim().isEmpty ? null : s.trim();
      await ref.read(orgRepositoryProvider).updateOrgDetails(org.id, {
        'enable_fodec':         _enableFodec,
        'enable_timbre_fiscal': _enableTimbreFiscal,
        'enable_retenu_source': _enableRetenuSource,
        'default_quote_notes':  nullable(_defaultNoteCtrl.text),
      });
      if (!mounted) return;
      ref.invalidate(orgDetailsProvider);
      setState(() { _dirty = false; _saving = false; _saved = true; });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markDirty() => setState(() { _dirty = true; _saved = false; });

  Future<void> _showBuilder({PaymentTermTemplate? template}) async {
    if (!mounted) return;
    final input = await showPaymentTermBuilder(context, initial: template);
    if (input == null || !mounted) return;
    if (template == null) {
      await ref.read(paymentTermsProvider.notifier).create(input);
    } else {
      await ref.read(paymentTermsProvider.notifier).save(template.id, input);
    }
  }

  Future<void> _deleteTemplate(String id) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.linearExt.surfaceBase,
        title: Text('Delete payment term?',
            style: context.text.titleSmall),
        content: Text(
          'Existing quotes already saved will not be affected.',
          style: context.text.bodySmall?.copyWith(
              color: context.linearExt.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: LinearColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(paymentTermsProvider.notifier).delete(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext        = context.linearExt;
    final orgAsync   = ref.watch(orgDetailsProvider);
    final membership = ref.watch(currentOrgMembershipProvider);
    final canEdit    = membership.value?.role.canEdit ?? false;

    return orgAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Failed to load org: $e',
              style: TextStyle(color: ext.textMuted))),
      data: (org) {
        if (org == null) return const SizedBox.shrink();
        if (_orgId != org.id) _initFrom(org);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(LinearSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quote / Invoice', style: context.text.titleMedium),
              const SizedBox(height: LinearSpacing.md),

              // ── Taxes (Tunisia) ───────────────────────────────────────────────
              Text('Taxes (Tunisia)',
                  style: context.text.titleSmall
                      ?.copyWith(color: ext.textSecondary)),
              const SizedBox(height: LinearSpacing.sm),
              _SettingsCard(
                children: [
                  _TaxToggleRow(
                    label: 'FODEC',
                    description:
                        'Applies to lines flagged FODEC, added to the TVA base.',
                    value: _enableFodec,
                    enabled: canEdit,
                    onChanged: (v) { setState(() => _enableFodec = v); _markDirty(); },
                  ),
                  _TaxToggleRow(
                    label: 'Timbre fiscal',
                    description: 'Flat stamp duty added to the TTC total.',
                    value: _enableTimbreFiscal,
                    enabled: canEdit,
                    onChanged: (v) { setState(() => _enableTimbreFiscal = v); _markDirty(); },
                  ),
                  _TaxToggleRow(
                    label: 'Retenue à la source (RS)',
                    description: 'Deducted from TTC to compute the net-à-payer.',
                    value: _enableRetenuSource,
                    enabled: canEdit,
                    onChanged: (v) { setState(() => _enableRetenuSource = v); _markDirty(); },
                  ),
                ],
              ),

              const SizedBox(height: LinearSpacing.md),

              // ── Payment Terms ──────────────────────────────────────────────────
              Builder(builder: (context) {
                final termsAsync = ref.watch(paymentTermsProvider);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment Terms',
                                  style: context.text.titleSmall
                                      ?.copyWith(color: ext.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                'Define the standard payment schedules available when creating a quote.',
                                style: context.text.bodySmall
                                    ?.copyWith(color: ext.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (canEdit)
                          TextButton.icon(
                            onPressed: () => _showBuilder(),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('New Payment Term'),
                            style: TextButton.styleFrom(
                              foregroundColor: LinearColors.accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: LinearSpacing.sm),
                    termsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(LinearSpacing.md),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Failed to load: $e',
                          style: context.text.bodySmall
                              ?.copyWith(color: LinearColors.danger)),
                      data: (terms) => terms.isEmpty
                          ? _SettingsCard(children: [
                              Padding(
                                padding: const EdgeInsets.all(LinearSpacing.md),
                                child: Text(
                                  'No payment terms defined. Add one to get started.',
                                  style: context.text.bodySmall
                                      ?.copyWith(color: ext.textMuted),
                                ),
                              ),
                            ])
                          : Column(
                              children: terms
                                  .map((t) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: LinearSpacing.sm),
                                        child: _PaymentTermCard(
                                          template: t,
                                          canEdit:  canEdit,
                                          onEdit:   () => _showBuilder(template: t),
                                          onDelete: () => _deleteTemplate(t.id),
                                          ext:      ext,
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: LinearSpacing.md),

              // ── Default Note ───────────────────────────────────────────────────
              Text('Default Note',
                  style: context.text.titleSmall
                      ?.copyWith(color: ext.textSecondary)),
              const SizedBox(height: LinearSpacing.xs),
              Text(
                'Pre-filled on the Notes field of every new quote.',
                style: context.text.bodySmall?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: LinearSpacing.sm),
              _SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(LinearSpacing.md),
                    child: TextFormField(
                      controller: _defaultNoteCtrl,
                      enabled: canEdit,
                      maxLines: 4,
                      minLines: 3,
                      onChanged: (_) => _markDirty(),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Goods remain property of seller until payment received in full.',
                        hintStyle: context.text.bodySmall
                            ?.copyWith(color: ext.textMuted),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Save / discard bar ────────────────────────────────────────────
              const SizedBox(height: LinearSpacing.lg),
              if (_saved)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      bottom: LinearSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 14, color: LinearColors.success),
                      const SizedBox(width: LinearSpacing.xs),
                      Text('Saved',
                          style: context.text.labelMedium
                              ?.copyWith(color: LinearColors.success)),
                    ],
                  ),
                ),
              if (!canEdit)
                Text(
                  'You need admin access or higher to edit org settings.',
                  style: context.text.labelMedium
                      ?.copyWith(color: ext.textMuted),
                )
              else
                Row(
                  children: [
                    FilledButton(
                      onPressed:
                          (!_dirty || _saving) ? null : () => _save(org),
                      child: _saving
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: Colors.white),
                            )
                          : const Text('Save changes'),
                    ),
                    if (_dirty) ...[
                      const SizedBox(width: LinearSpacing.sm),
                      TextButton(
                        onPressed: _saving ? null : () => _discard(org),
                        child: const Text('Discard'),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tax toggle row ────────────────────────────────────────────────────────────

class _TaxToggleRow extends StatelessWidget {
  const _TaxToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String  label;
  final String  description;
  final bool    value;
  final bool    enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.md,
        vertical: LinearSpacing.base,
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 0.72,
            alignment: Alignment.centerLeft,
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.bodySmall?.copyWith(
                    color: ext.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: context.text.labelMedium
                      ?.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment term card ─────────────────────────────────────────────────────────

class _PaymentTermCard extends StatelessWidget {
  const _PaymentTermCard({
    required this.template,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.ext,
  });

  final PaymentTermTemplate template;
  final bool        canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final LinearExt   ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        ext.surfaceBase,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border:       Border.all(color: ext.borderSubtle),
      ),
      padding: const EdgeInsets.all(LinearSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  style: context.text.bodySmall?.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              if (canEdit) ...[
                _ActionChip(
                  label: 'Edit',
                  onTap: onEdit,
                  ext: ext,
                ),
                const SizedBox(width: LinearSpacing.xs),
                _ActionChip(
                  label: 'Delete',
                  onTap: onDelete,
                  ext: ext,
                  danger: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: LinearSpacing.xs),
          ...template.installments.map((inst) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsetsDirectional.only(
                          end: LinearSpacing.xs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ext.textMuted,
                      ),
                    ),
                    Text(
                      '${inst.percent}% — ${inst.label}',
                      style: context.text.bodySmall
                          ?.copyWith(color: ext.textSecondary),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onTap,
    required this.ext,
    this.danger = false,
  });

  final String     label;
  final VoidCallback onTap;
  final LinearExt  ext;
  final bool       danger;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: LinearSpacing.sm, vertical: 3),
            decoration: BoxDecoration(
              color:        ext.surfaceRaised,
              borderRadius: BorderRadius.circular(LinearRadii.xs),
              border:       Border.all(color: ext.borderSubtle),
            ),
            child: Text(
              label,
              style: context.text.labelSmall?.copyWith(
                  color: danger ? LinearColors.danger : ext.textSecondary),
            ),
          ),
        ),
      );
}

// ── Delete Org tab ────────────────────────────────────────────────────────────

class _DeleteOrgTab extends ConsumerStatefulWidget {
  const _DeleteOrgTab();

  @override
  ConsumerState<_DeleteOrgTab> createState() => _DeleteOrgTabState();
}

class _DeleteOrgTabState extends ConsumerState<_DeleteOrgTab> {
  bool _deleting = false;

  Future<void> _handleDelete() async {
    final membership = ref.read(currentOrgMembershipProvider).value;
    if (membership == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDeleteDialog(orgName: membership.orgName),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(orgRepositoryProvider).deleteOrg(membership.orgId);
      if (!mounted) return;
      await ref.read(currentOrgIdProvider.notifier).clear();
      if (mounted) context.go('/org');
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext        = context.linearExt;
    final membership = ref.watch(currentOrgMembershipProvider);
    final orgName    = membership.value?.orgName ?? '…';
    final isOwner    = membership.value?.role.name == 'owner';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(LinearSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danger zone', style: context.text.titleMedium),
          const SizedBox(height: LinearSpacing.md),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: LinearColors.danger.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(LinearRadii.md),
            ),
            child: _SettingsRow(
              label: 'Delete organization',
              description:
                  'Permanently delete "$orgName" and all its data. '
                  'This cannot be undone.',
              trailing: FilledButton(
                onPressed: (!isOwner || _deleting) ? null : _handleDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: LinearColors.danger,
                  disabledBackgroundColor:
                      LinearColors.danger.withValues(alpha: 0.4),
                ),
                child: _deleting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Delete org'),
              ),
            ),
          ),
          if (!isOwner) ...[
            const SizedBox(height: LinearSpacing.sm),
            Text(
              'Only the org owner can delete the organization.',
              style: context.text.labelMedium?.copyWith(color: ext.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Export / Import tab ───────────────────────────────────────────────────────

class _ExportImportTab extends ConsumerStatefulWidget {
  const _ExportImportTab();

  @override
  ConsumerState<_ExportImportTab> createState() => _ExportImportTabState();
}

class _ExportImportTabState extends ConsumerState<_ExportImportTab> {
  final _rootCtrl = TextEditingController();

  bool _loaded = false;
  bool _dirty  = false;
  bool _saving = false;
  bool _saved  = false;

  @override
  void dispose() {
    _rootCtrl.dispose();
    super.dispose();
  }

  void _initFrom(ExportPrefs prefs) {
    _rootCtrl.text = prefs.rootFolder ?? '';
    _loaded = true;
    _dirty  = false;
    _saved  = false;
  }

  void _markDirty() => setState(() { _dirty = true; _saved = false; });

  Future<void> _pickFolder() async {
    final path = await folder_picker.pickFolder();
    if (path != null && mounted) {
      _rootCtrl.text = path;
      _markDirty();
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _saved = false; });
    try {
      await saveExportRoot(_rootCtrl.text);
      ref.invalidate(exportPrefsProvider);
      if (mounted) setState(() { _saving = false; _dirty = false; _saved = true; });
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext        = context.linearExt;
    final prefsAsync = ref.watch(exportPrefsProvider);

    return prefsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data: (prefs) {
        if (!_loaded) _initFrom(prefs);

        // Compute preview paths from whatever is in the text field right now.
        final root      = _rootCtrl.text.trim();
        final hasRoot   = root.isNotEmpty;
        final preview   = hasRoot ? ExportPrefs(rootFolder: root) : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(LinearSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export / Import', style: context.text.titleMedium),
              const SizedBox(height: LinearSpacing.md),

              // ── Platform note (web only) ───────────────────────────────────
              if (!file_saver.canSaveToFolder)
                Container(
                  margin: const EdgeInsetsDirectional.only(bottom: LinearSpacing.md),
                  padding: const EdgeInsets.symmetric(
                    horizontal: LinearSpacing.md,
                    vertical: LinearSpacing.base,
                  ),
                  decoration: BoxDecoration(
                    color:        ext.surfaceBase,
                    borderRadius: BorderRadius.circular(LinearRadii.md),
                    border:       Border.all(color: ext.borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: ext.textMuted),
                      const SizedBox(width: LinearSpacing.sm),
                      Expanded(
                        child: Text(
                          'On web, your browser controls the download location. '
                          'Folder configuration applies when running on Windows or macOS.',
                          style: context.text.labelMedium
                              ?.copyWith(color: ext.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),

              if (file_saver.canSaveToFolder) ...[
                // ── Root folder ──────────────────────────────────────────────
                Text(
                  'Export root folder',
                  style: context.text.titleSmall?.copyWith(color: ext.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quotes and Invoices subfolders are created automatically inside this folder.',
                  style: context.text.labelMedium?.copyWith(color: ext.textMuted),
                ),
                const SizedBox(height: LinearSpacing.sm),

                _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: LinearSpacing.md,
                        vertical: LinearSpacing.base,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rootCtrl,
                              readOnly:   true,
                              onChanged:  (_) => _markDirty(),
                              decoration: InputDecoration(
                                hintText: r'e.g. C:\Users\You\Documents\ERP',
                                isDense:  true,
                                prefixIcon: const Icon(Icons.folder_outlined, size: 16),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                            ),
                          ),
                          const SizedBox(width: LinearSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: _pickFolder,
                            icon: const Icon(Icons.drive_folder_upload_outlined, size: 14),
                            label: const Text('Browse…'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              textStyle: context.text.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Subfolder preview
                    if (preview != null)
                      Container(
                        decoration: BoxDecoration(
                          color: ext.surfaceRaised,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(LinearRadii.md)),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: LinearSpacing.md,
                          vertical: LinearSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SubfolderLine(
                              icon:  Icons.description_outlined,
                              label: 'Quotes',
                              path:  preview.quotesFolder!,
                              ext:   ext,
                            ),
                            const SizedBox(height: 4),
                            _SubfolderLine(
                              icon:  Icons.receipt_outlined,
                              label: 'Invoices',
                              path:  preview.invoicesFolder!,
                              ext:   ext,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // ── Save bar ─────────────────────────────────────────────────
                const SizedBox(height: LinearSpacing.lg),
                if (_saved)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: LinearSpacing.sm),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 14, color: LinearColors.success),
                        const SizedBox(width: LinearSpacing.xs),
                        Text('Saved',
                            style: context.text.labelMedium
                                ?.copyWith(color: LinearColors.success)),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    FilledButton(
                      onPressed: (!_dirty || _saving) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 12, height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: Colors.white),
                            )
                          : const Text('Save changes'),
                    ),
                    if (_dirty) ...[
                      const SizedBox(width: LinearSpacing.sm),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() { _loaded = false; _dirty = false; }),
                        child: const Text('Discard'),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Subfolder preview line ────────────────────────────────────────────────────

class _SubfolderLine extends StatelessWidget {
  const _SubfolderLine({
    required this.icon,
    required this.label,
    required this.path,
    required this.ext,
  });

  final IconData  icon;
  final String    label;
  final String    path;
  final LinearExt ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ext.textMuted),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: context.text.labelMedium?.copyWith(
            color:      ext.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            path,
            style: context.text.labelMedium?.copyWith(color: ext.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog({required this.orgName});
  final String orgName;

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _ctrl = TextEditingController();
  bool get _matches => _ctrl.text.trim() == widget.orgName;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete organization'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete "${widget.orgName}" and all '
              'associated data including contacts, deals, invoices, and '
              'projects. This action cannot be undone.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: LinearSpacing.md),
            Text(
              'Type the organization name to confirm:',
              style: context.text.labelMedium?.copyWith(
                color: context.linearExt.textSecondary,
              ),
            ),
            const SizedBox(height: LinearSpacing.sm),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: widget.orgName),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: LinearColors.danger,
            disabledBackgroundColor:
                LinearColors.danger.withValues(alpha: 0.4),
          ),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}

// ── Shared layout widgets ─────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Container(
      decoration: BoxDecoration(
        color: ext.surfaceBase,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border: Border.all(color: ext.borderSubtle),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: LinearSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.description,
    required this.trailing,
  });

  final String label;
  final String description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LinearSpacing.md,
        vertical: LinearSpacing.base,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.text.bodySmall?.copyWith(
                      color: ext.textPrimary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(description,
                    style: context.text.labelMedium
                        ?.copyWith(color: ext.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: LinearSpacing.md),
          trailing,
        ],
      ),
    );
  }
}
