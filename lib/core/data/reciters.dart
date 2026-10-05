class ReciterOption {
  final String id; // islamic.network / AlQuran.Cloud edition identifier
  final String displayName; // Arabic script, shown for the 'ar' locale
  final String latinDisplayName; // Transliterated, shown for other locales
  const ReciterOption(this.id, this.displayName, this.latinDisplayName);

  String displayNameFor(String languageCode) =>
      languageCode == 'ar' ? displayName : latinDisplayName;
}

/// Verified real reciter edition identifiers from the AlQuran.Cloud /
/// islamic.network CDN (https://api.alquran.cloud/v1/edition?format=audio).
class Reciters {
  Reciters._();

  static const List<ReciterOption> all = [
    ReciterOption('ar.alafasy', 'مشاري راشد العفاسي', 'Mishari Rashid Alafasy'),
    ReciterOption('ar.abdulbasitmurattal', 'عبد الباسط عبد الصمد (مرتل)', 'Abdul Basit Abdul Samad (Murattal)'),
    ReciterOption('ar.abdulbasitmujawwad', 'عبد الباسط عبد الصمد (مجود)', 'Abdul Basit Abdul Samad (Mujawwad)'),
    ReciterOption('ar.husary', 'محمود خليل الحصري (مرتل)', 'Mahmoud Khalil Al-Husary (Murattal)'),
    ReciterOption('ar.husarymujawwad', 'محمود خليل الحصري (مجود)', 'Mahmoud Khalil Al-Husary (Mujawwad)'),
    ReciterOption('ar.minshawi', 'محمد صديق المنشاوي (مرتل)', 'Mohamed Siddiq Al-Minshawi (Murattal)'),
    ReciterOption('ar.minshawimujawwad', 'محمد صديق المنشاوي (مجود)', 'Mohamed Siddiq Al-Minshawi (Mujawwad)'),
    ReciterOption('ar.mahermuaiqly', 'ماهر المعيقلي', 'Maher Al-Muaiqly'),
    ReciterOption('ar.abdurrahmaansudais', 'عبد الرحمن السديس', 'Abdul Rahman Al-Sudais'),
    ReciterOption('ar.saoodshuraym', 'سعود الشريم', 'Saood Ash-Shuraym'),
    ReciterOption('ar.hudhaify', 'علي بن عبد الرحمن الحذيفي', 'Ali Al-Hudhaify'),
    ReciterOption('ar.ghamadi', 'سعد الغامدي', 'Saad Al-Ghamadi'),
    ReciterOption('ar.shaatree', 'أبو بكر الشاطري', 'Abu Bakr Ash-Shaatree'),
    ReciterOption('ar.ahmedajamy', 'أحمد بن علي العجمي', 'Ahmed Al-Ajamy'),
    ReciterOption('ar.muhammadjibreel', 'محمد جبريل', 'Muhammad Jibreel'),
    ReciterOption('ar.yasseraddossari', 'ياسر الدوسري', 'Yasser Al-Dossari'),
    ReciterOption('ar.aymanswoid', 'أيمن سويد', 'Ayman Sowaid'),
    ReciterOption('ar.hanirifai', 'هاني الرفاعي', 'Hani Ar-Rifai'),
    ReciterOption('ar.nasserqatami', 'ناصر القطامي', 'Nasser Al-Qatami'),
  ];

  static ReciterOption byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}
