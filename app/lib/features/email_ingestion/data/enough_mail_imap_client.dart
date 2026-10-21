import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart' as em;
import 'package:hisaab/core/errors/failure.dart';
import 'package:hisaab/features/email_ingestion/domain/email_ports.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/raw_email.dart';

/// [ImapClient] over `enough_mail` (FR-02, FR-03-09). TLS only, read-only
/// folder, one envelope fetch, bodies only for accepted mail. Never logs.
class EnoughMailImapClient implements ImapClient {
  /// Creates the client; [create] is injectable for tests.
  EnoughMailImapClient({
    em.ImapClient Function()? create,
    this.timeout = const Duration(seconds: 20),
  }) : _create = create ?? em.ImapClient.new;

  final em.ImapClient Function() _create;

  /// Connect and command timeout (FR-03-02).
  final Duration timeout;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Future<void> testLogin(EmailAccount account, String password) =>
      _session(account, password, (_) async {});

  @override
  Future<List<RawEmail>> fetchSince(
    EmailAccount account,
    String password, {
    required DateTime since,
    required bool Function(String from, String subject) accept,
    int limit = 300,
  }) =>
      _session(account, password, (c) async {
        final boxes = await c.listMailboxes();
        final all = boxes.where((b) => b.hasFlag(em.MailboxFlag.all));
        final box = all.isNotEmpty ? all.first : await c.selectInbox();
        if (all.isNotEmpty) await c.examineMailbox(box);
        final u = since.toUtc();
        final hits = await c.searchMessages(
          searchCriteria: 'SINCE ${u.day}-${_months[u.month - 1]}-${u.year}',
        );
        final ids = hits.matchingSequence?.toList() ?? const <int>[];
        final out = <RawEmail>[];
        // Envelopes in chunks; decode a body only after the filter says yes.
        for (var i = 0; i < ids.length && out.length < limit; i += 100) {
          final chunk = ids.sublist(i, (i + 100).clamp(0, ids.length));
          final env = await c.fetchMessages(
            em.MessageSequence.fromIds(chunk),
            '(UID ENVELOPE INTERNALDATE)',
          );
          for (final m in env.messages) {
            if (out.length >= limit) break;
            final from = _from(m);
            final subject = m.decodeSubject() ?? m.envelope?.subject ?? '';
            if (!accept(from, subject)) continue;
            final seq = m.sequenceId;
            if (seq == null) continue;
            try {
              final full = await c.fetchMessage(seq, '(BODY.PEEK[])');
              if (full.messages.isEmpty) continue;
              out.add(_toRaw(m, full.messages.first, from, subject));
            } on Object {
              // One undecodable message never stops the sync.
            }
          }
        }
        out.sort((a, b) => a.receivedAt.compareTo(b.receivedAt));
        return out;
      });

  static String _from(em.MimeMessage m) {
    final a = m.envelope?.from;
    if (a == null || a.isEmpty) return m.fromEmail ?? '';
    return a.first.email;
  }

  static RawEmail _toRaw(
    em.MimeMessage env,
    em.MimeMessage body,
    String from,
    String subject,
  ) {
    final msgId = env.getHeaderValue('message-id') ?? env.envelope?.messageId;
    final uid = env.uid ?? env.sequenceId;
    final id = (msgId != null && msgId.trim().isNotEmpty)
        ? 'imap:${msgId.trim()}'
        : 'imap:uid:$uid';
    final date = body.decodeDate() ??
        env.envelope?.date ??
        DateTime.tryParse(env.internalDate ?? '');
    return RawEmail(
      id: id,
      from: from,
      subject: subject,
      receivedAt: date?.millisecondsSinceEpoch ?? 0,
      plain: body.decodeTextPlainPart() ?? '',
      html: body.decodeTextHtmlPart(),
    );
  }

  Future<T> _session<T>(
    EmailAccount account,
    String password,
    Future<T> Function(em.ImapClient c) body,
  ) async {
    final c = _create();
    try {
      try {
        await c.connectToServer(
          account.imapHost,
          account.imapPort,
          timeout: timeout,
        );
      } on Object catch (e) {
        throw mapError(e);
      }
      try {
        await c.login(account.address, password);
      } on em.ImapException {
        throw const AuthFailure('sign-in refused');
      } on Object catch (e) {
        throw mapError(e);
      }
      try {
        return await body(c).timeout(const Duration(minutes: 3));
      } on Failure {
        rethrow;
      } on Object catch (e) {
        throw mapError(e);
      }
    } finally {
      try {
        await c.logout().timeout(const Duration(seconds: 5));
      } on Object {
        // Already closed.
      }
      try {
        await c.disconnect();
      } on Object {
        // Already closed.
      }
    }
  }

  /// Maps a transport or protocol error to a [Failure]; the message never
  /// carries server text.
  static Failure mapError(Object e) {
    if (e is Failure) return e;
    if (e is HandshakeException || e is TlsException) {
      return const TlsFailure('secure connection failed');
    }
    if (e is em.ImapException) {
      final t = '${e.message}'.toUpperCase();
      return t.contains('AUTH') ||
              t.contains('LOGIN') ||
              t.contains('CREDENTIAL')
          ? const AuthFailure('sign-in refused')
          : const NetworkFailure('mail server error');
    }
    return const NetworkFailure('could not reach the mail server');
  }
}
