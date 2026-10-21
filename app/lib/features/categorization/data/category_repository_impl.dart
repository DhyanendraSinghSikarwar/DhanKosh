import 'package:drift/drift.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/categorization/domain/category_repository.dart';
import 'package:hisaab/features/categorization/domain/custom_category.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:parser_core/parser_core.dart';

/// [CategoryRepository] over `merchant_rules` and the custom tables.
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);

  final AppDatabase _db;

  static MerchantRule _rule(MerchantRuleRow r) => MerchantRule(
        merchantKey: r.merchantKey,
        category: enumFromDb(Category.values, r.category, Category.other),
        updatedAt: r.updatedAt,
        matchType:
            r.matchType == 'CONTAINS' ? RuleMatch.contains : RuleMatch.exact,
        subcategory: r.subcategory,
        customCategoryId: r.customCategoryId,
        manual: r.manual,
      );

  static MerchantRulesCompanion _companion(MerchantRule r) =>
      MerchantRulesCompanion(
        merchantKey: Value(r.merchantKey),
        category: Value(enumToDb(r.category)),
        updatedAt: Value(r.updatedAt),
        matchType: Value(enumToDb(r.matchType)),
        subcategory: Value(r.subcategory),
        customCategoryId: Value(r.customCategoryId),
        manual: Value(r.manual),
      );

  @override
  Future<RuleSet> loadRuleSet() async => RuleSet(
        (await _db.select(_db.merchantRules).get()).map(_rule).toList(),
      );

  @override
  Stream<List<MerchantRule>> watchRules() => (_db.select(_db.merchantRules)
        ..orderBy([
          (t) => OrderingTerm.desc(t.manual),
          (t) => OrderingTerm.asc(t.merchantKey),
        ]))
      .watch()
      .map((rows) => rows.map(_rule).toList());

  @override
  Future<bool> learn(String key, Category category, {required int at}) async {
    if (key.length < MerchantRule.minKey) return false;
    final existing = await (_db.select(_db.merchantRules)
          ..where((t) => t.merchantKey.equals(key)))
        .getSingleOrNull();
    if (existing != null && existing.manual) return false;
    await _db.into(_db.merchantRules).insertOnConflictUpdate(
          _companion(
            MerchantRule(merchantKey: key, category: category, updatedAt: at),
          ),
        );
    return true;
  }

  @override
  Future<void> saveManualRule(MerchantRule rule, {String? previousKey}) {
    assert(rule.manual, 'manual rules only');
    return _db.transaction(() async {
      if (previousKey != null && previousKey != rule.merchantKey) {
        await deleteRule(previousKey);
      }
      await _db
          .into(_db.merchantRules)
          .insertOnConflictUpdate(_companion(rule));
    });
  }

  @override
  Future<void> deleteRule(String key) =>
      (_db.delete(_db.merchantRules)..where((t) => t.merchantKey.equals(key)))
          .go();

  @override
  Future<int> addCustomCategory({
    required String name,
    required String icon,
    required int colorArgb,
  }) =>
      _db.into(_db.customCategories).insert(
            CustomCategoriesCompanion.insert(
              name: name,
              icon: icon,
              colorArgb: colorArgb,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

  @override
  Stream<List<CustomCategory>> watchCustomCategories() =>
      (_db.select(_db.customCategories)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                CustomCategory(
                  id: r.id,
                  name: r.name,
                  icon: r.icon,
                  colorArgb: r.colorArgb,
                  createdAt: r.createdAt,
                ),
            ],
          );

  @override
  Future<void> deleteCustomCategory(int id) =>
      (_db.delete(_db.customCategories)..where((t) => t.id.equals(id))).go();

  @override
  Future<int?> addSubcategory({
    required String parent,
    required String name,
    required String icon,
  }) async {
    final exists = await (_db.select(_db.customSubcategories)
          ..where((t) => t.parent.equals(parent) & t.name.equals(name)))
        .getSingleOrNull();
    if (exists != null) return null;
    return await _db.into(_db.customSubcategories).insert(
          CustomSubcategoriesCompanion.insert(
            parent: parent,
            name: name,
            icon: icon,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Stream<List<CustomSubcategory>> watchSubcategories(String parent) =>
      (_db.select(_db.customSubcategories)
            ..where((t) => t.parent.equals(parent))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                CustomSubcategory(
                  id: r.id,
                  parent: r.parent,
                  name: r.name,
                  icon: r.icon,
                  createdAt: r.createdAt,
                ),
            ],
          );

  @override
  Future<void> deleteSubcategory(int id) =>
      (_db.delete(_db.customSubcategories)..where((t) => t.id.equals(id))).go();
}
