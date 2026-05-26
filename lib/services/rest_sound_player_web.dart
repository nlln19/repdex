import 'dart:html' as html;

Future<void> playRestSound(String assetPath) async {
  final normalizedPath = _normalizeFlutterWebAssetPath(assetPath);
  final audio = html.AudioElement(normalizedPath)
    ..preload = 'auto'
    ..volume = 1;

  try {
    await audio.play();
  } catch (_) {
    // Browsers may block audio if the user has not interacted with the page.
    // The workout flow is normally user-triggered, so this should work after
    // the first set button interaction. Failing silently keeps the timer usable.
  }
}

String _normalizeFlutterWebAssetPath(String assetPath) {
  final cleaned = assetPath.trim();

  if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
    return cleaned;
  }

  if (cleaned.startsWith('assets/')) {
    return 'assets/$cleaned';
  }

  return cleaned;
}
