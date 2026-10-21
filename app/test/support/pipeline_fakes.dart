import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/features/onboarding_permissions/domain/entities/sms_permission_state.dart';
import 'package:hisaab/features/onboarding_permissions/domain/ports.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart';
import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';

/// In-memory [SecureStore].
class MemSecure implements SecureStore {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
}

/// Permission fake: granting needs [grantOnRequest].
class FakePermission implements SmsPermissionRepository {
  FakePermission({this.granted = false, this.blocked = false});
  bool granted;
  bool blocked;
  bool grantOnRequest = true;
  int opened = 0;
  @override
  Future<SmsPermissionState> read() async =>
      SmsPermissionState(granted: granted, blocked: blocked);
  @override
  Future<SmsPermissionState> request() async {
    if (!blocked && grantOnRequest) granted = true;
    return await read();
  }

  @override
  Future<void> openAppSettings() async => opened++;
}

class FakeNotifications implements NotificationPermission {
  int asked = 0;
  @override
  Future<void> request() async => asked++;
}

class FakeInbox implements SmsInboxSource {
  FakeInbox([this.rows = const []]);
  final List<InboxSms> rows;
  @override
  Future<SmsReadStats> readBatches({
    required int since,
    required int batchSize,
    required bool Function(String sender) accept,
    required Future<void> Function(List<InboxSms> batch) onBatch,
  }) async {
    final ok = rows.where((r) => accept(r.sender)).toList();
    if (ok.isNotEmpty) await onBatch(ok);
    return SmsReadStats(
      examined: rows.length,
      lastTimestamp: rows.isEmpty ? 0 : rows.last.receivedAt,
    );
  }
}

class FakeLive implements SmsLiveSource {
  bool? enabled;
  @override
  Stream<InboxSms> get live => const Stream.empty();
  @override
  Future<List<InboxSms>> drainPending() async => const [];
  @override
  Future<void> configure({
    required bool enabled,
    required String senderPattern,
  }) async {
    this.enabled = enabled;
  }
}

/// Everything a screen test needs; call [dispose] in tearDown.
class PipelineHarness {
  PipelineHarness({FakePermission? permission, List<InboxSms> inbox = const []})
      : db = AppDatabase(NativeDatabase.memory()),
        permission = permission ?? FakePermission(),
        inbox = FakeInbox(inbox);

  final AppDatabase db;
  final FakePermission permission;
  final FakeInbox inbox;
  final secure = MemSecure();
  final notifications = FakeNotifications();
  final live = FakeLive();

  List<Override> get overrides => [
        appDatabaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(secure),
        smsPermissionRepositoryProvider.overrideWithValue(permission),
        notificationPermissionProvider.overrideWithValue(notifications),
        smsInboxSourceProvider.overrideWithValue(inbox),
        smsLiveSourceProvider.overrideWithValue(live),
      ];

  Future<void> dispose() => db.close();
}
