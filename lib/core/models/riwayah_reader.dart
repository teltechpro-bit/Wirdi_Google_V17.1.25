class RiwayahReader {
  final String id;
  final String name;
  final String riwayahId;
  final String source;
  final String server;
  final Set<int> surahs;
  final bool hasAyahAudio;
  final Map<int, String> surahUrls;

  const RiwayahReader({
    required this.id,
    required this.name,
    required this.riwayahId,
    required this.source,
    required this.server,
    required this.surahs,
    this.hasAyahAudio = false,
    this.surahUrls = const <int, String>{},
  });

  bool supportsSurah(int surahNumber) => surahs.contains(surahNumber);
}
