import 'dart:convert';

import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// One section a screen can show (FR-28-16).
class SectionDef {
  /// Creates a definition.
  const SectionDef(this.id, this.label, {this.hiddenByDefault = false});

  /// Stable key.
  final String id;

  /// Label in Customise.
  final String label;

  /// Starts hidden (Home budgets).
  final bool hiddenByDefault;
}

/// A section's saved state: `{id, visible, order}` (FR-28-15).
class SectionSlot {
  /// Creates a slot.
  const SectionSlot({
    required this.id,
    required this.label,
    required this.visible,
    required this.order,
  });

  final String id;
  final String label;
  final bool visible;
  final int order;

  /// Copy with new visibility or order.
  SectionSlot copyWith({bool? visible, int? order}) => SectionSlot(
        id: id,
        label: label,
        visible: visible ?? this.visible,
        order: order ?? this.order,
      );
}

/// Layout screens (FR-28-15).
abstract final class ScreenIds {
  static const home = 'home';
  static const analytics = 'analytics';
  static const portfolio = 'portfolio';
  static const List<String> all = [home, analytics, portfolio];

  /// Label in the selector.
  static String label(String id) => switch (id) {
        home => 'Home',
        analytics => 'Analysis',
        _ => 'Portfolio',
      };
}

/// A Home preset: the shown sections, in order (FR-28-19).
class HomePreset {
  /// Creates a preset.
  const HomePreset(this.name, this.shown);

  final String name;
  final List<String> shown;
}

/// Pure layout logic: defaults, resolve, encode, move, presets (FR-28-16..19).
abstract final class SectionLayout {
  static const List<SectionDef> _home = [
    SectionDef('spent', 'Spent this month'),
    SectionDef('cards', 'Credit card dues'),
    SectionDef('cashflow', 'Cash flow'),
    SectionDef('upcoming', 'Upcoming'),
    SectionDef('insights', 'Insights'),
    SectionDef('categories', 'Spend by category'),
    SectionDef('recent', 'Recent transactions'),
    SectionDef('budgets', 'Budgets', hiddenByDefault: true),
  ];
  static const List<SectionDef> _analytics = [
    SectionDef('categories', 'Spend by category'),
    SectionDef('monthly', 'Monthly spend'),
    SectionDef('merchants', 'Top merchants'),
    SectionDef('budgets', 'Budgets'),
    SectionDef('when', 'When you spend'),
  ];
  static const List<SectionDef> _portfolio = [
    SectionDef('value', 'Portfolio value'),
    SectionDef('allocation', 'Asset allocation'),
    SectionDef('networth', 'Net worth'),
    SectionDef('holdings', 'Holdings'),
    SectionDef('loans', 'Loans'),
    SectionDef('maturity', 'Maturity calendar'),
  ];

  /// Home presets (FR-28-19); applying one is a working feature here.
  static const presets = [
    HomePreset('Minimal', ['spent', 'cashflow', 'upcoming']),
    HomePreset(
      'Spender',
      ['spent', 'cashflow', 'budgets', 'categories', 'upcoming', 'recent'],
    ),
    HomePreset('Investor', ['spent', 'insights', 'upcoming']),
    HomePreset('Business', ['cashflow', 'upcoming', 'insights', 'recent']),
    HomePreset('Everything', [
      'spent',
      'cards',
      'cashflow',
      'upcoming',
      'insights',
      'categories',
      'recent',
      'budgets',
    ]),
  ];

  /// Settings key holding the JSON layout of [screenId].
  static SettingKey<String> key(String screenId) =>
      SettingKey<String>('layout_$screenId', '');

  /// Defined sections of [screenId].
  static List<SectionDef> defs(String screenId) => switch (screenId) {
        ScreenIds.home => _home,
        ScreenIds.analytics => _analytics,
        _ => _portfolio,
      };

  /// Defaults: catalogue order, `hiddenByDefault` hidden.
  static List<SectionSlot> defaults(String screenId) => [
        for (final (i, d) in defs(screenId).indexed)
          SectionSlot(
            id: d.id,
            label: d.label,
            visible: !d.hiddenByDefault,
            order: i,
          ),
      ];

  /// Saved JSON to slots: unknown ids dropped, new ids appended with their
  /// default visibility, bad JSON gives the defaults (FR-28-17).
  static List<SectionSlot> resolve(String screenId, String? saved) {
    final defs = SectionLayout.defs(screenId);
    final byId = {for (final d in defs) d.id: d};
    final seen = <String>{};
    final out = <SectionSlot>[];
    try {
      if (saved != null && saved.isNotEmpty) {
        final rows = jsonDecode(saved) as List<dynamic>;
        final parsed = <(int, String, bool)>[];
        for (final r in rows) {
          final m = r as Map<String, dynamic>;
          final id = m['id'] as String;
          if (byId.containsKey(id) && seen.add(id)) {
            parsed.add(
              (
                (m['order'] as num?)?.toInt() ?? 0,
                id,
                m['visible'] as bool? ?? true,
              ),
            );
          }
        }
        parsed.sort((a, b) => a.$1.compareTo(b.$1));
        for (final p in parsed) {
          out.add(
            SectionSlot(
              id: p.$2,
              label: byId[p.$2]!.label,
              visible: p.$3,
              order: out.length,
            ),
          );
        }
      }
    } on Object {
      return defaults(screenId);
    }
    for (final d in defs) {
      if (seen.contains(d.id)) continue;
      out.add(
        SectionSlot(
          id: d.id,
          label: d.label,
          visible: !d.hiddenByDefault,
          order: out.length,
        ),
      );
    }
    return out;
  }

  /// Slots to saved JSON.
  static String encode(List<SectionSlot> slots) => jsonEncode([
        for (final s in slots)
          {'id': s.id, 'visible': s.visible, 'order': s.order},
      ]);

  /// Visible ids in order.
  static List<String> visibleIds(List<SectionSlot> slots) => [
        for (final s in slots)
          if (s.visible) s.id,
      ];

  static List<SectionSlot> _renumber(List<SectionSlot> l) =>
      [for (final (i, s) in l.indexed) s.copyWith(order: i)];

  /// Moves the slot at [from] to final index [to] (`onReorderItem`).
  static List<SectionSlot> reorder(List<SectionSlot> slots, int from, int to) {
    final l = [...slots];
    final item = l.removeAt(from);
    l.insert(to, item);
    return _renumber(l);
  }

  /// Shows or hides [id].
  static List<SectionSlot> setVisible(
    List<SectionSlot> slots,
    String id, {
    required bool visible,
  }) =>
      [
        for (final s in slots)
          if (s.id == id) s.copyWith(visible: visible) else s,
      ];

  /// Preset: [shown] first in that order, everything else hidden (FR-28-19).
  static List<SectionSlot> apply(String screenId, List<String> shown) {
    final base = defaults(screenId);
    final byId = {for (final s in base) s.id: s};
    final out = <SectionSlot>[
      for (final id in shown)
        if (byId.containsKey(id)) byId[id]!.copyWith(visible: true),
    ];
    final used = out.map((s) => s.id).toSet();
    for (final s in base) {
      if (!used.contains(s.id)) out.add(s.copyWith(visible: false));
    }
    return _renumber(out);
  }
}
