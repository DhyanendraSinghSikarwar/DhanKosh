/// Time until the next 02:30 local (FR-02-14): today if still ahead, else
/// tomorrow.
Duration nextNightlyDelay(DateTime now, {int hour = 2, int minute = 30}) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = DateTime(now.year, now.month, now.day + 1, hour, minute);
  }
  return next.difference(now);
}
