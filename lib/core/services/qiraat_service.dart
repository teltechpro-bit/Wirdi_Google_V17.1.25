import 'package:shared_preferences/shared_preferences.dart';

import '../data/qiraat_catalog.dart';

class QiraatService {
  QiraatService._();
  static final QiraatService instance = QiraatService._();

  static const _riwayahKey = 'qiraat_selected_riwayah';
  String _selectedRiwayahId = 'hafs';

  String get selectedRiwayahId => _selectedRiwayahId;
  RiwayahOption get selectedRiwayah => QiraatCatalog.byId(_selectedRiwayahId);
  bool get isHafs => _selectedRiwayahId == 'hafs';
  bool get isWarsh => _selectedRiwayahId == 'warsh';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_riwayahKey);
    if (stored != null && QiraatCatalog.allRiwayat.any((r) => r.id == stored)) {
      _selectedRiwayahId = stored;
    }
  }

  Future<void> setRiwayah(String id) async {
    if (!QiraatCatalog.allRiwayat.any((r) => r.id == id)) return;
    _selectedRiwayahId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_riwayahKey, id);
  }

  /// Returns a real per-ayah URL only for mappings verified against a public
  /// source. Unsupported riwayat deliberately return null: Wirdi must never
  /// silently play Hafs while the UI says another riwayah is selected.
  String? ayahAudioUrl(int surahNumber, int ayahNumber, int globalAyahNumber, {String hafsEdition = 'ar.alafasy'}) {
    switch (_selectedRiwayahId) {
      case 'hafs':
        return 'https://cdn.islamic.network/quran/audio/128/$hafsEdition/$globalAyahNumber.mp3';
      case 'warsh':
        final s = surahNumber.toString().padLeft(3, '0');
        final a = ayahNumber.toString().padLeft(3, '0');
        return 'https://everyayah.com/data/warsh/warsh_ibrahim_aldosary_128kbps/$s$a.mp3';
      default:
        return null;
    }
  }

  String audioStatusFor(RiwayahOption r, String languageCode) {
    if (r.hasVerifiedAyahAudio) {
      return languageCode == 'ar' ? 'صوت آية-بآية متحقق' : 'Verified verse-by-verse audio';
    }
    return languageCode == 'ar' ? 'المصدر الصوتي الآية-بآية غير متاح بعد' : 'Verse-by-verse audio source not mapped yet';
  }
}
