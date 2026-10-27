import 'package:hisaab/app/di/lock_skipper_provider.dart';
import 'package:hisaab/core/share/share_plus_gateway.dart';
import 'package:hisaab/shared/ports/share_gateway.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_providers.g.dart';

/// System share sheet; override in tests.
@Riverpod(keepAlive: true)
ShareGateway shareGateway(Ref ref) =>
    SharePlusGateway(lockSkipper: ref.watch(lockSkipperProvider));
