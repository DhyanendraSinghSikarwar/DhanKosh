import 'package:parser_core/src/extract/account_extractor.dart';
import 'package:parser_core/src/extract/amount_extractor.dart';
import 'package:parser_core/src/extract/channel_detector.dart';
import 'package:parser_core/src/extract/date_time_extractor.dart';
import 'package:parser_core/src/extract/generic_phrases.dart';
import 'package:parser_core/src/extract/merchant_extractor.dart';
import 'package:parser_core/src/extract/reference_extractor.dart';
import 'package:parser_core/src/extract/type_classifier.dart';
import 'package:parser_core/src/free_text/transaction_draft.dart';
import 'package:parser_core/src/hash/transaction_hasher.dart';
import 'package:parser_core/src/merchant/merchant_normalizer.dart';
import 'package:parser_core/src/model/model.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/rules/card_bill.dart';
import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/text/text_normalizer.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// Reads transactions out of free text with the same extractors the bank
/// parsers use, but without a sender to say which bank it is. A screenshot gives
/// a [TransactionDraft] for the user to confirm; a payment-app notification is
/// accepted only when it clearly describes a completed payment (FR-06-16).
class FreeTextParser {
  /// Creates a parser using [config].
  const FreeTextParser([this.config = const ParserConfig()]);

  /// Zone settings.
  final ParserConfig config;

  /// A draft from screenshot text, or null when there is no amount.
  TransactionDraft? draft(String raw, int timestamp) {
    final text = TextNormalizer.normalize(raw);
    final lower = text.toLowerCase();
    final money = AmountExtractor.extract(text);
    if (money == null) return null;
    final type = TypeClassifier.classify(text, lower: lower);
    final account = AccountExtractor.extract(text);
    final channel = ChannelDetector.detect(text, lower);
    final eff = type ?? TransactionType.debit;
    final raw0 = MerchantExtractor.extract(text, eff, lower);
    final merchant = MerchantNormalizer.normalize(raw0, eff, channel, text);
    final resolved = _resolveTime(text, lower, timestamp);
    return TransactionDraft(
      amountMinor: money.minor,
      currency: money.currency,
      type: type,
      merchant: GenericPhrases.clean(merchant.name),
      upiId: raw0.vpa?.toLowerCase(),
      reference: ReferenceExtractor.normalize(
        ReferenceExtractor.extract(text, lower),
      ),
      bankName: _bankIn(text),
      last4: account?.last4,
      accountKind: account?.kind ?? AccountKind.account,
      channel: channel,
      category: merchant.category,
      time: resolved.$1,
      hasExplicitTime: resolved.$2,
    );
  }

  /// A payment app's notification ("Paid ₹50 to Raju", "₹200 received from
  /// Asha"). Null for offers, cashback, requests, reminders, OTPs and failures,
  /// and for anything without an amount and a direction.
  ParsedTransaction? fromNotification(
    String appName,
    String? title,
    String? body,
    int postedAt,
  ) =>
      readNotification(appName, [title, body], postedAt).tx;

  /// Reads a payment app notification made of several text fields (title, text,
  /// big text, sub text, lines), in any layout: amount and payee may sit in
  /// different fields, with or without a currency symbol.
  NotificationRead readNotification(
    String appName,
    List<String?> parts,
    int postedAt, [
    Source source = Source.app,
  ]) {
    NotificationRead skip(String reason) => NotificationRead(null, reason);

    final seen = <String>{};
    final segments = <String>[];
    for (final part in parts) {
      if (part == null) continue;
      for (final field in part.split(_fieldSplit)) {
        final n = TextNormalizer.normalize(field);
        if (n.trim().isEmpty) continue;
        for (final s in n.split(_sentence)) {
          final t = s.trim();
          if (t.isNotEmpty && seen.add(t)) segments.add(t);
        }
      }
    }
    final whole = segments.join(' . ');
    if (whole.length < _minLength) return skip('too short');
    if (_otp.hasMatch(whole)) return skip('otp or security text');
    if (_failed.hasMatch(whole)) return skip('failed or pending payment');
    if (_reminder.hasMatch(whole)) {
      return skip('request, reminder or due notice');
    }
    // A balance, a promo amount ("Rs 5 off", "Pay now ₹1,299") or a cashback
    // line is never the payment.
    final kept = <String>[];
    for (final s in segments) {
      if (_promo.hasMatch(s) || _uiText.hasMatch(s) || _callToPay.hasMatch(s)) {
        continue;
      }
      final cut = trimChars(s.replaceAll(_balanceTail, ''), ' ,;-(');
      if (cut.trim().isEmpty) continue;
      kept.add(_addCurrency(cut));
    }
    if (kept.isEmpty) return skip('offer or promotion');
    final text = kept.join(' . ');
    final lower = text.toLowerCase();
    final signal = findFrom(_signal, text);
    if (signal == null) return skip('no payment wording');
    final type = signal.namedGroup('cr') != null
        ? TransactionType.credit
        : TransactionType.debit;
    final transferText =
        TypeClassifier.classify(text, lower: lower) == TransactionType.transfer;
    final money = AmountExtractor.extract(text);
    if (money == null || money.minor <= 0) return skip('no amount');

    var (name, vpa) = _payee(kept, type);
    // Paying a card's bill is kept, as a transfer, so it shows in Transactions
    // without counting as a spend.
    final cardBill = type == TransactionType.debit &&
        (CardBill.inText(text, lower) ||
            CardBill.paidToCard(text) ||
            CardBill.isPayee(name, vpa));
    if (transferText && !cardBill) return skip('own transfer or card bill');
    if (name == null && vpa == null && type == TransactionType.debit) {
      final bill = findFrom(_billKind, text);
      if (bill != null) {
        name = '${capitalize(grp(bill, 1))} bill';
      } else if (_recharge.hasMatch(text)) {
        name = 'Recharge';
      }
    }
    var channel = ChannelDetector.detect(text, lower);
    if (channel == Channel.other && _upiApps.contains(appName)) {
      channel = Channel.upi;
    }
    final outType = cardBill ? TransactionType.transfer : type;
    final merchant = MerchantNormalizer.normalize(
      RawMerchant(name, vpa),
      outType,
      channel,
      text,
    );
    final account = AccountExtractor.extract(text);
    final utr = findFrom(_utr, text);
    final vpaInText = findFrom(_vpa, text);
    final draft = TransactionDraft(
      amountMinor: money.minor,
      currency: money.currency,
      type: outType,
      merchant: cardBill && !CardBill.isPayee(name, vpa)
          ? CardBill.label
          : GenericPhrases.clean(merchant.name),
      upiId: vpa ?? vpaInText?.group(0)?.toLowerCase(),
      reference: (utr == null ? null : grp(utr, 1)) ??
          ReferenceExtractor.normalize(ReferenceExtractor.extract(text, lower)),
      bankName: _bankIn(text),
      last4: account?.last4,
      accountKind: account?.kind ?? AccountKind.account,
      channel: channel,
      category: merchant.category,
      // A notification is about now: dates in it are usually "valid till" or
      // offer dates.
      time: postedAt,
      hasExplicitTime: false,
    );
    return NotificationRead(
      toParsed(draft, outType, source, appName, postedAt, confidence: 0.55),
      null,
    );
  }

  /// "Paid 250 to X", "250 sent": gives a bare amount next to a payment verb
  /// the symbol the extractor needs.
  String _addCurrency(String s) {
    if (_currencyWord.hasMatch(s)) return s;
    final after = s.replaceAllMapped(
      _bareAfter,
      (m) => '${grp(m, 1)} INR ${grp(m, 2)}',
    );
    return after.replaceAllMapped(
      _bareBefore,
      (m) => 'INR ${grp(m, 1)} ${grp(m, 2)}',
    );
  }

  /// Payee (debit) or payer (credit): a name, or a UPI id when that is all the
  /// notification says.
  (String?, String?) _payee(List<String> segments, TransactionType type) {
    final candidates = <String>[];
    for (final s in segments) {
      if (type == TransactionType.credit) {
        final lead = findFrom(_senderLead, s);
        if (lead != null) candidates.add(grp(lead, 1));
        candidates.addAll(_fromName.allMatches(s).map((m) => grp(m, 1)));
      } else {
        final paid = findFrom(_paidName, s);
        if (paid != null) candidates.add(grp(paid, 1));
        candidates
          ..addAll(_toName.allMatches(s).map((m) => grp(m, 1)))
          ..addAll(_atName.allMatches(s).map((m) => grp(m, 1)));
      }
    }
    for (final c in candidates) {
      final t = trimChars(c.replaceAll(_trailingNoise, ''), ' -.,');
      if (t.length < 2 || _notName.hasMatch(t) || GenericPhrases.isGeneric(t)) {
        continue;
      }
      final vm = findFrom(_vpa, t);
      if (vm != null) {
        final vpa = vm.group(0)!;
        final rest = trimChars(t.replaceAll(vpa, ''), ' -()');
        final hasName = rest.length >= 2 && rest.split('').any(isLetter);
        return (hasName ? rest : null, vpa.toLowerCase());
      }
      if (!t.split('').any(isLetter)) continue;
      return (t, null);
    }
    return (null, null);
  }

  /// A parsed transaction from a [TransactionDraft]. [d] must have an amount.
  ParsedTransaction toParsed(
    TransactionDraft d,
    TransactionType type,
    Source source,
    String sender,
    int messageTimestamp, {
    double confidence = 0.9,
  }) {
    final amount = d.amountMinor;
    if (amount == null) throw ArgumentError('amount');
    final date = civilDateOf(d.time, config.utcOffset);
    return ParsedTransaction(
      amountMinor: amount,
      currency: d.currency,
      type: type,
      bankName: d.bankName ?? sender,
      accountLast4: d.last4,
      accountKind: d.accountKind,
      merchant: d.merchant,
      upiId: d.upiId,
      referenceNumber: d.reference,
      channel: d.channel,
      balanceMinor: null,
      availableLimitMinor: null,
      transactionTime: d.time,
      hasExplicitTime: d.hasExplicitTime,
      category: d.category,
      source: source,
      sender: sender,
      messageTimestamp: messageTimestamp,
      confidence: confidence,
      transactionHash: TransactionHasher.hash(
        amount,
        type,
        d.last4,
        date,
        d.reference,
      ),
    );
  }

  (int, bool) _resolveTime(String text, String lower, int fallback) {
    final parts = DateTimeExtractor.extract(text, lower);
    final date = parts.date;
    if (date == null) return (fallback, false);
    final time = parts.time ?? civilOf(fallback, config.utcOffset).time;
    final at = epochOf(date, time, config.utcOffset);
    // A screenshot is of something that already happened.
    return at > fallback + _dayMs
        ? (fallback, false)
        : (at, parts.time != null);
  }

  String? _bankIn(String text) {
    for (final (pattern, name) in _banks) {
      if (pattern.hasMatch(text)) return name;
    }
    return null;
  }

  static const _minLength = 8;
  static const int _dayMs = 24 * 60 * 60 * 1000;
  static const _upiApps = {
    'PhonePe', 'Google Pay', 'Paytm', 'BHIM', 'BHIM SBI Pay', 'CRED',
    'super.money', 'Navi', 'WhatsApp Pay', 'Amazon Pay', 'MobiKwik', //
  };
  static final _fieldSplit = RegExp(r'[\r\n]+|\s[•·|]\s|[•·]');
  // Sentence end, but not the dot of "Dr." or "Mr.".
  static final _sentence = RegExp(
    r'(?<!\b(?:Mr|Mrs|Ms|Dr|Smt|Shri|Sri)\.)(?<=[.!?])\s+',
  );
  static final RegExp _otp = rx(
    r'\botp\b|one[\s-]?time\s+pass|verification\s+code|\bcvv\b|\bupi\s+pin\b|\bpin\b',
  );
  static final RegExp _failed = rx(
    r"\b(?:fail(?:ed|ure|s)?|declined|unsuccessful|not\s+successful|could\s*n[o']?t|cancel(?:l)?ed|rejected|reversed|pending|"
    r'processing|in\s+progress|refund\s+(?:initiated|in\s+progress)|will\s+be\s+(?:refunded|credited)|timed?\s*out|on\s+hold|'
    r'bank\s+server|try\s+again)\b',
  );
  static final RegExp _reminder = rx(
    r'\b(?:requested|requesting|payment\s+request|collect\s+request|requests?\s+(?:you|money)|remind(?:er|s)?|due|overdue|expir(?:es|ing|ed)|'
    r'valid\s+(?:till|until)|bill\s+(?:is\s+)?generated|scheduled|upcoming|'
    r'will\s+be\s+(?:debited|deducted|charged)|set\s*up\s+autopay)\b',
  );

  /// Offers, rewards and promotions: the sentence is dropped, the rest of the
  /// notification still counts.
  static final RegExp _promo = rx(
    r'\b(?:cash\s*back|rewards?|scratch(?:\s*card)?|offers?|coupons?|vouchers?|won|win|claim|refer(?:ral)?|earn(?:ed|s)?|bonus|'
    r'discount|get\s+up\s*to|lucky|spin|\d+\s*points?)\b|\d+\s*%|\d\s*off\b|\boff\s+on\b|\bflat\s+(?:₹|rs|inr)',
  );

  /// Calls to pay that carry an amount ("Pay now ₹1,299"): dropped alone, so a
  /// payment sharing the notification still counts.
  static final RegExp _callToPay = rx(
    r'\b(?:pay\s+(?:now|again|later|bill)|recharge\s+now|set\s*up\s+autopay|pay\s+(?:₹|rs\.?|inr)\s*\d)',
  );

  /// "Avl bal Rs 4,000", "Balance: ₹500" at the end of a sentence: figures that
  /// are not the payment.
  static final RegExp _balanceTail = rx(
    r'(?:[,;(\-]\s*)?\b(?:(?:avl|avail|available|total|closing|wallet|new|updated|remaining)\.?\s+)*(?:bal(?:ance)?|limit)\b.*$',
  );

  /// Buttons and links that notifications append.
  static final RegExp _uiText = rx(
    r'^(?:view|tap|know|check|learn|download|track|explore|open|see|click|share|rate|swipe|repay|invite|enjoy|thank|split|add\s+(?:money|to))\b|\b(?:tap|click|swipe)\s+to\b',
  );
  static final RegExp _signal = rx(
    r'(?<cr>\b(?:(?:sent|paid)\s+you|received|credited|refund(?:ed)?\s+(?:of\s+\S+\s+\S+\s+)?(?:processed|credited|successful)|money\s+received|payment\s+received)\b)'
    r'|(?<db>\b(?:paid|sent|debited|spent|transferred|deducted|charged|purchased|money\s+sent|'
    r'payment\b(?!.{0,60}?\breceived\b).{0,60}?\b(?:successful|done|completed|made|sent)|'
    r'(?:recharge|bill)(?:\s+(?:payment\s+)?of\s+INR\s*[\d,.]+)?\s+(?:is\s+)?(?:successful|done|completed|paid))\b)',
  );
  static final RegExp _currencyWord = rx(r'\b(?:INR|USD|EUR|GBP|AED|SGD)\s*\d');
  static const _num = r'(\d[\d,]*(?:\.\d{1,2})?)';
  static final RegExp _bareAfter = rx(
    r'\b(paid|sent|received|debited|credited|spent|payment\s+of|bill\s+of|recharge\s+of|you)\s+' +
        _num +
        r'\b(?!\s*(?:%|days?|hours?|mins?|messages?|times?))',
  );
  static final RegExp _bareBefore =
      rx('^' + _num + r'\s+(paid|sent|received|debited|credited)\b');
  static const _name = r"([A-Za-z0-9][A-Za-z0-9 &'*_\-./@]{1,50}?)";
  static const _nameEnd =
      r'(?=\s+(?:via|using|on|dated|from|ref|refno|utr|upi|for|at|with|txn|transaction|successfully|successful|id|a/c|account|bank|is|was|has|through|thru|date|time|status|amount|debited|credited|reference)\b|\s*[,;:(!]|$)';
  static final RegExp _toName = rx(r'\bto\s+' + _name + _nameEnd);
  static final RegExp _atName = rx(r'\bat\s+' + _name + _nameEnd);

  /// "You paid Ravi Kumar INR 250": the payee sits between the verb and the
  /// amount.
  static final RegExp _paidName =
      rx(r'\bpaid\s+(?!you\b|INR)' + _name + r'\s+INR\s*\d');
  static final RegExp _fromName = rx(r'\bfrom\s+' + _name + _nameEnd);
  static final RegExp _senderLead =
      rx('^' + _name + r'\s+(?:has\s+)?(?:sent|paid)\s+you\b');
  static final RegExp _notName = rx(
    r'^(?:your|you|my|a/c|ac|acct|account|bank|the|a|an|card|wallet|upi|inr|view|see|check|know|get|earn|avoid|us|me|self)\b|^x+\d',
  );
  static final RegExp _recharge =
      rx(r'\b(?:mobile\s+|dth\s+|fastag\s+)?recharge\b');
  static final RegExp _billKind = rx(
    r'\b(electricity|water|gas|broadband|postpaid|mobile|dth|phone|internet|insurance)\s+bill\b',
  );
  static final RegExp _trailingNoise = rx(
    r'(?:\s+(?:via|using|on|upi|through|thru|ref|utr)\b.*|\s*\(.*)$',
  );

  /// The 12-digit UPI reference the bank repeats in its own alert, which beats
  /// an app's own transaction id.
  static final RegExp _utr = rx(
    r'\b(?:utr|rrn|upi\s+ref(?:erence)?(?:\s+(?:no|id))?)\W{0,4}(\d{10,22})\b',
  );
  static final RegExp _vpa = rx(r'\b[a-z0-9][\w.\-]{1,}@[a-z][a-z0-9]{1,20}\b');
  static final List<(RegExp, String)> _banks = [
    (rx(r'\bHDFC\b'), 'HDFC Bank'),
    (rx(r'\bICICI\b'), 'ICICI Bank'),
    (rx(r'\bSBI\b|state\s+bank'), 'SBI'),
    (rx(r'\bAxis\b'), 'Axis Bank'),
    (rx(r'\bKotak\b'), 'Kotak Mahindra Bank'),
    (rx(r'\bIDFC\b'), 'IDFC FIRST Bank'),
    (rx(r'\bYes\s+Bank\b'), 'Yes Bank'),
    (rx(r'\bBank\s+of\s+Baroda\b|\bBoB\b'), 'Bank of Baroda'),
    (rx(r'\bPNB\b|Punjab\s+National'), 'Punjab National Bank'),
    (rx(r'\bAU\s+(?:Small\s+Finance\s+)?Bank\b'), 'AU Small Finance Bank'),
    (rx(r'\bIndusInd\b'), 'IndusInd Bank'),
    (rx(r'\bFederal\s+Bank\b'), 'Federal Bank'),
    (rx(r'\bCanara\b'), 'Canara Bank'),
    (rx(r'\bUnion\s+Bank\b'), 'Union Bank of India'),
    (rx(r'\bHSBC\b'), 'HSBC'),
    (rx(r'\bRBL\b'), 'RBL Bank'),
  ];
}
