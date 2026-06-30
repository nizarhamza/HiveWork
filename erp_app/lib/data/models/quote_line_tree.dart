import 'quote.dart';

/// A [QuoteLine] plus its nested children, built from the flat
/// `parent_id`-linked rows returned by Supabase.
class QuoteLineNode {
  const QuoteLineNode(this.line, this.children);

  final QuoteLine line;
  final List<QuoteLineNode> children;

  bool get isLeaf => children.isEmpty;

  /// Leaf rows use their own stored total; category/sub-category rows
  /// roll up the sum of their descendants (the stored total on a parent
  /// row is not trusted, mirroring how the OBAT template always shows a
  /// computed category subtotal).
  double get total =>
      isLeaf ? line.lineTotal : children.fold(0.0, (s, c) => s + c.total);
}

/// Builds the category/sub-category/detail tree from a flat list of
/// [QuoteLine]s using their `parentId` links.
List<QuoteLineNode> buildQuoteLineTree(List<QuoteLine> lines) {
  final byParent = <String?, List<QuoteLine>>{};
  for (final l in lines) {
    byParent.putIfAbsent(l.parentId, () => []).add(l);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.position.compareTo(b.position));
  }
  QuoteLineNode build(QuoteLine l) =>
      QuoteLineNode(l, (byParent[l.id] ?? []).map(build).toList());
  return (byParent[null] ?? []).map(build).toList();
}

/// One row of a flattened (pre-order) walk of the line tree, carrying
/// its nesting [depth] (0 = top-level) and dotted [number] (e.g. "1.2.1").
class QuoteLineRow {
  const QuoteLineRow(this.node, this.depth, this.number);

  final QuoteLineNode node;
  final int depth;
  final String number;

  QuoteLine get line => node.line;
  bool get isLeaf => node.isLeaf;
  double get displayTotal => node.total;
}

/// Flattens a line tree into ordered rows with computed depth + numbering,
/// ready for table rendering (PDF or in-app).
List<QuoteLineRow> flattenQuoteLineTree(List<QuoteLineNode> roots) {
  final out = <QuoteLineRow>[];
  void walk(List<QuoteLineNode> nodes, List<int> prefix) {
    for (var i = 0; i < nodes.length; i++) {
      final path = [...prefix, i + 1];
      out.add(QuoteLineRow(nodes[i], prefix.length, path.join('.')));
      walk(nodes[i].children, path);
    }
  }
  walk(roots, const []);
  return out;
}

/// Convenience: builds + flattens in one call.
List<QuoteLineRow> flattenQuoteLines(List<QuoteLine> lines) =>
    flattenQuoteLineTree(buildQuoteLineTree(lines));
