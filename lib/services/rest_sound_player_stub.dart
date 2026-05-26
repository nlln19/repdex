import 'package:flutter/services.dart';

Future<void> playRestSound(String assetPath) async {
  await SystemSound.play(SystemSoundType.alert);
}
