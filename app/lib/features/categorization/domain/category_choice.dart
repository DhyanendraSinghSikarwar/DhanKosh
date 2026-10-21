import 'package:parser_core/parser_core.dart';

/// Result of the category picker (FR-09-05, FR-09-08, FR-09-09).
class CategoryChoice {
  const CategoryChoice(
    this.category, {
    this.customCategoryId,
    this.saveRule = false,
    this.applyToPast = false,
  });

  final Category category;

  /// Custom category (files under [Category.other]).
  final int? customCategoryId;

  /// Also save a manual EXACT rule for the merchant.
  final bool saveRule;

  /// Also re-file matching past rows with that rule.
  final bool applyToPast;
}
