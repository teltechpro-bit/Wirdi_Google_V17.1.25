/// Media-id scheme used by the Android Auto browse tree. Kept free of Flutter/audio imports so the parsing rules can be unit-tested.
class WirdiBrowseIds {
  WirdiBrowseIds._();

  static const String surahs = 'wirdi:browse:surahs';
  static const String radio = 'wirdi:browse:radio';
  static const String surahPrefix = 'wirdi:surah:';
  static const String radioPrefix = 'wirdi:radio:';

  static String surah(int number) => '$surahPrefix$number';
  static String station(String id) => '$radioPrefix$id';

  /// Surah number 1..114, or null when [mediaId] is not a valid surah id.
  static int? parseSurah(String mediaId) {
    if (!mediaId.startsWith(surahPrefix)) return null;
    final n = int.tryParse(mediaId.substring(surahPrefix.length));
    return (n == null || n < 1 || n > 114) ? null : n;
  }

  /// Station id, or null when [mediaId] is not a station id or is empty.
  static String? parseStation(String mediaId) {
    if (!mediaId.startsWith(radioPrefix)) return null;
    final id = mediaId.substring(radioPrefix.length);
    return id.isEmpty ? null : id;
  }
}
