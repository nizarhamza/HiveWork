import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view_prefs_service.dart';

// ── Preference keys ───────────────────────────────────────────────────────────

const kPdfShowClientAddress    = 'pdf.show_client_address';
const kPdfShowClientPhone      = 'pdf.show_client_phone';
const kPdfShowClientTaxId      = 'pdf.show_client_tax_id';
const kPdfShowContractNumber   = 'pdf.show_contract_number';
const kPdfShowValidityDate     = 'pdf.show_validity_date';
const kPdfShowPaymentMode      = 'pdf.show_payment_mode';
const kPdfShowUnitColumn       = 'pdf.show_unit_column';
const kPdfShowDiscountColumn   = 'pdf.show_discount_column';
const kPdfShowPaymentTerms     = 'pdf.show_payment_terms';
const kPdfShowBankDetails      = 'pdf.show_bank_details';
const kPdfShowSignatures       = 'pdf.show_signatures';
const kPdfShowTvaRecap         = 'pdf.show_tva_recap';
const kPdfShowMontantEnLettres = 'pdf.show_montant_en_lettres';
const kPdfCustomFields         = 'pdf.custom_fields';

// ── Custom-field selection (key + label pair) ─────────────────────────────────

class PdfCustomField {
  const PdfCustomField({required this.key, required this.label});
  final String key;
  final String label;
}

// ── Model ─────────────────────────────────────────────────────────────────────

class PdfLayoutPrefs {
  const PdfLayoutPrefs({
    this.showClientAddress    = true,
    this.showClientPhone      = true,
    this.showClientTaxId      = true,
    this.showContractNumber   = true,
    this.showValidityDate     = true,
    this.showPaymentMode      = true,
    this.showUnitColumn       = true,
    this.showDiscountColumn   = true,
    this.showPaymentTerms     = true,
    this.showBankDetails      = true,
    this.showSignatures       = true,
    this.showTvaRecap         = true,
    this.showMontantEnLettres = true,
    this.customFields         = const [],
  });

  final bool showClientAddress;
  final bool showClientPhone;
  final bool showClientTaxId;
  final bool showContractNumber;
  final bool showValidityDate;
  final bool showPaymentMode;
  final bool showUnitColumn;
  final bool showDiscountColumn;
  final bool showPaymentTerms;
  final bool showBankDetails;
  final bool showSignatures;
  final bool showTvaRecap;
  final bool showMontantEnLettres;
  final List<PdfCustomField> customFields;

  static Future<bool> _b(String key) async =>
      (await ViewPrefsService.getBoolOrNull(key)) ?? true;

  static Future<List<PdfCustomField>> _loadCustomFields() async {
    final raw = await ViewPrefsService.getString(kPdfCustomFields);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => PdfCustomField(
                key:   e['key']   as String,
                label: e['label'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<PdfLayoutPrefs> load() async => PdfLayoutPrefs(
        showClientAddress:    await _b(kPdfShowClientAddress),
        showClientPhone:      await _b(kPdfShowClientPhone),
        showClientTaxId:      await _b(kPdfShowClientTaxId),
        showContractNumber:   await _b(kPdfShowContractNumber),
        showValidityDate:     await _b(kPdfShowValidityDate),
        showPaymentMode:      await _b(kPdfShowPaymentMode),
        showUnitColumn:       await _b(kPdfShowUnitColumn),
        showDiscountColumn:   await _b(kPdfShowDiscountColumn),
        showPaymentTerms:     await _b(kPdfShowPaymentTerms),
        showBankDetails:      await _b(kPdfShowBankDetails),
        showSignatures:       await _b(kPdfShowSignatures),
        showTvaRecap:         await _b(kPdfShowTvaRecap),
        showMontantEnLettres: await _b(kPdfShowMontantEnLettres),
        customFields:         await _loadCustomFields(),
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final pdfLayoutPrefsProvider = FutureProvider<PdfLayoutPrefs>(
  (_) => PdfLayoutPrefs.load(),
);

/// Saves a single toggle to SharedPreferences; call [ref.invalidate] after.
Future<void> savePdfLayoutPref(String key, bool value) =>
    ViewPrefsService.setBoolOrNull(key, value);

/// Saves the list of custom fields to show in the PDF client block.
Future<void> savePdfCustomFields(List<PdfCustomField> fields) async {
  final json = jsonEncode(
    fields.map((f) => {'key': f.key, 'label': f.label}).toList(),
  );
  await ViewPrefsService.setString(kPdfCustomFields, json);
}
