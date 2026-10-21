/// A calendar date without a zone (the Kotlin `LocalDate`).
class CivilDate implements Comparable<CivilDate> {
  /// Creates a date; no validation (see [CivilDate.tryCreate]).
  const CivilDate(this.year, this.month, this.day);

  /// A date only when it exists on the calendar.
  static CivilDate? tryCreate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final d = DateTime.utc(year, month, day);
    if (d.year != year || d.month != month || d.day != day) return null;
    return CivilDate(year, month, day);
  }

  /// Year.
  final int year;

  /// Month, 1 to 12.
  final int month;

  /// Day of month.
  final int day;

  /// This date moved by [days].
  CivilDate plusDays(int days) {
    final d = DateTime.utc(year, month, day).add(Duration(days: days));
    return CivilDate(d.year, d.month, d.day);
  }

  /// This date moved back by [days].
  CivilDate minusDays(int days) => plusDays(-days);

  /// Whether this is later than [other].
  bool isAfter(CivilDate other) => compareTo(other) > 0;

  /// Whether this is earlier than [other].
  bool isBefore(CivilDate other) => compareTo(other) < 0;

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `yyyy-MM-dd`, as the dedup hash writes it.
  @override
  String toString() => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// A time of day without a zone (the Kotlin `LocalTime`).
class CivilTime {
  /// Creates a time of day.
  const CivilTime(this.hour, this.minute, [this.second = 0, this.milli = 0]);

  /// Hour, 0 to 23.
  final int hour;

  /// Minute.
  final int minute;

  /// Second.
  final int second;

  /// Millisecond.
  final int milli;

  @override
  bool operator ==(Object other) =>
      other is CivilTime &&
      other.hour == hour &&
      other.minute == minute &&
      other.second == second &&
      other.milli == milli;

  @override
  int get hashCode => Object.hash(hour, minute, second, milli);

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}:'
      '${second.toString().padLeft(2, '0')}';
}

/// The date and time of day of [epochMs] in the zone at [offset].
({CivilDate date, CivilTime time}) civilOf(int epochMs, Duration offset) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    epochMs + offset.inMilliseconds,
    isUtc: true,
  );
  return (
    date: CivilDate(d.year, d.month, d.day),
    time: CivilTime(d.hour, d.minute, d.second, d.millisecond),
  );
}

/// The local date of [epochMs] in the zone at [offset].
CivilDate civilDateOf(int epochMs, Duration offset) =>
    civilOf(epochMs, offset).date;

/// The epoch milliseconds of [date] at [time] in the zone at [offset].
int epochOf(CivilDate date, CivilTime time, Duration offset) =>
    DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
      time.milli,
    ).millisecondsSinceEpoch -
    offset.inMilliseconds;
