/// SMS permission snapshot (FR-01-09).
class SmsPermissionState {
  /// Creates a state.
  const SmsPermissionState({this.granted = false, this.blocked = false});

  /// READ_SMS and RECEIVE_SMS granted.
  final bool granted;

  /// Only App settings can grant now.
  final bool blocked;
}
