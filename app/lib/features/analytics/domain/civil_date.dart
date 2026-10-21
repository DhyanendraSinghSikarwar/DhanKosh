/// Calendar helpers shared by the Phase 4 domain logic. A "day" is a UTC
/// midnight [DateTime] used only for its year, month and day. Pure Dart.

/// India Standard Time, the default bucketing offset (see memory 18 Open
/// Question 9: the old app used the device zone, the ledger day keys use IST).
const istOffset = Duration(hours: 5, minutes: 30);

const _msPerDay = 86400000;

/// The calendar day of [epochMs] at [offset] from UTC.
DateTime dayOf(int epochMs, {Duration offset = istOffset}) {
  final l =
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).add(offset);
  return DateTime.utc(l.year, l.month, l.day);
}

/// Epoch ms of local [hour]:[minute] on [day] at [offset].
int epochMsOf(DateTime day,
        {int hour = 0, int minute = 0, Duration offset = istOffset}) =>
    DateTime.utc(day.year, day.month, day.day, hour, minute)
        .millisecondsSinceEpoch -
    offset.inMilliseconds;

/// Whole days since 1970-01-01 of [day].
int epochDayOf(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
    _msPerDay;

/// The day for an epoch-day number.
DateTime fromEpochDay(int n) =>
    DateTime.fromMillisecondsSinceEpoch(n * _msPerDay, isUtc: true);

/// Days from [a] to [b] (negative when [b] is earlier).
int daysBetween(DateTime a, DateTime b) => epochDayOf(b) - epochDayOf(a);

/// Length of month [month] of [year].
int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Whole month difference of the year-months of [a] and [b].
int monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + (b.month - a.month);

/// [day] moved by [n] months, its day of month clamped to the new month.
DateTime addMonths(DateTime day, int n) {
  final idx = day.year * 12 + (day.month - 1) + n;
  final y = idx ~/ 12;
  final m = idx % 12 + 1;
  final d = day.day < daysInMonth(y, m) ? day.day : daysInMonth(y, m);
  return DateTime.utc(y, m, d);
}

/// The day [dom] of the month of [ym], clamped to the month length.
DateTime clampedDay(int year, int month, int dom) {
  final len = daysInMonth(year, month);
  return DateTime.utc(year, month, dom < len ? dom : len);
}

/// Same calendar day.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Stable sort by [compare] (Dart's `List.sort` is not guaranteed stable).
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final idx = <(int, T)>[
    for (final e in items.indexed) (e.$1, e.$2),
  ];
  idx.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in idx) e.$2];
}
