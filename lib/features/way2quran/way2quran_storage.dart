/// Shared paths for Way2Quran audio stored in Wirdi's private app documents.
class Way2QuranStorage {
  Way2QuranStorage._();

  static const String recitationsRelativePath = 'way2quran/recitations';

  /// Builds a filename from API/user-derived data without allowing path
  /// separators or other characters to escape the private recitations folder.
  static String recitationFilePath(String appDocumentsPath, String slug) {
    final safeStem = slug.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final fileStem = safeStem.isEmpty ? 'recitation' : safeStem;
    return '$appDocumentsPath/$recitationsRelativePath/$fileStem.mp3';
  }
}
