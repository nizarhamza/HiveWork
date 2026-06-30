import 'package:flutter/material.dart';

import '../../shell/widgets/linear_view_header.dart';
import '../../theme/linear_tokens.dart';

// ── Data ───────────────────────────────────────────────────────────────────

class _Contact {
  const _Contact(this.name, this.company, this.email, this.phone, this.status, this.color);
  final String name, company, email, phone, status;
  final Color color;

  String get initials =>
      name.split(' ').take(2).map((w) => w.isEmpty ? '' : w[0]).join();
}

const _kContacts = <_Contact>[
  _Contact('Amira Ben Salah',  'Atlas Energy',   'amira@atlas.tn',        '+216 71 000 001', 'Active', Color(0xFF5E6AD2)),
  _Contact('Youssef Trabelsi', 'SCATEC',         'y.trabelsi@scatec.com', '+47 123 456 78',  'Active', Color(0xFF2BA87E)),
  _Contact('Lina Haddad',      'STEG',           'l.haddad@steg.tn',      '+216 71 000 002', 'Lead',   Color(0xFFD9730D)),
  _Contact('Karim Mansour',    'Meknassy Infra', 'karim@meknassy.tn',     '+216 72 000 010', 'Active', Color(0xFFC2554D)),
  _Contact('Sofia Rossi',      'Delta Grid',     'sofia@deltagrid.it',    '+39 02 000 0101', 'Lead',   Color(0xFF9D5BD2)),
  _Contact('Omar Khaled',      'Sahara Solar',   'omar@saharasolar.tn',   '+216 71 000 003', 'Active', Color(0xFF3A87C2)),
];

// ── Column definitions ─────────────────────────────────────────────────────

class _Col {
  const _Col({
    required this.id,
    required this.label,
    this.width,
    this.flex,
    this.hideable = true,
  }) : assert(width != null || flex != null);

  final String id;
  final String label;
  final double? width;
  final int? flex;
  final bool hideable;
}

const _kCols = <_Col>[
  _Col(id: 'name',    label: 'Name',    width: 200, hideable: false),
  _Col(id: 'company', label: 'Company', flex: 1),
  _Col(id: 'email',   label: 'Email',   width: 200),
  _Col(id: 'phone',   label: 'Phone',   width: 140),
  _Col(id: 'status',  label: 'Status',  width: 88),
];

// ── Page ───────────────────────────────────────────────────────────────────

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _visible = <String, bool>{
    'name':    true,
    'company': true,
    'email':   true,
    'phone':   false,
    'status':  true,
  };

  List<_Col> get _cols => _kCols.where((c) => _visible[c.id] == true).toList();

  @override
  Widget build(BuildContext context) {
    final cols = _cols;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearViewHeader(
          icon: Icons.person_outline,
          title: 'Contacts',
          actions: [
            const LinearGhostButton(icon: Icons.filter_list, label: 'Filter'),
            _DisplayButton(
              visible: _visible,
              onToggle: (id, val) => setState(() => _visible[id] = val),
            ),
            FilledButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connect Supabase to persist new contacts.'),
                  behavior: SnackBarBehavior.floating,
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New contact'),
            ),
          ],
        ),
        _GroupHeader(label: 'All contacts', count: _kContacts.length),
        _TableHeader(cols: cols),
        Expanded(
          child: ListView.builder(
            itemCount: _kContacts.length,
            itemBuilder: (ctx, i) => _ContactRow(contact: _kContacts[i], cols: cols),
          ),
        ),
      ],
    );
  }
}

// ── Group header ───────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: 34,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: LinearSpacing.base),
      color: Colors.white.withOpacity(0.015),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: LinearColors.textMuted,
              borderRadius: BorderRadius.circular(LinearRadii.xs),
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: LinearColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Text('$count', style: text.labelMedium?.copyWith(color: LinearColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Table header ───────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.cols});
  final List<_Col> cols;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: LinearColors.textMuted,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    );

    final cells = <Widget>[];
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i];
      // Indent the "Name" label past the avatar (20px) + gap (LinearSpacing.md)
      final child = col.id == 'name'
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: 20 + LinearSpacing.md),
              child: Text(col.label, style: labelStyle, overflow: TextOverflow.ellipsis),
            )
          : Text(col.label, style: labelStyle, overflow: TextOverflow.ellipsis);

      cells.add(
        col.flex != null
            ? Expanded(flex: col.flex!, child: child)
            : SizedBox(width: col.width, child: child),
      );
      if (i < cols.length - 1) cells.add(const SizedBox(width: LinearSpacing.md));
    }

    return Container(
      height: 32,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: LinearSpacing.base),
      decoration: const BoxDecoration(
        color: Color(0x07FFFFFF),
        border: Border(
          top: BorderSide(color: LinearColors.borderSubtle),
          bottom: BorderSide(color: LinearColors.borderSubtle),
        ),
      ),
      child: Row(children: cells),
    );
  }
}

// ── Contact row ────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.cols});
  final _Contact contact;
  final List<_Col> cols;

  Widget _cellContent(BuildContext context, _Col col) {
    final text = Theme.of(context).textTheme;
    switch (col.id) {
      case 'name':
        return Row(children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: contact.color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              contact.initials,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: LinearSpacing.md),
          Expanded(
            child: Text(
              contact.name,
              style: text.bodySmall?.copyWith(color: LinearColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]);
      case 'company':
        return Text(
          contact.company,
          style: text.bodySmall?.copyWith(color: LinearColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        );
      case 'email':
        return Text(
          contact.email,
          style: text.bodySmall?.copyWith(color: LinearColors.textMuted),
          overflow: TextOverflow.ellipsis,
        );
      case 'phone':
        return Text(
          contact.phone,
          style: text.bodySmall?.copyWith(color: LinearColors.textMuted),
          overflow: TextOverflow.ellipsis,
        );
      case 'status':
        return _StatusChip(label: contact.status, lead: contact.status == 'Lead');
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < cols.length; i++) {
      final col = cols[i];
      final content = _cellContent(context, col);
      cells.add(
        col.flex != null
            ? Expanded(flex: col.flex!, child: content)
            : SizedBox(width: col.width, child: content),
      );
      if (i < cols.length - 1) cells.add(const SizedBox(width: LinearSpacing.md));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        overlayColor: const WidgetStatePropertyAll(LinearColors.overlay),
        child: Container(
          height: 38,
          padding: const EdgeInsetsDirectional.symmetric(horizontal: LinearSpacing.base),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x09FFFFFF))),
          ),
          child: Row(children: cells),
        ),
      ),
    );
  }
}

// ── Status chip ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.lead});
  final String label;
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final color = lead ? LinearColors.warning : LinearColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: LinearSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(LinearRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(LinearRadii.pill),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Display button ─────────────────────────────────────────────────────────

class _DisplayButton extends StatefulWidget {
  const _DisplayButton({required this.visible, required this.onToggle});
  final Map<String, bool> visible;
  final void Function(String id, bool value) onToggle;

  @override
  State<_DisplayButton> createState() => _DisplayButtonState();
}

class _DisplayButtonState extends State<_DisplayButton> {
  final _anchor = GlobalKey();
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _open() {
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final btnSize = box.size;

    _entry = OverlayEntry(builder: (ctx) {
      final screenW = MediaQuery.of(ctx).size.width;
      return Stack(children: [
        // Full-screen dismiss layer (behind the panel)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
          ),
        ),
        // Panel — on top, absorbs its own taps so they don't reach dismiss layer
        Positioned(
          top: pos.dy + btnSize.height + 6,
          right: screenW - pos.dx - btnSize.width,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Material(
              color: Colors.transparent,
              child: _ColumnPickerPanel(
                visible: widget.visible,
                onToggle: (id, val) {
                  widget.onToggle(id, val);
                  _entry?.markNeedsBuild();
                },
              ),
            ),
          ),
        ),
      ]);
    });

    Overlay.of(context).insert(_entry!);
  }

  void _toggle() => _entry == null ? _open() : _close();

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: _anchor,
      child: LinearGhostButton(
        icon: Icons.view_column_outlined,
        label: 'Display',
        onTap: _toggle,
      ),
    );
  }
}

// ── Column picker panel ────────────────────────────────────────────────────

class _ColumnPickerPanel extends StatelessWidget {
  const _ColumnPickerPanel({required this.visible, required this.onToggle});
  final Map<String, bool> visible;
  final void Function(String id, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: LinearColors.surfaceBase,
        borderRadius: BorderRadius.circular(LinearRadii.md),
        border: Border.all(color: LinearColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LinearSpacing.base, LinearSpacing.sm, LinearSpacing.base, 6,
            ),
            child: Text(
              'Columns',
              style: text.labelMedium?.copyWith(
                color: LinearColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: LinearColors.borderSubtle),
          for (final col in _kCols)
            _ColumnRow(
              col: col,
              checked: visible[col.id] == true,
              onToggle: (val) => onToggle(col.id, val),
            ),
          const SizedBox(height: LinearSpacing.xs),
        ],
      ),
    );
  }
}

class _ColumnRow extends StatelessWidget {
  const _ColumnRow({required this.col, required this.checked, required this.onToggle});
  final _Col col;
  final bool checked;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = col.hideable;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onToggle(!checked) : null,
        overlayColor: const WidgetStatePropertyAll(LinearColors.overlay),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LinearSpacing.base,
            vertical: 7,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: checked,
                  onChanged: enabled ? (v) => onToggle(v ?? checked) : null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: LinearColors.textMuted, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: LinearSpacing.sm),
              Expanded(
                child: Text(
                  col.label,
                  style: text.bodySmall?.copyWith(
                    color: enabled ? LinearColors.textPrimary : LinearColors.textMuted,
                  ),
                ),
              ),
              if (!enabled)
                Text(
                  'Always',
                  style: text.labelSmall?.copyWith(color: LinearColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
