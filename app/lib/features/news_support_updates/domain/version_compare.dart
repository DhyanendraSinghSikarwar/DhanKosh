/// True when [candidate] is newer than [current] (FR-31-17). Parts split on
/// `.` and `-`; non-numeric parts count as 0; missing parts pad with 0.
bool isNewer(String candidate, String current) {
  final a = _parts(candidate);
  final b = _parts(current);
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

List<int> _parts(String v) =>
    v.trim().split(RegExp('[.-]')).map((p) => int.tryParse(p) ?? 0).toList();
