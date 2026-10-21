import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// What banks build statement passwords from. Everything is optional.
/// [altName] and [altPhone] cover a second name or mobile on record with
/// another bank or card (a spelling variant, a maiden name, an old number).
class Identity {
  /// Creates an identity.
  const Identity({
    this.name,
    this.dob,
    this.pan,
    this.phone,
    this.altName,
    this.altPhone,
    this.email,
  });

  /// Full name.
  final String? name;

  /// Date of birth.
  final CivilDate? dob;

  /// PAN, ten characters.
  final String? pan;

  /// Mobile number.
  final String? phone;

  /// A second name on record.
  final String? altName;

  /// A second mobile on record.
  final String? altPhone;

  /// Kept with the sealed details so accounts can inherit it; not used to
  /// build guesses.
  final String? email;
}

/// What one bank account or card adds to [Identity]: details the bank itself
/// holds. [names], [phones] and [emails] are the account's effective values,
/// its own before the profile's.
class BankIdentity {
  /// Creates bank details.
  const BankIdentity({
    this.customerId,
    this.accountNumber,
    this.ifsc,
    this.names = const [],
    this.phones = const [],
    this.emails = const [],
  });

  /// Customer id.
  final String? customerId;

  /// Account number.
  final String? accountNumber;

  /// IFSC code.
  final String? ifsc;

  /// Names on the account.
  final List<String> names;

  /// Phones on the account.
  final List<String> phones;

  /// Emails on the account.
  final List<String> emails;
}

/// Maps a bank's name, or an email sender, to a stable key, so accounts and
/// statements of one bank meet.
abstract final class BankKeys {
  static final List<(String, RegExp)> _rules = [
    ('hdfc', rx('hdfc')),
    ('icici', rx('icici')),
    ('axis', rx(r'\baxis')),
    ('hsbc', rx('hsbc')),
    ('sbi', rx(r'\bsbi|state bank')),
    ('kotak', rx('kotak')),
    ('yes', rx(r'\byes\s*bank|yesbank')),
    ('idfc', rx('idfc')),
    ('indusind', rx('indusind')),
    ('baroda', rx(r'baroda|\bbob\b')),
    ('pnb', rx(r'\bpnb\b|punjab national')),
    ('federal', rx('federal')),
    ('canara', rx('canara')),
    ('union', rx('union bank')),
    ('rbl', rx(r'\brbl')),
    ('scb', rx(r'standard chartered|\bscb\b')),
    ('amex', rx(r'\bamex|american express')),
    ('au', rx(r'\bau small|\bau bank')),
  ];

  /// The key of the first bank named in [text] (a bank name, or a sender like
  /// `Name <alerts@hdfcbank.net>`), or null.
  static String? of(String? text) {
    if (text == null) return null;
    for (final (key, re) in _rules) {
      if (re.hasMatch(text)) return key;
    }
    return null;
  }
}

/// Likely statement passwords from the user's details, most common formats
/// first: card statements (HDFC, Axis: NAME + DDMM; ICICI, Kotak: name + DDMM;
/// SBI Card: DDMMYYYY + last 4 of card), CAS from CAMS, KFintech, NSDL and CDSL
/// (PAN), NPS and bank statements (DOB, customer details). The primary name and
/// mobile come before the alternates; the list is capped at [max] so every PDF
/// stays quick to try (FR-05-09).
abstract final class PasswordGuesser {
  /// Cap for [candidates].
  static const max = 240;

  /// Cap for [forBanks]: exact forms from every account, then name and date
  /// combinations.
  static const maxWithBanks = 300;

  static final RegExp _ws = RegExp(r'\s+');

  static String _p2(int n) => n.toString().padLeft(2, '0');

  static String? _clean(String? s) {
    if (s == null) return null;
    return s;
  }

  /// Exact forms first (HDFC uses the customer ID as it is), then, when
  /// [combos], the usual combinations built from each account's own name and
  /// mobile before the profile's, then the profile alone. [banks] holds the
  /// accounts and cards of the statement's bank, or of every bank when that
  /// bank is unknown.
  static List<String> forBanks(
    Identity profile,
    List<BankIdentity> banks, {
    Iterable<String> last4s = const [],
    bool combos = true,
  }) {
    final out = <String>{};
    for (final b in banks) {
      out.addAll(_exactForms(b));
    }
    if (combos) {
      for (final b in banks) {
        final names = <String>{
          ...b.names,
          if (_clean(profile.name) != null) profile.name!,
          if (_clean(profile.altName) != null) profile.altName!,
        }.where((s) => s.trim().isNotEmpty).toList();
        final phones = <String>{
          ...b.phones,
          if (profile.phone != null) profile.phone!,
          if (profile.altPhone != null) profile.altPhone!,
        }.where((s) => s.trim().isNotEmpty).toList();
        if (b.names.isEmpty && b.phones.isEmpty) continue;
        out.addAll(
          candidates(
            Identity(
              name: names.isNotEmpty ? names[0] : null,
              altName: names.length > 1 ? names[1] : null,
              phone: phones.isNotEmpty ? phones[0] : null,
              altPhone: phones.length > 1 ? phones[1] : null,
              dob: profile.dob,
              pan: profile.pan,
              email: profile.email,
            ),
            last4s,
          ),
        );
      }
    }
    out.addAll(candidates(profile, last4s));
    return out.take(maxWithBanks).toList();
  }

  static List<String> _exactForms(BankIdentity b) {
    final out = <String>{};
    final cid = b.customerId?.trim();
    if (cid != null && cid.isNotEmpty) {
      out
        ..add(cid)
        ..add(lettersAndDigits(cid));
    }
    final acctRaw =
        b.accountNumber == null ? '' : lettersAndDigits(b.accountNumber!);
    if (acctRaw.isNotEmpty) {
      out.add(acctRaw);
      for (final n in [4, 5, 6, 8]) {
        if (acctRaw.length > n) out.add(takeLast(acctRaw, n));
      }
    }
    final ifsc = b.ifsc == null ? '' : lettersAndDigits(b.ifsc!);
    if (ifsc.isNotEmpty) {
      out
        ..add(ifsc.toUpperCase())
        ..add(ifsc.toLowerCase());
    }
    return out.where((s) => s.length >= 4).toList();
  }

  /// The candidate passwords for [id], best first, at most [max]. [last4s] are
  /// the last four digits of the cards the statement may belong to.
  static List<String> candidates(
    Identity id, [
    Iterable<String> last4s = const [],
  ]) {
    final out = <String>{};
    final panRaw =
        id.pan == null ? null : lettersAndDigits(id.pan!.toUpperCase());
    final pan = panRaw != null && panRaw.length == 10 ? panRaw : null;
    final phones = <String>{
      for (final p in [id.phone, id.altPhone])
        if (p != null)
          if (takeLast(p.split('').where(isDigit).join(), 10) case final d
              when d.length == 10)
            d,
    }.toList();
    // Four-letter name prefixes, primary name first; the same prefix from both
    // names is tried once.
    final prefixes = <String>[];
    final seen = <String>{};
    for (final part in [..._nameParts(id.name), ..._nameParts(id.altName)]) {
      final four = part.length > 4 ? part.substring(0, 4) : part;
      if (seen.add(four.toLowerCase())) prefixes.add(four);
    }
    final dob = id.dob;
    final ddmm = dob == null ? null : '${_p2(dob.day)}${_p2(dob.month)}';
    final ddmmyy = dob == null ? null : '$ddmm${_p2(dob.year % 100)}';
    final ddmmyyyy = dob == null ? null : '$ddmm${dob.year}';
    final dates = <String>[
      if (ddmm != null) ddmm,
      if (ddmmyyyy != null) ddmmyyyy,
      if (ddmmyy != null) ddmmyy,
      if (dob != null)
        '${dob.year.toString().padLeft(4, '0')}${_p2(dob.month)}${_p2(dob.day)}',
      if (dob != null)
        '${_p2(dob.month)}${_p2(dob.day)}${dob.year.toString().padLeft(4, '0')}',
      if (dob != null) '${_p2(dob.month)}${_p2(dob.day)}',
      if (dob != null) dob.year.toString(),
    ];

    // CAS (CAMS, KFintech, NSDL, CDSL) and many tax and NPS documents: the PAN.
    if (pan != null) {
      out
        ..add(pan)
        ..add(pan.toLowerCase());
    }

    // NAME + DDMM and its relatives: the usual card statement password.
    for (final four in prefixes) {
      for (final base in [
        four.toUpperCase(),
        four.toLowerCase(),
        capitalize(four.toLowerCase()),
      ]) {
        if (ddmm != null) out.add('$base$ddmm');
        if (ddmmyy != null) out.add('$base$ddmmyy');
        if (ddmmyyyy != null) out.add('$base$ddmmyyyy');
        for (final l in last4s) {
          out.add('$base$l');
        }
        for (final p in phones) {
          out.add('$base${takeLast(p, 4)}');
        }
        if (dob != null) out.add('$base${dob.year}');
      }
    }
    // SBI Card: DDMMYYYY + last 4 of the card; some banks put the digits first.
    for (final l4 in last4s) {
      if (ddmmyyyy != null) out.add('$ddmmyyyy$l4');
      if (ddmm != null) {
        out
          ..add('$ddmm$l4')
          ..add('$l4$ddmm');
      }
    }
    out.addAll(dates);
    for (final p in phones) {
      out
        ..add(p)
        ..add(takeLast(p, 4))
        ..add(takeLast(p, 5))
        ..add(takeLast(p, 6));
    }
    // PAN with the DOB (some insurers and brokers), and the first five letters
    // of the PAN.
    if (pan != null) {
      if (ddmmyyyy != null) {
        out
          ..add('$pan$ddmmyyyy')
          ..add('${pan.toLowerCase()}$ddmmyyyy');
      }
      if (ddmm != null) {
        out
          ..add('${pan.substring(0, 5)}$ddmm')
          ..add('${pan.substring(0, 5).toLowerCase()}$ddmm');
      }
    }
    if (ddmm != null) {
      for (final p in phones) {
        out
          ..add('${takeLast(p, 4)}$ddmm')
          ..add('$ddmm${takeLast(p, 4)}');
      }
    }
    return out.where((s) => s.length >= 4).take(max).toList();
  }

  static List<String> _nameParts(String? name) {
    if (name == null) return const [];
    final words = name
        .trim()
        .split(_ws)
        .map((w) => w.split('').where(isLetter).join())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    // First name first; then the last name and the whole name run together.
    final parts = <String>[];
    for (final p in [words.first, words.last, words.join()]) {
      if (!parts.contains(p)) parts.add(p);
    }
    return parts.where((p) => p.length >= 2).toList();
  }
}
