import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

/// Arms the lock skip before the system document picker opens (FR-25-06).
class LockSkippingFileSource implements FileSource {
  /// Wraps [_inner].
  const LockSkippingFileSource(this._inner, this._skipper);

  final FileSource _inner;
  final LockSkipper _skipper;

  @override
  Future<PickedFile?> pick() {
    _skipper.skipNextLock();
    return _inner.pick();
  }
}
