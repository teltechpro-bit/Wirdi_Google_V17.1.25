/// Display strings for the Android Auto browse tree, in the app language.
/// [arabic] true → Arabic first; otherwise English (the car UI language the
/// user chose in Wirdi's settings.]
class WirdiBrowseText {
  final bool arabic;
  const WirdiBrowseText({required this.arabic});

  String get surahsFolder => arabic ? 'سور القرآن الكريم' : 'Quran Surahs';
  String get radioFolder => arabic ? 'إذاعات القرآن الكريم' : 'Quran Radio';
  String get quranAlbum => arabic ? 'القرآن الكريم' : 'The Holy Quran';

  String surahTitle(String arabicName, String englishName) {
    if (arabic) return arabicName;
    return englishName.isEmpty ? arabicName : englishName;
  }

  String surahSubtitle(String arabicName, String englishName) =>
      arabic ? englishName : arabicName;

  String stationTitle(String nameAr, String nameEn) {
    if (arabic) return nameAr.isNotEmpty ? nameAr : nameEn;
    return nameEn.isNotEmpty ? nameEn : nameAr;
  }

  String stationSubtitle(String nameAr, String nameEn) =>
      arabic ? nameEn : nameAr;
}