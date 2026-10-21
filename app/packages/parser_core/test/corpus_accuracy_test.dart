// The accuracy targets, measured across every bank's corpus through the
// registry, as the app will call it. Port of CorpusAccuracyTest (FR-06-18,
// AC-06-02, AC-06-03, TC-06-23). This is the parity gate.
import 'package:parser_core/parser_core.dart';
import 'package:test/test.dart';

import 'corpus/axis_corpus.dart';
import 'corpus/icici_corpus.dart';
import 'corpus/kotak_corpus.dart';
import 'corpus/sbi_corpus.dart';
import 'support/corpus.dart';

void main() {
  final registry = ParserRegistry.standard();

  ParsedTransaction? parseSample(Sample s) =>
      registry.parse(s.body, s.sender, receivedAt, s.source);

  test('field extraction accuracy is at least 98 percent', () {
    var checked = 0;
    var correct = 0;
    final misses = <String>[];
    void field(String label, {required bool ok}) {
      checked++;
      if (ok) {
        correct++;
      } else {
        misses.add(label);
      }
    }

    for (final s in allSamples) {
      final e = s.expect;
      if (e == null) continue;
      final tx = parseSample(s);
      final tag = s.label;
      field('$tag amount', ok: tx?.amountMinor == Money.parse(e.amount)!.minor);
      field('$tag type', ok: tx?.type == e.type);
      field('$tag account', ok: tx != null && tx.accountLast4 == e.last4);
      field('$tag ref', ok: tx != null && tx.referenceNumber == e.ref);
      if (e.merchant != null) {
        field('$tag merchant', ok: tx?.merchant == e.merchant);
      }
      if (e.balance != null) {
        field(
          '$tag balance',
          ok: tx?.balanceMinor == Money.parse(e.balance!)!.minor,
        );
      }
      if (e.date != null) {
        field(
          '$tag date',
          ok: tx != null && istDate(tx.transactionTime) == e.date,
        );
      }
    }
    final accuracy = correct / checked;
    // The CI log shows how much margin the 98% gate has.
    // ignore: avoid_print
    print('Field accuracy: $correct/$checked = '
        '${(accuracy * 100).toStringAsFixed(2)}%');
    expect(accuracy, greaterThanOrEqualTo(0.98), reason: 'misses: $misses');
  });

  test('no negative sample is ever parsed', () {
    final leaked = [
      for (final s in allSamples)
        if (s.expect == null && parseSample(s) != null) s.label,
    ];
    expect(leaked, <String>[]);
  });

  test('the corpus has the Kotlin size (10 banks, 199 messages)', () {
    expect(allCorpora.length, 10);
    expect(allSamples.length, 199);
  });

  test(
      'the sms and the email for the same transaction produce the same '
      'hash', () {
    // Pairs that describe one transaction: same amount, account, reference and
    // day.
    Sample firstEmail(List<Sample> l) => l.firstWhere(
          (s) => s.source == Source.email && s.body.contains('526812345678'),
        );
    final pairs = [
      (
        iciciSamples[0],
        iciciSamples
            .firstWhere((s) => s.body.contains('UPI/526612345678/SWIGGY')),
      ),
      (axisSamples[0], firstEmail(axisSamples)),
      (sbiSamples[0], firstEmail(sbiSamples)),
      (kotakSamples[0], firstEmail(kotakSamples)),
    ];
    for (final (sms, mail) in pairs) {
      final a = parseSample(sms)!;
      final b = parseSample(mail)!;
      expect(
        a.transactionHash,
        b.transactionHash,
        reason: '${sms.label} vs ${mail.label}',
      );
    }
  });
}
