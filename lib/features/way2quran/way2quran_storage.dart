import 'dart:io';

/// Shared paths for Way2Quran audio stored in Wirdi's private app documents.
class Way2QuranStorage {
  Way2QuranStorage._();

  static const String recitationsRelativePath = 'way2quran/recitations';
  static const String translationsRelativePath = 'way2quran/translations';

  /// Sanitizes API-derived filename stems before they are used in local paths.
  static String safeFileStem(String slug) {
    final safeStem = slug.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safeStem.isEmpty ? 'recitation' : safeStem;
  }

  static String recitationFilePath(String appDocumentsPath, String slug) =>
      '$appDocumentsPath/$recitationsRelativePath/${safeFileStem(slug)}.mp3';

  /// Stores each translation edition and surah in a separate private JSON file.
  static String translationFilePath(
    String appDocumentsPath,
    int surahNumber,
    String edition,
  ) =>
      '$appDocumentsPath/$translationsRelativePath/${surahNumber}_${safeFileStem(edition)}.json';

  /// Writes a completed download through a temporary file so interrupted
  /// network or disk writes never appear as a finished library item.
  static Future<File> writeBytesAtomically(File target, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw const FormatException('Cannot save an empty download');
    }
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.part');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      return await partial.rename(target.path);
    } catch (_) {
      try {
        if (await partial.exists()) await partial.delete();
      } catch (_) {
        // Keep the original write error.
      }
      rethrow;
    }
  }
}
