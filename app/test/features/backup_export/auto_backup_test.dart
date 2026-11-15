// FR-24-34..34: month-wise automatic backup, phone copy always, cloud copy
// only when allowed, only changed months rewritten.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/backup_export/data/auto_backup_runner.dart';
import 'package:hisaab/features/backup_export/data/backup_crypto.dart';
import 'package:hisaab/features/backup_export/data/scheduled_backup_service.dart';
import 'package:hisaab/features/backup_export/domain/scheduled_backup.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';

import '../../support/parsed.dart';
import '../../support/test_env.dart';
import 'full_backup_test.dart' show dataOf, seed, svcOf;

class _Sink implements BackupSink {
  _Sink(this.id, {this.broken = false});

  @override
  final String id;
  final bool broken;
  final files = <String, Uint8List>{};
  final writes = <String>[];

  @override
  Future<Set<String>> list() async {
    if (broken) throw StateError('offline');
    return files.keys.toSet();
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (broken) throw StateError('offline');
    files[name] = bytes;
    writes.add(name);
  }
}

class _Secure implements SecureStore {
  final m = <String, String>{};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
}

void main() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  final may = DateTime(2026, 5, 20).millisecondsSinceEpoch;
  final jun = DateTime(2026, 6, 20).millisecondsSinceEpoch;

  ScheduledBackupService service() => ScheduledBackupService(
        dataOf(env),
        iterations: BackupCrypto.minIterations,
      );

  test('a backup splits into a base part and one part per month', () {
    final parts = BackupParts.split({
      'format': 'x',
      'schema': 1,
      'createdAt': 5,
      'accounts': [1],
      'transactions': [
        {'ts': may},
        {'ts': may + 1},
        {'ts': jun},
      ],
    });
    expect(
      parts.keys,
      [BackupParts.base, 'dhankosh-2026-05.dkbk', 'dhankosh-2026-06.dkbk'],
    );
    expect(parts[BackupParts.base]!['transactions'], isEmpty);
    expect(parts[BackupParts.base]!['accounts'], [1]);
    expect(parts['dhankosh-2026-05.dkbk']!['transactions'], hasLength(2));
    expect(parts['dhankosh-2026-06.dkbk']!.containsKey('accounts'), isFalse);
  });

  test(
      'first run writes every part, the next run nothing, a new month only '
      'that month', () async {
    await env.ingest(parsed(ref: 'a1', time: may));
    await env.ingest(parsed(ref: 'a2', time: jun, amountMinor: 700));
    final phone = _Sink('phone');
    var r = await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone},
      manifest: '{}',
      now: DateTime(2026, 6, 21),
    );
    expect(r.result.ok, isTrue);
    expect(phone.files.keys, containsAll(['dhankosh-2026-05.dkbk']));
    expect(phone.files.keys, contains('dhankosh-2026-06.dkbk'));
    expect(phone.files.keys, contains(BackupParts.base));

    phone.writes.clear();
    r = await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone},
      manifest: r.manifest,
      now: DateTime(2026, 6, 22),
    );
    expect(phone.writes, isEmpty);

    await env.ingest(
      parsed(
        ref: 'a3',
        time: DateTime(2026, 7, 2).millisecondsSinceEpoch,
        amountMinor: 900,
      ),
    );
    phone.writes.clear();
    r = await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone},
      manifest: r.manifest,
      now: DateTime(2026, 7, 3),
    );
    expect(phone.writes, contains('dhankosh-2026-07.dkbk'));
    expect(phone.writes, isNot(contains('dhankosh-2026-05.dkbk')));
    expect(phone.writes, isNot(contains('dhankosh-2026-06.dkbk')));
  });

  test('a deleted file is written again', () async {
    await env.ingest(parsed(ref: 'a1', time: may));
    final phone = _Sink('phone');
    var r = await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone},
      manifest: '{}',
      now: DateTime(2026, 6),
    );
    phone.files.remove('dhankosh-2026-05.dkbk');
    phone.writes.clear();
    r = await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone},
      manifest: r.manifest,
      now: DateTime(2026, 6, 2),
    );
    expect(phone.writes, ['dhankosh-2026-05.dkbk']);
  });

  test('one failing folder does not stop the other', () async {
    await env.ingest(parsed(ref: 'a1', time: may));
    final phone = _Sink('phone');
    final cloud = _Sink('cloud', broken: true);
    final r = await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone, 'cloud': cloud},
      manifest: '{}',
      now: DateTime(2026, 6),
    );
    expect(r.result.failed, {'cloud'});
    expect(phone.files, isNotEmpty);
  });

  test(
      'every part opens with the passphrase and a month restores its '
      'transactions', () async {
    await seed(env);
    final phone = _Sink('phone');
    await service().run(
      passphrase: 'correct horse',
      sinks: {'phone': phone},
      manifest: '{}',
      now: DateTime(2026, 11),
    );
    final svc = svcOf(env);
    final month = phone.files.entries.firstWhere(
      (e) => e.key != BackupParts.base && e.key.endsWith('.dkbk'),
    );
    final opened = await svc.open(month.value, 'correct horse');
    expect(opened.counts.counts['transactions'], greaterThan(0));
    final base =
        await svc.open(phone.files[BackupParts.base]!, 'correct horse');
    expect(base.counts.counts['transactions'], 0);
    expect(
      () => svc.open(month.value, 'wrong passphrase!'),
      throwsA(anything),
    );
  });

  group('runner', () {
    late _Secure secure;
    late _Sink phone;
    late _Sink cloud;
    late DateTime now;

    AutoBackupRunner runner() => AutoBackupRunner(
          service: service(),
          settings: env.settings,
          secure: secure,
          phoneSink: phone,
          treeSink: (id, uri) => id == 'cloud' ? cloud : _Sink('picked-$uri'),
          clock: () => now,
        );

    setUp(() async {
      secure = _Secure();
      phone = _Sink('phone');
      cloud = _Sink('cloud');
      now = DateTime(2026, 6, 21, 10);
      await env.ingest(parsed(ref: 'a1', time: may));
    });

    test('off by default: nothing runs', () async {
      expect(await runner().run(), isNull);
      expect(phone.files, isEmpty);
    });

    test('on: the phone copy only, until the cloud copy is allowed', () async {
      await env.settings.write(autoBackupKey, true);
      secure.m[autoBackupPassphraseSecret] = 'correct horse';
      final r = await runner().run();
      expect(r!.ok, isTrue);
      expect(phone.files, isNotEmpty);
      expect(cloud.files, isEmpty);
      expect(await env.settings.read(autoBackupResultKey), 'ok');

      await env.settings.write(autoBackupDriveKey, true);
      await env.settings.write(autoBackupDriveUriKey, 'content://drive/tree');
      now = now.add(const Duration(hours: 1));
      await runner().run();
      expect(cloud.files, isNotEmpty);
    });

    test('the minimum gap holds back a run unless forced', () async {
      await env.settings.write(autoBackupKey, true);
      secure.m[autoBackupPassphraseSecret] = 'correct horse';
      await runner().run();
      now = now.add(const Duration(minutes: 2));
      expect(await runner().run(), isNull);
      expect(await runner().run(force: true), isNotNull);
    });

    test('without a saved passphrase nothing runs', () async {
      await env.settings.write(autoBackupKey, true);
      expect(await runner().run(), isNull);
    });
  });
}
