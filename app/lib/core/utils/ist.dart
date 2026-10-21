/// India Standard Time helpers (UTC+5:30, no DST). Days are epoch days.
abstract final class Ist {
  /// Offset in ms.
  static const offsetMs = 19800000;
  static const _dayMs = 86400000;

  /// Epoch day of [ms] in IST.
  static int dayOf(int ms) => (ms + offsetMs) ~/ _dayMs;

  /// The IST calendar date of [ms] as a UTC midnight `DateTime`.
  static DateTime dateOf(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms + offsetMs, isUtc: true)
          .let((d) => DateTime.utc(d.year, d.month, d.day));

  /// Epoch ms at IST midnight of the calendar date `y-m-d`.
  static int startMs(int y, int m, int d) =>
      DateTime.utc(y, m, d).millisecondsSinceEpoch - offsetMs;

  /// Days in month [m] of [y].
  static int lengthOfMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

  /// `yyyy-MM` of [ms] in IST.
  static String yearMonth(int ms) {
    final d = dateOf(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
