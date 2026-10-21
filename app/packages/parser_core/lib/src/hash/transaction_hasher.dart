import 'package:parser_core/src/hash/sha256.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/util/civil.dart';

/// transactionHash = SHA-256(amount | direction | accountLast4 | yyyy-MM-dd |
/// refNo-or-empty), lower-case hex (FR-06-13). Byte-identical to the Kotlin
/// hasher.
///
/// The SMS and the email for one transaction produce the same hash when they
/// agree on those fields. When one carries the reference and the other does
/// not, the hashes differ, and the fuzzy matcher in the dedup layer catches
/// the pair instead.
abstract final class TransactionHasher {
  /// The hash of the key fields; [date] is the local (IST) date.
  static String hash(
    int amountMinor,
    TransactionType type,
    String? accountLast4,
    CivilDate date,
    String? referenceNumber,
  ) {
    final paise = (amountMinor % 100).toString().padLeft(2, '0');
    final amount = '${amountMinor ~/ 100}.$paise';
    final key = '$amount|${type.direction}|${accountLast4 ?? ''}|$date|'
        '${referenceNumber ?? ''}';
    return sha256Hex(key);
  }
}
