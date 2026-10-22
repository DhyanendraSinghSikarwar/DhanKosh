import 'package:hisaab/features/email_ingestion/domain/statement_attachments.dart';

/// One fetched message, body parts still undecided (FR-03-15).
class RawEmail {
  /// Creates a message.
  const RawEmail({
    required this.id,
    required this.from,
    required this.subject,
    required this.receivedAt,
    this.plain = '',
    this.html,
    this.attachments = const [],
  });

  /// `imap:<Message-ID>` or `imap:uid:<n>` (FR-03-10).
  final String id;

  /// `Name <address>` or bare address.
  final String from;

  /// Subject line.
  final String subject;

  /// Epoch ms.
  final int receivedAt;

  /// The text/plain part, empty when none.
  final String plain;

  /// The text/html part, when present.
  final String? html;

  /// Statement files attached (FR-03-16).
  final List<EmailAttachment> attachments;
}
