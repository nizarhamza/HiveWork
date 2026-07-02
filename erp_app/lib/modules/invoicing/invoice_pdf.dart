import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/platform/file_saver.dart' as file_saver;
import '../../core/prefs/export_prefs.dart';
import '../../core/prefs/view_prefs_service.dart';
import '../../core/utils/french_words.dart';
import '../../data/models/invoice.dart';
import '../../theme/linear_tokens.dart';
import '../org/org_details.dart';
import '../../core/prefs/pdf_layout_prefs.dart';

pw.Font? _monoFont;

// ── Palette (shared with quote_pdf) ──────────────────────────────────────────

const _accent       = PdfColor.fromInt(0xFF3D4B6B);
const _accentSoft   = PdfColor.fromInt(0xFFEEF3FB);
const _catBg        = PdfColor.fromInt(0xFFEEF1F7);
const _subCatBg     = PdfColor.fromInt(0xFFF7F8FC);
const _rowTint      = PdfColor.fromInt(0xFFF7F8FA);
const _ttcHighlight = PdfColor.fromInt(0xFFEEF0F8);
const _sigBg        = PdfColor.fromInt(0xFFF9F9FB);
const _greyBorder   = PdfColor.fromInt(0xFFE2E4E9);
const _textMuted    = PdfColor.fromInt(0xFF9CA3AF);
const _fodecBg      = PdfColor.fromInt(0xFFFFF8DC);
const _fodecBorder  = PdfColor.fromInt(0xFFE6C34B);
const _fodecText    = PdfColor.fromInt(0xFF7A5F00);
const _netBg        = _accent;

// ── Public API ────────────────────────────────────────────────────────────────

Future<void> showInvoicePdfPreview(
  BuildContext context,
  InvoiceWithClient item, {
  required OrgDetails org,
}) async {
  final fileName =
      'invoice_${item.invoice.number.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _InvoicePdfPreviewDialog(
      item:     item,
      org:      org,
      fileName: fileName,
    ),
  );
}

// ── PDF bytes builder ─────────────────────────────────────────────────────────

Future<Uint8List> _buildInvoicePdfBytes(
  InvoiceWithClient item, {
  required OrgDetails org,
}) async {
  final inv  = item.invoice;
  final doc  = pw.Document();
  final rows = _flattenInvLines(inv.lines);
  final tva  = inv.tvaByRate;

  final fontBase   = await PdfGoogleFonts.notoSansRegular();
  final fontBold   = await PdfGoogleFonts.notoSansBold();
  final fontItalic = await PdfGoogleFonts.notoSansItalic();
  _monoFont        = await PdfGoogleFonts.robotoMonoRegular();

  final prefs = await PdfLayoutPrefs.load();

  final theme = pw.ThemeData.withFont(
    base:       fontBase,
    bold:       fontBold,
    italic:     fontItalic,
    boldItalic: fontBold,
  );

  pw.ImageProvider? logoImage;
  if (org.logoUrl != null && org.logoUrl!.isNotEmpty) {
    try { logoImage = await networkImage(org.logoUrl!); } catch (_) {}
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin:     const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      theme:      theme,
      footer:     (ctx) => _footer(org, inv, ctx),
      build: (_) => [
        _header(org, logoImage),
        pw.SizedBox(height: 4),
        pw.Divider(color: _greyBorder, height: 1),
        pw.SizedBox(height: 12),
        _clientMetaRow(item, inv, prefs),
        pw.SizedBox(height: 10),
        if (_notEmpty(inv.objet)) ...[
          _objet(inv.objet!),
          pw.SizedBox(height: 8),
        ],
        _lineTable(inv, rows, prefs),
        if (tva.isNotEmpty && prefs.showTvaRecap) ...[
          pw.SizedBox(height: 10),
          _tvaRecap(inv, tva),
        ],
        pw.SizedBox(height: 14),
        _bottomRow(org, inv, prefs),
        if (prefs.showSignatures) ...[
          pw.Expanded(child: pw.SizedBox()),
          _signatures(),
        ],
      ],
    ),
  );

  return doc.save();
}

// ── Line tree helpers (inline equivalent of flattenQuoteLines) ────────────────

class _InvRow {
  const _InvRow({
    required this.line,
    required this.depth,
    required this.number,
    required this.isLeaf,
    required this.displayTotal,
  });

  final InvoiceLine line;
  final int         depth;
  final String      number;
  final bool        isLeaf;
  final double      displayTotal;
}

List<_InvRow> _flattenInvLines(List<InvoiceLine> lines) {
  final byParent = <String?, List<InvoiceLine>>{};
  for (final l in lines) {
    byParent.putIfAbsent(l.parentId, () => []).add(l);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.position.compareTo(b.position));
  }

  final out = <_InvRow>[];

  void walk(InvoiceLine l, List<int> prefix) {
    final children = byParent[l.id] ?? const <InvoiceLine>[];
    final isLeaf   = children.isEmpty;
    final total    = isLeaf
        ? l.lineTotal
        : children.fold(0.0, (s, c) => s + c.lineTotal);
    out.add(_InvRow(
      line:         l,
      depth:        prefix.length - 1,
      number:       prefix.join('.'),
      isLeaf:       isLeaf,
      displayTotal: total,
    ));
    for (var i = 0; i < children.length; i++) {
      walk(children[i], [...prefix, i + 1]);
    }
  }

  final roots = byParent[null] ?? const <InvoiceLine>[];
  for (var i = 0; i < roots.length; i++) {
    walk(roots[i], [i + 1]);
  }
  return out;
}

// ── In-app PDF preview dialog ─────────────────────────────────────────────────

class _InvoicePdfPreviewDialog extends StatefulWidget {
  const _InvoicePdfPreviewDialog({
    required this.item,
    required this.org,
    required this.fileName,
  });

  final InvoiceWithClient item;
  final OrgDetails        org;
  final String            fileName;

  @override
  State<_InvoicePdfPreviewDialog> createState() =>
      _InvoicePdfPreviewDialogState();
}

class _InvoicePdfPreviewDialogState extends State<_InvoicePdfPreviewDialog> {
  bool    _printing    = false;
  bool    _downloading = false;
  String? _invoicesFolder;

  @override
  void initState() {
    super.initState();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final v       = await ViewPrefsService.getString(kPrefInvoicesFolder);
    final trimmed = v?.trim();
    if (mounted) {
      setState(() =>
          _invoicesFolder = (trimmed?.isNotEmpty == true) ? trimmed : null);
    }
  }

  Future<Uint8List> _bytes(PdfPageFormat _) =>
      _buildInvoicePdfBytes(widget.item, org: widget.org);

  bool get _hasFolder =>
      _invoicesFolder != null && file_saver.canSaveToFolder;

  @override
  Widget build(BuildContext context) {
    final lx     = context.linearExt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: lx.pageBg,
      insetPadding:    const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: lx.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  900,
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: Column(
          children: [
            _buildHeader(lx),
            Divider(height: 1, color: lx.borderSubtle),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(10)),
                child: ColoredBox(
                  color: isDark
                      ? const Color(0xFF1A1A1C)
                      : const Color(0xFFE8E8EA),
                  child: PdfPreview(
                    build:                _bytes,
                    pdfFileName:          widget.fileName,
                    allowSharing:         false,
                    allowPrinting:        false,
                    canChangePageFormat:  false,
                    canChangeOrientation: false,
                    canDebug:             false,
                    actions:              const [],
                    initialPageFormat:    PdfPageFormat.a4,
                    scrollViewDecoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1A1C)
                          : const Color(0xFFE8E8EA),
                    ),
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: lx.borderSubtle),
            _buildFooter(lx),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LinearExt lx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 17, color: lx.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.fileName,
                style: TextStyle(
                  color:      lx.textPrimary,
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color:        Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: lx.textMuted),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildFooter(LinearExt lx) => ColoredBox(
        color: lx.surfaceBase,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (_hasFolder) ...[
                Icon(Icons.folder_outlined, size: 13, color: lx.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _invoicesFolder!,
                    style: TextStyle(fontSize: 11, color: lx.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
              ] else
                const Spacer(),
              _GhostButton(
                icon:    Icons.print_outlined,
                label:   'Print',
                loading: _printing,
                lx:      lx,
                onPressed: () async {
                  setState(() => _printing = true);
                  try {
                    final bytes = await _buildInvoicePdfBytes(
                      widget.item,
                      org: widget.org,
                    );
                    await Printing.layoutPdf(
                      onLayout: (_) async => bytes,
                      name:     widget.fileName,
                    );
                  } finally {
                    if (mounted) setState(() => _printing = false);
                  }
                },
              ),
              const SizedBox(width: 10),
              _PrimaryButton(
                icon:    _hasFolder ? Icons.save_outlined : Icons.download_outlined,
                label:   _hasFolder ? 'Save PDF' : 'Download PDF',
                loading: _downloading,
                onPressed: () async {
                  setState(() => _downloading = true);
                  try {
                    final bytes = await _buildInvoicePdfBytes(
                      widget.item,
                      org: widget.org,
                    );
                    if (_hasFolder) {
                      final saved = await file_saver.saveToFolder(
                        _invoicesFolder!, widget.fileName, bytes,
                      );
                      if (saved && mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        final folder    = _invoicesFolder!;
                        Navigator.of(context).pop();
                        messenger.showSnackBar(SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text('PDF saved to $folder')),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                          width:    420,
                        ));
                        return;
                      }
                    }
                    await Printing.sharePdf(
                      bytes:    bytes,
                      filename: widget.fileName,
                    );
                  } finally {
                    if (mounted) setState(() => _downloading = false);
                  }
                },
              ),
            ],
          ),
        ),
      );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.lx,
    required this.onPressed,
  });

  final IconData     icon;
  final String       label;
  final bool         loading;
  final LinearExt    lx;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: loading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(icon, size: 15),
        label:     Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: lx.textSecondary,
          side:            BorderSide(color: lx.borderBase),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final IconData     icon;
  final String       label;
  final bool         loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        icon: loading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white))
            : Icon(icon, size: 15),
        label:     Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5E6AD2),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      );
}

// ── Header: logo/org name (left) | org full details (right) ──────────────────

pw.Widget _header(OrgDetails org, pw.ImageProvider? logoImage) {
  final addressParts = [
    if (_notEmpty(org.address)) org.address!,
    if (_notEmpty(org.country)) org.country!,
  ];
  final contactParts = [
    if (_notEmpty(org.phone)) 'Tél : ${org.phone}',
    if (_notEmpty(org.email)) 'Email : ${org.email}',
  ];
  final legalParts = [
    if (_notEmpty(org.taxId))     'MF : ${org.taxId}',
    if (_notEmpty(org.rcNumber))  'RC : ${org.rcNumber}',
    if (_notEmpty(org.rneNumber)) 'RNE : ${org.rneNumber}',
  ];

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width:  150,
        height: 68,
        decoration: pw.BoxDecoration(
          border:       pw.Border.all(color: _greyBorder, width: 1),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        alignment: pw.Alignment.center,
        padding:   const pw.EdgeInsets.all(8),
        child: logoImage != null
            ? pw.Image(logoImage, fit: pw.BoxFit.contain)
            : pw.Text(
                org.name,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: _accent),
              ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(org.name,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            if (addressParts.isNotEmpty)
              pw.Text(addressParts.join(' | '),
                  style: const pw.TextStyle(fontSize: 9)),
            if (contactParts.isNotEmpty)
              pw.Text(contactParts.join('   |   '),
                  style: const pw.TextStyle(fontSize: 9)),
            if (legalParts.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(
                  legalParts.join('   |   '),
                  style: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: _accent),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

// ── Client block (left) | FACTURE meta (right) ────────────────────────────────

pw.Widget _clientMetaRow(InvoiceWithClient item, Invoice inv, PdfLayoutPrefs prefs) {
  final date = inv.issueDate ?? inv.createdAt;

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 5,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DESTINATAIRE',
              style: pw.TextStyle(
                fontSize:      7.5,
                color:         _textMuted,
                fontWeight:    pw.FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              item.clientName ?? inv.clientSnapshotName ?? 'Client',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
            if (prefs.showClientAddress && _notEmpty(inv.clientSnapshotAddress))
              pw.Text(inv.clientSnapshotAddress!,
                  style: const pw.TextStyle(fontSize: 9.5)),
            if (prefs.showClientPhone && _notEmpty(inv.clientSnapshotPhone))
              pw.Text('Tél : ${inv.clientSnapshotPhone}',
                  style: const pw.TextStyle(fontSize: 9.5)),
            if (prefs.showClientTaxId && _notEmpty(inv.clientSnapshotTaxId))
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  'MF : ${inv.clientSnapshotTaxId}',
                  style: pw.TextStyle(
                      fontSize: 8.5, color: _accent, fontWeight: pw.FontWeight.bold),
                ),
              ),
            for (final cf in prefs.customFields)
              if (_notEmpty(inv.clientSnapshotCustomFields[cf.key]?.toString()))
                pw.Text(
                  '${cf.label} : ${inv.clientSnapshotCustomFields[cf.key]}',
                  style: const pw.TextStyle(fontSize: 9.5),
                ),
          ],
        ),
      ),
      pw.SizedBox(width: 24),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'FACTURE',
            style: pw.TextStyle(fontSize: 28, color: _accent, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _metaLine('N°', inv.number, bold: true),
          if (prefs.showContractNumber && _notEmpty(inv.contractNumber)) _metaLine('N° Contrat', inv.contractNumber!),
          _metaLine('Date', _fmtDate(date)),
          if (prefs.showValidityDate && inv.dueDate != null) _metaLine('Échéance', _fmtDate(inv.dueDate!)),
          if (prefs.showPaymentMode && _notEmpty(inv.paymentMode))
            _metaLine('Payment Terms', _asciiSafe(inv.paymentMode!)),
        ],
      ),
    ],
  );
}

pw.Widget _metaLine(String label, String value, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1),
      child: pw.RichText(
        textAlign: pw.TextAlign.right,
        text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label : ', style: const pw.TextStyle(fontSize: 9.5)),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(
              fontSize:   9.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ]),
      ),
    );

// ── Objet ─────────────────────────────────────────────────────────────────────

pw.Widget _objet(String text) => pw.RichText(
      text: pw.TextSpan(children: [
        pw.TextSpan(
          text: 'Objet : ',
          style: pw.TextStyle(
              fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _textMuted),
        ),
        pw.TextSpan(
          text: text,
          style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
        ),
      ]),
    );

// ── Line table ────────────────────────────────────────────────────────────────

pw.Widget _lineTable(Invoice inv, List<_InvRow> rows, PdfLayoutPrefs prefs) {
  final dataRows = <pw.TableRow>[];
  var leafIdx = 0;
  for (final r in rows) {
    dataRows.addAll(_lineRows(inv, r, isEven: leafIdx % 2 == 0, prefs: prefs));
    if (r.isLeaf) leafIdx++;
  }

  var ci = 0;
  final colWidths = <int, pw.TableColumnWidth>{};
  colWidths[ci++] = const pw.FixedColumnWidth(28);
  colWidths[ci++] = const pw.FlexColumnWidth(4);
  if (prefs.showUnitColumn)     colWidths[ci++] = const pw.FixedColumnWidth(40);
  colWidths[ci++] = const pw.FixedColumnWidth(36);
  colWidths[ci++] = const pw.FixedColumnWidth(56);
  if (prefs.showDiscountColumn) colWidths[ci++] = const pw.FixedColumnWidth(50);
  colWidths[ci++] = const pw.FixedColumnWidth(36);
  colWidths[ci++] = const pw.FixedColumnWidth(64);

  return pw.Table(
    columnWidths: colWidths,
    border:       const pw.TableBorder(),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _accent),
        children: [
          _hdrCell('N°', center: true),
          _hdrCell('Désignation', left: true),
          if (prefs.showUnitColumn) _hdrCell('Unité'),
          _hdrCell('Qté'),
          _hdrCell('Prix U. HT'),
          if (prefs.showDiscountColumn) _hdrCell('Remise'),
          _hdrCell('TVA'),
          _hdrCell('Total HT'),
        ],
      ),
      ...dataRows,
    ],
  );
}

List<pw.TableRow> _lineRows(Invoice inv, _InvRow r, {required bool isEven, required PdfLayoutPrefs prefs}) {
  if (!r.isLeaf) {
    final bg       = r.depth == 0 ? _catBg : _subCatBg;
    final fontSize = r.depth == 0 ? 11.0 : 10.5;
    return [
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color:  bg,
          border: const pw.Border(bottom: pw.BorderSide(color: _greyBorder, width: 0.5)),
        ),
        children: [
          _cell(r.number, center: true, bold: true, color: _accent, fontSize: fontSize),
          _cell(r.line.label, left: true, bold: true, fontSize: fontSize),
          if (prefs.showUnitColumn) _cell(''),
          _cell(''), _cell(''),
          if (prefs.showDiscountColumn) _cell(''),
          _cell(''),
          _cell(_fmtMoney(r.displayTotal, inv.currency),
              right: true, bold: true, mono: true, fontSize: fontSize),
        ],
      ),
    ];
  }

  final l = r.line;
  return [
    pw.TableRow(
      decoration: pw.BoxDecoration(
        color:  isEven ? null : _rowTint,
        border: const pw.Border(
            bottom: pw.BorderSide(color: _greyBorder, width: 0.5)),
      ),
      children: [
        _cell(r.number, center: true, color: _accent, fontSize: 10),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Wrap(
            crossAxisAlignment: pw.WrapCrossAlignment.center,
            children: [
              pw.Text(l.label, style: const pw.TextStyle(fontSize: 10)),
              if (l.fodecApplicable && inv.fodecEnabled) ...[
                pw.SizedBox(width: 3),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: pw.BoxDecoration(
                    color:        _fodecBg,
                    border:       pw.Border.all(color: _fodecBorder, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    'FODEC ${_fmtPercent(inv.fodecRate)}',
                    style: pw.TextStyle(
                        fontSize: 6.5,
                        color:    _fodecText,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (prefs.showUnitColumn) _cell(_safeStr(l.unit), right: true, fontSize: 10),
        _cell(_fmtQty(l.qty), right: true, fontSize: 10),
        _cell(_fmtMoney(l.unitPrice, inv.currency, withSuffix: false),
            right: true, fontSize: 10),
        if (prefs.showDiscountColumn) _cell(l.discountRate > 0 ? '${_fmtPercent(l.discountRate)}%' : '-',
            right: true, fontSize: 10),
        _cell('${_fmtPercent(l.taxRate)}%', right: true, fontSize: 10),
        _cell(_fmtMoney(l.lineTotal, inv.currency, withSuffix: false),
            right: true, mono: true, fontSize: 10),
      ],
    ),
  ];
}

pw.Widget _hdrCell(String text, {bool center = false, bool left = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: center
            ? pw.TextAlign.center
            : (left ? pw.TextAlign.left : pw.TextAlign.right),
        style: pw.TextStyle(
          fontSize:      8.5,
          fontWeight:    pw.FontWeight.bold,
          color:         PdfColors.white,
          letterSpacing: 0.4,
        ),
      ),
    );

pw.Widget _cell(
  String text, {
  bool center   = false,
  bool left     = false,
  bool right    = false,
  bool bold     = false,
  bool mono     = false,
  double fontSize = 10,
  PdfColor? color,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: center
            ? pw.TextAlign.center
            : (right ? pw.TextAlign.right : pw.TextAlign.left),
        style: pw.TextStyle(
          fontSize:   fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color:      color ?? PdfColors.black,
          font:       mono ? _monoFont ?? pw.Font.courier() : null,
        ),
      ),
    );

// ── TVA recap ─────────────────────────────────────────────────────────────────

pw.Widget _tvaRecap(
    Invoice inv, Map<double, ({double base, double amount})> tva) {
  final rates = tva.keys.toList()..sort();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'RÉCAPITULATIF DES TAXES${inv.fodecEnabled ? ' (FODEC inclus dans base TVA)' : ''}',
        style: pw.TextStyle(
            fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted, letterSpacing: 0.5),
      ),
      pw.SizedBox(height: 4),
      pw.Container(
        decoration: pw.BoxDecoration(
          border:       pw.Border.all(color: _greyBorder, width: 0.8),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Table(
          border: const pw.TableBorder(),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF555555)),
              children: [
                _hdrCell('Taux TVA', center: true),
                _hdrCell('Base HT'),
                if (inv.fodecEnabled) _hdrCell('FODEC'),
                if (inv.fodecEnabled) _hdrCell('Base TVA'),
                _hdrCell('Montant TVA'),
              ],
            ),
            for (final rate in rates)
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(
                          color: PdfColor.fromInt(0xFFEEEEEE), width: 0.5)),
                ),
                children: [
                  _cell('${_fmtPercent(rate)}%',
                      center: true, color: _accent, bold: true, fontSize: 9.5),
                  _cell(
                    _fmtMoney(
                      tva[rate]!.base -
                          (inv.fodecEnabled
                              ? tva[rate]!.base * inv.fodecRate / (100 + inv.fodecRate)
                              : 0),
                      inv.currency,
                      withSuffix: false,
                    ),
                    right: true, mono: true, fontSize: 9.5,
                  ),
                  if (inv.fodecEnabled)
                    _cell(
                      _fmtMoney(
                          tva[rate]!.base * inv.fodecRate / (100 + inv.fodecRate),
                          inv.currency,
                          withSuffix: false),
                      right: true, mono: true, fontSize: 9.5,
                    ),
                  if (inv.fodecEnabled)
                    _cell(_fmtMoney(tva[rate]!.base, inv.currency, withSuffix: false),
                        right: true, mono: true, fontSize: 9.5),
                  _cell(_fmtMoney(tva[rate]!.amount, inv.currency, withSuffix: false),
                      right: true, mono: true, fontSize: 9.5),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}

// ── Bottom row: payment/bank (left) | totals (right) ─────────────────────────

pw.Widget _bottomRow(OrgDetails org, Invoice inv, PdfLayoutPrefs prefs) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 5, child: _paymentColumn(org, inv, prefs)),
        pw.SizedBox(width: 16),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _totalsColumn(inv),
              if (prefs.showMontantEnLettres) ...[
                pw.SizedBox(height: 8),
                _montantEnLettres(inv),
              ],
            ],
          ),
        ),
      ],
    );

pw.Widget _paymentColumn(OrgDetails org, Invoice inv, PdfLayoutPrefs prefs) {
  final snapshot    = inv.paymentTermSnapshot ?? <Map<String, dynamic>>[];
  final hasSnapshot = snapshot.isNotEmpty;
  final fallbackText = !hasSnapshot
      ? (_safeVal(inv.notes) ?? _safeVal(org.defaultPaymentTerms))
      : null;
  final showTerms = prefs.showPaymentTerms && (hasSnapshot || fallbackText != null);

  final hasBank = _notEmpty(org.bankName) || _notEmpty(org.bankRib) ||
      _notEmpty(org.bankIban) || _notEmpty(org.bankBic);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (showTerms) ...[
        _labeledBox(
          label: 'PAYMENT TERMS',
          child: hasSnapshot
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: snapshot
                      .map((inst) => pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              '- ${inst['percent']}% : ${inst['label']}',
                              style: const pw.TextStyle(fontSize: 9.5),
                            ),
                          ))
                      .toList(),
                )
              : pw.Text(fallbackText!, style: const pw.TextStyle(fontSize: 9.5)),
        ),
        pw.SizedBox(height: 8),
      ],
      if (prefs.showBankDetails && hasBank) ...[
        _labeledBox(
          label: 'COORDONNÉES BANCAIRES',
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (_notEmpty(org.bankName))
                pw.Text('Banque : ${org.bankName}',
                    style: const pw.TextStyle(fontSize: 9.5)),
              if (_notEmpty(org.bankRib))
                pw.Text('RIB : ${org.bankRib}',
                    style: pw.TextStyle(
                        fontSize: 9, font: _monoFont ?? pw.Font.courier())),
              if (_notEmpty(org.bankIban))
                pw.Text('IBAN : ${org.bankIban}',
                    style: pw.TextStyle(
                        fontSize: 9, font: _monoFont ?? pw.Font.courier())),
              if (_notEmpty(org.bankBic))
                pw.Text('BIC : ${org.bankBic}',
                    style: pw.TextStyle(
                        fontSize: 9, font: _monoFont ?? pw.Font.courier())),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
      ],
      if (inv.rsEnabled)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: pw.BoxDecoration(
            color:  _accentSoft,
            border: const pw.Border(
                left: pw.BorderSide(color: _accent, width: 2.5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Retenue à la source (RS) — ${_fmtPercent(inv.rsRate)}%',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1A3560)),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Montant RS à déduire : ${_fmtMoney(inv.rsAmount, inv.currency)}',
                style: const pw.TextStyle(
                    fontSize: 8.5, color: PdfColor.fromInt(0xFF2C4A7C)),
              ),
              pw.Text(
                'Le client remet un certificat RS via la plateforme TEJ.',
                style: const pw.TextStyle(
                    fontSize: 8.5, color: PdfColor.fromInt(0xFF2C4A7C)),
              ),
            ],
          ),
        ),
    ],
  );
}

pw.Widget _labeledBox({required String label, required pw.Widget child}) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border:       pw.Border.all(color: _greyBorder, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
                fontSize:   7,
                color:      _textMuted,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5),
          ),
          pw.SizedBox(height: 4),
          child,
        ],
      ),
    );

pw.Widget _totalsColumn(Invoice inv) {
  final rows = <pw.Widget>[
    _totalRow('Total HT', _fmtMoney(inv.subtotal, inv.currency)),
  ];
  if (inv.fodecEnabled && inv.fodecAmount > 0) {
    rows.add(_totalRow(
      'FODEC ${_fmtPercent(inv.fodecRate)}% (produits industriels)',
      _fmtMoney(inv.fodecAmount, inv.currency),
    ));
  }
  rows.add(pw.Divider(color: _greyBorder, height: 8));
  for (final entry in inv.tvaByRate.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    rows.add(_totalRow(
      'TVA ${_fmtPercent(entry.key)}% (base : ${_fmtMoney(entry.value.base, inv.currency)})',
      _fmtMoney(entry.value.amount, inv.currency),
    ));
  }
  if (inv.timbreEnabled) {
    rows.add(_totalRow('Timbre fiscal', _fmtMoney(inv.timbre, inv.currency)));
  }
  rows.add(pw.SizedBox(height: 4));
  rows.add(_totalRow(
    'Total TTC',
    _fmtMoney(inv.totalTtc + inv.timbre, inv.currency),
    bold:      true,
    highlight: true,
  ));
  if (inv.rsEnabled) {
    rows.add(_totalRow(
      '(–) Retenue à la source ${_fmtPercent(inv.rsRate)}%',
      '– ${_fmtMoney(inv.rsAmount, inv.currency)}',
    ));
    rows.add(pw.SizedBox(height: 4));
    rows.add(pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      color:   _netBg,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Net à payer',
              style: pw.TextStyle(
                  color:      PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize:   11)),
          pw.Text(_fmtMoney(inv.netToPay, inv.currency),
              style: pw.TextStyle(
                  color:      PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize:   12)),
        ],
      ),
    ));
  }
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: rows);
}

pw.Widget _totalRow(String label, String value,
    {bool bold = false, bool highlight = false}) {
  final content = pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 3, horizontal: highlight ? 6 : 0),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize:   bold ? 10.5 : 9.5,
            color:      bold ? PdfColors.black : const PdfColor.fromInt(0xFF555555),
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize:   bold ? 11 : 9.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            font:       _monoFont ?? pw.Font.courier(),
          ),
        ),
      ],
    ),
  );

  if (highlight) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        color:  _ttcHighlight,
        border: pw.Border(top: pw.BorderSide(color: _accent, width: 1.5)),
      ),
      child: content,
    );
  }
  return content;
}

// ── Montant en lettres ────────────────────────────────────────────────────────

pw.Widget _montantEnLettres(Invoice inv) {
  final amount =
      inv.rsEnabled || inv.timbreEnabled ? inv.netToPay : inv.totalTtc;
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      color:  _subCatBg,
      border: const pw.Border(
          left: pw.BorderSide(color: _accent, width: 2.5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ARRÊTÉE LA PRÉSENTE À LA SOMME DE',
          style: pw.TextStyle(fontSize: 7, color: _textMuted, letterSpacing: 0.6),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '${amountInWordsFrench(amount, currency: inv.currency)} (${_fmtMoney(amount, inv.currency)})',
          style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );
}

// ── Signatures ────────────────────────────────────────────────────────────────

pw.Widget _signatures() => pw.Row(
      children: [
        pw.Expanded(child: _sigBox('Cachet & signature du fournisseur')),
        pw.SizedBox(width: 16),
        pw.Expanded(
            child: _sigBox('Bon pour accord - cachet & signature du client')),
      ],
    );

pw.Widget _sigBox(String label) => pw.Container(
      height:  70,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color:        _sigBg,
        border:       pw.Border.all(color: _greyBorder),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(
            fontSize:   7,
            color:      _textMuted,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5),
      ),
    );

// ── Footer ────────────────────────────────────────────────────────────────────

pw.Widget _footer(OrgDetails org, Invoice inv, pw.Context ctx) {
  final footerParts = [
    org.name,
    if (_notEmpty(org.address))  org.address!,
    if (_notEmpty(org.rcNumber)) 'RC : ${org.rcNumber}',
    if (_notEmpty(org.rneNumber)) 'RNE : ${org.rneNumber}',
  ];
  final mfLine = _notEmpty(org.taxId)
      ? '\nMF : ${org.taxId} - Assujetti a la TVA'
      : '';

  return pw.Container(
    margin:  const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _greyBorder, width: 0.6))),
    child: pw.Row(
      mainAxisAlignment:  pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            footerParts.join(' | ') + mfLine,
            style: const pw.TextStyle(fontSize: 7.5, color: _textMuted),
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(inv.number,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    color:    _textMuted,
                    font:     _monoFont ?? pw.Font.courier())),
            pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7.5, color: _textMuted)),
          ],
        ),
      ],
    ),
  );
}

// ── Formatting helpers ────────────────────────────────────────────────────────

String _asciiSafe(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('•', '-')
    .replaceAll('·', '|')
    .replaceAll('‘', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"');

bool    _notEmpty(String? s) => s != null && s.trim().isNotEmpty;
String? _safeVal(String? s)  => _notEmpty(s) ? s : null;
String  _safeStr(String? s)  => _notEmpty(s) ? s! : '-';

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String _fmtPercent(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _fmtQty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _fmtMoney(double v, String currency, {bool withSuffix = true}) {
  final isTnd    = currency.toUpperCase() == 'TND';
  final decimals = isTnd ? 3 : 2;
  final number   = _fmtGrouped(v, decimals);
  if (!withSuffix) return number;
  if (isTnd) return '$number DT';
  final sym = switch (currency.toUpperCase()) {
    'EUR' => '€',
    'USD' => '\$',
    'GBP' => '£',
    _     => '$currency ',
  };
  return '$sym$number';
}

String _fmtGrouped(double v, int decimals) {
  final neg   = v < 0;
  final fixed = v.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts.length > 1 ? parts[1] : '';
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(' ');
    buf.write(intPart[i]);
  }
  final result = decimals > 0 ? '$buf,$decPart' : buf.toString();
  return neg ? '-$result' : result;
}
