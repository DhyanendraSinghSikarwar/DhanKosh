import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/text/rx.dart';

/// What a [Template] pulled out of a message; null fields fall back to the
/// generic extractors.
class TemplateMatch {
  /// Creates a match.
  const TemplateMatch({
    this.amount,
    this.currency,
    this.account,
    this.merchant,
    this.vpa,
    this.reference,
    this.balance,
    this.type,
    this.accountKind,
  });

  /// `amt` group.
  final String? amount;

  /// `cur` group.
  final String? currency;

  /// `acct` group.
  final String? account;

  /// `merchant` group.
  final String? merchant;

  /// `vpa` group.
  final String? vpa;

  /// `ref` group.
  final String? reference;

  /// `bal` group.
  final String? balance;

  /// Type the template fixes, if any.
  final TransactionType? type;

  /// Account kind the template fixes, if any.
  final AccountKind? accountKind;
}

/// A bank-specific pattern. Named groups (amt, cur, acct, merchant, vpa, ref,
/// bal) fill fields; any field a template leaves out falls back to the generic
/// extractors. Compiled once, at construction (FR-06-08).
///
/// `%AMT%` in the pattern stands for `Template.amt`.
class Template {
  /// Compiles [pattern].
  Template(String pattern, {this.type, this.accountKind})
      : _regex = rx(pattern.replaceAll('%AMT%', amt));

  /// A number as it appears after normalization. Never swallows a trailing
  /// full stop.
  static const amt = r'\d[\d,]*(?:\.\d{1,2})?';

  /// Type the template fixes.
  final TransactionType? type;

  /// Account kind the template fixes.
  final AccountKind? accountKind;
  final RegExp _regex;

  /// The match of this template in [text], or null.
  TemplateMatch? match(String text) {
    final m = _regex.firstMatch(text);
    if (m == null) return null;
    String? g(String name) {
      if (!m.groupNames.contains(name)) return null;
      final v = m.namedGroup(name)?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return TemplateMatch(
      amount: g('amt'),
      currency: g('cur'),
      account: g('acct'),
      merchant: g('merchant'),
      vpa: g('vpa'),
      reference: g('ref'),
      balance: g('bal'),
      type: type,
      accountKind: accountKind,
    );
  }
}
