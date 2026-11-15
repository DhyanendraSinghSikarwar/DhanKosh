import 'package:flutter/services.dart';
import 'package:hisaab/core/platform_channels/channel_base.dart';
import 'package:hisaab/core/platform_channels/channel_names.dart';

/// A folder the user chose with the system picker.
class PickedFolder {
  /// Creates a folder.
  const PickedFolder({
    required this.uri,
    required this.name,
    required this.provider,
  });

  /// Persistable tree address.
  final String uri;

  /// Folder name.
  final String name;

  /// "Google Drive", "This phone" or the provider's id.
  final String provider;
}

/// Typed wrapper for the `backup_folder` channel (F-24).
class FolderChannel extends ChannelBase {
  /// Creates the wrapper.
  const FolderChannel() : super(_channel);

  /// Opens the system folder picker; null when cancelled.
  Future<PickedFolder?> pick() async {
    final m = await invoke<Map<Object?, Object?>>('pick');
    final uri = m?['uri'] as String?;
    if (uri == null) return null;
    return PickedFolder(
      uri: uri,
      name: (m?['name'] as String?) ?? '',
      provider: (m?['provider'] as String?) ?? '',
    );
  }

  /// Whether the app may still write in [uri].
  Future<bool> canWrite(String uri) async =>
      (await invoke<bool>('canWrite', {'uri': uri})) ?? false;

  /// File names in [uri].
  Future<Set<String>> list(String uri) async => {
        for (final n in (await invoke<List<Object?>>('list', {'uri': uri})) ??
            const <Object?>[])
          n! as String,
      };

  /// Writes [bytes] as [name] in [uri], replacing a file of that name.
  Future<void> write(String uri, String name, Uint8List bytes) async {
    await invoke<bool>('write', {'uri': uri, 'name': name, 'bytes': bytes});
  }

  static const MethodChannel _channel =
      MethodChannel(ChannelNames.backupFolder);
}
