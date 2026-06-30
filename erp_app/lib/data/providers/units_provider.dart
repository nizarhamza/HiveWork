import 'package:flutter_riverpod/flutter_riverpod.dart';

const kDefaultUnits = [
  'Piece', 'Metre', 'Metre²', 'Metre³', 'Kg',
  'Tonne', 'Litre', 'Box', 'Roll', 'Lot', 'Hour', 'Flat rate',
];

final unitsProvider =
    NotifierProvider<UnitsNotifier, List<String>>(UnitsNotifier.new);

class UnitsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => List.unmodifiable(kDefaultUnits);

  void addUnit(String unit) {
    final trimmed = unit.trim();
    if (trimmed.isEmpty) return;
    if (state.any((u) => u.toLowerCase() == trimmed.toLowerCase())) return;
    state = List.unmodifiable([...state, trimmed]);
  }
}
