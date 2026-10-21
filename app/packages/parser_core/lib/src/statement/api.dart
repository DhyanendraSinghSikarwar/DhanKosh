import 'package:parser_core/src/model/holding.dart';
import 'package:parser_core/src/parser_config.dart';
import 'package:parser_core/src/registry/parser_registry.dart';
import 'package:parser_core/src/statement/card_due.dart';
import 'package:parser_core/src/statement/investment_parser.dart';
import 'package:parser_core/src/statement/mf_order_parser.dart';
import 'package:parser_core/src/statement/portfolio_summary.dart';
import 'package:parser_core/src/statement/statement_parser.dart';

final ParserRegistry _registry = ParserRegistry.standard();

/// Reads the text of a statement (PDF text, or spreadsheet rows turned into
/// lines by `SpreadsheetLines.toText`): transaction rows, summary totals,
/// holdings and deposits (FR-05-03 .. FR-05-18). [sender] is the email sender
/// or file name; [receivedAt] is epoch milliseconds. Pure and deterministic.
StatementResult parseStatement(
  String text,
  String sender,
  int receivedAt, {
  ParserConfig config = const ParserConfig(),
}) =>
    StatementParser(config).parse(text, sender, receivedAt);

/// What a card issuer's bill or payment SMS or email says: total and minimum
/// due, due date, or the payment it acknowledges; null for anything else.
/// Equivalent to `ParserRegistry.cardDue` on the standard registry.
CardDue? parseCardDue(
  String body,
  String sender,
  int timestamp, {
  ParserRegistry? registry,
}) =>
    (registry ?? _registry).cardDue(body, sender, timestamp);

/// A mutual fund purchase confirmed by an investing app or registrar email
/// (FR-05-24), or null.
MfOrder? parseMfOrder(
  String text,
  String? subject,
  String sender,
  int receivedAt, {
  ParserConfig config = const ParserConfig(),
}) =>
    MfOrderParser(config).parse(text, subject, sender, receivedAt);

/// The aggregate holdings in an INDmoney portfolio summary email (FR-05-25).
List<HoldingSnapshot> parsePortfolioSummary(
  String text,
  String? subject,
  String sender,
  int receivedAt, {
  ParserConfig config = const ParserConfig(),
}) =>
    PortfolioSummary.parse(text, subject, sender, receivedAt, config: config);

/// The EPF or NPS holding an investment SMS from EPFO, UMANG or an NPS CRA
/// reports, or null (FR-06-15).
HoldingSnapshot? parseInvestmentSms(
  String body,
  String sender,
  int timestamp,
) =>
    InvestmentParser.parse(body, sender, timestamp);

/// The EPF or NPS holding an email body reports, or null.
HoldingSnapshot? parseInvestmentEmail(String body, int timestamp) =>
    InvestmentParser.parseEmail(body, timestamp);
