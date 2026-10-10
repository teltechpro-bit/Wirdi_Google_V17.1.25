/// Shared paths for Way2Quran audio stored in Wirdi's private app documents.
class Way2QuranStorage {
  Way2QuranStorage._();

  static const String recitationsRelativePath = 'way2quran/recitations';

  /// Sanitizes API-derived filename stems before they are used in local paths.
  static String safeFileStem(String slug) {
    final safeStem = slug.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return safeStem.isEmpty ? 'recitation' : safeStem;
  }

  static String recitationFilePath(String appDocumentsPath, String slug) =>
      '$appDocumentsPath/$recitationsRelativePath/${safeFileStem(slug)}.mp3';
}
