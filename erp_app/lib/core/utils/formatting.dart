import 'package:intl/intl.dart';

/// Shared number formatters — single source of truth (F-3/R-1).
///
/// Use [fmtPrice] for monetary amounts (3 decimal places, Tunisian convention).
/// Use [fmtQty] for quantities / plain numbers (strips trailing zeros up to 3 dp).

final _priceFormat = NumberFormat('#,##0.000');
final _qtyFormat   = NumberFormat('#,##0.###');

/// Formats a price/amount with 3 decimal places (e.g. 1,250.000).
String fmtPrice(double v) => _priceFormat.format(v);

/// Formats a quantity — trims trailing zeros up to 3 decimal places.
String fmtQty(double v) => _qtyFormat.format(v);
