import 'package:parser_core/src/text/rx.dart';
import 'package:parser_core/src/util/civil.dart';
import 'package:parser_core/src/util/strings.dart';

/// The date and time found in a message; either may be missing.
class DateTimeParts {
  /// Creates parts.
  const DateTimeParts(this.date, this.time);

  /// Calendar date, if the text gave a valid one.
  final CivilDate? date;

  /// Time of day, if the text gave one.
  final CivilTime? time;
}

/// Understands the date spellings Indian banks use: 25/09/26, 25-Sep-2026,
/// 25Sep26, 2026-09-25:10:15:32, Sep 25, 2026 (FR-06-07).
abstract final class DateTimeExtractor {
  static const _months = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';
  static final List<String> _monthNames = _months.split('|');
  static final RegExp _iso = rx(
    r'\b(20\d{2})[-/:](\d{1,2})[-/:](\d{1,2})(?:[\sT:]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
  );
  static final RegExp _dmy =
      rx(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})\b');
  static final _dMonY = Guarded(
    r'\b(\d{1,2})[-\s/]?(' + _months + r')[a-z]*\.?[-\s/,]*(\d{4}|\d{2})\b',
    _monthNames,
  );
  static final _monDY = Guarded(
    r'\b(' + _months + r')[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})\b',
    _monthNames,
  );
  static final RegExp _time = rx(
    r'\b([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?:\s*([ap])\.?m\b\.?)?',
  );
  static const _timeNearDate = 30;

  static final Map<String, int> _monthIndex = {
    for (var i = 0; i < _monthNames.length; i++) _monthNames[i]: i + 1,
  };

  /// Reads the earliest valid date and its time of day from [text].
  static DateTimeParts extract(String text, [String? lowerText]) {
    final lower = lowerText ?? text.toLowerCase();
    // The earliest date wins, so each later pattern only searches the text
    // before the best match so far.
    var scope = text;
    var bestEnd = 0;
    CivilDate? date;
    CivilTime? isoTime;

    void take(RegExpMatch m, CivilDate? d, CivilTime? time) {
      if (d == null) return;
      date = d;
      isoTime = time;
      bestEnd = m.end;
      scope = text.substring(0, m.start);
    }

    final iso = findFrom(_iso, scope);
    if (iso != null) {
      final time = grp(iso, 4).isNotEmpty
          ? _timeOf(grp(iso, 4), grp(iso, 5), grp(iso, 6), '')
          : null;
      take(
        iso,
        _dateOf(
          int.parse(grp(iso, 1)),
          int.parse(grp(iso, 2)),
          int.parse(grp(iso, 3)),
        ),
        time,
      );
    }
    final dmy = findFrom(_dmy, scope);
    if (dmy != null) {
      take(
        dmy,
        _dateOf(
          _year(grp(dmy, 3)),
          int.parse(grp(dmy, 2)),
          int.parse(grp(dmy, 1)),
        ),
        null,
      );
    }
    if (_dMonY.allows(lower)) {
      final m = findFrom(_dMonY.regex, scope);
      if (m != null) {
        take(
          m,
          _dateOf(
            _year(grp(m, 3)),
            _monthIndex[grp(m, 2).toLowerCase()]!,
            int.parse(grp(m, 1)),
          ),
          null,
        );
      }
    }
    if (_monDY.allows(lower)) {
      final m = findFrom(_monDY.regex, scope);
      if (m != null) {
        take(
          m,
          _dateOf(
            int.parse(grp(m, 3)),
            _monthIndex[grp(m, 1).toLowerCase()]!,
            int.parse(grp(m, 2)),
          ),
          null,
        );
      }
    }

    if (isoTime != null) return DateTimeParts(date, isoTime);
    if (!text.contains(':')) return DateTimeParts(date, null);
    // Prefer a time printed right after the date; otherwise the first time in
    // the message.
    RegExpMatch? near;
    if (date != null) {
      final t = findFrom(_time, text, bestEnd);
      if (t != null && t.start - bestEnd <= _timeNearDate) near = t;
    }
    final time = near ?? findFrom(_time, text);
    return DateTimeParts(
      date,
      time == null
          ? null
          : _timeOf(grp(time, 1), grp(time, 2), grp(time, 3), grp(time, 4)),
    );
  }

  static int _year(String y) =>
      y.length == 2 ? 2000 + int.parse(y) : int.parse(y);

  static CivilDate? _dateOf(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000 || y > 2099) return null;
    return CivilDate.tryCreate(y, m, d);
  }

  static CivilTime? _timeOf(String h, String m, String s, String ampm) {
    var hour = int.parse(h);
    switch (ampm.toLowerCase()) {
      case 'p':
        if (hour < 12) hour += 12;
      case 'a':
        if (hour == 12) hour = 0;
    }
    if (hour < 0 || hour > 23) return null;
    return CivilTime(hour, int.parse(m), s.isEmpty ? 0 : int.parse(s));
  }
}
