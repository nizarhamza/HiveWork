import 'package:flutter/material.dart';
import '../../theme/linear_tokens.dart';

// ── Column definition ──────────────────────────────────────────────────────────

/// Defines one column in [AppDataTable].
/// Exactly one column per table should set [flex] = true (the primary/name column).
class AppColumnDef<T> {
  const AppColumnDef({
    required this.id,
    required this.label,
    required this.width,
    required this.builder,
    this.visible = true,
    this.alwaysVisible = false,
    this.flex = false,
    this.sortKey,
    this.valueForFit,
  });

  final String id;
  final String label;
  final double width;
  final bool visible;
  final bool alwaysVisible;

  /// If true, this column is [Expanded] and fills remaining horizontal space.
  final bool flex;

  /// Returns a [Comparable] for sorting. null = column is not sortable.
  final Comparable? Function(T)? sortKey;

  /// Returns a plain string used to measure auto-fit width on double-click.
  /// If null, double-click auto-fit is disabled for this column.
  final String? Function(T)? valueForFit;

  /// Builds the cell. [selected] is true when this row is the active selection.
  final Widget Function(BuildContext context, T item, bool selected) builder;

  AppColumnDef<T> copyWith({bool? visible, double? width}) => AppColumnDef<T>(
        id: id,
        label: label,
        width: width ?? this.width,
        visible: visible ?? this.visible,
        alwaysVisible: alwaysVisible,
        flex: flex,
        sortKey: sortKey,
        valueForFit: valueForFit,
        builder: builder,
      );
}

// ── Group ──────────────────────────────────────────────────────────────────────

class AppTableGroup<T> {
  const AppTableGroup({required this.label, required this.items});
  final String label;
  final List<T> items;
}

// ── Internal sealed row types ──────────────────────────────────────────────────

sealed class _Row<T> {}

final class _GroupRow<T> extends _Row<T> {
  _GroupRow(this.label, this.count);
  final String label;
  final int count;
}

final class _DataRow<T> extends _Row<T> {
  _DataRow(this.item);
  final T item;
}

// ── Table ──────────────────────────────────────────────────────────────────────

/// Generic sortable, resizable, reorderable data table.
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.groups,
    required this.columns,
    required this.leadingBuilder,
    required this.itemKey,
    required this.onTap,
    this.trailingColumns = const [],
    this.leadingWidth = 36.0,
    this.selectedKey,
    this.sortColumnId,
    this.sortAscending = true,
    this.onSortChanged,
    this.onColumnsReorder,
    this.onColumnResize,
    this.onTrailingColumnResize,
    this.onHideColumn,
    this.onColumnAutoFit,
  });

  final List<AppTableGroup<T>> groups;
  final List<AppColumnDef<T>> columns;
  final List<AppColumnDef<T>> trailingColumns;
  final Widget Function(BuildContext, T) leadingBuilder;
  final double leadingWidth;
  final String Function(T) itemKey;
  final void Function(T) onTap;
  final String? selectedKey;
  final String? sortColumnId;
  final bool sortAscending;

  final void Function(String columnId)? onSortChanged;
  final void Function(int from, int to)? onColumnsReorder;
  final void Function(int visibleIndex, double delta)? onColumnResize;
  final void Function(int trailingIndex, double delta)? onTrailingColumnResize;

  /// Called when the user right-clicks a header and selects "Hide column".
  final void Function(String columnId)? onHideColumn;

  /// Called when the user double-clicks a resize handle to auto-fit the column.
  final void Function(String columnId, double width)? onColumnAutoFit;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  int? _draggingIndex;
  int? _hoverTargetIndex;

  final _hHeader = ScrollController();
  final _hBody   = ScrollController();
  bool _syncing  = false;

  double _flexLockedWidth = 0;
  double _lastFlexColW    = 0;

  // Double-tap tracking for resize handles — lives here so it survives any
  // child widget rebuild that would otherwise wipe per-handle state.
  String?   _lastTappedResizeCol;
  DateTime? _lastResizeTapTime;

  void _handleResizeHandleTap(AppColumnDef<T> col) {
    final now = DateTime.now();
    if (_lastTappedResizeCol == col.id &&
        _lastResizeTapTime != null &&
        now.difference(_lastResizeTapTime!) < const Duration(milliseconds: 500)) {
      _lastTappedResizeCol = null;
      _lastResizeTapTime   = null;
      // Pin the flex column first so the auto-fit expands the table to the
      // right (horizontal scroll) rather than stealing from the flex column,
      // which would make the left edge appear to move.
      _pinFlex();
      _autoFitColumn(col);
    } else {
      _lastTappedResizeCol = col.id;
      _lastResizeTapTime   = now;
    }
  }

  @override
  void initState() {
    super.initState();
    _hHeader.addListener(_syncBodyFromHeader);
    _hBody.addListener(_syncHeaderFromBody);
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  void _syncBodyFromHeader() {
    if (_syncing) return;
    if (_hBody.hasClients && _hBody.offset != _hHeader.offset) {
      _syncing = true;
      _hBody.jumpTo(_hHeader.offset);
      _syncing = false;
    }
  }

  void _syncHeaderFromBody() {
    if (_syncing) return;
    if (_hHeader.hasClients && _hHeader.offset != _hBody.offset) {
      _syncing = true;
      _hHeader.jumpTo(_hBody.offset);
      _syncing = false;
    }
  }

  List<AppColumnDef<T>> get _visible =>
      widget.columns.where((c) => c.visible).toList();

  double _minTableWidth(List<AppColumnDef<T>> visible) {
    const hPad = LinearSpacing.base * 2.0;
    final colsW = visible.fold<double>(0, (s, c) =>
        s + (c.flex && _flexLockedWidth > 0 ? _flexLockedWidth : c.width));
    final trailW = widget.trailingColumns.fold<double>(0, (s, c) => s + c.width);
    return hPad + widget.leadingWidth + colsW + trailW;
  }

  void _pinFlex() {
    if (_flexLockedWidth == 0 && _lastFlexColW > 0) {
      setState(() => _flexLockedWidth = _lastFlexColW);
    }
  }

  // ── Auto-fit ─────────────────────────────────────────────────────────────────

  static double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return tp.width;
  }

  void _autoFitColumn(AppColumnDef<T> col) {
    // Use the actual theme styles so character widths match what's on screen.
    final theme       = Theme.of(context);
    final cellStyle   = theme.textTheme.bodySmall
        ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
    final headerStyle = theme.textTheme.labelMedium
        ?? const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
    const hPad = 32.0; // horizontal padding added to the measured text width

    double maxW = _measureText(col.label, headerStyle);

    if (col.valueForFit != null) {
      for (final g in widget.groups) {
        for (final item in g.items) {
          final str = col.valueForFit!(item);
          if (str != null && str.isNotEmpty) {
            final w = _measureText(str, cellStyle);
            if (w > maxW) maxW = w;
          }
        }
      }
    }

    final fitted = (maxW + hPad).clamp(48.0, double.infinity);
    widget.onColumnAutoFit?.call(col.id, fitted);
  }

  // ── Context menu (right-click header) ────────────────────────────────────────

  void _showHideMenu(BuildContext ctx, AppColumnDef<T> col, Offset globalPos) {
    if (col.alwaysVisible || widget.onHideColumn == null) return;
    final ext = ctx.linearExt;
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1,
      ),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LinearRadii.sm),
        side: BorderSide(color: ext.borderSubtle),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'hide',
          height: 32,
          padding: const EdgeInsets.symmetric(
              horizontal: LinearSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility_off_outlined,
                  size: 13, color: ext.textSecondary),
              const SizedBox(width: LinearSpacing.xs),
              Text('Hide column',
                  style: TextStyle(fontSize: 12, color: ext.textSecondary)),
            ],
          ),
        ),
      ],
    ).then((v) {
      if (v == 'hide') widget.onHideColumn?.call(col.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final rows = <_Row<T>>[];
    for (final g in widget.groups) {
      rows.add(_GroupRow<T>(g.label, g.items.length));
      for (final item in g.items) {
        rows.add(_DataRow<T>(item));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final minW = _minTableWidth(visible);
        final needsHScroll = minW > constraints.maxWidth;
        final tableW = needsHScroll ? minW : constraints.maxWidth;

        final nfW = visible.where((c) => !c.flex).fold<double>(0, (s, c) => s + c.width);
        final trW = widget.trailingColumns.fold<double>(0, (s, c) => s + c.width);
        final rawFlexW = tableW - LinearSpacing.base * 2.0 - widget.leadingWidth - nfW - trW;
        _lastFlexColW = (_flexLockedWidth > 0 ? _flexLockedWidth : rawFlexW).clamp(0.0, double.infinity);
        final double? flexColFixedW = _flexLockedWidth > 0 ? _flexLockedWidth : null;

        final header = _buildHeader(context, visible, flexColFixedW);

        final body = ListView.builder(
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final row = rows[i];
            return switch (row) {
              _GroupRow<T>(:final label, :final count) =>
                _AppGroupRow(label: label, count: count),
              _DataRow<T>(:final item) => _AppDataRow<T>(
                  item: item,
                  columns: visible,
                  trailingColumns: widget.trailingColumns,
                  leadingBuilder: widget.leadingBuilder,
                  itemKey: widget.itemKey,
                  selectedKey: widget.selectedKey,
                  onTap: widget.onTap,
                  flexColW: flexColFixedW,
                ),
            };
          },
        );

        if (!needsHScroll) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const Divider(height: 1, thickness: 1),
              Expanded(child: body),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _hHeader,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(width: tableW, child: header),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Scrollbar(
                controller: _hBody,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hBody,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(width: tableW, child: body),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, List<AppColumnDef<T>> visible, double? flexColFixedW) {
    final ext = context.linearExt;
    return Container(
      height: 32,
      color: ext.surfaceBase,
      padding: const EdgeInsetsDirectional.only(
        start: LinearSpacing.base,
        end: LinearSpacing.base,
      ),
      child: Row(
        children: [
          SizedBox(width: widget.leadingWidth),
          for (int i = 0; i < visible.length; i++)
            _buildHeaderCell(context, i, visible[i], flexColFixedW),
          for (int j = 0; j < widget.trailingColumns.length; j++)
            SizedBox(
              width: widget.trailingColumns[j].width,
              child: Row(
                children: [
                  Expanded(
                    child: _SortableHeaderCell(
                      label: widget.trailingColumns[j].label,
                      isSorted: false,
                      ascending: true,
                      highlighted: false,
                    ),
                  ),
                  _ResizeHandle(
                    onDragStart: _pinFlex,
                    onDelta: (dx) =>
                        widget.onTrailingColumnResize?.call(j, dx),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
      BuildContext context, int i, AppColumnDef<T> col, double? flexColFixedW) {
    final isSorted = widget.sortColumnId == col.id;
    final isTarget = _hoverTargetIndex == i &&
        _draggingIndex != null &&
        _draggingIndex != i;

    final cell = _SortableHeaderCell(
      label: col.label,
      isSorted: isSorted,
      ascending: widget.sortAscending,
      highlighted: isTarget,
      onTap: col.sortKey != null
          ? () => widget.onSortChanged?.call(col.id)
          : null,
      onSecondaryTapUp: col.alwaysVisible
          ? null
          : (d) => _showHideMenu(context, col, d.globalPosition),
    );

    if (col.flex) {
      final handle = _ResizeHandle(
        key: ValueKey('rh_flex_\${col.id}'),
        onDragStart: _pinFlex,
        onDelta: (dx) => setState(() {
          _flexLockedWidth = (_flexLockedWidth + dx).clamp(40.0, double.infinity);
        }),
        onTap: () => _handleResizeHandleTap(col),
      );
      final inner = Row(children: [Expanded(child: cell), handle]);
      return flexColFixedW != null
          ? SizedBox(width: flexColFixedW, child: inner)
          : Expanded(child: inner);
    }

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) {
        setState(() => _hoverTargetIndex = i);
        return d.data != i;
      },
      onLeave: (_) {
        if (_hoverTargetIndex == i) setState(() => _hoverTargetIndex = null);
      },
      onAcceptWithDetails: (d) {
        setState(() => _hoverTargetIndex = null);
        widget.onColumnsReorder?.call(d.data, i);
      },
      builder: (context, candidates, rejected) => SizedBox(
        width: col.width,
        child: Row(
          children: [
            Expanded(
              child: Draggable<int>(
                data: i,
                onDragStarted: () => setState(() => _draggingIndex = i),
                onDragEnd: (_) => setState(() {
                  _draggingIndex = null;
                  _hoverTargetIndex = null;
                }),
                feedback: _DragFeedback(label: col.label, width: col.width),
                childWhenDragging: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: LinearColors.accent, width: 2),
                    ),
                  ),
                ),
                child: cell,
              ),
            ),
            _ResizeHandle(
              key: ValueKey('rh_\${col.id}'),
              onDragStart: _pinFlex,
              onDelta: (dx) => widget.onColumnResize?.call(i, dx),
              onTap: () => _handleResizeHandleTap(col),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sortable header cell ───────────────────────────────────────────────────────

class _SortableHeaderCell extends StatelessWidget {
  const _SortableHeaderCell({
    required this.label,
    required this.isSorted,
    required this.ascending,
    required this.highlighted,
    this.onTap,
    this.onSecondaryTapUp,
  });

  final String label;
  final bool isSorted;
  final bool ascending;
  final bool highlighted;
  final VoidCallback? onTap;
  final void Function(TapUpDetails)? onSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSorted ? LinearColors.accent : ext.textMuted,
                  fontWeight: isSorted ? FontWeight.w600 : FontWeight.w500,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isSorted) ...[
          const SizedBox(width: 2),
          Icon(
            ascending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: LinearColors.accent,
          ),
        ],
      ],
    );

    Widget decorated = Container(
      decoration: highlighted
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: LinearColors.accent, width: 2),
              ),
            )
          : null,
      padding:
          highlighted ? const EdgeInsetsDirectional.only(start: 4) : null,
      child: content,
    );

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTapUp,
      behavior: HitTestBehavior.opaque,
      child: onTap != null
          ? MouseRegion(cursor: SystemMouseCursors.click, child: decorated)
          : decorated,
    );
  }
}

// ── Resize handle ──────────────────────────────────────────────────────────────

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    super.key,
    required this.onDelta,
    this.onDragStart,
    this.onTap,
  });
  final void Function(double delta) onDelta;
  final VoidCallback? onDragStart;
  /// Called on a clean pointer-down/up with no drag. The parent is responsible
  /// for deciding whether two quick taps constitute a double-tap.
  final VoidCallback? onTap;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered     = false;
  bool _pressing    = false;
  bool _dragStarted = false;
  double? _lastX;
  double? _downX;

  void _onDown(PointerDownEvent e) {
    // Do NOT call onDragStart here — it triggers _pinFlex → parent setState →
    // rebuild. Defer to first real movement so clean taps never cause rebuilds.
    setState(() {
      _pressing    = true;
      _dragStarted = false;
      _lastX       = e.position.dx;
      _downX       = e.position.dx;
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pressing || _lastX == null) return;
    final delta = e.position.dx - _lastX!;
    if (delta.abs() < 0.3) return;
    if (!_dragStarted) {
      _dragStarted = true;
      widget.onDragStart?.call();
      setState(() {});
    }
    _lastX = e.position.dx;
    widget.onDelta(delta);
  }

  void _onUp(PointerUpEvent e) {
    final totalDrag = _downX != null ? (e.position.dx - _downX!).abs() : 99.0;
    final wasDrag   = _dragStarted;
    setState(() {
      _pressing    = false;
      _dragStarted = false;
      _lastX       = null;
      _downX       = null;
    });
    // Report a clean tap to the parent; parent tracks timing for double-tap.
    if (!wasDrag && totalDrag < 4) {
      widget.onTap?.call();
    }
  }

  void _onCancel(PointerCancelEvent e) {
    setState(() {
      _pressing    = false;
      _dragStarted = false;
      _lastX       = null;
      _downX       = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext    = context.linearExt;
    final active = _hovered || (_pressing && _dragStarted);
    return MouseRegion(
      cursor:  SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: Listener(
        behavior:        HitTestBehavior.opaque,
        onPointerDown:   _onDown,
        onPointerMove:   _onMove,
        onPointerUp:     _onUp,
        onPointerCancel: _onCancel,
        child: SizedBox(
          width: 10,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 2 : 1,
              color: active ? LinearColors.accent : ext.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Drag feedback ghost ────────────────────────────────────────────────────────

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.label, required this.width});
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: 32,
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: LinearSpacing.sm),
        decoration: BoxDecoration(
          color: LinearColors.accent.withValues(alpha: 0.12),
          border:
              Border.all(color: LinearColors.accent.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(LinearRadii.xs),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: LinearColors.accent,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Group row ──────────────────────────────────────────────────────────────────

class _AppGroupRow extends StatelessWidget {
  const _AppGroupRow({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ext = context.linearExt;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 34,
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: LinearSpacing.base),
      color: ext.overlay,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: ext.textMuted,
              borderRadius: BorderRadius.circular(LinearRadii.xs),
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: ext.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: LinearSpacing.sm),
          Text(
            '$count',
            style: text.labelMedium?.copyWith(color: ext.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Data row ───────────────────────────────────────────────────────────────────

class _AppDataRow<T> extends StatelessWidget {
  const _AppDataRow({
    required this.item,
    required this.columns,
    required this.trailingColumns,
    required this.leadingBuilder,
    required this.itemKey,
    required this.selectedKey,
    required this.onTap,
    this.flexColW,
  });

  final T item;
  final List<AppColumnDef<T>> columns;
  final List<AppColumnDef<T>> trailingColumns;
  final Widget Function(BuildContext, T) leadingBuilder;
  final String Function(T) itemKey;
  final String? selectedKey;
  final void Function(T) onTap;
  final double? flexColW;

  @override
  Widget build(BuildContext context) {
    final selected = itemKey(item) == selectedKey;
    final ext = context.linearExt;
    return Semantics(
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(item),
          overlayColor: WidgetStatePropertyAll(ext.overlay),
          child: Container(
            height: 38,
            padding: const EdgeInsetsDirectional.symmetric(
                horizontal: LinearSpacing.base),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ext.borderSubtle)),
              color: selected
                  ? LinearColors.accent.withValues(alpha: 0.06)
                  : null,
            ),
            child: Row(
              children: [
                leadingBuilder(context, item),
                for (final col in columns)
                  if (col.flex)
                    if (flexColW != null)
                      SizedBox(
                        width: flexColW!,
                        child: ClipRect(child: col.builder(context, item, selected)),
                      )
                    else
                      Expanded(child: ClipRect(child: col.builder(context, item, selected)))
                  else
                    SizedBox(
                      width: col.width,
                      child: ClipRect(child: col.builder(context, item, selected)),
                    ),
                for (final col in trailingColumns)
                  SizedBox(
                    width: col.width,
                    child: ClipRect(child: col.builder(context, item, selected)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
