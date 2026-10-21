import 'package:hisaab/features/categorization/domain/custom_category.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:parser_core/parser_core.dart';

/// Stores for category rules and custom categories (FR-09). Changing a
/// transaction's category is `TransactionRepository.setCategory`.
abstract interface class CategoryRepository {
  Future<RuleSet> loadRuleSet();

  /// "Your rules" first, then learned; by key.
  Stream<List<MerchantRule>> watchRules();

  /// Upserts a learned EXACT rule unless a manual rule owns [key].
  /// Returns whether it wrote one (FR-09-06).
  Future<bool> learn(String key, Category category, {required int at});

  /// Creates or replaces a manual rule; [previousKey] is removed (FR-09-08).
  Future<void> saveManualRule(MerchantRule rule, {String? previousKey});

  Future<void> deleteRule(String key);

  /// Adds a custom category (FR-09-13).
  Future<int> addCustomCategory({
    required String name,
    required String icon,
    required int colorArgb,
  });
  Stream<List<CustomCategory>> watchCustomCategories();
  Future<void> deleteCustomCategory(int id);

  /// Adds a sub-category; null when (parent, name) exists.
  Future<int?> addSubcategory({
    required String parent,
    required String name,
    required String icon,
  });
  Stream<List<CustomSubcategory>> watchSubcategories(String parent);
  Future<void> deleteSubcategory(int id);
}
