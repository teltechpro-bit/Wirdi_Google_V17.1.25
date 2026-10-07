class QiraatReading {
  final String id;
  final String nameAr;
  final String nameEn;
  final String imamAr;
  final String imamEn;
  final List<RiwayahOption> riwayat;
  final String descriptionAr;
  final String descriptionEn;
  final String historyAr;
  final String historyEn;
  final String regionsAr;
  final String regionsEn;

  const QiraatReading({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.imamAr,
    required this.imamEn,
    required this.riwayat,
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.historyAr = '',
    this.historyEn = '',
    this.regionsAr = '',
    this.regionsEn = '',
  });

  String nameFor(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

class QiraatSecondaryRoute {
  final String id;
  final String nameAr;
  final String nameEn;
  final String qiraatId;
  final String routeAr;
  final String routeEn;

  const QiraatSecondaryRoute({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.qiraatId,
    this.routeAr = '',
    this.routeEn = '',
  });

  String nameFor(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
  String routeFor(String languageCode) => languageCode == 'ar' ? routeAr : routeEn;
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
    QiraatReading(id: 'nafi', nameAr: 'نافع المدني', nameEn: 'Nafiʿ al-Madani', imamAr: 'نافع', imamEn: 'Nafiʿ', descriptionAr: 'قراءة إمام أهل المدينة، اشتهرت بروايتي ورش وقالون، ولها حضور واسع في المغرب العربي وغرب أفريقيا.', descriptionEn: 'The reading of the imam of Madinah, transmitted chiefly through Warsh and Qalun, with a strong historical presence in North and West Africa.', historyAr: 'نشأت في المدرسة المدنية، واشتهرت بخصائص في الهمز والمد والإمالة والتقليل.', historyEn: 'It belongs to the Madinan school and is known for distinctive treatment of hamzah, madd, imalah and taqlil.', regionsAr: 'المغرب والجزائر وتونس وليبيا وغرب أفريقيا، مع حضور تاريخي في السودان ومصر.', regionsEn: 'North Africa and West Africa, with historical presence in Sudan and Egypt.', riwayat: [
      RiwayahOption(id: 'warsh', hasSurahAudio: true, nameAr: 'ورش عن نافع', nameEn: 'Warsh ʿan Nafiʿ', qiraatId: 'nafi', hasVerifiedAyahAudio: true, audioLabel: 'EveryAyah — Ibrahim Al-Dosary / Yassin Al-Jazaery'),
      RiwayahOption(id: 'qalun', hasSurahAudio: true, nameAr: 'قالون عن نافع', nameEn: 'Qalun ʿan Nafiʿ', qiraatId: 'nafi', audioLabel: 'MP3Quran — full-surah riwayah source'),
    ]),
    QiraatReading(id: 'ibn_kathir', nameAr: 'ابن كثير المكي', nameEn: 'Ibn Kathir al-Makki', imamAr: 'ابن كثير', imamEn: 'Ibn Kathir', descriptionAr: 'قراءة إمام أهل مكة، ذات جذور حجازية قديمة واتصال معروف بقراءة الصحابة.', descriptionEn: 'The reading of the imam of Makkah, rooted in the Hijazi tradition and connected to early Companions of the Prophet.', historyAr: 'تمثل المدرسة المكية، ومن سماتها أحكام في القصر والمد ومعاملة الهمز.', historyEn: 'It represents the Makkan school and includes distinctive treatment of madd and hamzah.', regionsAr: 'الحجاز وأجزاء من اليمن، وتُدرّس في مؤسسات القراءات.', regionsEn: 'The Hijaz and parts of Yemen, with continued teaching in specialist institutes.', riwayat: [
      RiwayahOption(id: 'al_bazzi', hasSurahAudio: true, nameAr: 'البزي عن ابن كثير', nameEn: 'Al-Bazzi ʿan Ibn Kathir', qiraatId: 'ibn_kathir', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'qunbul', hasSurahAudio: true, nameAr: 'قنبل عن ابن كثير', nameEn: 'Qunbul ʿan Ibn Kathir', qiraatId: 'ibn_kathir', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'abu_amr', nameAr: 'أبو عمرو البصري', nameEn: 'Abu ʿAmr al-Basri', imamAr: 'أبو عمرو', imamEn: 'Abu ʿAmr', descriptionAr: 'قراءة إمام أهل البصرة، واشتهرت بميزة الإدغام الكبير إلى جانب خصائصها في الأداء.', descriptionEn: 'The reading of the imam of Basrah, especially known for the feature of major idgham and distinctive vocal rules.', historyAr: 'تمثل المدرسة البصرية وتتصل بالحجاز بسند معروف في كتب القراءات.', historyEn: 'It represents the Basran school and preserves a documented transmission connected to the Hijaz.', regionsAr: 'البصرة وبلاد المشرق، مع انتشار تاريخي لرواية الدوري في أجزاء من أفريقيا.', regionsEn: 'Basrah and the eastern Islamic lands, with a historical presence of al-Duri in parts of Africa.', riwayat: [
      RiwayahOption(id: 'al_duri_abu_amr', hasSurahAudio: true, nameAr: 'الدوري عن أبي عمرو', nameEn: 'Al-Duri ʿan Abu ʿAmr', qiraatId: 'abu_amr', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'al_susi', hasSurahAudio: true, nameAr: 'السوسي عن أبي عمرو', nameEn: 'Al-Susi ʿan Abu ʿAmr', qiraatId: 'abu_amr', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'ibn_amir', nameAr: 'ابن عامر الشامي', nameEn: 'Ibn ʿAmir al-Shami', imamAr: 'ابن عامر', imamEn: 'Ibn ʿAmir', descriptionAr: 'قراءة إمام أهل الشام، وتتصل بسند مشهور عبر المغيرة بن أبي شهاب إلى عثمان بن عفان رضي الله عنه.', descriptionEn: 'The reading of the imam of the Levant, with a well-known chain through al-Mughira ibn Abi Shihab to Uthman ibn Affan.', historyAr: 'تمثل المدرسة الشامية، ولها خصائص في التفخيم والهمز.', historyEn: 'It represents the Levantine school and has distinctive features in tafkhim and hamzah.', regionsAr: 'بلاد الشام، مع استمرار تدريسها في مراكز القراءات.', regionsEn: 'The Levant, with continued teaching in specialist Quranic reading centers.', riwayat: [
      RiwayahOption(id: 'hisham', hasSurahAudio: true, nameAr: 'هشام عن ابن عامر', nameEn: 'Hisham ʿan Ibn ʿAmir', qiraatId: 'ibn_amir', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'ibn_dhakwan', hasSurahAudio: true, nameAr: 'ابن ذكوان عن ابن عامر', nameEn: 'Ibn Dhakwan ʿan Ibn ʿAmir', qiraatId: 'ibn_amir', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'asim', nameAr: 'عاصم الكوفي', nameEn: 'ʿAsim al-Kufi', imamAr: 'عاصم', imamEn: 'ʿAsim', descriptionAr: 'قراءة إمام من أئمة الكوفة، وتُعد رواية حفص عنها من أوسع الروايات انتشاراً في العالم الإسلامي.', descriptionEn: 'The reading of the Kufan imam whose transmission through Hafs is among the most widespread Quranic readings today.', historyAr: 'اشتهرت بدقة الأداء وانتشارها الواسع، مع روايتي حفص وشعبة.', historyEn: 'It became widely transmitted through Hafs and Shuʿbah and is known for precise performance.', regionsAr: 'واسعة الانتشار في العالم الإسلامي، مع غلبة حفص في المصاحف المطبوعة الحديثة.', regionsEn: 'Widely used across the Muslim world, with Hafs predominating in modern printed Qurans.', riwayat: [
      RiwayahOption(id: 'hafs', nameAr: 'حفص عن عاصم', nameEn: 'Hafs ʿan ʿAsim', qiraatId: 'asim', hasVerifiedAyahAudio: true, audioLabel: 'Al Quran Cloud / Islamic Network'),
      RiwayahOption(id: 'shuba', hasSurahAudio: true, nameAr: 'شعبة عن عاصم', nameEn: 'Shuʿbah ʿan ʿAsim', qiraatId: 'asim', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'hamza', nameAr: 'حمزة الزيات', nameEn: 'Hamzah al-Zayyat', imamAr: 'حمزة', imamEn: 'Hamzah', descriptionAr: 'قراءة إمام كوفي عُرفت بخصائص صوتية دقيقة في السكت والمد والهمز.', descriptionEn: 'A Kufan reading known for detailed vocal features involving pauses, madd and hamzah.', historyAr: 'تنتمي إلى المدرسة الكوفية وتحتاج إلى عناية في الأداء والتحرير.', historyEn: 'It belongs to the Kufan school and is studied with careful attention to its performance rules.', regionsAr: 'الكوفة وبلاد المشرق وأجزاء من الأناضول، مع حضورها في مراكز القراءات.', regionsEn: 'Kufa, eastern lands and parts of Anatolia, with continued specialist teaching.', riwayat: [
      RiwayahOption(id: 'khalaf_hamza', hasSurahAudio: true, nameAr: 'خلف عن حمزة', nameEn: 'Khalaf ʿan Hamzah', qiraatId: 'hamza', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'khallad', nameAr: 'خلاد عن حمزة', nameEn: 'Khallad ʿan Hamzah', qiraatId: 'hamza'),
    ]),
    QiraatReading(id: 'alkisai', nameAr: 'الكسائي الكوفي', nameEn: 'Al-Kisaʾi al-Kufi', imamAr: 'الكسائي', imamEn: 'Al-Kisaʾi', descriptionAr: 'قراءة إمام كوفي بارز جمع بين علم القراءة واللغة والنحو، وتميزت بكثرة الإمالة في مواضعها.', descriptionEn: 'A prominent Kufan reading associated with a leading scholar of recitation, Arabic language and grammar, known for extensive imalah in its places.', historyAr: 'تجمع خصائص من المدرسة الكوفية والمدنية، ولها أوجه أداء مميزة في الألفات والراءات وبعض الكلمات.', historyEn: 'It combines features associated with the Kufan and Madinan traditions, with distinctive treatment of alifs, ra and selected words.', regionsAr: 'العراق وإيران وخراسان تاريخياً، وتُدرّس اليوم في مراكز القراءات.', regionsEn: 'Historically Iraq, Iran and Khurasan, with teaching today in specialist centers.', riwayat: [
      RiwayahOption(id: 'abu_al_harith', nameAr: 'أبو الحارث عن الكسائي', nameEn: 'Abu al-Harith ʿan al-Kisaʾi', qiraatId: 'alkisai'),
      RiwayahOption(id: 'al_duri_kisai', hasSurahAudio: true, nameAr: 'الدوري عن الكسائي', nameEn: 'Al-Duri ʿan al-Kisaʾi', qiraatId: 'alkisai', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'abu_jafar', nameAr: 'أبو جعفر المدني', nameEn: 'Abu Jaʿfar al-Madani', imamAr: 'أبو جعفر', imamEn: 'Abu Jaʿfar', descriptionAr: 'قراءة مدنية قديمة، وهي من القراءات الثلاث الزائدة على السبع والمتممة للعشر.', descriptionEn: 'An early Madinan reading and one of the three readings that complete the canonical ten beyond the famous seven.', historyAr: 'تتميز بأوجه خاصة في الهمز والمد والإدغام، وحفظها علماء الإقراء عبر الأجيال.', historyEn: 'It has distinctive rules for hamzah, madd and idgham and has been preserved through specialist teaching.', regionsAr: 'السعودية ومصر والمغرب ومراكز القراءات المتخصصة.', regionsEn: 'Saudi Arabia, Egypt, Morocco and specialist Quranic reading institutions.', riwayat: [
      RiwayahOption(id: 'ibn_wardan', nameAr: 'ابن وردان عن أبي جعفر', nameEn: 'Ibn Wardan ʿan Abu Jaʿfar', qiraatId: 'abu_jafar'),
      RiwayahOption(id: 'ibn_jammaz', nameAr: 'ابن جماز عن أبي جعفر', nameEn: 'Ibn Jammaz ʿan Abu Jaʿfar', qiraatId: 'abu_jafar', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'yaqub', nameAr: 'يعقوب الحضرمي', nameEn: 'Yaʿqub al-Hadrami', imamAr: 'يعقوب', imamEn: 'Yaʿqub', descriptionAr: 'قراءة إمام بصري عُرفت بأوجه خاصة في الهاء والمد والهمز.', descriptionEn: 'A Basran reading known for distinctive treatment of silent ha, madd and hamzah.', historyAr: 'تنتمي إلى المدرسة البصرية وحُفظت ضمن منظومة القراءات العشر.', historyEn: 'It belongs to the Basran school and was preserved within the canonical ten.', regionsAr: 'البصرة والخليج تاريخياً، وتُدرّس في مؤسسات القراءات.', regionsEn: 'Basrah and the Gulf historically, with continued specialist teaching.', riwayat: [
      RiwayahOption(id: 'ruways', hasSurahAudio: true, nameAr: 'رويس عن يعقوب', nameEn: 'Ruways ʿan Yaʿqub', qiraatId: 'yaqub', audioLabel: 'MP3Quran — riwayah source'),
      RiwayahOption(id: 'rawh', hasSurahAudio: true, nameAr: 'روح عن يعقوب', nameEn: 'Rawh ʿan Yaʿqub', qiraatId: 'yaqub', audioLabel: 'MP3Quran — riwayah source'),
    ]),
    QiraatReading(id: 'khalaf', nameAr: 'خلف العاشر', nameEn: 'Khalaf al-ʿAshir', imamAr: 'خلف', imamEn: 'Khalaf', descriptionAr: 'قراءة خلف العاشر، وهي قراءة مستقلة لخلف بن هشام البزار ضمن القراءات العشر.', descriptionEn: 'The independent reading of Khalaf ibn Hisham al-Bazzar, included among the canonical ten.', historyAr: 'يجمع طريقها أوجهاً اختارها خلف من روايات متعددة، وتُدرس ضمن منظومة القراءات العشر الكبرى.', historyEn: 'Its transmission preserves choices made by Khalaf from multiple traditions and is studied within the ten major readings.', regionsAr: 'تُدرّس في مؤسسات القراءات العشر في مصر والسعودية وسائر البلدان الإسلامية.', regionsEn: 'Taught in specialist ten-reading institutions in Egypt, Saudi Arabia and elsewhere.', riwayat: [
      RiwayahOption(id: 'ishaq', nameAr: 'إسحاق عن خلف', nameEn: 'Ishaq ʿan Khalaf', qiraatId: 'khalaf'),
      RiwayahOption(id: 'idris', nameAr: 'إدريس عن خلف', nameEn: 'Idris ʿan Khalaf', qiraatId: 'khalaf'),
    ]),
  ];

  static const List<QiraatSecondaryRoute> secondaryRoutes = [
    QiraatSecondaryRoute(
      id: 'hafs_tayyibah',
      qiraatId: 'asim',
      nameAr: 'حفص عن عاصم من طريق الطيبة',
      nameEn: 'Hafs ʿan ʿAsim min Tariq al-Tayyibah',
      routeAr: 'طريق فرعي',
      routeEn: 'Secondary route',
    ),
    QiraatSecondaryRoute(
      id: 'warsh_al_azraq',
      qiraatId: 'nafi',
      nameAr: 'ورش عن نافع من طريق الأزرق',
      nameEn: 'Warsh ʿan Nafiʿ min Tariq al-Azraq',
      routeAr: 'طريق فرعي',
      routeEn: 'Secondary route',
    ),
    QiraatSecondaryRoute(
      id: 'warsh_al_asbahani',
      qiraatId: 'nafi',
      nameAr: 'ورش عن نافع من طريق الأصبهاني',
      nameEn: 'Warsh ʿan Nafiʿ min Tariq al-Asbahani',
      routeAr: 'طريق فرعي',
      routeEn: 'Secondary route',
    ),
    QiraatSecondaryRoute(
      id: 'ibn_kathir_combined',
      qiraatId: 'ibn_kathir',
      nameAr: 'البزي وقنبل عن ابن كثير — جمع',
      nameEn: 'Al-Bazzi wa Qunbul ʿan Ibn Kathir — combined',
      routeAr: 'جمع الروايتين',
      routeEn: 'Combined riwayat',
    ),
    QiraatSecondaryRoute(
      id: 'abu_jafar_combined',
      qiraatId: 'abu_jafar',
      nameAr: 'ابن وردان وابن جماز من طريق الدرة — جمع',
      nameEn: 'Ibn Wardan wa Ibn Jammaz min Tariq al-Durrah — combined',
      routeAr: 'جمع الروايتين',
      routeEn: 'Combined riwayat',
    ),
    QiraatSecondaryRoute(
      id: 'khalaf_combined',
      qiraatId: 'khalaf',
      nameAr: 'إسحاق الوراق وإدريس الحداد عن خلف البزار — جمع',
      nameEn: 'Ishaq al-Waraq and Idris al-Haddad ʿan Khalaf al-Bazzar — combined',
      routeAr: 'جمع الروايتين',
      routeEn: 'Combined riwayat',
    ),
  ];

  static List<QiraatSecondaryRoute> secondaryRoutesFor(String qiraatId) =>
      secondaryRoutes.where((route) => route.qiraatId == qiraatId).toList(growable: false);

  static List<RiwayahOption> get allRiwayat =>
      all.expand((q) => q.riwayat).toList(growable: false);

  static RiwayahOption byId(String id) =>
      allRiwayat.firstWhere((r) => r.id == id, orElse: () => allRiwayat.first);
}
