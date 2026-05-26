import 'package:hive_ce/hive.dart';

import 'rest_sound_player_stub.dart'
    if (dart.library.html) 'rest_sound_player_web.dart' as platform;

class RestSoundPlayer {
  const RestSoundPlayer._();

  static const String enabledKey = 'rest_sound_enabled';
  static const String assetPathKey = 'rest_sound_asset_path';
  static const String defaultAssetPath = 'assets/audio/rest_complete.wav';

  static bool isEnabled(Box<dynamic> settingsBox) {
    return settingsBox.get(enabledKey, defaultValue: true) != false;
  }

  static String assetPath(Box<dynamic> settingsBox) {
    final value = settingsBox.get(assetPathKey);

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return defaultAssetPath;
  }

  static Future<void> setEnabled(Box<dynamic> settingsBox, bool enabled) async {
    await settingsBox.put(enabledKey, enabled);
  }

  static Future<void> setAssetPath(Box<dynamic> settingsBox, String path) async {
    final cleaned = path.trim();

    if (cleaned.isEmpty) {
      await settingsBox.delete(assetPathKey);
      return;
    }

    await settingsBox.put(assetPathKey, cleaned);
  }

  static Future<void> playIfEnabled(Box<dynamic> settingsBox) async {
    if (!isEnabled(settingsBox)) {
      return;
    }

    await play(settingsBox);
  }

  static Future<void> play(Box<dynamic> settingsBox) async {
    await platform.playRestSound(assetPath(settingsBox));
  }
}
