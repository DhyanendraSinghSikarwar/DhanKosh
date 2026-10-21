import 'package:hisaab/core/db/app_database.dart';
import 'package:hisaab/core/db/enum_codec.dart';
import 'package:hisaab/features/dedup_review/domain/dedup_policy.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

LedgerTx toLedgerTx(TransactionRow r) => LedgerTx(
      id: r.id,
      amountMinor: r.amountMinor,
      currency: r.currency,
      type: enumFromDb(TransactionType.values, r.type, TransactionType.debit),
      bankName: r.bankName,
      accountLast4: r.accountLast4,
      accountKind:
          enumFromDb(AccountKind.values, r.accountKind, AccountKind.account),
      accountId: r.accountId,
      merchant: r.merchant,
      upiId: r.upiId,
      referenceNumber: r.referenceNumber,
      channel: enumFromDb(Channel.values, r.channel, Channel.other),
      balanceMinor: r.balanceMinor,
      availableLimitMinor: r.availableLimitMinor,
      timestamp: r.timestamp,
      hasExplicitTime: r.hasExplicitTime,
      category: enumFromDb(Category.values, r.category, Category.other),
      subcategory: r.subcategory,
      customCategoryId: r.customCategoryId,
      transactionHash: r.transactionHash,
      confidence: r.confidence,
      needsReview: r.needsReview,
      duplicateOfId: r.duplicateOfId,
      reviewReason: r.reviewReason,
      note: r.note,
      createdAt: r.createdAt,
      inrMinor: r.inrMinor,
    );

TxSourceRow toSourceRow(TransactionSourceRow r) => TxSourceRow(
      id: r.id,
      transactionId: r.transactionId,
      source: enumFromDb(Source.values, r.source, Source.sms),
      sourceMessageId: r.sourceMessageId,
      sender: r.sender,
      parsedHash: r.parsedHash,
      rawText: r.rawText,
      subject: r.subject,
      receivedAt: r.receivedAt,
    );

DedupCandidate toCandidate(
  TransactionRow r,
  List<TransactionSourceRow> sources,
) =>
    DedupCandidate(
      id: r.id,
      amountMinor: r.amountMinor,
      currency: r.currency,
      type: enumFromDb(TransactionType.values, r.type, TransactionType.debit),
      timestamp: r.timestamp,
      hasExplicitTime: r.hasExplicitTime,
      transactionHash: r.transactionHash,
      category: enumFromDb(Category.values, r.category, Category.other),
      confidence: r.confidence,
      sources: {
        for (final s in sources)
          enumFromDb(Source.values, s.source, Source.sms),
      },
      sourceHashes: {for (final s in sources) s.parsedHash},
      referenceNumber: r.referenceNumber,
      accountLast4: r.accountLast4,
      accountId: r.accountId,
      merchant: r.merchant,
      upiId: r.upiId,
      balanceMinor: r.balanceMinor,
      availableLimitMinor: r.availableLimitMinor,
    );

/// Copy of [p] with a different category (rule applied at ingest).
ParsedTransaction withCategory(ParsedTransaction p, Category category) =>
    ParsedTransaction(
      amountMinor: p.amountMinor,
      currency: p.currency,
      type: p.type,
      bankName: p.bankName,
      accountLast4: p.accountLast4,
      accountKind: p.accountKind,
      merchant: p.merchant,
      upiId: p.upiId,
      referenceNumber: p.referenceNumber,
      channel: p.channel,
      balanceMinor: p.balanceMinor,
      availableLimitMinor: p.availableLimitMinor,
      transactionTime: p.transactionTime,
      hasExplicitTime: p.hasExplicitTime,
      category: category,
      source: p.source,
      sender: p.sender,
      messageTimestamp: p.messageTimestamp,
      confidence: p.confidence,
      transactionHash: p.transactionHash,
      isDebitCard: p.isDebitCard,
    );
