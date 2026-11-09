import 'package:intl/intl.dart';

/// How dates are written (FR-28-31).
enum DateStyle {
  /// 7 Nov 2026.
  auto('Auto', 'd MMM yyyy', 'd MMM'),

  /// 07/11/2026.
  dayFirst('dd/mm/yyyy', 'dd/MM/yyyy', 'dd/MM'),

  /// 11/07/2026.
  monthFirst('mm/dd/yyyy', 'MM/dd/yyyy', 'MM/dd'),

  /// 2026-11-07.
  iso('yyyy-mm-dd', 'yyyy-MM-dd', 'MM-dd');

  const DateStyle(this.label, this._long, this._short);

  /// Choice label.
  final String label;
  final String _long;
  final String _short;

  /// Style by name; [auto] when unknown.
  static DateStyle of(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => auto);
}

/// The date style chosen in Customise, applied by every date the app writes
/// out (FR-28-31). Time stays 12-hour as before.
abstract final class AppDates {
  /// Active style.
  static DateStyle style = DateStyle.auto;

  /// [d] as date, with [year] by default, [weekday] in front, [time] after.
  static String format(
    DateTime d, {
    bool year = true,
    bool time = false,
    bool weekday = false,
  }) {
    final date = DateFormat(year ? style._long : style._short).format(d);
    final day = weekday ? '${DateFormat('EEE').format(d)}, ' : '';
    final at = time ? ', ${DateFormat('h:mm a').format(d)}' : '';
    return '$day$date$at';
  }
}
