import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/key_value_store.dart';

/// [WatchedAppsRepository] over a [KeyValueStore] (FR-04-19, FR-04-20).
///
/// `notif_apps_off` holds the built-in packages the user switched off, one per
/// line. `notif_apps_extra` holds the apps they added, one `package=label`
/// per line. Both are empty by default, so the built-in list is what ships.
class WatchedAppsStore implements WatchedAppsRepository {
  /// Creates the store.
  const WatchedAppsStore(this._kv);

  final KeyValueStore _kv;

  static const _offKey = 'notif_apps_off';
  static const _extraKey = 'notif_apps_extra';

  @override
  Future<WatchedApps> load() async => WatchedApps(
        disabled: _lines(await _kv.getString(_offKey)).toSet(),
        extra: _pairs(await _kv.getString(_extraKey)),
      );

  @override
  Future<void> setBuiltIn(String packageName, {required bool watched}) async {
    final off = _lines(await _kv.getString(_offKey)).toSet();
    if (watched) {
      off.remove(packageName);
    } else {
      off.add(packageName);
    }
    await _kv.setString(_offKey, off.join('\n'));
  }

  @override
  Future<void> addExtra(String packageName, String label) async {
    if (packageName.isEmpty || PaymentApps.byPackage(packageName) != null) {
      // A built-in is turned back on rather than added twice.
      await setBuiltIn(packageName, watched: true);
      return;
    }
    final extra = _pairs(await _kv.getString(_extraKey))
      ..[packageName] = _clean(label.isEmpty ? packageName : label);
    await _write(extra);
  }

  @override
  Future<void> removeExtra(String packageName) async {
    final extra = _pairs(await _kv.getString(_extraKey))..remove(packageName);
    await _write(extra);
  }

  Future<void> _write(Map<String, String> extra) => _kv.setString(
        _extraKey,
        [for (final e in extra.entries) '${e.key}=${e.value}'].join('\n'),
      );

  /// A label may not carry the separators the format uses.
  static String _clean(String label) =>
      label.replaceAll(RegExp(r'[\r\n=]'), ' ').trim();

  static List<String> _lines(String? raw) => [
        for (final l in (raw ?? '').split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ];

  static Map<String, String> _pairs(String? raw) {
    final out = <String, String>{};
    for (final line in _lines(raw)) {
      final i = line.indexOf('=');
      if (i <= 0) continue;
      final pkg = line.substring(0, i).trim();
      final label = line.substring(i + 1).trim();
      if (pkg.isNotEmpty) out[pkg] = label.isEmpty ? pkg : label;
    }
    return out;
  }
}
