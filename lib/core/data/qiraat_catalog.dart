class QiraatReading {
  final String id;
  final String nameAr;
  final String nameEn;
  final String imamAr;
  final String imamEn;
  final List<RiwayahOption> riwayat;

  const QiraatReading({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.imamAr,
    required this.imamEn,
    required this.riwayat,
  });

  String nameFor(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

class RiwayahOption {
  final String id;
  final String nameAr;
  final String nameEn;
  final String qiraatId;
  final bool hasVerifiedAyahAudio;
  final bool hasSurahAudio;
  final String? audioLabel;

  const RiwayahOption({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.qiraatId,
    this.hasVerifiedAyahAudio = false,
    this.hasSurahAudio = false,
    this.audioLabel,
  });

  String nameFor(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

class QiraatCatalog {
  QiraatCatalog._();

  static const List<QiraatReading> all = [
    QiraatReading(id: 'nafi', nameAr: 'نافع المدني', nameEn: 'Nafiʿ al-Madani', imamAr: 'نافع', imamEn: 'Nafiʿ', riwayat: [
      RiwayahOption(id: 'warsh', hasSurahAudio: true, nameAr: 'ورش عن نافع', nameEn: 'Warsh ʿan Nafiʿ', qiraatId: 'nafi', hasVerifiedAyahAudio: true, audioLabel: 'EveryAyah — Ibrahim Al-Dosary / Yassin Al-Jazaery'),
      RiwayahOption(id: 'qalun', hasSurahAudio: true, nameAr: 'قالون عن نافع', nameEn: 'Qalun ʿan Nafiʿ', qiraatId: 'nafi', audioLabel: 'MP3Quran — full-surah riwayah source'),
    ]),
    QiraatReading(id: 'ibn_kathir', nameAr: 'ابن كثير المكي', nameEn: 'Ibn Kathir al-Makki', imamAr: 'ابن كثير', imamEn: 'Ibn Kathir', riwayat: [
      RiwayahOption(id: 'al_bazzi', hasSurahAudio: true, nameAr: 'البزي عن ابن كثير', nameEn: 'Al-Bazzi ʿan Ibn Kathir', qiraatId: 'ibn_kathir', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'qunbul', hasSurahAudio: true, nameAr: 'قنبل عن ابن كثير', nameEn: 'Qunbul ʿan Ibn Kathir', qiraatId: 'ibn_kathir', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'abu_amr', nameAr: 'أبو عمرو البصري', nameEn: 'Abu ʿAmr al-Basri', imamAr: 'أبو عمرو', imamEn: 'Abu ʿAmr', riwayat: [
      RiwayahOption(id: 'al_duri_abu_amr', hasSurahAudio: true, nameAr: 'الدوري عن أبي عمرو', nameEn: 'Al-Duri ʿan Abu ʿAmr', qiraatId: 'abu_amr', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'al_susi', hasSurahAudio: true, nameAr: 'السوسي عن أبي عمرو', nameEn: 'Al-Susi ʿan Abu ʿAmr', qiraatId: 'abu_amr', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'ibn_amir', nameAr: 'ابن عامر الشامي', nameEn: 'Ibn ʿAmir al-Shami', imamAr: 'ابن عامر', imamEn: 'Ibn ʿAmir', riwayat: [
      RiwayahOption(id: 'hisham', hasSurahAudio: true, nameAr: 'هشام عن ابن عامر', nameEn: 'Hisham ʿan Ibn ʿAmir', qiraatId: 'ibn_amir', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'ibn_dhakwan', hasSurahAudio: true, nameAr: 'ابن ذكوان عن ابن عامر', nameEn: 'Ibn Dhakwan ʿan Ibn ʿAmir', qiraatId: 'ibn_amir', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'asim', nameAr: 'عاصم الكوفي', nameEn: 'ʿAsim al-Kufi', imamAr: 'عاصم', imamEn: 'ʿAsim', riwayat: [
      RiwayahOption(id: 'hafs', nameAr: 'حفص عن عاصم', nameEn: 'Hafs ʿan ʿAsim', qiraatId: 'asim', hasVerifiedAyahAudio: true, audioLabel: 'Al Quran Cloud / Islamic Network'),
      RiwayahOption(id: 'shuba', hasSurahAudio: true, nameAr: 'شعبة عن عاصم', nameEn: 'Shuʿbah ʿan ʿAsim', qiraatId: 'asim', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'hamza', nameAr: 'حمزة الزيات', nameEn: 'Hamzah al-Zayyat', imamAr: 'حمزة', imamEn: 'Hamzah', riwayat: [
      RiwayahOption(id: 'khalaf_hamza', hasSurahAudio: true, nameAr: 'خلف عن حمزة', nameEn: 'Khalaf ʿan Hamzah', qiraatId: 'hamza', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'khallad', nameAr: 'خلاد عن حمزة', nameEn: 'Khallad ʿan Hamzah', qiraatId: 'hamza', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'alkisai', nameAr: 'الكسائي', nameEn: 'Al-Kisaʾi', imamAr: 'الكسائي', imamEn: 'Al-Kisaʾi', riwayat: [
      RiwayahOption(id: 'abu_al_harith', nameAr: 'أبو الحارث عن الكسائي', nameEn: 'Abu al-Harith ʿan al-Kisaʾi', qiraatId: 'alkisai', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'al_duri_kisai', hasSurahAudio: true, nameAr: 'الدوري عن الكسائي', nameEn: 'Al-Duri ʿan al-Kisaʾi', qiraatId: 'alkisai', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'abu_jafar', nameAr: 'أبو جعفر المدني', nameEn: 'Abu Jaʿfar al-Madani', imamAr: 'أبو جعفر', imamEn: 'Abu Jaʿfar', riwayat: [
      RiwayahOption(id: 'ibn_wardan', nameAr: 'ابن وردان عن أبي جعفر', nameEn: 'Ibn Wardan ʿan Abu Jaʿfar', qiraatId: 'abu_jafar', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'ibn_jammaz', nameAr: 'ابن جماز عن أبي جعفر', nameEn: 'Ibn Jammaz ʿan Abu Jaʿfar', qiraatId: 'abu_jafar', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'yaqub', nameAr: 'يعقوب الحضرمي', nameEn: 'Yaʿqub al-Hadrami', imamAr: 'يعقوب', imamEn: 'Yaʿqub', riwayat: [
      RiwayahOption(id: 'ruways', hasSurahAudio: true, nameAr: 'رويس عن يعقوب', nameEn: 'Ruways ʿan Yaʿqub', qiraatId: 'yaqub', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'rawh', hasSurahAudio: true, nameAr: 'روح عن يعقوب', nameEn: 'Rawh ʿan Yaʿqub', qiraatId: 'yaqub', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'khalaf', nameAr: 'خلف العاشر', nameEn: 'Khalaf al-ʿAshir', imamAr: 'خلف', imamEn: 'Khalaf', riwayat: [
      RiwayahOption(id: 'ishaq', nameAr: 'إسحاق عن خلف', nameEn: 'Ishaq ʿan Khalaf', qiraatId: 'khalaf', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'idris', nameAr: 'إدريس عن خلف', nameEn: 'Idris ʿan Khalaf', qiraatId: 'khalaf', audioLabel: 'MP3Quran — riwayah source'),
    ]),
  ];

  static List<RiwayahOption> get allRiwayat =>
      all.expand((q) => q.riwayat).toList(growable: false);

  static RiwayahOption byId(String id) =>
      allRiwayat.firstWhere((r) => r.id == id, orElse: () => allRiwayat.first);
}
