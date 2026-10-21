// Port of TransactionHasherTest plus SHA-256 vectors (FR-06-13, TC-06-19,
// TC-07-01). The hash must be byte-identical to the Kotlin hasher.
import 'package:parser_core/parser_core.dart';
import 'package:parser_core/src/hash/sha256.dart';
import 'package:test/test.dart';

void main() {
  const day = CivilDate(2026, 9, 25);

  test('sha-256 matches the standard vectors', () {
    expect(
      sha256Hex(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Hex(
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    expect(
      sha256Hex('a' * 1000),
      '41edece42d63e8d9bf515a9ba6932e1c20cbc9f5a5d134645adb5db1b9737ea3',
    );
  });

  test('hash is a stable lowercase sha-256 hex of the canonical key', () {
    final h = TransactionHasher.hash(
      25000,
      TransactionType.debit,
      '1234',
      day,
      '526812345678',
    );
    expect(h.length, 64);
    expect(
      h,
      TransactionHasher.hash(
        25000,
        TransactionType.debit,
        '1234',
        day,
        '526812345678',
      ),
    );
    // SHA-256("250.00|OUT|1234|2026-09-25|526812345678"), computed with
    // Python's hashlib for the Kotlin key layout.
    expect(
      h,
      '274762cdb346c6b373d9956c54b97f7ba47540e87d9489688d3a0be6133afe6b',
    );
    expect(h, sha256Hex('250.00|OUT|1234|2026-09-25|526812345678'));
  });

  test('debit and investment hash alike because both move money out', () {
    expect(
      TransactionHasher.hash(99900, TransactionType.debit, '1234', day, null),
      TransactionHasher.hash(
        99900,
        TransactionType.investment,
        '1234',
        day,
        null,
      ),
    );
  });

  test('every key field changes the hash', () {
    final base = TransactionHasher.hash(
      25000,
      TransactionType.debit,
      '1234',
      day,
      'R1',
    );
    String h(
      int amount,
      TransactionType type,
      String? last4,
      CivilDate d,
      String? ref,
    ) =>
        TransactionHasher.hash(amount, type, last4, d, ref);
    expect(base, isNot(h(25001, TransactionType.debit, '1234', day, 'R1')));
    expect(base, isNot(h(25000, TransactionType.credit, '1234', day, 'R1')));
    expect(base, isNot(h(25000, TransactionType.debit, '9999', day, 'R1')));
    expect(
      base,
      isNot(h(25000, TransactionType.debit, '1234', day.plusDays(1), 'R1')),
    );
    expect(base, isNot(h(25000, TransactionType.debit, '1234', day, null)));
  });

  test('amounts are formatted with two decimals', () {
    expect(
      TransactionHasher.hash(5, TransactionType.debit, null, day, null),
      sha256Hex('0.05|OUT||2026-09-25|'),
    );
    expect(
      TransactionHasher.hash(5, TransactionType.transfer, null, day, null),
      sha256Hex('0.05|XFER||2026-09-25|'),
    );
  });
}
