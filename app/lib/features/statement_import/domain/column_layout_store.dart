import 'package:parser_core/parser_core.dart';

/// Remembers the column mapping the user confirmed for a spreadsheet layout,
/// keyed by its header signature, so the next statement from the same bank
/// opens already mapped (FR-05-28).
abstract interface class ColumnLayoutStore {
  /// The saved mapping for [signature], or null.
  Future<ColumnMapping?> find(String signature);

  /// Saves [mapping] for [signature].
  Future<void> save(String signature, ColumnMapping mapping);

  /// Forgets every saved layout.
  Future<void> clear();
}
