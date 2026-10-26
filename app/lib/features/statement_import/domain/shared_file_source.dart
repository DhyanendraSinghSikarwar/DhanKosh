import 'package:hisaab/features/statement_import/domain/statement_ports.dart';

/// Files other apps share with, or open in, DhanKosh (FR-05-26).
abstract interface class SharedFileSource {
  /// The waiting file, read once and then forgotten; null when none or when
  /// it is too large or unreadable.
  Future<PickedFile?> take();
}
