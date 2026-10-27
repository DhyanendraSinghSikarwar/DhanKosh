/// Provider presets for the IMAP login (FR-03-01).
enum EmailProvider {
  /// Gmail.
  gmail(
    'Gmail',
    'imap.gmail.com',
    'https://myaccount.google.com/apppasswords',
    [
      'Turn on 2-Step Verification.',
      'Open App passwords, name it DhanKosh, tap Create.',
      'Paste the 16-letter password here.',
    ],
  ),

  /// Outlook, Hotmail, Live.
  outlook(
    'Outlook',
    'outlook.office365.com',
    'https://account.live.com/proofs/AppPassword',
    [
      'Open Advanced security options.',
      'Turn on Two-step verification first. App passwords only appears after.',
      'Tap Create a new app password.',
      'Paste it here. Work or school accounts may block this.',
    ],
  ),

  /// Yahoo Mail.
  yahoo(
    'Yahoo',
    'imap.mail.yahoo.com',
    'https://login.yahoo.com/account/security',
    [
      'Open Account security.',
      'Generate app password, name it DhanKosh.',
      'Paste it here.',
    ],
  ),

  /// iCloud Mail.
  icloud(
    'iCloud',
    'imap.mail.me.com',
    'https://appleid.apple.com',
    [
      'Open Sign-In and Security.',
      'App-Specific Passwords, tap +, name it DhanKosh.',
      'Paste it here.',
    ],
  ),

  /// Any other IMAP server; host is typed by the user.
  custom(
    'Other',
    '',
    null,
    [
      'Create an app password in your provider settings.',
      'Make sure IMAP is switched on.',
    ],
  );

  const EmailProvider(
    this.label,
    this.imapHost,
    this.appPasswordUrl,
    this.steps,
  );

  /// Name shown in the picker.
  final String label;

  /// IMAP host preset; empty for [custom].
  final String imapHost;

  /// Where to create an app password.
  final String? appPasswordUrl;

  /// Brief how-to, one line per step.
  final List<String> steps;

  /// Domains handled by this preset.
  static const _domains = <String, EmailProvider>{
    'gmail.com': gmail,
    'googlemail.com': gmail,
    'outlook.com': outlook,
    'hotmail.com': outlook,
    'live.com': outlook,
    'msn.com': outlook,
    'outlook.in': outlook,
    'hotmail.co.in': outlook,
    'yahoo.com': yahoo,
    'yahoo.co.in': yahoo,
    'yahoo.in': yahoo,
    'ymail.com': yahoo,
    'rocketmail.com': yahoo,
    'icloud.com': icloud,
    'me.com': icloud,
    'mac.com': icloud,
  };

  /// Preset for [address]'s domain, or [custom].
  static EmailProvider detect(String address) {
    final at = address.lastIndexOf('@');
    if (at < 0) return custom;
    return _domains[address.substring(at + 1).trim().toLowerCase()] ?? custom;
  }
}

/// A mailbox login without its password (the password lives in secure
/// storage only, FR-03-05).
class EmailAccount {
  /// Creates an account; [address] is lower-cased and trimmed.
  EmailAccount({
    required String address,
    required this.provider,
    required String imapHost,
    this.imapPort = 993,
    this.enabled = true,
  })  : address = address.trim().toLowerCase(),
        imapHost = imapHost.trim().toLowerCase();

  /// Account for [address] using the [provider] preset (custom: [host]).
  factory EmailAccount.forAddress(
    String address, {
    EmailProvider? provider,
    String? host,
    int port = 993,
  }) {
    final p = provider ?? EmailProvider.detect(address);
    final domain = address.contains('@')
        ? address.substring(address.lastIndexOf('@') + 1).trim()
        : '';
    final h = (host != null && host.trim().isNotEmpty)
        ? host
        : (p.imapHost.isNotEmpty ? p.imapHost : 'imap.$domain');
    return EmailAccount(
      address: address,
      provider: p,
      imapHost: h,
      imapPort: port,
    );
  }

  static final RegExp _addressPattern =
      RegExp(r'^[A-Za-z0-9._%+\-]+@([A-Za-z0-9\-]+\.)+[A-Za-z]{2,}$');

  /// Whether [address] looks like a full email address (FR-03-01).
  static bool isValidAddress(String address) =>
      _addressPattern.hasMatch(address.trim());

  /// Lower-case address.
  final String address;

  /// Preset in use.
  final EmailProvider provider;

  /// IMAP host.
  final String imapHost;

  /// IMAP TLS port.
  final int imapPort;

  /// Whether syncs read this mailbox (FR-03-22).
  final bool enabled;

  /// Copy with a new [enabled] flag.
  EmailAccount withEnabled({required bool enabled}) => EmailAccount(
        address: address,
        provider: provider,
        imapHost: imapHost,
        imapPort: imapPort,
        enabled: enabled,
      );

  /// SMTP host used to mail the verification code to the address itself
  /// (FR-03-03); same login as IMAP.
  String get smtpHost => switch (provider) {
        EmailProvider.gmail => 'smtp.gmail.com',
        EmailProvider.outlook => 'smtp-mail.outlook.com',
        EmailProvider.yahoo => 'smtp.mail.yahoo.com',
        EmailProvider.icloud => 'smtp.mail.me.com',
        EmailProvider.custom => imapHost.startsWith('imap.')
            ? 'smtp.${imapHost.substring(5)}'
            : 'smtp.${address.substring(address.lastIndexOf('@') + 1)}',
      };

  /// SMTP port: 465 (TLS from the start) or 587 (STARTTLS).
  int get smtpPort => smtpSsl ? 465 : 587;

  /// Outlook and iCloud use STARTTLS; the rest TLS from the start.
  bool get smtpSsl =>
      provider != EmailProvider.outlook && provider != EmailProvider.icloud;

  /// App passwords are pasted with spaces; the server wants none (FR-03-02).
  static String cleanPassword(String raw) => raw.replaceAll(RegExp(r'\s+'), '');
}
