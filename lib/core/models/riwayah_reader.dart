class RiwayahReader {
  final String id;
  final String name;
  final String? nameAr;
  final String riwayahId;
  final String source;
  final String server;
  final Set<int> surahs;
  final bool hasAyahAudio;
  final Map<int, String> surahUrls;
  final int? timingReadId;

  const RiwayahReader({
    required this.id,
    required this.name,
    this.nameAr,
    required this.riwayahId,
    required this.source,
    required this.server,
    required this.surahs,
    this.hasAyahAudio = false,
    this.surahUrls = const <int, String>{},
    this.timingReadId,
  });

  String nameFor(String languageCode) =>
      languageCode == 'ar' && nameAr != null && nameAr!.trim().isNotEmpty ? nameAr! : name;

  bool supportsSurah(int surahNumber) => surahs.contains(surahNumber);
}
