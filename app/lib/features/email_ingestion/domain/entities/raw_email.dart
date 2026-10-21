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
}
