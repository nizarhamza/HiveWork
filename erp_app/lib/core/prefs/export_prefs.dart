import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view_prefs_service.dart';

const kPrefRootFolder     = 'export.root_folder';
// Kept so quote_pdf.dart and future invoice code can read the derived paths.
const kPrefQuotesFolder   = 'export.quotes_folder';
const kPrefInvoicesFolder = 'export.invoices_folder';

class ExportPrefs {
  const ExportPrefs({this.rootFolder});
  final String? rootFolder;

  String? get quotesFolder   => rootFolder != null ? _join(rootFolder!, 'Quotes')   : null;
  String? get invoicesFolder => rootFolder != null ? _join(rootFolder!, 'Invoices') : null;

  static String _join(String root, String sub) {
    final sep = root.contains('\\') ? r'\' : '/';
    return root.endsWith(sep) ? '$root$sub' : '$root$sep$sub';
  }
}

final exportPrefsProvider = FutureProvider<ExportPrefs>((ref) async {
  final raw = await ViewPrefsService.getString(kPrefRootFolder);
  final root = (raw?.trim().isEmpty ?? true) ? null : raw!.trim();
  return ExportPrefs(rootFolder: root);
});

/// Saves [rootFolder] and writes the derived subfolder keys so existing
/// consumers (e.g. quote_pdf.dart) keep working without changes.
Future<void> saveExportRoot(String? rootFolder) async {
  final trimmed = rootFolder?.trim() ?? '';
  if (trimmed.isEmpty) {
    await ViewPrefsService.removeKey(kPrefRootFolder);
    await ViewPrefsService.removeKey(kPrefQuotesFolder);
    await ViewPrefsService.removeKey(kPrefInvoicesFolder);
  } else {
    final prefs = ExportPrefs(rootFolder: trimmed);
    await ViewPrefsService.setString(kPrefRootFolder,     trimmed);
    await ViewPrefsService.setString(kPrefQuotesFolder,   prefs.quotesFolder!);
    await ViewPrefsService.setString(kPrefInvoicesFolder, prefs.invoicesFolder!);
  }
}
