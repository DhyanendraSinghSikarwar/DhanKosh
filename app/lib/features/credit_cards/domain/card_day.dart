/// Day arithmetic for cards. Days are epoch days in IST; timestamps are epoch
/// ms.
abstract final class CardDay {
  /// IST offset in ms.
  static const istOffsetMs = 19800000;
  static const _dayMs = 86400000;

  /// Epoch day of [ms] in IST.
  static int ofMs(int ms) => (ms + istOffsetMs) ~/ _dayMs;

  /// Epoch ms at the start of [day] in IST.
  static int startMs(int day) => day * _dayMs - istOffsetMs;

  static DateTime _date(int day) =>
      DateTime.utc(1970).add(Duration(days: day));

  /// Epoch day of a calendar date.
  static int fromYmd(int y, int m, int d) =>
      DateTime.utc(y, m, d).difference(DateTime.utc(1970)).inDays;

  /// Day of month of [day].
  static int dayOfMonth(int day) => _date(day).day;

  /// Latest date <= [today] whose day of month is [dom] (clamped to the
  /// month length).
  static int latestWithDom(int dom, int today) {
    final t = _date(today);
    final here = _inMonth(t.year, t.month, dom);
    if (here <= today) return here;
    return _inMonth(t.year, t.month - 1, dom);
  }

  /// Same day of month in the month before [day]'s month.
  static int sameDomPrevMonth(int day) {
    final d = _date(day);
    return _inMonth(d.year, d.month - 1, d.day);
  }

  static int _inMonth(int y, int m, int dom) {
    final last = DateTime.utc(y, m + 1, 0).day;
    return fromYmd(y, m, dom > last ? last : dom);
  }
}
