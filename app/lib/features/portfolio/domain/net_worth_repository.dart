import 'package:hisaab/features/portfolio/domain/net_worth.dart';

/// Daily net worth points (FR-16-05).
abstract interface class NetWorthRepository {
  /// Records [assetsMinor]/[liabilitiesMinor] for epoch day [day] when
  /// `shouldRecordWorth` says so; keeps the last 1,100 points. Returns true
  /// when a point was written.
  Future<bool> recordPoint(int day, int assetsMinor, int liabilitiesMinor);

  /// Recorded points, oldest first; [sinceDay] limits the range.
  Stream<List<WorthPoint>> watchPoints({int? sinceDay});

  /// Recorded points, oldest first.
  Future<List<WorthPoint>> points({int? sinceDay});
}

/// Exclusions that persist (FR-16-14).
abstract interface class NetWorthPrefsRepository {
  /// Current exclusions.
  Stream<NetWorthFilter> watch();

  /// Current exclusions once.
  Future<NetWorthFilter> read();

  /// Replaces the exclusions.
  Future<void> save(NetWorthFilter filter);
}
