/// Pure-Dart message parsing for Hisaab. Parity target: Kotlin `parser-core`.
///
/// Entry point: `parse`. No Flutter, no I/O, deterministic for fixed inputs.
library;

export 'src/bank/banks.dart';
export 'src/bank/base_bank_parser.dart';
export 'src/bank/deposits.dart';
export 'src/bank/generic_bank_parser.dart';
export 'src/bank/indian_banks.dart';
export 'src/bank/lender_parser.dart';
export 'src/bank/loan_status.dart';
export 'src/bank/payment_app_parser.dart';
export 'src/dedup/dedup_models.dart';
export 'src/dedup/duplicate_matcher.dart';
export 'src/extract/account_extractor.dart';
export 'src/extract/amount_extractor.dart';
export 'src/extract/balance_extractor.dart';
export 'src/extract/channel_detector.dart';
export 'src/extract/date_time_extractor.dart';
export 'src/extract/generic_phrases.dart';
export 'src/extract/merchant_extractor.dart';
export 'src/extract/money.dart';
export 'src/extract/reference_extractor.dart';
export 'src/extract/type_classifier.dart';
export 'src/free_text/free_text_parser.dart';
export 'src/free_text/transaction_draft.dart';
export 'src/hash/transaction_hasher.dart';
export 'src/merchant/merchant_directory.dart';
export 'src/merchant/merchant_normalizer.dart';
export 'src/merchant/subcategories.dart';
export 'src/model/model.dart';
export 'src/parse.dart';
export 'src/parse_result.dart';
export 'src/parser_config.dart';
export 'src/registry/bank_parser.dart';
export 'src/registry/parser_registry.dart';
export 'src/registry/sender_keys.dart';
export 'src/rules/card_bill.dart';
export 'src/rules/rejection_rules.dart';
export 'src/template/template.dart';
export 'src/text/text_normalizer.dart';
export 'src/util/civil.dart';
