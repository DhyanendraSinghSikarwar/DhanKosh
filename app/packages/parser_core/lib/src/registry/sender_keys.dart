import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/strings.dart';

/// Registry lookup keys for a sender, most specific first (FR-06-02).
///
/// SMS `VM-HDFCBK-S` gives `[HDFCBK]` (TRAI header: 2-char operator prefix,
/// 6-char entity, optional suffix). Email `HDFC Bank <alerts@hdfcbank.net>`
/// gives `[alerts@hdfcbank.net, hdfcbank.net, net]`. Email
/// `x@alerts.sbi.co.in` gives
/// `[x@alerts.sbi.co.in, alerts.sbi.co.in, sbi.co.in, co.in]`.
abstract final class SenderKeys {
  static final RegExp _angleAddress = rx('<([^>]+)>');

  /// The keys for [sender].
  static List<String> candidates(String sender) {
    final s = sender.trim();
    if (s.isEmpty) return const [];
    if (s.contains('@')) {
      final angle = findFrom(_angleAddress, s);
      final address = (angle == null ? s : grp(angle, 1)).trim().toLowerCase();
      final out = <String>[address];
      var domain = address.substring(address.lastIndexOf('@') + 1);
      while (domain.contains('.')) {
        out.add(domain);
        domain = domain.substring(domain.indexOf('.') + 1);
      }
      return out;
    }
    return [smsHeader(s)];
  }

  /// The six-character entity of an SMS sender id.
  static String smsHeader(String sender) {
    final parts = sender
        .toUpperCase()
        .split('-')
        .map(lettersAndDigits)
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length >= 2 && parts[0].length <= 2) return parts[1];
    return parts[0];
  }
}
