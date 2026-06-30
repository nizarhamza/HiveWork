/// French number-to-words conversion, used for the "montant en lettres"
/// (amount in words) line on quotes/invoices — a standard requirement on
/// Tunisian/French-style commercial documents.
library;

const _kUnits = [
  '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
  'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
  'dix-sept', 'dix-huit', 'dix-neuf',
];

String _tens(int n) {
  if (n < 20) return _kUnits[n];
  if (n < 70) {
    final tensWord = switch (n ~/ 10) {
      2 => 'vingt',
      3 => 'trente',
      4 => 'quarante',
      5 => 'cinquante',
      6 => 'soixante',
      _ => '',
    };
    final rem = n % 10;
    if (rem == 0) return tensWord;
    if (rem == 1) return '$tensWord-et-un';
    return '$tensWord-${_kUnits[rem]}';
  }
  if (n < 80) {
    final rem = n - 60; // 10..19
    if (rem == 11) return 'soixante-et-onze';
    return 'soixante-${_kUnits[rem]}';
  }
  final rem = n - 80; // 0..19
  if (rem == 0) return 'quatre-vingts';
  return 'quatre-vingt-${_kUnits[rem]}';
}

String _hundreds(int n) {
  if (n < 100) return _tens(n);
  final h   = n ~/ 100;
  final rem = n % 100;
  final prefix = h == 1 ? 'cent' : '${_kUnits[h]} cent';
  if (rem == 0) return h > 1 ? '${prefix}s' : prefix;
  return '$prefix ${_tens(rem)}';
}

String _convertGroup(int n) {
  if (n < 1000) return _hundreds(n);
  final parts = <String>[];

  final billions = n ~/ 1000000000;
  n %= 1000000000;
  final millions = n ~/ 1000000;
  n %= 1000000;
  final thousands = n ~/ 1000;
  final rest = n % 1000;

  if (billions > 0) {
    parts.add('${_hundreds(billions)} milliard${billions > 1 ? 's' : ''}');
  }
  if (millions > 0) {
    parts.add('${_hundreds(millions)} million${millions > 1 ? 's' : ''}');
  }
  if (thousands > 0) {
    parts.add(thousands == 1 ? 'mille' : '${_hundreds(thousands)} mille');
  }
  if (rest > 0) parts.add(_hundreds(rest));

  return parts.join(' ');
}

/// Converts a non-negative integer to French words, e.g. 20456 ->
/// "vingt mille quatre cent cinquante-six".
String numberToFrenchWords(int n) {
  if (n == 0) return 'zéro';
  if (n < 0) return 'moins ${numberToFrenchWords(-n)}';
  return _convertGroup(n);
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Major/minor unit words for a given currency code, used in the
/// "montant en lettres" line. Defaults to the currency code itself if
/// unknown (e.g. "TND" -> "dinars"/"millimes").
(String major, String minor) currencyWordsFor(String code) =>
    switch (code.toUpperCase()) {
      'TND' => ('dinars', 'millimes'),
      'EUR' => ('euros', 'centimes'),
      'USD' => ('dollars', 'cents'),
      'GBP' => ('livres sterling', 'pence'),
      _     => (code, 'centimes'),
    };

/// Formats [amount] as a French "montant en lettres" sentence, e.g.
/// `amountInWordsFrench(20456.0, currency: 'TND')` ->
/// "Vingt mille quatre cent cinquante-six dinars".
///
/// Tunisian dinar amounts carry 3 decimal places (millimes); other
/// currencies use 2 (cents/centimes) — pass [minorDigits] to override.
String amountInWordsFrench(
  double amount, {
  String currency    = 'TND',
  int?   minorDigits,
}) {
  final digits = minorDigits ?? (currency.toUpperCase() == 'TND' ? 3 : 2);
  final factor = _intPow10(digits);
  final major  = amount.truncate();
  final minor  = ((amount - major) * factor).round();
  final (majorWord, minorWord) = currencyWordsFor(currency);

  final majorPart = '${_capitalize(numberToFrenchWords(major))} $majorWord';
  if (minor == 0) return majorPart;
  return '$majorPart et ${numberToFrenchWords(minor)} $minorWord';
}

int _intPow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
