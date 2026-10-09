/// Shared paths for Way2Quran audio stored in Wirdi's private app documents.
class Way2QuranStorage {
  Way2QuranStorage._();

  static const String recitationsRelativePath = 'way2quran/recitations';

  static String recitationFilePath(String appDocumentsPath, String slug) =>
      '$appDocumentsPath/$recitationsRelativePath/$slug.mp3';
}
