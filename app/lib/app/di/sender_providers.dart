import 'package:hisaab/app/di/pipeline_providers.dart';
import 'package:hisaab/features/sms_ingestion/domain/sender_overrides.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sender_providers.g.dart';

/// Saved edits to the bank sender list (FR-26-31).
@Riverpod(keepAlive: true)
SenderOverridesStore senderOverridesStore(Ref ref) =>
    KvSenderOverridesStore(ref.watch(keyValueStoreProvider));

/// In-memory copy used by the sender pre-filter; loads on first use.
@Riverpod(keepAlive: true)
SenderOverridesCache senderOverridesCache(Ref ref) =>
    SenderOverridesCache(ref.watch(senderOverridesStoreProvider));
