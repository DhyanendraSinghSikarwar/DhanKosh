import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';

List<String> ids(List<SectionSlot> l) => [for (final s in l) s.id];

void main() {
  // TC-28-05 (FR-28-16)
  test('defaults: eight home sections in mock order, all visible', () {
    final d = SectionLayout.defaults('home');
    expect(ids(d), [
      'spent',
      'cashflow',
      'budgets',
      'upcoming',
      'cards',
      'insights',
      'categories',
      'recent',
    ]);
    expect(SectionLayout.visibleIds(d), contains('budgets'));
    expect(ids(SectionLayout.defaults('analytics')).length, 5);
    expect(
      SectionLayout.visibleIds(SectionLayout.defaults('portfolio')).length,
      6,
    );
  });

  // TC-28-05 (FR-28-17)
  test('resolve drops unknown ids and appends new ones', () {
    final saved = SectionLayout.encode([
      const SectionSlot(id: 'recent', label: '', visible: true, order: 0),
      const SectionSlot(id: 'spent', label: '', visible: true, order: 1),
      const SectionSlot(id: 'bogus', label: '', visible: true, order: 2),
    ]);
    final l = SectionLayout.resolve('home', saved);
    expect(ids(l), [
      'recent',
      'spent',
      'cashflow',
      'budgets',
      'upcoming',
      'cards',
      'insights',
      'categories',
    ]);
    expect(l.last.visible, isTrue);
    expect(l.map((s) => s.order), [for (var i = 0; i < 8; i++) i]);
  });

  test('resolve falls back to defaults on bad or empty input', () {
    expect(ids(SectionLayout.resolve('home', '{oops')).first, 'spent');
    expect(ids(SectionLayout.resolve('home', '')).first, 'spent');
    expect(ids(SectionLayout.resolve('home', null)).length, 8);
  });

  // TC-28-07 (FR-28-15)
  test('reorder moves a section and renumbers', () {
    final l = SectionLayout.reorder(SectionLayout.defaults('home'), 0, 2);
    expect(ids(l).take(3), ['cashflow', 'budgets', 'spent']);
    expect(l.map((s) => s.order), [for (var i = 0; i < 8; i++) i]);
  });

  test('setVisible toggles one section', () {
    final l = SectionLayout.setVisible(
      SectionLayout.defaults('home'),
      'budgets',
      visible: false,
    );
    expect(SectionLayout.visibleIds(l), isNot(contains('budgets')));
  });

  // TC-28-08 (FR-28-19)
  test('every Home preset shows exactly its sections first', () {
    for (final p in SectionLayout.presets) {
      final l = SectionLayout.apply('home', p.shown);
      expect(SectionLayout.visibleIds(l), p.shown, reason: p.name);
      expect(ids(l).take(p.shown.length), p.shown);
      expect(l.length, 8);
    }
    expect(SectionLayout.presets.map((p) => p.name), [
      'Minimal',
      'Spender',
      'Investor',
      'Business',
      'Everything',
    ]);
  });

  test('encode and resolve round trip keeps order and visibility', () {
    final l = SectionLayout.apply('home', ['recent', 'spent']);
    final back = SectionLayout.resolve('home', SectionLayout.encode(l));
    expect(SectionLayout.visibleIds(back), ['recent', 'spent']);
    expect(ids(back), ids(l));
  });
}
