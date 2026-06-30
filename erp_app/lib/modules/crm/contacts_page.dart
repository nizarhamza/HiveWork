import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/view_prefs_service.dart';
import '../../data/models/contact.dart';
import '../../data/models/custom_field.dart';
import '../../data/providers/contacts_provider.dart';
import '../../data/providers/custom_fields_provider.dart';
import '../../shell/widgets/linear_view_header.dart';
import '../../shell/widgets/resizable_pane_layout.dart';
import '../../theme/linear_tokens.dart';
import '../../ui/molecules/app_empty_state.dart';
import '../../ui/molecules/app_skeleton.dart';
import '../../ui/organisms/app_data_table.dart';
import 'contact_detail_pane.dart';
import 'contact_form_dialog.dart';
import 'crm_commands.dart';
import 'manage_fields_dialog.dart';

const double _kSplitBreak   = 840.0;
const double _kListWidth    = 340.0;
const double _kListWidthMin = 200.0;
const double _kListWidthMax = 520.0;

// ── Filter model ───────────────────────────────────────────────────────────────

class _ContactFilter {
  const _ContactFilter({
    this.searchText = '',
    this.statuses = const {},
    this.hasEmail,
    this.hasPhone,
  });

  final String searchText;
  final Set<ContactStatus> statuses;
  final bool? hasEmail;
  final bool? hasPhone;

  bool get isActive =>
      searchText.isNotEmpty || statuses.isNotEmpty ||
      hasEmail != null || hasPhone != null;

  int get activeCount {
    var n = searchText.isNotEmpty ? 1 : 0;
    if (statuses.isNotEmpty) n++;
    if (hasEmail != null) n++;
    if (hasPhone != null) n++;
    return n;
  }

  List<Contact> apply(List<Contact> contacts) {
    final q = searchText.trim().toLowerCase();
    return contacts.where((c) {
      if (q.isNotEmpty) {
        final inName    = c.fullName.toLowerCase().contains(q);
        final inTitle   = c.title?.toLowerCase().contains(q) ?? false;
        final inCompany = c.companyName?.toLowerCase().contains(q) ?? false;
        if (!inName && !inTitle && !inCompany) return false;
      }
      if (statuses.isNotEmpty && !statuses.contains(c.status)) return false;
      if (hasEmail == true && (c.email == null || c.email!.isEmpty)) return false;
      if (hasPhone == true && (c.phone == null || c.phone!.isEmpty)) return false;
      return true;
    }).toList();
  }

  _ContactFilter toggleStatus(ContactStatus s) {
    final next = Set<ContactStatus>.of(statuses);
    next.contains(s) ? next.remove(s) : next.add(s);
    return _ContactFilter(searchText: searchText, statuses: next,
        hasEmail: hasEmail, hasPhone: hasPhone);
  }

  _ContactFilter withSearchText(String v) =>
      _ContactFilter(searchText: v, statuses: statuses,
          hasEmail: hasEmail, hasPhone: hasPhone);

  _ContactFilter withHasEmail(bool? v) =>
      _ContactFilter(searchText: searchText, statuses: statuses,
          hasEmail: v, hasPhone: hasPhone);

  _ContactFilter withHasPhone(bool? v) =>
      _ContactFilter(searchText: searchText, statuses: statuses,
          hasEmail: hasEmail, hasPhone: v);

}

// ── Column definitions ─────────────────────────────────────────────────────────

enum _ColId { name, company, title, email, phone, status, tags, created, createdBy, updatedBy }

class _ColDef {
  const _ColDef({
    required this.id,
    required this.label,
    required this.width,
    this.visible = true,
    this.alwaysVisible = false,
  });

  final _ColId  id;
  final String  label;
  final double  width;
  final bool    visible;
  final bool    alwaysVisible;

  _ColDef copyWith({bool? visible, double? width}) => _ColDef(
        id: id, label: label, width: width ?? this.width,
        visible: visible ?? this.visible, alwaysVisible: alwaysVisible,
      );
}

const _kDefaultColumns = <_ColDef>[
  _ColDef(id: _ColId.name,      label: 'Name',        width: 200, alwaysVisible: true),
  _ColDef(id: _ColId.company,   label: 'Company',     width: 160),
  _ColDef(id: _ColId.title,     label: 'Title',       width: 140),
  _ColDef(id: _ColId.email,     label: 'Email',       width: 180),
  _ColDef(id: _ColId.phone,     label: 'Phone',       width: 130),
  _ColDef(id: _ColId.status,    label: 'Status',      width: 100),
  _ColDef(id: _ColId.tags,      label: 'Tags',        width: 140, visible: false),
  _ColDef(id: _ColId.created,   label: 'Created',     width: 100, visible: false),
  _ColDef(id: _ColId.createdBy, label: 'Created by',  width: 130, visible: false),
  _ColDef(id: _ColId.updatedBy, label: 'Modified by', width: 130, visible: false),
];

// ── Cell builder helpers ───────────────────────────────────────────────────────

Widget _buildContactCell(
    _ColId id, Contact c, BuildContext ctx, bool selected) {
  final ext  = ctx.linearExt;
  final text = Theme.of(ctx).textTheme;
  switch (id) {
    case _ColId.name:
      return Text(
        c.fullName,
        style: text.bodySmall?.copyWith(
          color: ext.textPrimary,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      );
    case _ColId.company:
      return Text(c.companyName ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.title:
      return Text(c.title ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.email:
      return Text(c.email ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.phone:
      return Text(c.phone ?? '',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.status:
      return _StatusChip(status: c.status);
    case _ColId.tags:
      if (c.tags.isEmpty) return const SizedBox.shrink();
      return Text(c.tags.join(', '),
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.created:
      return Text(_fmtDate(c.createdAt),
          style: text.bodySmall?.copyWith(color: ext.textMuted),
          overflow: TextOverflow.ellipsis);
    case _ColId.createdBy:
      return Text(c.createdByName ?? '—',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
    case _ColId.updatedBy:
      return Text(c.updatedByName ?? '—',
          style: text.bodySmall?.copyWith(color: ext.textSecondary),
          overflow: TextOverflow.ellipsis);
  }
}

Comparable? Function(Contact)? _sortKeyForCol(_ColId id) => switch (id) {
  _ColId.name      => (c) => c.fullName.toLowerCase(),
  _ColId.company   => (c) => c.companyName?.toLowerCase(),
  _ColId.title     => (c) => c.title?.toLowerCase(),
  _ColId.email     => (c) => c.email?.toLowerCase(),
  _ColId.phone     => (c) => c.phone?.toLowerCase(),
  _ColId.status    => (c) => c.status.index,
  _ColId.created   => (c) => c.createdAt.millisecondsSinceEpoch,
  _                => null,
};

String? _contactFitValue(_ColId id, Contact c) => switch (id) {
  _ColId.name      => c.fullName,
  _ColId.company   => c.companyName,
  _ColId.title     => c.title,
  _ColId.email     => c.email,
  _ColId.phone     => c.phone,
  _ColId.status    => c.status?.name,
  _ColId.tags      => c.tags?.join(', '),
  _ColId.created   => null,
  _ColId.createdBy => c.createdByName,
  _ColId.updatedBy => c.updatedByName,
};

AppColumnDef<Contact> _colToAppDef(_ColDef col) => AppColumnDef<Contact>(
  id: col.id.name,
  label: col.label,
  width: col.width,
  visible: col.visible,
  alwaysVisible: col.alwaysVisible,
  flex: col.id == _ColId.name,
  sortKey: _sortKeyForCol(col.id),
  valueForFit: (c) => _contactFitValue(col.id, c),
  builder: (ctx, c, sel) => _buildContactCell(col.id, c, ctx, sel),
);

String _fmtDate(DateTime dt) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ── Preference persistence ─────────────────────────────────────────────────────

class _Prefs {
  static const _listWidthKey  = 'contacts.listWidth';
  static const _visibleCols   = 'contacts.visibleColumns';
  static const _colWidths     = 'contacts.colWidths';
  static const _cfColWidths   = 'contacts.cfColWidths';
  static const _statuses      = 'contacts.filter.statuses';
  static const _hasEmail      = 'contacts.filter.hasEmail';
  static const _hasPhone      = 'contacts.filter.hasPhone';
  static const _sortColKey = 'contacts.sortCol';
  static const _sortAscKey = 'contacts.sortAsc';

  static Future<void> saveListWidth(double v) =>
      ViewPrefsService.setDouble(_listWidthKey, v);

  static Future<void> saveColumns(List<_ColDef> cols) =>
      ViewPrefsService.setStringList(
          _visibleCols, [for (final c in cols) if (c.visible) c.id.name]);

  static Future<void> saveColumnWidths(List<_ColDef> cols) =>
      ViewPrefsService.setStringList(
          _colWidths, [for (final c in cols) '${c.id.name}:${c.width}']);

  static Future<void> saveCfColWidths(Map<String, double> widths) =>
      ViewPrefsService.setStringList(
          _cfColWidths,
          [for (final e in widths.entries) '${e.key}:${e.value}']);

  static Future<void> saveFilter(_ContactFilter f) async {
    await ViewPrefsService.setStringList(
        _statuses, [for (final s in f.statuses) s.name]);
    await ViewPrefsService.setBoolOrNull(_hasEmail, f.hasEmail);
    await ViewPrefsService.setBoolOrNull(_hasPhone, f.hasPhone);
  }

  static Future<void> saveSort(String? colId, bool ascending) async {
    if (colId == null) {
      await ViewPrefsService.removeKey(_sortColKey);
    } else {
      await ViewPrefsService.setString(_sortColKey, colId);
    }
    await ViewPrefsService.setBoolOrNull(_sortAscKey, ascending);
  }

  static Map<String, double> _parseWidthList(List<String> list) {
    final map = <String, double>{};
    for (final entry in list) {
      final i = entry.indexOf(':');
      if (i > 0) {
        final w = double.tryParse(entry.substring(i + 1));
        if (w != null) map[entry.substring(0, i)] = w;
      }
    }
    return map;
  }

  static Future<({
    double listWidth,
    List<_ColDef> columns,
    Map<String, double> cfColWidths,
    _ContactFilter filter,
    String? sortColId,
    bool sortAscending,
  })> load() async {
    final listWidth = await ViewPrefsService.getDouble(_listWidthKey, _kListWidth);

    List<_ColDef> cols = _kDefaultColumns;
    final savedVis = await ViewPrefsService.getStringList(_visibleCols);
    if (savedVis != null) {
      final visSet = savedVis.toSet();
      cols = [
        for (final c in _kDefaultColumns)
          c.alwaysVisible ? c : c.copyWith(visible: visSet.contains(c.id.name)),
      ];
    }

    final savedWidths = await ViewPrefsService.getStringList(_colWidths);
    if (savedWidths != null) {
      final widthMap = _parseWidthList(savedWidths);
      cols = [
        for (final c in cols)
          widthMap.containsKey(c.id.name) ? c.copyWith(width: widthMap[c.id.name]!) : c,
      ];
    }

    final cfWidths = _parseWidthList(
        await ViewPrefsService.getStringList(_cfColWidths) ?? const []);

    final statusSet = <ContactStatus>{};
    for (final s in await ViewPrefsService.getStringList(_statuses) ?? const <String>[]) {
      try { statusSet.add(ContactStatus.values.byName(s)); } catch (_) {}
    }
    final hasEmail = await ViewPrefsService.getBoolOrNull(_hasEmail);
    final hasPhone = await ViewPrefsService.getBoolOrNull(_hasPhone);

    final sortColId   = await ViewPrefsService.getString(_sortColKey);
    final sortAscBool = await ViewPrefsService.getBoolOrNull(_sortAscKey);

    return (
      listWidth:     listWidth,
      columns:       cols,
      cfColWidths:   cfWidths,
      filter:        _ContactFilter(statuses: statusSet, hasEmail: hasEmail, hasPhone: hasPhone),
      sortColId:     sortColId,
      sortAscending: sortAscBool ?? true,
    );
  }
}

// ── Page ───────────────────────────────────────────────────────────────────────

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key, this.initialContactId});
  final String? initialContactId;

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  String?        _selectedId;
  double         _listWidth = _kListWidth;
  List<_ColDef>  _columns   = _kDefaultColumns;
  _ContactFilter _filter    = const _ContactFilter();
  String?        _sortColId;
  bool           _sortAsc   = true;
  Timer?         _saveWidthTimer;
  Timer?         _saveColWidthTimer;
  Timer?         _saveCfWidthTimer;
  Map<String, double> _trailingColWidths = {};
  List<CustomFieldDef> _customFieldDefs  = [];

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialContactId;
    _loadPrefs();
  }

  @override
  void dispose() {
    _saveWidthTimer?.cancel();
    _saveColWidthTimer?.cancel();
    _saveCfWidthTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final p = await _Prefs.load();
    if (!mounted) return;
    setState(() {
      _listWidth        = p.listWidth;
      _columns          = p.columns;
      _trailingColWidths = Map.of(p.cfColWidths);
      _filter           = p.filter;
      _sortColId        = p.sortColId;
      _sortAsc          = p.sortAscending;
    });
  }

  void _select(String? id) => setState(() => _selectedId = id);

  void _toggleColumn(_ColId id) {
    setState(() {
      _columns = [
        for (final c in _columns)
          if (c.id == id) c.copyWith(visible: !c.visible) else c,
      ];
    });
    _Prefs.saveColumns(_columns);
  }

  void _reorderColumns(int from, int to) {
    if (from == to) return;
    final visible = _columns.where((c) => c.visible).toList();
    final hidden  = _columns.where((c) => !c.visible).toList();
    final col = visible.removeAt(from);
    visible.insert(to, col);
    setState(() => _columns = [...visible, ...hidden]);
    _Prefs.saveColumns(_columns);
  }

  void _resizeColumn(int visibleIndex, double delta) {
    final visible = _columns.where((c) => c.visible).toList();
    if (visibleIndex >= visible.length) return;
    final col     = visible[visibleIndex];
    final newWidth = (col.width + delta).clamp(40.0, double.infinity);
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id == col.id ? c.copyWith(width: newWidth) : c,
      ];
    });
    _saveColWidthTimer?.cancel();
    _saveColWidthTimer = Timer(const Duration(milliseconds: 400), () {
      _Prefs.saveColumnWidths(_columns);
    });
  }

  void _resizeTrailingColumn(int index, double delta) {
    if (index >= _customFieldDefs.length) return;
    final fieldKey = _customFieldDefs[index].fieldKey;
    setState(() {
      final cur = _trailingColWidths[fieldKey] ?? 140.0;
      _trailingColWidths[fieldKey] = (cur + delta).clamp(40.0, double.infinity);
    });
    _saveCfWidthTimer?.cancel();
    _saveCfWidthTimer = Timer(const Duration(milliseconds: 400), () {
      _Prefs.saveCfColWidths(_trailingColWidths);
    });
  }

  void _hideColumn(String columnId) {
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id.name == columnId ? c.copyWith(visible: false) : c,
      ];
    });
    _Prefs.saveColumns(_columns);
  }

  void _autoFitColumn(String columnId, double width) {
    setState(() {
      _columns = [
        for (final c in _columns)
          c.id.name == columnId ? c.copyWith(width: width) : c,
      ];
    });
    _Prefs.saveColumnWidths(_columns);
  }

  void _onSortChanged(String columnId) {
    setState(() {
      if (_sortColId == columnId) {
        _sortAsc = !_sortAsc;
      } else {
        _sortColId = columnId;
        _sortAsc   = true;
      }
    });
    _Prefs.saveSort(_sortColId, _sortAsc);
  }

  // ── Layout helpers ───────────────────────────────────────────────────────────

  Contact? _findSelected(List<Contact> contacts) {
    if (_selectedId == null) return null;
    for (final c in contacts) {
      if (c.id == _selectedId) return c;
    }
    return null;
  }

  List<AppTableGroup<Contact>> _buildGroups(List<Contact> contacts) {
    final sorted = List<Contact>.from(contacts);
    if (_sortColId != null) {
      try {
        final colId = _ColId.values.byName(_sortColId!);
        final key = _sortKeyForCol(colId);
        if (key != null) {
          sorted.sort((a, b) {
            final ka = key(a);
            final kb = key(b);
            if (ka == null && kb == null) return 0;
            if (ka == null) return _sortAsc ? 1 : -1;
            if (kb == null) return _sortAsc ? -1 : 1;
            return _sortAsc ? ka.compareTo(kb) : kb.compareTo(ka);
          });
        }
      } catch (_) {}
    }

    final groups = <ContactStatus, List<Contact>>{};
    for (final c in sorted) {
      groups.putIfAbsent(c.status, () => []).add(c);
    }
    return [
      (ContactStatus.active,   'Active'),
      (ContactStatus.lead,     'Leads'),
      (ContactStatus.inactive, 'Inactive'),
    ]
        .where((t) => groups.containsKey(t.$1))
        .map((t) => AppTableGroup<Contact>(
              label: t.$2, items: groups[t.$1]!))
        .toList();
  }

  void _openFilterPanel() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _FilterDialog(
        filter: _filter,
        onChanged: (f) {
          setState(() => _filter = f);
          _Prefs.saveFilter(f);
        },
      ),
    );
  }

  void _openDisplayPanel() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => _ColumnPickerDialog(
        columns: _columns,
        onToggle: _toggleColumn,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final contactsAsync  = ref.watch(contactsProvider);
    final customFieldDefs =
        ref.watch(customFieldDefsProvider('contact')).value ?? [];
    _customFieldDefs = customFieldDefs;
    final isWide = MediaQuery.sizeOf(context).width >= _kSplitBreak;

    return CrmCommands(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearViewHeader(
            icon: Icons.person_outline,
            title: 'Contacts',
            actions: [
              _FilterButton(
                isActive: _filter.isActive,
                count: _filter.activeCount,
                onTap: _openFilterPanel,
              ),
              LinearGhostButton(
                icon: Icons.view_column_outlined,
                label: 'Display',
                onTap: _openDisplayPanel,
              ),
              LinearGhostButton(
                icon: Icons.tune_rounded,
                label: 'Fields',
                onTap: () =>
                    showManageFieldsDialog(context, entityType: 'contact'),
              ),
              LinearNewButton(
                label: 'New contact',
                onPressed: () => showContactForm(context),
              ),
            ],
          ),
          Expanded(
            child: contactsAsync.when(
              loading: () => _LoadingSkeleton(),
              error:   (e, _) => _ErrorState(message: e.toString()),
              data:    (contacts) =>
                  _buildBody(contacts, isWide, customFieldDefs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Contact> contacts, bool isWide,
      List<CustomFieldDef> customFieldDefs) {
    final filtered = _filter.apply(contacts);
    final selected = _findSelected(contacts);

    if (_selectedId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedId = null);
      });
    }

    // Wide + selection → resizable split pane
    if (isWide && selected != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _listWidth,
            child: _ContactList(
              contacts: filtered, selectedId: _selectedId, onSelect: _select),
          ),
          ResizablePaneDivider(
            onDrag: (delta) {
              setState(() {
                _listWidth =
                    (_listWidth + delta).clamp(_kListWidthMin, _kListWidthMax);
              });
              _saveWidthTimer?.cancel();
              _saveWidthTimer =
                  Timer(const Duration(milliseconds: 400), () {
                _Prefs.saveListWidth(_listWidth);
              });
            },
          ),
          Expanded(
            child: ContactDetailPane(
                contact: selected, onClose: () => _select(null)),
          ),
        ],
      );
    }

    // Narrow + selection → detail fills pane
    if (selected != null) {
      return ContactDetailPane(
          contact: selected, onClose: () => _select(null));
    }

    // No selection → full-width table
    if (filtered.isEmpty) {
      return _EmptyContacts(filterActive: _filter.isActive);
    }

    final trailingCols = [
      for (final entry in customFieldDefs.asMap().entries)
        AppColumnDef<Contact>(
          id: 'cf_${entry.value.fieldKey}',
          label: entry.value.label,
          width: _trailingColWidths[entry.value.fieldKey] ?? 140.0,
          builder: (ctx, c, _) => Text(
            c.customFields[entry.value.fieldKey]?.toString() ?? '',
            style: Theme.of(ctx).textTheme.bodySmall
                ?.copyWith(color: ctx.linearExt.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    return AppDataTable<Contact>(
      groups: _buildGroups(filtered),
      columns: [for (final c in _columns) _colToAppDef(c)],
      trailingColumns: trailingCols,
      leadingBuilder: (ctx, c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Avatar(contact: c),
          const SizedBox(width: LinearSpacing.md),
        ],
      ),
      itemKey:           (c) => c.id,
      onTap:             (c) => _select(c.id),
      selectedKey:       _selectedId,
      sortColumnId:      _sortColId,
      sortAscending:     _sortAsc,
      onSortChanged:     _onSortChanged,
      onColumnsReorder:  _reorderColumns,
      onColumnResize:    _resizeColumn,
      onTrailingColumnResize: _resizeTrailingColumn,
      onHideColumn:      _hideColumn,
      onColumnAutoFit:   _autoFitColumn,
    );
  }
}

// ── Loading / error / empty states ────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      ListView.builder(
        itemCount: 8,
        itemBuilder: (_, _) => const AppContactRowSkeleton(),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: LinearColors.danger, size: 32),
            const SizedBox(height: LinearSpacing.sm),
            Text('Could not load contacts',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: LinearSpacing.xs),
            Text(message,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.filterActive});
  final bool filterActive;

  @override
  Widget build(BuildContext context) => AppEmptyState(
        icon: Icons.person_outline,
        title: filterActive
            ? 'No contacts match your filters'
            : 'No contacts yet',
        description: filterActive
            ? 'Try adjusting or clearing your filters.'
            : 'Add your first contact to start building your CRM.',
      );
}

// ── Filter button ──────────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.isActive,
    required this.count,
    required this.onTap,
  });
  final bool isActive;
  final int  count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LinearGhostButton(
          icon: Icons.filter_list,
          label: isActive ? 'Filter ($count)' : 'Filter',
          onTap: onTap,
        ),
        if (isActive)
          PositionedDirectional(
            top: 5, end: 5,
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                color: LinearColors.accent, shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Filter dialog ──────────────────────────────────────────────────────────────

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.filter, required this.onChanged});
  final _ContactFilter filter;
  final ValueChanged<_ContactFilter> onChanged;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late _ContactFilter _local;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _local     = widget.filter;
    _searchCtrl = TextEditingController(text: widget.filter.searchText);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _update(_ContactFilter f) {
    setState(() => _local = f);
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 52, end: 190),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 220,
            decoration: BoxDecoration(
              color: ext.surfaceRaised,
              borderRadius: BorderRadius.circular(LinearRadii.md),
              border: Border.all(color: ext.borderSubtle),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LinearSpacing.base, LinearSpacing.sm,
                      LinearSpacing.base, LinearSpacing.xs),
                  child: Row(
                    children: [
                      Text('Filter',
                          style: text.labelMedium
                              ?.copyWith(color: ext.textMuted)),
                      const Spacer(),
                      if (_local.isActive)
                        GestureDetector(
                          onTap: () => _update(const _ContactFilter()),
                          child: Text('Clear all',
                              style: text.labelSmall
                                  ?.copyWith(color: LinearColors.accent)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LinearSpacing.sm, LinearSpacing.sm,
                      LinearSpacing.sm, LinearSpacing.xs),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: text.bodySmall?.copyWith(color: ext.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Name, title, company…',
                      hintStyle: text.bodySmall?.copyWith(color: ext.textMuted),
                      prefixIcon:
                          Icon(Icons.search, size: 14, color: ext.textMuted),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                      suffixIcon: _local.searchText.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _update(_local.withSearchText(''));
                              },
                              child: Icon(Icons.close,
                                  size: 13, color: ext.textMuted),
                            )
                          : null,
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: LinearSpacing.sm,
                          vertical: LinearSpacing.sm),
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
                    onChanged: (v) => _update(_local.withSearchText(v)),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LinearSpacing.base, LinearSpacing.sm,
                      LinearSpacing.base, LinearSpacing.xs),
                  child: Text('Status',
                      style: text.labelSmall?.copyWith(color: ext.textMuted)),
                ),
                for (final s in ContactStatus.values)
                  _FilterRow(
                    label: s.label,
                    checked: _local.statuses.contains(s),
                    dot: s.color,
                    onToggle: () => _update(_local.toggleStatus(s)),
                  ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LinearSpacing.base, LinearSpacing.sm,
                      LinearSpacing.base, LinearSpacing.xs),
                  child: Text('Fields',
                      style: text.labelSmall?.copyWith(color: ext.textMuted)),
                ),
                _FilterRow(
                  label: 'Has email',
                  checked: _local.hasEmail == true,
                  onToggle: () => _update(_local.withHasEmail(
                      _local.hasEmail == true ? null : true)),
                ),
                _FilterRow(
                  label: 'Has phone',
                  checked: _local.hasPhone == true,
                  onToggle: () => _update(_local.withHasPhone(
                      _local.hasPhone == true ? null : true)),
                ),
                const SizedBox(height: LinearSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.checked,
    required this.onToggle,
    this.dot,
  });
  final String label;
  final bool   checked;
  final VoidCallback onToggle;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base, vertical: LinearSpacing.sm - 2),
        child: Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: LinearSpacing.sm),
            if (dot != null) ...[
              Container(
                width: 8, height: 8,
                decoration:
                    BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: LinearSpacing.xs),
            ],
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: ext.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Column-picker dialog ───────────────────────────────────────────────────────

class _ColumnPickerDialog extends StatefulWidget {
  const _ColumnPickerDialog(
      {required this.columns, required this.onToggle});
  final List<_ColDef>        columns;
  final void Function(_ColId) onToggle;

  @override
  State<_ColumnPickerDialog> createState() => _ColumnPickerDialogState();
}

class _ColumnPickerDialogState extends State<_ColumnPickerDialog> {
  late List<_ColDef> _local;

  @override
  void initState() {
    super.initState();
    _local = List.of(widget.columns);
  }

  void _toggle(_ColId id) {
    setState(() {
      _local = [
        for (final c in _local)
          if (c.id == id) c.copyWith(visible: !c.visible) else c,
      ];
    });
    widget.onToggle(id);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
            top: 52, end: LinearSpacing.base),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 210,
            decoration: BoxDecoration(
              color: context.linearExt.surfaceRaised,
              borderRadius: BorderRadius.circular(LinearRadii.md),
              border: Border.all(color: context.linearExt.borderSubtle),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      LinearSpacing.base, LinearSpacing.sm,
                      LinearSpacing.base, LinearSpacing.xs),
                  child: Text(
                    'Columns',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: context.linearExt.textMuted),
                  ),
                ),
                const Divider(height: 1),
                for (final col in _local)
                  _ColumnToggleRow(col: col, onToggle: () => _toggle(col.id)),
                const SizedBox(height: LinearSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnToggleRow extends StatelessWidget {
  const _ColumnToggleRow({required this.col, required this.onToggle});
  final _ColDef      col;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ext      = context.linearExt;
    final disabled = col.alwaysVisible;
    return InkWell(
      onTap: disabled ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base, vertical: LinearSpacing.sm - 2),
        child: Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: Checkbox(
                value: col.visible,
                onChanged: disabled ? null : (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: LinearSpacing.sm),
            Text(
              col.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: disabled ? ext.textMuted : ext.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact list (split-pane left rail) ───────────────────────────────────────

class _ContactList extends StatelessWidget {
  const _ContactList({
    required this.contacts,
    required this.onSelect,
    this.selectedId,
  });
  final List<Contact> contacts;
  final String?       selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final groups = <ContactStatus, List<Contact>>{};
    for (final c in contacts) {
      groups.putIfAbsent(c.status, () => []).add(c);
    }
    final sections = [
      (ContactStatus.active,   'Active'),
      (ContactStatus.lead,     'Leads'),
      (ContactStatus.inactive, 'Inactive'),
    ].where((t) => groups.containsKey(t.$1)).toList();

    return ListView.builder(
      itemCount: sections.fold<int>(
          0, (sum, t) => sum + 1 + (groups[t.$1]?.length ?? 0)),
      itemBuilder: (context, i) {
        var offset = 0;
        for (final (status, label) in sections) {
          final rows = groups[status]!;
          if (i == offset) return _GroupHeader(label: label, count: rows.length);
          offset++;
          if (i < offset + rows.length) {
            final contact = rows[i - offset];
            return _ContactRow(
              contact:  contact,
              selected: contact.id == selectedId,
              onTap:    () => onSelect(contact.id),
            );
          }
          offset += rows.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});
  final String label;
  final int    count;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
      color: ext.overlay,
      child: Row(
        children: [
          Container(
            width: 9, height: 9,
            decoration: BoxDecoration(
              color: ext.textMuted,
              borderRadius: BorderRadius.circular(LinearRadii.xs),
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Text(label,
              style: text.labelMedium?.copyWith(
                  color: ext.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: LinearSpacing.sm),
          Text('$count',
              style: text.labelMedium?.copyWith(color: ext.textMuted)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.onTap,
    this.selected = false,
  });
  final Contact      contact;
  final VoidCallback onTap;
  final bool         selected;

  @override
  Widget build(BuildContext context) {
    final ext  = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? ext.overlayActive : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          overlayColor: WidgetStatePropertyAll(ext.overlay),
          child: Container(
            height: 38,
            padding:
                const EdgeInsets.symmetric(horizontal: LinearSpacing.base),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ext.borderSubtle)),
              color: selected
                  ? LinearColors.accent.withValues(alpha: 0.06)
                  : null,
            ),
            child: Row(
              children: [
                _Avatar(contact: contact),
                const SizedBox(width: LinearSpacing.md),
                SizedBox(
                  width: 140,
                  child: Text(
                    contact.fullName,
                    style: text.bodySmall?.copyWith(
                      color: ext.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    contact.companyName ?? contact.title ?? '',
                    style:
                        text.bodySmall?.copyWith(color: ext.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: contact.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.contact});
  final Contact contact;

  @override
  Widget build(BuildContext context) {
    if (contact.avatarUrl != null) {
      return CircleAvatar(
          radius: 10,
          backgroundImage: NetworkImage(contact.avatarUrl!));
    }
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
          color: contact.avatarColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        contact.initials,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ContactStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(LinearRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(LinearRadii.pill),
              ),
            ),
            const SizedBox(width: 5),
            Text(status.label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
