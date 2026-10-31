/// Short rupee text of [minor] paise: `19.6L`, `1.2Cr`, `45K` (chart axes
/// and the donut centre).
String compactMoney(int minor) {
  final r = minor.abs() / 100;
  final sign = minor < 0 ? '-' : '';
  String f(double v) => v >= 10 || v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1);
  if (r >= 1e7) return '$sign${f(r / 1e7)}Cr';
  if (r >= 1e5) return '$sign${f(r / 1e5)}L';
  if (r >= 1e3) return '$sign${f(r / 1e3)}K';
  return '$sign${r.round()}';
}
