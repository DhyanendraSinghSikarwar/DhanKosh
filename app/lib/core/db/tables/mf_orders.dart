import 'package:drift/drift.dart';

/// Mutual fund purchases read from mail or SMS (FR-12-18, FR-16-22). Kept so
/// SIPs and the investment list can be shown. Written with the holding.
@DataClassName('MfOrderRow')
class MfOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get identifier => text()();
  TextColumn get schemeName => text()();

  /// Epoch ms of the order.
  IntColumn get at => integer()();
  IntColumn get amountMinor => integer().nullable()();
  RealColumn get units => real().nullable()();
  RealColumn get nav => real().nullable()();
  TextColumn get platform => text().nullable()();
}
