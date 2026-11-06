import 'dart:async';

import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_repository.dart';

/// An in-memory queue for widget tests: no database streams, so no pending
/// timers after the tree is disposed.
class FakeUnrecognisedRepo implements UnrecognisedRepository {
  final List<UnrecognisedMessage> rows = [];
  final Map<String, SenderPref> prefs = {};
  int _next = 1;
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<T> _watch<T>(T Function() read) => Stream<T>.multi((c) {
        c.add(read());
        final sub = _changes.stream.listen((_) => c.add(read()));
        c.onCancel = sub.cancel;
      });

  void _set(int id, UnrecognisedStatus s, {int? tx}) {
    final i = rows.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final r = rows[i];
    rows[i] = UnrecognisedMessage(
      id: r.id,
      source: r.source,
      sender: r.sender,
      senderKey: r.senderKey,
      sourceMessageId: r.sourceMessageId,
      body: r.body,
      receivedAt: r.receivedAt,
      status: s,
      transactionId: tx,
    );
    _changes.add(null);
  }

  List<UnrecognisedMessage> get _fresh => [
        for (final r in rows)
          if (r.status == UnrecognisedStatus.fresh) r,
      ];

  @override
  Stream<List<UnrecognisedMessage>> watchFresh() => _watch(() => _fresh);

  @override
  Stream<int> watchFreshCount() => _watch(() => _fresh.length);

  @override
  Future<UnrecognisedMessage?> byId(int id) async {
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<int?> offer(NewUnrecognised m) async {
    final key = SenderKey.of(m.source, m.sender);
    final id = _next++;
    rows.add(
      UnrecognisedMessage(
        id: id,
        source: m.source,
        sender: m.sender,
        senderKey: key,
        sourceMessageId: m.sourceMessageId,
        body: m.body,
        receivedAt: m.receivedAt,
        status: UnrecognisedStatus.fresh,
      ),
    );
    _changes.add(null);
    return id;
  }

  @override
  Future<void> markAdded(int id, {int? transactionId}) async =>
      _set(id, UnrecognisedStatus.added, tx: transactionId);

  @override
  Future<void> dismiss(int id) async => _set(id, UnrecognisedStatus.dismissed);

  @override
  Future<void> restore(int id) async => _set(id, UnrecognisedStatus.fresh);

  @override
  Future<int> ignoreSender(String senderKey) async {
    prefs[senderKey] = SenderPref(
      senderKey: senderKey,
      ignored: true,
      learnedAt: 0,
    );
    var n = 0;
    for (final r in List.of(rows)) {
      if (r.senderKey == senderKey && r.status == UnrecognisedStatus.fresh) {
        _set(r.id, UnrecognisedStatus.ignored);
        n++;
      }
    }
    _changes.add(null);
    return n;
  }

  @override
  Future<void> learn(
    String senderKey, {
    String? bankName,
    String? last4,
    String? currency,
  }) async {
    prefs[senderKey] = SenderPref(
      senderKey: senderKey,
      ignored: false,
      learnedAt: 0,
      bankName: bankName,
      last4: last4,
      currency: currency,
    );
    _changes.add(null);
  }

  @override
  Future<void> forget(String senderKey) async {
    prefs.remove(senderKey);
    _changes.add(null);
  }

  @override
  Future<SenderPref?> pref(String senderKey) async => prefs[senderKey];

  @override
  Stream<List<SenderPref>> watchPrefs() => _watch(() => prefs.values.toList());

  @override
  Future<int> purge() async => 0;
}
