import 'package:parser_core/src/merchant/subcategory_data.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';

/// One built-in sub-category: name, icon key and the merchant pattern that
/// puts a transaction in it (null for a fallback entry).
class SubcategoryDef {
  /// Creates a definition.
  const SubcategoryDef(this.name, this.icon, [this.pattern]);

  /// Display name.
  final String name;

  /// Icon key in the app's icon library.
  final String icon;

  /// Case-insensitive regex over `"merchant upiId"`, or null.
  final String? pattern;
}

/// The popular sub-categories of each category, with the merchants that
/// usually belong in them (FR-06-17). A transaction the user has not placed is
/// put in the first sub-category whose pattern matches its merchant; one that
/// matches none is "Other".
abstract final class Subcategories {
  /// The fallback sub-category name.
  static const other = 'Other';

  static final Map<SubcategoryDef, RegExp?> _compiled = {};

  /// The built-in sub-categories of [category].
  static List<SubcategoryDef> builtIn(Category category) =>
      subcategoryCatalog[category] ?? const [];

  static RegExp? _regex(SubcategoryDef d) {
    final p = d.pattern;
    if (p == null) return null;
    return _compiled.putIfAbsent(d, () => rx(p));
  }

  /// The built-in sub-category a merchant belongs in, or null when none
  /// matches.
  static String? guess(Category category, String? merchant, [String? upiId]) {
    final text = [
      if (merchant != null) merchant,
      if (upiId != null) upiId,
    ].join(' ');
    if (text.trim().isEmpty) return null;
    for (final d in builtIn(category)) {
      if (_regex(d)?.hasMatch(text) ?? false) return d.name;
    }
    return null;
  }

  /// The sub-category a transaction is counted under: the user's choice, else
  /// the guess, else the single pattern-less entry, else "Other".
  static String of(
    Category category,
    String? subcategory,
    String? merchant,
    String? upiId,
  ) {
    if (subcategory != null) return subcategory;
    final g = guess(category, merchant, upiId);
    if (g != null) return g;
    final subs = builtIn(category);
    if (subs.length == 1 && subs.first.pattern == null) return subs.first.name;
    return other;
  }
}
