import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';

/// Newest version found by the last successful check, `''` when none or the
/// installed one is current (FR-31-33, FR-31-35).
const knownUpdateKey = SettingKey<String>('known_update_version', '');

/// Version whose Home notice the user dismissed (FR-31-33).
const updateNoticeDismissedKey =
    SettingKey<String>('update_notice_dismissed', '');

/// JSON of the last successfully fetched release history (FR-31-30).
const releaseHistoryCacheKey = SettingKey<String>('release_history_cache', '');

/// Version the What's new sheet was last handled for (FR-31-36).
const lastSeenVersionKey = SettingKey<String>('last_seen_version', '');
