import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/security_privacy/presentation/lock_controller.dart';
import 'package:hisaab/shared/ports/lock_skipper.dart';

class _ControllerSkipper implements LockSkipper {
  const _ControllerSkipper(this._ref);

  final Ref _ref;

  @override
  void skipNextLock() =>
      _ref.read(lockControllerProvider.notifier).skipNextLock();
}

/// Lock skip port handed to data layers that open system UI (FR-25-06).
final lockSkipperProvider = Provider<LockSkipper>(_ControllerSkipper.new);
